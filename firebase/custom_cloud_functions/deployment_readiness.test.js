const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  REQUIRED_FUNCTIONS,
  analyzeFunctionsDeployment,
  analyzeReadinessDeployCommand,
  parseFunctionsListJson,
} = require("./scripts/validate_deployment_readiness");

function deployedFunction({
  id,
  trigger = "callable",
  project = "smalltalk-2109b",
  codebase = "custom_cloud_functions",
  state = "ACTIVE",
  secrets = [],
  environmentVariables = {},
}) {
  const fn = {
    id,
    project,
    codebase,
    state,
    environmentVariables,
    secretEnvironmentVariables: secrets.map((key) => ({key})),
  };

  if (trigger === "callable") {
    fn.callableTrigger = {};
  } else if (trigger === "https") {
    fn.httpsTrigger = {};
  } else if (trigger === "scheduled") {
    fn.scheduleTrigger = {};
  } else if (trigger === "firestore") {
    fn.eventTrigger = {
      eventType: "providers/cloud.firestore/eventTypes/document.write",
    };
  } else if (trigger === "auth") {
    fn.eventTrigger = {
      eventType: "providers/firebase.auth/eventTypes/user.delete",
    };
  }

  return fn;
}

function completeDeployment() {
  return REQUIRED_FUNCTIONS.map((required) => deployedFunction({
    id: required.id,
    trigger: required.trigger,
    codebase: required.codebase || "custom_cloud_functions",
    secrets: required.secrets || [],
    environmentVariables: {...(required.environment || {})},
  }));
}

test("deployment readiness accepts the required critical functions", () => {
  const report = analyzeFunctionsDeployment(completeDeployment());

  assert.equal(report.ok, true);
  assert.equal(report.failures.length, 0);
  assert.equal(report.checkedFunctions, REQUIRED_FUNCTIONS.length);
});

test("deployment readiness requires the Expatlio RevenueCat app id", () => {
  const deployment = completeDeployment();
  const webhook = deployment.find((fn) => fn.id === "revenueCatWebhook");
  webhook.environmentVariables.REVENUECAT_APP_ID = "wrong_app";

  const report = analyzeFunctionsDeployment(deployment);

  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.id === "revenueCatWebhook" &&
      failure.reason === "missing_required_environment",
  ));
});

test("deployment readiness fails missing critical functions", () => {
  const report = analyzeFunctionsDeployment([
    deployedFunction({id: "acceptCall"}),
    deployedFunction({id: "createVideoSession"}),
  ]);
  const missingIds = report.failures
    .filter((failure) => failure.reason === "missing_function")
    .map((failure) => failure.id);

  assert.equal(report.ok, false);
  assert.ok(missingIds.includes("dailyWebhook"));
  assert.ok(missingIds.includes("getSessionTokens"));
  assert.ok(missingIds.includes("getDeepgramToken"));
  assert.ok(missingIds.includes("processExpiredNotifications"));
  assert.ok(missingIds.includes("markSessionConnected"));
  assert.ok(missingIds.includes("startSearch"));
  assert.ok(missingIds.includes("heartbeatSearch"));
  assert.ok(missingIds.includes("cleanupStaleSearchRequests"));
  assert.ok(missingIds.includes("stopSearch"));
  assert.ok(missingIds.includes("getDirectCallStatus"));
  assert.ok(missingIds.includes("syncUserPublicProfile"));
  assert.ok(missingIds.includes("createEvent"));
  assert.ok(missingIds.includes("editEvent"));
  assert.ok(missingIds.includes("cancelEvent"));
  assert.ok(missingIds.includes("joinEvent"));
  assert.ok(missingIds.includes("leaveEvent"));
  assert.ok(missingIds.includes("sendEventChatMessage"));
  assert.ok(missingIds.includes("getEventChatAccessState"));
  assert.ok(missingIds.includes("sendCustomEmailVerification"));
  assert.ok(missingIds.includes("requestPasswordReset"));
  assert.ok(missingIds.includes("processPasswordResetRequest"));
  assert.ok(missingIds.includes("submitReview"));
  assert.ok(missingIds.includes("getEventHistory"));
  assert.ok(missingIds.includes("getCallHistory"));
  assert.ok(missingIds.includes("translateTerm"));
  assert.ok(missingIds.includes("saveTranslatedTerm"));
  assert.ok(missingIds.includes("generateCallFeedback"));
  assert.ok(missingIds.includes("cleanupUserCallIntegrationsOnDelete"));
});

test("deployment readiness requires core call runtime exports", () => {
  const deployedWithoutCreate = completeDeployment()
    .filter((fn) => fn.id !== "createVideoSession");
  const deployedWithoutTokens = completeDeployment()
    .filter((fn) => fn.id !== "getSessionTokens");

  const createReport = analyzeFunctionsDeployment(deployedWithoutCreate);
  const tokenReport = analyzeFunctionsDeployment(deployedWithoutTokens);

  assert.equal(createReport.ok, false);
  assert.equal(tokenReport.ok, false);
  assert.ok(createReport.failures.some((failure) =>
    failure.id === "createVideoSession" &&
      failure.reason === "missing_function",
  ));
  assert.ok(tokenReport.failures.some((failure) =>
    failure.id === "getSessionTokens" &&
      failure.reason === "missing_function",
  ));
});

test("deployment readiness exposes no event chat message mutation callables", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];
  const disallowedIds = [
    "editEventChatMessage",
    "updateEventChatMessage",
    "deleteEventChatMessage",
    "softDeleteEventChatMessage",
    "hardDeleteEventChatMessage",
  ];

  assert.ok(functionIds.has("sendEventChatMessage"));
  assert.ok(functionIds.has("getEventChatAccessState"));
  assert.match(indexSource, /exports\.sendEventChatMessage\b/);
  assert.match(indexSource, /exports\.getEventChatAccessState\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:sendEventChatMessage\b/);
  assert.match(
      deployScript,
      /functions:custom_cloud_functions:getEventChatAccessState\b/,
  );
  for (const id of disallowedIds) {
    assert.equal(functionIds.has(id), false);
    assert.doesNotMatch(indexSource, new RegExp(`exports\\.${id}\\b`));
    assert.doesNotMatch(
        deployScript,
        new RegExp(`functions:custom_cloud_functions:${id}\\b`),
    );
  }
});

test("deployment readiness exposes event report callable", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.ok(functionIds.has("reportEvent"));
  assert.ok(functionIds.has("reportEventChatMessage"));
  assert.match(indexSource, /exports\.reportEvent\b/);
  assert.match(indexSource, /exports\.reportEventChatMessage\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:reportEvent\b/);
  assert.match(
      deployScript,
      /functions:custom_cloud_functions:reportEventChatMessage\b/,
  );
});

test("deployment readiness exposes event history callable and index", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];
  const firestoreIndexes = JSON.parse(fs.readFileSync(
      path.join(__dirname, "..", "firestore.indexes.json"),
      "utf8",
  ));
  const hasParticipantsHistoryIndex = firestoreIndexes.indexes.some((index) =>
    index.collectionGroup === "participants" &&
      index.queryScope === "COLLECTION_GROUP" &&
      JSON.stringify(index.fields) === JSON.stringify([
        {fieldPath: "userId", order: "ASCENDING"},
        {fieldPath: "joinedAt", order: "DESCENDING"},
        {fieldPath: "__name__", order: "DESCENDING"},
      ]),
  );

  assert.ok(functionIds.has("getEventHistory"));
  assert.match(indexSource, /exports\.getEventHistory\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:getEventHistory\b/);
  assert.equal(hasParticipantsHistoryIndex, true);
});

test("deployment readiness exposes call history callable", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.ok(functionIds.has("getCallHistory"));
  assert.match(indexSource, /exports\.getCallHistory\b/);
  assert.match(deployScript, /functions:custom_cloud_functions:getCallHistory\b/);
});

test("deployment readiness exposes translation and feedback callables", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
    path.join(__dirname, "index.js"),
    "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
    path.join(__dirname, "package.json"),
    "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];
  const focusedDeployScript = packageJson.scripts["deploy:call-integrations"];
  const firestoreIndexes = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "firestore.indexes.json"),
    "utf8",
  ));
  const hasCaptionFeedbackIndex = firestoreIndexes.indexes.some((index) =>
    index.collectionGroup === "captionLogs" &&
      index.queryScope === "COLLECTION" &&
      JSON.stringify(index.fields) === JSON.stringify([
        {fieldPath: "speakerId", order: "ASCENDING"},
        {fieldPath: "writerId", order: "ASCENDING"},
        {fieldPath: "source", order: "ASCENDING"},
        {fieldPath: "createdAtServer", order: "DESCENDING"},
      ]),
  );
  const ttlCollectionGroups = new Set(
    firestoreIndexes.fieldOverrides
      .filter((override) =>
        override.fieldPath === "expiresAt" && override.ttl === true,
      )
      .map((override) => override.collectionGroup),
  );

  for (const id of [
    "translateTerm",
    "saveTranslatedTerm",
    "generateCallFeedback",
    "cleanupUserCallIntegrationsOnDelete",
  ]) {
    assert.ok(functionIds.has(id));
    assert.match(indexSource, new RegExp(`exports\\.${id}\\b`));
    assert.match(
      deployScript,
      new RegExp(`functions:custom_cloud_functions:${id}\\b`),
    );
    assert.match(
      focusedDeployScript,
      new RegExp(`functions:custom_cloud_functions:${id}\\b`),
    );
  }
  assert.match(focusedDeployScript, /firestore:rules,firestore:indexes,/);
  assert.equal(hasCaptionFeedbackIndex, true);
  for (const collectionGroup of [
    "aiFeedback",
    "aiFeedbackRateLimits",
    "translationCache",
    "translationRateLimits",
  ]) {
    assert.ok(ttlCollectionGroups.has(collectionGroup));
  }
});

test("deployment readiness exposes the password reset queue", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];
  const firestoreIndexes = JSON.parse(fs.readFileSync(
      path.join(__dirname, "..", "firestore.indexes.json"),
      "utf8",
  ));
  const firebaseConfig = JSON.parse(fs.readFileSync(
      path.join(__dirname, "..", "firebase.json"),
      "utf8",
  ));
  const ttlCollectionGroups = new Set(
      firestoreIndexes.fieldOverrides
          .filter((override) =>
            override.fieldPath === "expiresAt" && override.ttl === true,
          )
          .map((override) => override.collectionGroup),
  );

  for (const id of ["requestPasswordReset", "processPasswordResetRequest"]) {
    assert.ok(functionIds.has(id));
    assert.match(indexSource, new RegExp(`exports\\.${id}\\b`));
    assert.match(
        deployScript,
        new RegExp(`functions:custom_cloud_functions:${id}\\b`),
    );
  }
  assert.match(deployScript, /firestore:rules,firestore:indexes,hosting,/);
  assert.equal(firebaseConfig.hosting.site, "smalltalk-2109b");
  assert.ok(ttlCollectionGroups.has("passwordResetRequests"));
  assert.ok(ttlCollectionGroups.has("passwordResetRateLimits"));
});

test("deployment readiness requires production integration flags", () => {
  const functionsList = completeDeployment();
  const feedback = functionsList.find((fn) => fn.id === "generateCallFeedback");
  delete feedback.environmentVariables.ENABLE_CALL_FEEDBACK;

  const report = analyzeFunctionsDeployment(functionsList);
  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.id === "generateCallFeedback" &&
      failure.reason === "missing_required_environment",
  ));
});

test("deployment readiness requires Expatlio APNs topics", () => {
  const functionsList = completeDeployment();
  const startSearch = functionsList.find((fn) => fn.id === "startSearch");
  startSearch.environmentVariables.IOS_BUNDLE_ID = "com.appwave.smalltalk";
  delete startSearch.environmentVariables.IOS_VOIP_TOPIC;

  const report = analyzeFunctionsDeployment(functionsList);
  assert.equal(report.ok, false);
  assert.ok(report.failures.some((failure) =>
    failure.id === "startSearch" &&
      failure.reason === "missing_required_environment",
  ));
});

test("deployment readiness exposes startSearch queue callable", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const readinessEntry = REQUIRED_FUNCTIONS.find(
      (item) => item.id === "startSearch",
  );
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const startSearchSource = fs.readFileSync(
      path.join(__dirname, "start_search.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.ok(functionIds.has("startSearch"));
  assert.deepEqual(readinessEntry.secrets, [
    "APNS_KEY_P8",
    "APNS_KEY_ID",
    "APNS_TEAM_ID",
  ]);
  assert.match(indexSource, /exports\.startSearch\b/);
  assert.match(startSearchSource, /exports\.startSearch\s*=\s*functions/);
  assert.match(
      startSearchSource,
      /\.runWith\(\{\s*secrets:\s*apnsSecrets\s*\}\)/,
  );
  assert.match(startSearchSource, /\.https\.onCall\(startSearchCallable\)/);
  assert.match(deployScript, /functions:custom_cloud_functions:startSearch\b/);
});

test("deployment readiness exposes heartbeatSearch queue callable", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.ok(functionIds.has("heartbeatSearch"));
  assert.match(indexSource, /exports\.heartbeatSearch\b/);
  assert.match(
      deployScript,
      /functions:custom_cloud_functions:heartbeatSearch\b/,
  );
});

test("deployment readiness exposes stale search cleanup scheduler", () => {
  const functionIds = new Set(REQUIRED_FUNCTIONS.map((item) => item.id));
  const readinessEntry = REQUIRED_FUNCTIONS.find(
      (item) => item.id === "cleanupStaleSearchRequests",
  );
  const indexSource = fs.readFileSync(
      path.join(__dirname, "index.js"),
      "utf8",
  );
  const packageJson = JSON.parse(fs.readFileSync(
      path.join(__dirname, "package.json"),
      "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.ok(functionIds.has("cleanupStaleSearchRequests"));
  assert.equal(readinessEntry.trigger, "scheduled");
  assert.match(indexSource, /exports\.cleanupStaleSearchRequests\b/);
  assert.match(deployScript, /--only firestore:rules,firestore:indexes,/);
  assert.match(
      deployScript,
      /functions:custom_cloud_functions:cleanupStaleSearchRequests\b/,
  );
});

test("readiness deployment includes rules and indexes atomically", () => {
  const packageJson = JSON.parse(fs.readFileSync(
    path.join(__dirname, "package.json"),
    "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.deepEqual(analyzeReadinessDeployCommand(deployScript).failures, []);
  assert.equal(
    analyzeReadinessDeployCommand(
      "firebase deploy --only firestore:indexes,functions:x",
    ).failures[0].message,
    "deploy:readiness-functions is missing firestore:rules",
  );
});

test("deployment source does not depend on retired Runtime Config", () => {
  const legacyConfigUsers = fs.readdirSync(__dirname)
    .filter((name) => name.endsWith(".js") && !name.endsWith(".test.js"))
    .filter((name) => {
      const source = fs.readFileSync(path.join(__dirname, name), "utf8");
      return /functions\.config(?:\?\.)?\s*\(/.test(source);
    });

  assert.deepEqual(legacyConfigUsers, []);
});

test("deployment readiness rejects wrong triggers and missing secrets", () => {
  const functionsList = completeDeployment().map((fn) => ({...fn}));
  const webhook = functionsList.find((fn) => fn.id === "dailyWebhook");
  delete webhook.httpsTrigger;
  webhook.callableTrigger = {};
  webhook.secretEnvironmentVariables = [{key: "DAILY_API_KEY"}];

  const report = analyzeFunctionsDeployment(functionsList);
  const reasons = report.failures.map((failure) => failure.reason);

  assert.equal(report.ok, false);
  assert.ok(reasons.includes("wrong_trigger"));
  assert.ok(reasons.includes("missing_secret_binding"));
});

test("deployment readiness rejects secret values in plain env vars", () => {
  const functionsList = completeDeployment();
  functionsList.push(deployedFunction({
    id: "acceptCall",
    environmentVariables: {
      DAILY_API_KEY: "not printed by report",
      APNS_KEY: "also not printed",
      REVENUECAT_SECRET_KEY: "also not printed",
    },
    secrets: ["DAILY_API_KEY"],
  }));

  const report = analyzeFunctionsDeployment(functionsList);
  const failures = report.failures.filter((item) =>
    item.reason === "plaintext_secret_environment_variable",
  );

  assert.equal(report.ok, false);
  assert.ok(failures.some((failure) =>
    failure.id === "acceptCall" && /DAILY_API_KEY/.test(failure.message),
  ));
  assert.ok(failures.some((failure) =>
    failure.id === "acceptCall" && /APNS_KEY/.test(failure.message),
  ));
  assert.ok(failures.some((failure) =>
    failure.id === "acceptCall" &&
      /REVENUECAT_SECRET_KEY/.test(failure.message),
  ));
  assert.doesNotMatch(JSON.stringify(failures), /not printed/);
  assert.doesNotMatch(JSON.stringify(failures), /also not printed/);
});

test("deployment readiness parses firebase functions:list json", () => {
  const parsed = parseFunctionsListJson(`
warning on stderr can be copied here
{"status":"success","result":[{"id":"dailyWebhook"}]}
`);

  assert.deepEqual(parsed, [{id: "dailyWebhook"}]);
});
