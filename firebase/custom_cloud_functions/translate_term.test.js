const test = require("node:test");
const assert = require("node:assert/strict");

const admin = require("firebase-admin");

const {
  __private__,
} = require("./translate_term");

class FakeDocumentSnapshot {
  constructor(reference, value) {
    this.ref = reference;
    this.exists = value !== undefined;
    this._value = value;
  }

  data() {
    return this._value;
  }
}

class FakeDocumentReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  collection(name) {
    return new FakeCollectionReference(this.firestore, `${this.path}/${name}`);
  }
}

class FakeCollectionReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  doc(id) {
    const resolvedId = id || `auto_${++this.firestore.autoId}`;
    return new FakeDocumentReference(
      this.firestore,
      `${this.path}/${resolvedId}`,
    );
  }
}

function isDeleteTransform(value) {
  return value && value.constructor &&
    value.constructor.name === "DeleteTransform";
}

function applyFields(existing, fields, {merge = false} = {}) {
  const next = merge ? {...(existing || {})} : {};
  for (const [key, value] of Object.entries(fields || {})) {
    if (isDeleteTransform(value)) {
      delete next[key];
    } else {
      next[key] = value;
    }
  }
  return next;
}

class FakeTransaction {
  constructor(firestore) {
    this.firestore = firestore;
    this.writes = [];
  }

  async get(reference) {
    return new FakeDocumentSnapshot(
      reference,
      this.firestore.documents.get(reference.path),
    );
  }

  set(reference, data, options) {
    this.writes.push({type: "set", reference, data, options});
  }

  update(reference, data) {
    this.writes.push({type: "update", reference, data});
  }

  create(reference, data) {
    this.writes.push({type: "create", reference, data});
  }

  commit() {
    for (const write of this.writes) {
      const path = write.reference.path;
      const existing = this.firestore.documents.get(path);
      if (write.type === "create" && existing !== undefined) {
        throw new Error(`Document already exists: ${path}`);
      }
      if (write.type === "update" && existing === undefined) {
        throw new Error(`Document does not exist: ${path}`);
      }
      this.firestore.documents.set(
        path,
        applyFields(existing, write.data, {
          merge: write.type === "update" || write.options?.merge === true,
        }),
      );
    }
  }
}

class FakeFirestore {
  constructor(seed = {}) {
    this.documents = new Map(Object.entries(seed));
    this.autoId = 0;
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  async runTransaction(callback) {
    const transaction = new FakeTransaction(this);
    const result = await callback(transaction);
    transaction.commit();
    return result;
  }

  read(path) {
    return this.documents.get(path);
  }

  paths(prefix) {
    return [...this.documents.keys()].filter((path) => path.startsWith(prefix));
  }
}

function activeSession(uid = "user-a") {
  return {
    status: "active",
    participantIds: [uid, "user-b"],
    requesterId: uid,
    responderId: "user-b",
  };
}

function callableContext(uid = "user-a") {
  return {
    auth: {uid},
    app: {appId: "test-app"},
  };
}

function translatePayload(overrides = {}) {
  return {
    text: "Привет",
    sourceLang: "ru",
    targetLang: "en",
    sessionId: "session-a",
    ...overrides,
  };
}

function assertDomainError(error, domainCode) {
  assert.equal(error.details?.domainCode, domainCode);
  return true;
}

test("normalizes translation input without folding case", () => {
  assert.equal(
    __private__.normalizeTranslationText("  May\u00a0  day  "),
    "May day",
  );
  assert.notEqual(
    __private__.translationCacheId({
      text: "May",
      sourceLang: "en",
      targetLang: "ru",
    }),
    __private__.translationCacheId({
      text: "may",
      sourceLang: "en",
      targetLang: "ru",
    }),
  );
});

test("validates required session and the ru-en language allowlist", () => {
  assert.deepEqual(
    __private__.normalizeTranslateRequest(translatePayload()),
    translatePayload(),
  );
  assert.throws(
    () => __private__.normalizeTranslateRequest(
      translatePayload({sessionId: null}),
    ),
    (error) => assertDomainError(error, "invalid_request"),
  );
  assert.throws(
    () => __private__.normalizeTranslateRequest(
      translatePayload({sourceLang: "de"}),
    ),
    (error) => assertDomainError(error, "invalid_request"),
  );
  assert.throws(
    () => __private__.normalizeTranslateRequest({
      ...translatePayload(),
      unexpected: true,
    }),
    (error) => assertDomainError(error, "invalid_request"),
  );
});

test("translateTerm requires authentication and App Check", async () => {
  const db = new FakeFirestore({
    "videoSessions/session-a": activeSession(),
  });
  const handler = __private__.createTranslateTermHandler({
    db,
    isFeatureEnabled: () => true,
    translateText: async () => "Hello",
  });

  await assert.rejects(
    handler(translatePayload(), {app: {appId: "test"}}),
    (error) => assertDomainError(error, "auth_required"),
  );
  await assert.rejects(
    handler(translatePayload(), {auth: {uid: "user-a"}}),
    (error) => assertDomainError(error, "app_check_required"),
  );
});

test("translateTerm calls provider once and reuses a case-sensitive cache", async () => {
  const db = new FakeFirestore({
    "videoSessions/session-a": activeSession(),
  });
  let nowMillis = Date.UTC(2026, 7, 4, 12, 0, 0);
  let providerCalls = 0;
  const handler = __private__.createTranslateTermHandler({
    db,
    now: () => nowMillis,
    leaseIdFactory: () => "lease-a",
    isFeatureEnabled: () => true,
    translateText: async (request) => {
      providerCalls += 1;
      assert.equal(request.text, "Привет");
      return "Hello";
    },
  });

  const first = await handler(translatePayload(), callableContext());
  nowMillis += 100;
  const second = await handler(translatePayload(), callableContext());

  assert.equal(first.translatedText, "Hello");
  assert.equal(first.cacheHit, false);
  assert.equal(second.cacheHit, true);
  assert.equal(providerCalls, 1);
  assert.equal(
    db.paths("users/user-a/translationLookups/").length,
    2,
  );
  const cacheId = __private__.translationCacheId({
    text: "Привет",
    sourceLang: "ru",
    targetLang: "en",
  });
  assert.equal(
    db.read(`translationCache/${cacheId}`).usageCount,
    2,
  );
  assert.equal(
    db.read("translationRateLimits/user-a").providerAttempts,
    1,
  );
});

test("translateTerm rejects nonparticipants and terminal sessions", async () => {
  const db = new FakeFirestore({
    "videoSessions/session-a": {
      ...activeSession("someone-else"),
      status: "ended",
    },
  });
  const handler = __private__.createTranslateTermHandler({
    db,
    isFeatureEnabled: () => true,
    translateText: async () => "Hello",
  });

  await assert.rejects(
    handler(translatePayload(), callableContext()),
    (error) => assertDomainError(error, "session_access_denied"),
  );

  db.documents.set("videoSessions/session-a", {
    ...activeSession(),
    status: "ended",
  });
  await assert.rejects(
    handler(translatePayload(), callableContext()),
    (error) => assertDomainError(error, "session_not_active"),
  );
});

test("translateTerm respects live cache leases and daily provider limits", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12, 0, 0);
  const request = translatePayload();
  const cacheId = __private__.translationCacheId({
    text: request.text,
    sourceLang: request.sourceLang,
    targetLang: request.targetLang,
  });
  const db = new FakeFirestore({
    "videoSessions/session-a": activeSession(),
    [`translationCache/${cacheId}`]: {
      status: "pending",
      sourceText: request.text,
      sourceLang: request.sourceLang,
      targetLang: request.targetLang,
      leaseId: "other",
      leaseExpiresAt: admin.firestore.Timestamp.fromMillis(nowMillis + 10000),
    },
  });
  const handler = __private__.createTranslateTermHandler({
    db,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
    translateText: async () => "Hello",
  });

  await assert.rejects(
    handler(request, callableContext()),
    (error) => assertDomainError(error, "translation_pending"),
  );

  db.documents.delete(`translationCache/${cacheId}`);
  db.documents.set("translationRateLimits/user-a", {
    dayKey: __private__.utcDayKey(nowMillis),
    providerAttempts: __private__.MAX_DAILY_PROVIDER_ATTEMPTS,
    lastProviderAttemptAt: admin.firestore.Timestamp.fromMillis(
      nowMillis - 2000,
    ),
  });
  await assert.rejects(
    handler(request, callableContext()),
    (error) => assertDomainError(error, "translation_daily_limit"),
  );
});

test("provider failure consumes an attempt and releases the cache lease", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12, 0, 0);
  const db = new FakeFirestore({
    "videoSessions/session-a": activeSession(),
  });
  const handler = __private__.createTranslateTermHandler({
    db,
    now: () => nowMillis,
    leaseIdFactory: () => "lease-failure",
    isFeatureEnabled: () => true,
    translateText: async () => {
      throw new Error("provider details must not escape");
    },
  });

  await assert.rejects(
    handler(translatePayload(), callableContext()),
    (error) => assertDomainError(
      error,
      "translation_provider_unavailable",
    ),
  );
  const cacheId = __private__.translationCacheId({
    text: "Привет",
    sourceLang: "ru",
    targetLang: "en",
  });
  const cache = db.read(`translationCache/${cacheId}`);
  assert.equal(cache.status, "failed");
  assert.equal(cache.leaseId, undefined);
  assert.equal(db.read("translationRateLimits/user-a").providerAttempts, 1);
});

test("saveTranslatedTerm creates deterministic word and review atomically", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12, 0, 0);
  const db = new FakeFirestore({
    "users/user-a/translationLookups/lookup-a": {
      ownerUid: "user-a",
      sourceText: "Привет",
      translatedText: "Hello",
      sourceLang: "ru",
      targetLang: "en",
      sessionRef: new FakeDocumentReference(dbPlaceholder(), "videoSessions/s"),
      savedToDictionary: false,
    },
  });
  const handler = __private__.createSaveTranslatedTermHandler({
    db,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
  });

  const result = await handler(
    {lookupId: "lookup-a"},
    callableContext(),
  );
  const wordId = __private__.translatedWordId({
    sourceLang: "ru",
    sourceText: "Привет",
  });
  assert.equal(result.wordPath, `users/user-a/userWords/${wordId}`);
  assert.equal(result.alreadyExisted, false);
  assert.equal(
    db.read(`users/user-a/userWords/${wordId}`).entry[0].tr[0].text,
    "Hello",
  );
  assert.equal(
    db.read(`users/user-a/wordReviews/${wordId}`).stage,
    1,
  );

  const repeated = await handler(
    {lookupId: "lookup-a"},
    callableContext(),
  );
  assert.equal(repeated.wordPath, result.wordPath);
  assert.equal(repeated.alreadyExisted, true);
});

function dbPlaceholder() {
  return {documents: new Map(), autoId: 0};
}

test("saveTranslatedTerm rejects incompatible legacy and deterministic words", async () => {
  const lookup = {
    ownerUid: "user-a",
    sourceText: "May",
    translatedText: "май",
    sourceLang: "en",
    targetLang: "ru",
    savedToDictionary: false,
  };
  const deterministicId = __private__.translatedWordId({
    sourceLang: "en",
    sourceText: "May",
  });
  const db = new FakeFirestore({
    "users/user-a/translationLookups/lookup-a": lookup,
    "users/user-a/userWords/legacy": {
      entry: [{text: "May", tr: [{text: "может"}]}],
      Sentence: [{text: "May I?", lang: "eng"}],
    },
    [`users/user-a/userWords/${deterministicId}`]: {
      ownerUid: "user-a",
      source: "client_collision",
      sourceLanguage: "en",
      targetLanguage: "ru",
      normalizedSourceText: "may",
      entry: [{text: "May", tr: [{text: "май"}]}],
    },
  });
  const handler = __private__.createSaveTranslatedTermHandler({
    db,
    isFeatureEnabled: () => true,
  });

  await assert.rejects(
    handler(
      {lookupId: "lookup-a", existingWordId: "legacy"},
      callableContext(),
    ),
    (error) => assertDomainError(error, "dictionary_word_mismatch"),
  );
  await assert.rejects(
    handler({lookupId: "lookup-a"}, callableContext()),
    (error) => assertDomainError(error, "dictionary_word_collision"),
  );
});
