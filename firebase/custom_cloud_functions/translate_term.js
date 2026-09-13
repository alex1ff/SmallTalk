const crypto = require("node:crypto");

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {TranslationServiceClient} = require("@google-cloud/translate");
const {createSafeConsole} = require("./safe_log");
const safeLog = createSafeConsole({source: "translate_term"});

const {
  isSessionParticipant,
} = require("./video_sessions_shared");

const TRANSLATION_REGION = "us-central1";
const TRANSLATION_TIMEOUT_SECONDS = 15;
const TRANSLATION_MEMORY = "256MB";
const MAX_TEXT_CHARACTERS = 250;
const MAX_DAILY_PROVIDER_ATTEMPTS = 30;
const PROVIDER_COOLDOWN_MS = 1000;
const PROVIDER_TIMEOUT_MS = 8000;
const LEASE_DURATION_MS = 15000;
const FAILURE_RETRY_MS = 5000;
const CACHE_TTL_MS = 180 * 24 * 60 * 60 * 1000;
const RATE_LIMIT_TTL_MS = 3 * 24 * 60 * 60 * 1000;
const ACTIVE_TRANSLATION_STATUSES = new Set([
  "connecting",
  "connected",
  "active",
]);
const ALLOWED_TRANSLATION_KEYS = new Set([
  "text",
  "sourceLang",
  "targetLang",
  "sessionId",
]);
const ALLOWED_SAVE_KEYS = new Set([
  "lookupId",
  "existingWordId",
]);
const LANGUAGE_ALIASES = Object.freeze({
  en: "en",
  eng: "en",
  ru: "ru",
  rus: "ru",
});

let translationClient;

function featureEnabled(rawValue) {
  return String(rawValue || "").trim().toLowerCase() === "true";
}

function defaultTranslationFeatureEnabled() {
  return featureEnabled(process.env.ENABLE_CALL_TRANSLATION);
}

function unicodeLength(value) {
  return Array.from(String(value || "")).length;
}

function normalizeTranslationText(rawText) {
  if (typeof rawText !== "string") {
    return "";
  }
  return rawText
    .normalize("NFC")
    .trim()
    .replace(/[\s\u00a0]+/gu, " ");
}

function normalizeDictionaryIdentity(rawText) {
  return normalizeTranslationText(rawText).toLocaleLowerCase("und");
}

function normalizeLanguageCode(rawCode) {
  if (typeof rawCode !== "string") {
    return "";
  }
  const normalized = rawCode.trim().toLowerCase().replaceAll("_", "-");
  const base = normalized.split("-")[0];
  return LANGUAGE_ALIASES[normalized] || LANGUAGE_ALIASES[base] || "";
}

function normalizeId(rawValue, fieldName, {optional = false} = {}) {
  if (rawValue === undefined || rawValue === null) {
    if (optional) return "";
    throwDomainError("invalid-argument", "invalid_request", {
      field: fieldName,
      reason: "required",
    });
  }
  if (typeof rawValue !== "string") {
    throwDomainError("invalid-argument", "invalid_request", {
      field: fieldName,
      reason: "invalid_type",
    });
  }
  const value = rawValue.trim();
  if (!value && optional) return "";
  if (!value || value.length > 200 || value.includes("/")) {
    throwDomainError("invalid-argument", "invalid_request", {
      field: fieldName,
      reason: "invalid_id",
    });
  }
  return value;
}

function validateExactKeys(data, allowedKeys) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throwDomainError("invalid-argument", "invalid_request", {
      field: "payload",
      reason: "invalid_type",
    });
  }
  for (const key of Object.keys(data)) {
    if (!allowedKeys.has(key)) {
      throwDomainError("invalid-argument", "invalid_request", {
        field: key,
        reason: "unknown_key",
      });
    }
  }
}

function normalizeTranslateRequest(data) {
  validateExactKeys(data, ALLOWED_TRANSLATION_KEYS);
  const text = normalizeTranslationText(data.text);
  if (!text || unicodeLength(text) > MAX_TEXT_CHARACTERS) {
    throwDomainError("invalid-argument", "invalid_request", {
      field: "text",
      reason: !text ? "required" : "too_long",
    });
  }

  const sourceLang = normalizeLanguageCode(data.sourceLang);
  const targetLang = normalizeLanguageCode(data.targetLang);
  const validPair =
    (sourceLang === "ru" && targetLang === "en") ||
    (sourceLang === "en" && targetLang === "ru");
  if (!validPair) {
    throwDomainError("invalid-argument", "invalid_request", {
      field: "languagePair",
      reason: "unsupported_pair",
    });
  }

  return {
    text,
    sourceLang,
    targetLang,
    sessionId: normalizeId(data.sessionId, "sessionId"),
  };
}

function normalizeSaveRequest(data) {
  validateExactKeys(data, ALLOWED_SAVE_KEYS);
  return {
    lookupId: normalizeId(data.lookupId, "lookupId"),
    existingWordId: normalizeId(
      data.existingWordId,
      "existingWordId",
      {optional: true},
    ),
  };
}

function throwDomainError(code, domainCode, details = {}) {
  throw new functions.https.HttpsError(
    code,
    domainCode,
    {domainCode, ...details},
  );
}

function requireCallableIdentity(context, {requireAppCheck = true} = {}) {
  const uid = context && context.auth && String(context.auth.uid || "").trim();
  if (!uid) {
    throwDomainError("unauthenticated", "auth_required");
  }
  if (requireAppCheck && !context.app) {
    throwDomainError("unauthenticated", "app_check_required");
  }
  return uid;
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : 0;
  }
  if (value instanceof Date) return value.getTime();
  const millis = Number(value);
  return Number.isFinite(millis) ? millis : 0;
}

function utcDayKey(nowMillis) {
  return new Date(nowMillis).toISOString().slice(0, 10);
}

function translationCacheId({text, sourceLang, targetLang}) {
  const digest = crypto
    .createHash("sha256")
    .update(`${sourceLang}\u0000${targetLang}\u0000${text}`, "utf8")
    .digest("hex");
  return `${sourceLang}_${targetLang}_${digest}`;
}

function translatedWordId({sourceLang, sourceText}) {
  const identity = normalizeDictionaryIdentity(sourceText);
  const digest = crypto
    .createHash("sha256")
    .update(`${sourceLang}|${identity}`, "utf8")
    .digest("hex");
  return `translation_${digest}`;
}

function randomLeaseId() {
  return crypto.randomUUID();
}

function projectIdFromEnvironment() {
  const direct = String(
    process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      "",
  ).trim();
  if (direct) return direct;

  try {
    const firebaseConfig = JSON.parse(process.env.FIREBASE_CONFIG || "{}");
    return String(firebaseConfig.projectId || "").trim();
  } catch (_) {
    return "";
  }
}

function defaultTranslateText(request) {
  if (!translationClient) {
    translationClient = new TranslationServiceClient();
  }
  const projectId = projectIdFromEnvironment();
  if (!projectId) {
    throw new Error("Google Cloud project ID is not configured");
  }

  return translationClient
    .translateText(
      {
        parent: `projects/${projectId}/locations/global`,
        contents: [request.text],
        mimeType: "text/plain",
        sourceLanguageCode: request.sourceLang,
        targetLanguageCode: request.targetLang,
      },
      {timeout: PROVIDER_TIMEOUT_MS},
    )
    .then(([response]) => {
      const translatedText = normalizeTranslationText(
        response && response.translations &&
          response.translations[0] &&
          response.translations[0].translatedText,
      );
      if (!translatedText) {
        throw new Error("Cloud Translation returned an empty result");
      }
      return translatedText;
    });
}

function toTimestamp(ms) {
  return admin.firestore.Timestamp.fromMillis(ms);
}

function buildLookupData({
  uid,
  request,
  translatedText,
  sessionRef,
  cacheHit,
  nowMillis,
}) {
  return {
    ownerUid: uid,
    sourceText: request.text,
    translatedText,
    sourceLang: request.sourceLang,
    targetLang: request.targetLang,
    sessionRef,
    cacheHit,
    savedToDictionary: false,
    createdAt: toTimestamp(nowMillis),
  };
}

function assertActiveSession(sessionSnap, uid) {
  if (!sessionSnap.exists) {
    throwDomainError("not-found", "session_not_found");
  }
  const sessionData = sessionSnap.data() || {};
  if (!isSessionParticipant(sessionData, uid)) {
    throwDomainError("permission-denied", "session_access_denied");
  }
  if (!ACTIVE_TRANSLATION_STATUSES.has(String(sessionData.status || ""))) {
    throwDomainError("failed-precondition", "session_not_active", {
      reason: "invalid_session_status",
    });
  }
  return sessionData;
}

function assertCacheMatchesRequest(cacheData, request) {
  if (
    cacheData.sourceText !== request.text ||
    cacheData.sourceLang !== request.sourceLang ||
    cacheData.targetLang !== request.targetLang
  ) {
    throwDomainError("internal", "translation_cache_collision");
  }
}

async function markTranslationFailed({
  db,
  cacheRef,
  leaseId,
  nowMillis,
  errorCode,
}) {
  await db.runTransaction(async (transaction) => {
    const cacheSnap = await transaction.get(cacheRef);
    if (!cacheSnap.exists) return;
    const cacheData = cacheSnap.data() || {};
    if (cacheData.status !== "pending" || cacheData.leaseId !== leaseId) {
      return;
    }
    transaction.update(cacheRef, {
      status: "failed",
      errorCode,
      retryAt: toTimestamp(nowMillis + FAILURE_RETRY_MS),
      updatedAt: toTimestamp(nowMillis),
      leaseId: admin.firestore.FieldValue.delete(),
      leaseExpiresAt: admin.firestore.FieldValue.delete(),
    });
  });
}

function createTranslateTermHandler({
  db,
  translateText = defaultTranslateText,
  now = () => Date.now(),
  leaseIdFactory = randomLeaseId,
  isFeatureEnabled = defaultTranslationFeatureEnabled,
  requireAppCheck = true,
} = {}) {
  return async (data, context) => {
    if (!isFeatureEnabled()) {
      throwDomainError("failed-precondition", "feature_disabled");
    }
    const uid = requireCallableIdentity(context, {requireAppCheck});
    const request = normalizeTranslateRequest(data);
    const firestore = db || admin.firestore();
    const nowMillis = Number(now());
    const dayKey = utcDayKey(nowMillis);
    const leaseId = leaseIdFactory();
    const cacheId = translationCacheId(request);
    const sessionRef = firestore
      .collection("videoSessions")
      .doc(request.sessionId);
    const cacheRef = firestore.collection("translationCache").doc(cacheId);
    const rateRef = firestore.collection("translationRateLimits").doc(uid);
    const lookupRef = firestore
      .collection("users")
      .doc(uid)
      .collection("translationLookups")
      .doc();

    const claim = await firestore.runTransaction(async (transaction) => {
      const [sessionSnap, cacheSnap, rateSnap] = await Promise.all([
        transaction.get(sessionRef),
        transaction.get(cacheRef),
        transaction.get(rateRef),
      ]);
      assertActiveSession(sessionSnap, uid);

      const cacheData = cacheSnap.exists ? cacheSnap.data() || {} : {};
      if (cacheSnap.exists) {
        assertCacheMatchesRequest(cacheData, request);
      }
      if (
        cacheData.status === "ready" &&
        typeof cacheData.translatedText === "string" &&
        normalizeTranslationText(cacheData.translatedText)
      ) {
        const translatedText = normalizeTranslationText(
          cacheData.translatedText,
        );
        transaction.update(cacheRef, {
          usageCount: Number(cacheData.usageCount || 0) + 1,
          lastUsedAt: toTimestamp(nowMillis),
          updatedAt: toTimestamp(nowMillis),
          expiresAt: toTimestamp(nowMillis + CACHE_TTL_MS),
        });
        transaction.set(
          lookupRef,
          buildLookupData({
            uid,
            request,
            translatedText,
            sessionRef,
            cacheHit: true,
            nowMillis,
          }),
        );
        return {kind: "ready", translatedText, cacheHit: true};
      }

      if (
        cacheData.status === "pending" &&
        timestampMillis(cacheData.leaseExpiresAt) > nowMillis
      ) {
        throwDomainError("aborted", "translation_pending", {
          retryAfterMs: Math.max(
            250,
            timestampMillis(cacheData.leaseExpiresAt) - nowMillis,
          ),
        });
      }
      if (
        cacheData.status === "failed" &&
        timestampMillis(cacheData.retryAt) > nowMillis
      ) {
        throwDomainError("unavailable", "translation_retry_later", {
          retryAfterMs: timestampMillis(cacheData.retryAt) - nowMillis,
        });
      }

      const rateData = rateSnap.exists ? rateSnap.data() || {} : {};
      const sameDay = rateData.dayKey === dayKey;
      const providerAttempts = sameDay ?
        Number(rateData.providerAttempts || 0) :
        0;
      if (providerAttempts >= MAX_DAILY_PROVIDER_ATTEMPTS) {
        throwDomainError("resource-exhausted", "translation_daily_limit");
      }
      const lastAttemptAt = sameDay ?
        timestampMillis(rateData.lastProviderAttemptAt) :
        0;
      if (lastAttemptAt && nowMillis - lastAttemptAt < PROVIDER_COOLDOWN_MS) {
        throwDomainError("resource-exhausted", "translation_cooldown", {
          retryAfterMs: PROVIDER_COOLDOWN_MS - (nowMillis - lastAttemptAt),
        });
      }

      transaction.set(
        rateRef,
        {
          dayKey,
          providerAttempts: providerAttempts + 1,
          lastProviderAttemptAt: toTimestamp(nowMillis),
          updatedAt: toTimestamp(nowMillis),
          expiresAt: toTimestamp(nowMillis + RATE_LIMIT_TTL_MS),
        },
        {merge: true},
      );
      transaction.set(
        cacheRef,
        {
          status: "pending",
          sourceText: request.text,
          sourceLang: request.sourceLang,
          targetLang: request.targetLang,
          provider: "google_cloud_translation_v3",
          leaseId,
          leaseExpiresAt: toTimestamp(nowMillis + LEASE_DURATION_MS),
          updatedAt: toTimestamp(nowMillis),
          expiresAt: toTimestamp(nowMillis + CACHE_TTL_MS),
          translatedText: admin.firestore.FieldValue.delete(),
          errorCode: admin.firestore.FieldValue.delete(),
          retryAt: admin.firestore.FieldValue.delete(),
        },
        {merge: true},
      );
      return {kind: "claimed"};
    });

    if (claim.kind === "ready") {
      return {
        sourceText: request.text,
        translatedText: claim.translatedText,
        sourceLang: request.sourceLang,
        targetLang: request.targetLang,
        lookupId: lookupRef.id,
        cacheHit: true,
      };
    }

    let translatedText;
    try {
      translatedText = normalizeTranslationText(await translateText(request));
      if (!translatedText || unicodeLength(translatedText) > 2000) {
        throw new Error("Translation provider returned an empty result");
      }
    } catch (error) {
      await markTranslationFailed({
        db: firestore,
        cacheRef,
        leaseId,
        nowMillis: Number(now()),
        errorCode: "provider_unavailable",
      }).catch(() => {});
      safeLog.error("translation_provider_failed", {
        errorType: error && error.name ? String(error.name) : "Error",
      });
      throwDomainError("unavailable", "translation_provider_unavailable");
    }

    const completedAt = Number(now());
    await firestore.runTransaction(async (transaction) => {
      const cacheSnap = await transaction.get(cacheRef);
      const cacheData = cacheSnap.exists ? cacheSnap.data() || {} : {};
      if (
        cacheData.status !== "pending" ||
        cacheData.leaseId !== leaseId
      ) {
        throwDomainError("aborted", "translation_lease_lost", {
          retryAfterMs: 250,
        });
      }
      assertCacheMatchesRequest(cacheData, request);
      transaction.set(
        cacheRef,
        {
          status: "ready",
          translatedText,
          provider: "google_cloud_translation_v3",
          usageCount: Number(cacheData.usageCount || 0) + 1,
          lastUsedAt: toTimestamp(completedAt),
          updatedAt: toTimestamp(completedAt),
          expiresAt: toTimestamp(completedAt + CACHE_TTL_MS),
          leaseId: admin.firestore.FieldValue.delete(),
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
          errorCode: admin.firestore.FieldValue.delete(),
          retryAt: admin.firestore.FieldValue.delete(),
        },
        {merge: true},
      );
      transaction.set(
        lookupRef,
        buildLookupData({
          uid,
          request,
          translatedText,
          sessionRef,
          cacheHit: false,
          nowMillis: completedAt,
        }),
      );
    });

    return {
      sourceText: request.text,
      translatedText,
      sourceLang: request.sourceLang,
      targetLang: request.targetLang,
      lookupId: lookupRef.id,
      cacheHit: false,
    };
  };
}

function normalizedEntryText(wordData) {
  const entries = Array.isArray(wordData && wordData.entry) ?
    wordData.entry :
    [];
  const first = entries[0];
  return normalizeDictionaryIdentity(first && first.text);
}

function normalizedTranslations(wordData) {
  const entries = Array.isArray(wordData && wordData.entry) ?
    wordData.entry :
    [];
  const translations =
    entries[0] && Array.isArray(entries[0].tr) ? entries[0].tr : [];
  return new Set(
    translations
      .map((translation) => normalizeDictionaryIdentity(translation.text))
      .filter(Boolean),
  );
}

function wordSourceLanguages(wordData) {
  const languages = new Set();
  const topLevel = normalizeLanguageCode(wordData && wordData.sourceLanguage);
  if (topLevel) languages.add(topLevel);
  const sentences = Array.isArray(wordData && wordData.Sentence) ?
    wordData.Sentence :
    [];
  for (const sentence of sentences) {
    const language = normalizeLanguageCode(sentence && sentence.lang);
    if (language) languages.add(language);
  }
  return languages;
}

function assertCompatibleExistingWord({
  wordData,
  lookupData,
  uid,
  deterministic,
}) {
  const expectedSource = normalizeDictionaryIdentity(lookupData.sourceText);
  const expectedTranslation = normalizeDictionaryIdentity(
    lookupData.translatedText,
  );
  const sourceLanguage = normalizeLanguageCode(lookupData.sourceLang);
  const targetLanguage = normalizeLanguageCode(lookupData.targetLang);

  if (normalizedEntryText(wordData) !== expectedSource) {
    throwDomainError("failed-precondition", "dictionary_word_mismatch");
  }
  if (!normalizedTranslations(wordData).has(expectedTranslation)) {
    throwDomainError("failed-precondition", "dictionary_word_mismatch");
  }

  if (deterministic) {
    if (
      wordData.ownerUid !== uid ||
      wordData.source !== "google_cloud_translation" ||
      normalizeLanguageCode(wordData.sourceLanguage) !== sourceLanguage ||
      normalizeLanguageCode(wordData.targetLanguage) !== targetLanguage ||
      normalizeDictionaryIdentity(wordData.normalizedSourceText) !==
        expectedSource
    ) {
      throwDomainError("failed-precondition", "dictionary_word_collision");
    }
    return;
  }

  if (!wordSourceLanguages(wordData).has(sourceLanguage)) {
    throwDomainError("failed-precondition", "dictionary_word_mismatch");
  }
}

function isOwnWordReference(reference, uid) {
  return Boolean(
    reference &&
      reference.path &&
      reference.path.startsWith(`users/${uid}/userWords/`) &&
      reference.path.split("/").length === 4,
  );
}

function createSaveTranslatedTermHandler({
  db,
  now = () => Date.now(),
  isFeatureEnabled = defaultTranslationFeatureEnabled,
  requireAppCheck = true,
} = {}) {
  return async (data, context) => {
    if (!isFeatureEnabled()) {
      throwDomainError("failed-precondition", "feature_disabled");
    }
    const uid = requireCallableIdentity(context, {requireAppCheck});
    const request = normalizeSaveRequest(data);
    const firestore = db || admin.firestore();
    const userRef = firestore.collection("users").doc(uid);
    const lookupRef = userRef.collection("translationLookups").doc(
      request.lookupId,
    );
    const nowMillis = Number(now());

    return firestore.runTransaction(async (transaction) => {
      const lookupSnap = await transaction.get(lookupRef);
      if (!lookupSnap.exists) {
        throwDomainError("not-found", "translation_lookup_not_found");
      }
      const lookupData = lookupSnap.data() || {};
      if (lookupData.ownerUid !== uid) {
        throwDomainError("permission-denied", "translation_lookup_denied");
      }
      if (
        !normalizeTranslationText(lookupData.sourceText) ||
        !normalizeTranslationText(lookupData.translatedText)
      ) {
        throwDomainError("failed-precondition", "translation_lookup_invalid");
      }
      const sourceLang = normalizeLanguageCode(lookupData.sourceLang);
      const targetLang = normalizeLanguageCode(lookupData.targetLang);
      if (!sourceLang || !targetLang || sourceLang === targetLang) {
        throwDomainError("failed-precondition", "translation_lookup_invalid");
      }

      if (lookupData.savedToDictionary === true) {
        if (!isOwnWordReference(lookupData.savedWordRef, uid)) {
          throwDomainError("internal", "saved_dictionary_reference_invalid");
        }
        return {
          wordPath: lookupData.savedWordRef.path,
          alreadyExisted: true,
        };
      }

      const deterministicWordId = translatedWordId({
        sourceLang,
        sourceText: lookupData.sourceText,
      });
      const wordId = request.existingWordId || deterministicWordId;
      const wordRef = userRef.collection("userWords").doc(wordId);
      const reviewRef = userRef.collection("wordReviews").doc(wordId);
      const [wordSnap, reviewSnap] = await Promise.all([
        transaction.get(wordRef),
        transaction.get(reviewRef),
      ]);
      const deterministic = wordId === deterministicWordId;

      if (wordSnap.exists) {
        assertCompatibleExistingWord({
          wordData: wordSnap.data() || {},
          lookupData,
          uid,
          deterministic,
        });
      } else {
        if (!deterministic) {
          throwDomainError("not-found", "dictionary_word_not_found");
        }
        transaction.create(wordRef, {
          addedAt: toTimestamp(nowMillis),
          entry: [
            {
              text: lookupData.sourceText,
              tr: [{text: lookupData.translatedText}],
            },
          ],
          Sentence: [],
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
          normalizedSourceText: normalizeDictionaryIdentity(
            lookupData.sourceText,
          ),
          translationLookupRef: lookupRef,
          sessionRef: lookupData.sessionRef || null,
          ownerUid: uid,
          source: "google_cloud_translation",
        });
      }

      if (!reviewSnap.exists) {
        transaction.create(reviewRef, {
          wordRef,
          stage: 1,
          dueAt: toTimestamp(nowMillis),
          createdAt: toTimestamp(nowMillis),
          updatedAt: toTimestamp(nowMillis),
        });
      }
      transaction.update(lookupRef, {
        savedToDictionary: true,
        savedWordRef: wordRef,
        savedAt: toTimestamp(nowMillis),
      });

      return {
        wordPath: wordRef.path,
        alreadyExisted: wordSnap.exists,
      };
    });
  };
}

const translateTermHandler = createTranslateTermHandler();
const saveTranslatedTermHandler = createSaveTranslatedTermHandler();

exports.translateTerm = functions
  .region(TRANSLATION_REGION)
  .runWith({
    timeoutSeconds: TRANSLATION_TIMEOUT_SECONDS,
    memory: TRANSLATION_MEMORY,
    enforceAppCheck: true,
  })
  .https.onCall(translateTermHandler);

exports.saveTranslatedTerm = functions
  .region(TRANSLATION_REGION)
  .runWith({
    timeoutSeconds: TRANSLATION_TIMEOUT_SECONDS,
    memory: TRANSLATION_MEMORY,
    enforceAppCheck: true,
  })
  .https.onCall(saveTranslatedTermHandler);

exports.__private__ = {
  ACTIVE_TRANSLATION_STATUSES,
  MAX_DAILY_PROVIDER_ATTEMPTS,
  PROVIDER_COOLDOWN_MS,
  assertCompatibleExistingWord,
  createSaveTranslatedTermHandler,
  createTranslateTermHandler,
  featureEnabled,
  normalizeDictionaryIdentity,
  normalizeLanguageCode,
  normalizeSaveRequest,
  normalizeTranslateRequest,
  normalizeTranslationText,
  projectIdFromEnvironment,
  translatedWordId,
  translationCacheId,
  utcDayKey,
};
