const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  buildReadOnlyVoipTokenState,
  buildVoipTokenUpdate,
  normalizeVoipTokenType,
  preserveLegacyCompanionToken,
  VOIP_TOKEN_FRESHNESS_MS,
} = require("./voip_tokens");
const {
  buildMatchProtocolCapabilityUpdate,
} = require("./register_voip_token").__private__;

function timestampFromMillis(millis) {
  return {toMillis: () => millis};
}

function readSource(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
}

function readVoipTokenRegistrySource() {
  return readSource("lib/services/voip_token_registry.dart");
}

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("VoIP token registration uses server-owned callable storage", () => {
  const source = readSource("lib/services/voip_service.dart");
  const registrySource = readVoipTokenRegistrySource();

  assert.match(source, /httpsCallable\('registerVoipToken'\)/);
  assert.match(source, /_tokenRegistry\.saveFcmToken/);
  assert.match(source, /_tokenRegistry\.syncPushKitToken/);
  assert.match(source, /invokeRegistration:\s*_invokeVoipTokenRegistration/);
  assert.match(registrySource, /'clearAll': true/);
  for (const sourceText of [source, registrySource]) {
    // Client code must not mention the persisted token field names at all.
    // This catches writes assembled before the Firestore call (reverse-order
    // maps) that a call-chain regex cannot reliably identify.
    assert.doesNotMatch(sourceText, /\bvoip(?:Push)?Token\b/);
    assert.doesNotMatch(
      sourceText,
      /collection\(\s*['"]users['"]\s*\)[\s\S]{0,300}(?:voipToken|voipPushToken)/,
    );
    assert.doesNotMatch(
      sourceText,
      /FirebaseFirestore(?:\.instance)?[\s\S]{0,300}(?:voipToken|voipPushToken)/,
    );
    assert.doesNotMatch(sourceText, /substring\(0,\s*20\)/);
  }
  assert.doesNotMatch(
    source,
    /collection\('users'\)\.doc\(user\.uid\)\.update\(\{\s*'voipToken'/s,
  );
  assert.doesNotMatch(
    source,
    /collection\('users'\)\.doc\(user\.uid\)\.update\(\{\s*'voipPushToken'/s,
  );
});

test("push senders read VoIP tokens through the private-token helper", () => {
  for (const fileName of [
    "accept_call.js",
    "create_video_session.js",
    "decline_call.js",
    "process_expired_notifications.js",
  ]) {
    const source = readFunctionSource(fileName);
    assert.match(source, /getUserVoipTokens/);
    assert.doesNotMatch(source, /Data\.voip(?:Push)?Token/);
    assert.doesNotMatch(source, /fcmToken\.substring/);
  }
});

test("legacy VoIP token migration is available and admin-gated", () => {
  const migrationSource = readFunctionSource("migrate_legacy_voip_tokens.js");
  const indexSource = readFunctionSource("index.js");
  const helperSource = readFunctionSource("voip_tokens.js");

  assert.match(migrationSource, /migrateLegacyVoipTokensBatch/);
  assert.match(migrationSource, /context\.auth\?\.token\?\.admin === true/);
  assert.match(migrationSource, /every 5 minutes/);
  assert.match(indexSource, /scheduledLegacyVoipTokenMigration/);
  assert.match(helperSource, /voipTokensClearedAt/);
  assert.match(helperSource, /isVoipTokenFallbackDisabled/);
  assert.match(helperSource, /transaction\.get\(privateRef\)/);
  assert.match(helperSource, /buildPrivateTokenDataFromLegacy\(currentLegacyData\)/);
});

test("Firestore rules block public user-doc VoIP token fields", () => {
  const rules = readSource("firebase/firestore.rules");

  assert.match(rules, /function privateUserTokenFields\(\)/);
  assert.match(rules, /function privateUserLifecycleFields\(\)/);
  assert.match(rules, /match \/userPrivateTokens\/\{userId\}/);
  assert.match(rules, /allow read, write: if false;/);
  assert.match(rules, /allow get, list: if canReadUserDocument\(userId\);/);
  assert.match(rules, /canUpdateOwnUser\(userId\)[\s\S]+privateUserTokenFields/);
  assert.match(rules, /canUpdateOwnUser\(userId\)[\s\S]+privateUserLifecycleFields/);
});

test("VoIP token helper accepts only known token types", () => {
  assert.equal(normalizeVoipTokenType("fcm"), "fcm");
  assert.equal(normalizeVoipTokenType("pushkit"), "pushkit");
  assert.equal(normalizeVoipTokenType("unknown"), "");
  assert.equal(buildVoipTokenUpdate("fcm", " token ")?.voipToken, "token");
  assert.equal(buildVoipTokenUpdate("pushkit", " token ")?.voipPushToken, "token");
  assert.equal(buildVoipTokenUpdate("fcm", ""), null);
});

test("VoIP token registration does not revive cleared legacy companions", () => {
  const update = buildVoipTokenUpdate("fcm", " private-fcm ");

  preserveLegacyCompanionToken(
    update,
    {voipPushToken: " legacy-push "},
    {voipTokensClearedAt: true},
  );

  assert.equal(update.voipToken, "private-fcm");
  assert.equal(update.voipPushToken, undefined);
});

test("read-only VoIP token state does not expose token strings", () => {
  assert.deepEqual(
    buildReadOnlyVoipTokenState({
      privateData: {voipToken: " private-fcm "},
      legacyUserData: {voipPushToken: " legacy-push "},
    }),
    {
      hasUsableToken: true,
      source: "private",
      hasFcmToken: true,
      hasFreshFcmToken: false,
      freshFcmTokenExpiresAtMillis: null,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasVoipPushToken: true,
    },
  );
  assert.deepEqual(
    buildReadOnlyVoipTokenState({
      privateData: {voipTokensClearedAt: true},
      legacyUserData: {
        voipPushToken: "legacy-push",
        voipToken: "legacy-fcm",
      },
    }),
    {
      hasUsableToken: false,
      source: "cleared",
      hasFcmToken: false,
      hasFreshFcmToken: false,
      freshFcmTokenExpiresAtMillis: null,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasVoipPushToken: false,
    },
  );
  assert.deepEqual(
    buildReadOnlyVoipTokenState({
      privateData: {
        voipTokensClearedAt: true,
        voipToken: " private-fcm ",
      },
      legacyUserData: {
        voipPushToken: "legacy-push",
      },
    }),
    {
      hasUsableToken: true,
      source: "private",
      hasFcmToken: true,
      hasFreshFcmToken: false,
      freshFcmTokenExpiresAtMillis: null,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasVoipPushToken: false,
    },
  );
  assert.deepEqual(
    buildReadOnlyVoipTokenState({
      legacyUserData: {voipPushToken: " legacy-push "},
    }),
    {
      hasUsableToken: true,
      source: "legacy",
      hasFcmToken: false,
      hasFreshFcmToken: false,
      freshFcmTokenExpiresAtMillis: null,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasVoipPushToken: true,
    },
  );
  assert.deepEqual(
    buildReadOnlyVoipTokenState({
      privateData: {voipPushToken: " private-push "},
    }),
    {
      hasUsableToken: true,
      source: "private",
      hasFcmToken: false,
      hasFreshFcmToken: false,
      freshFcmTokenExpiresAtMillis: null,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasVoipPushToken: true,
    },
  );
  assert.deepEqual(
    buildReadOnlyVoipTokenState({
      legacyUserData: {voipToken: " legacy-fcm "},
    }),
    {
      hasUsableToken: true,
      source: "legacy",
      hasFcmToken: true,
      hasFreshFcmToken: false,
      freshFcmTokenExpiresAtMillis: null,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasVoipPushToken: false,
    },
  );
});

test("fresh token state exposes expiry metadata without token values", () => {
  const nowMillis = 100_000;
  const updatedAtMillis = nowMillis - 1_000;
  const state = buildReadOnlyVoipTokenState({
    privateData: {
      voipPushToken: "private-push",
      voipPushTokenUpdatedAt: timestampFromMillis(updatedAtMillis),
    },
    nowMillis,
  });

  assert.equal(state.hasFreshVoipPushToken, true);
  assert.equal(
    state.freshVoipPushTokenExpiresAtMillis,
    updatedAtMillis + VOIP_TOKEN_FRESHNESS_MS,
  );
  assert.equal(JSON.stringify(state).includes("private-push"), false);
});

test("iOS FCM refresh never extends PushKit capability", () => {
  const nowMillis = 100_000;
  const pushExpiry = nowMillis + 2_000;
  const fcmExpiry = nowMillis + VOIP_TOKEN_FRESHNESS_MS;
  const update = buildMatchProtocolCapabilityUpdate({
    tokenType: "fcm",
    platform: "ios",
    requestedVersion: 2,
    nowMillis,
    tokenState: {
      hasVoipPushToken: true,
      hasFreshVoipPushToken: true,
      freshVoipPushTokenExpiresAtMillis: pushExpiry,
      hasFreshFcmToken: true,
      freshFcmTokenExpiresAtMillis: fcmExpiry,
    },
  });

  assert.equal(update.matchProtocolVersion, 2);
  assert.equal(update.v2CallKitCapable, true);
  assert.equal(update.v2CallKitCapabilityExpiresAt.toMillis(), pushExpiry);

  const stalePushUpdate = buildMatchProtocolCapabilityUpdate({
    tokenType: "fcm",
    platform: "ios",
    requestedVersion: 2,
    nowMillis,
    tokenState: {
      hasVoipPushToken: true,
      hasFreshVoipPushToken: false,
      freshVoipPushTokenExpiresAtMillis: null,
      hasFreshFcmToken: true,
      freshFcmTokenExpiresAtMillis: fcmExpiry,
    },
  });
  assert.equal(stalePushUpdate.matchProtocolVersion, 1);
  assert.equal(stalePushUpdate.v2CallKitCapable, false);
});

test("Android v2 capability follows the FCM token expiry", () => {
  const nowMillis = 100_000;
  const fcmExpiry = nowMillis + 5_000;
  const update = buildMatchProtocolCapabilityUpdate({
    tokenType: "fcm",
    platform: "android",
    requestedVersion: 2,
    nowMillis,
    tokenState: {
      hasFreshFcmToken: true,
      freshFcmTokenExpiresAtMillis: fcmExpiry,
    },
  });

  assert.equal(update.matchProtocolVersion, 2);
  assert.equal(update.v2CallKitCapabilityExpiresAt.toMillis(), fcmExpiry);
});
