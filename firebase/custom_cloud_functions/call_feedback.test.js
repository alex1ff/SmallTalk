const test = require("node:test");
const assert = require("node:assert/strict");

const admin = require("firebase-admin");

const {
  createGenerateCallFeedbackHandler,
  __private__,
} = require("./call_feedback");

class FakeDocumentSnapshot {
  constructor(reference, value) {
    this.ref = reference;
    this.id = reference.id;
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

  async get() {
    return new FakeDocumentSnapshot(
      this,
      this.firestore.documents.get(this.path),
    );
  }
}

class FakeQuery {
  constructor(firestore, path, filters = [], order = null, max = null) {
    this.firestore = firestore;
    this.path = path;
    this.filters = filters;
    this.order = order;
    this.max = max;
  }

  where(field, operator, value) {
    assert.equal(operator, "==");
    return new FakeQuery(
      this.firestore,
      this.path,
      [...this.filters, {field, value}],
      this.order,
      this.max,
    );
  }

  orderBy(field, direction) {
    return new FakeQuery(
      this.firestore,
      this.path,
      this.filters,
      {field, direction},
      this.max,
    );
  }

  limit(max) {
    return new FakeQuery(
      this.firestore,
      this.path,
      this.filters,
      this.order,
      max,
    );
  }

  async get() {
    const prefix = `${this.path}/`;
    let docs = [...this.firestore.documents.entries()]
      .filter(([path]) => {
        if (!path.startsWith(prefix)) return false;
        return !path.slice(prefix.length).includes("/");
      })
      .map(([path, value]) => new FakeDocumentSnapshot(
        new FakeDocumentReference(this.firestore, path),
        value,
      ))
      .filter((snapshot) => this.filters.every(
        ({field, value}) => snapshot.data()?.[field] === value,
      ));
    if (this.order) {
      const multiplier = this.order.direction === "desc" ? -1 : 1;
      docs.sort((left, right) => multiplier * (
        timestampMillis(left.data()?.[this.order.field]) -
        timestampMillis(right.data()?.[this.order.field])
      ));
    }
    if (this.max !== null) docs = docs.slice(0, this.max);
    return {docs, size: docs.length, empty: docs.length === 0};
  }
}

class FakeCollectionReference extends FakeQuery {
  doc(id) {
    return new FakeDocumentReference(this.firestore, `${this.path}/${id}`);
  }
}

function isDeleteTransform(value) {
  return value?.constructor?.name === "DeleteTransform";
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
    return reference.get();
  }

  set(reference, data, options) {
    this.writes.push({type: "set", reference, data, options});
  }

  update(reference, data) {
    this.writes.push({type: "update", reference, data});
  }

  commit() {
    for (const write of this.writes) {
      const existing = this.firestore.documents.get(write.reference.path);
      if (write.type === "update" && existing === undefined) {
        throw new Error(`Document does not exist: ${write.reference.path}`);
      }
      this.firestore.documents.set(
        write.reference.path,
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
}

function timestampMillis(value) {
  return typeof value?.toMillis === "function" ? value.toMillis() : Number(value);
}

function terminalSession(nowMillis, overrides = {}) {
  return {
    status: "ended",
    participantIds: ["user-a", "user-b"],
    requesterId: "user-a",
    responderId: "user-b",
    language: "en",
    endedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 20000),
    ...overrides,
  };
}

function caption(text, createdAt, overrides = {}) {
  return {
    speakerId: "user-a",
    writerId: "user-a",
    source: "local_deepgram_final",
    utteranceId: `utterance-${createdAt}`,
    text,
    createdAtServer: admin.firestore.Timestamp.fromMillis(createdAt),
    ...overrides,
  };
}

function validFeedback() {
  return {
    summary: "Good conversational control.",
    score: 82,
    strengths: ["Clear sentence structure."],
    corrections: [{
      original: "I go yesterday.",
      better: "I went yesterday.",
      explanation: "Use the past form for a completed event.",
    }],
    vocabulary: [{
      term: "confident",
      translation: "уверенный",
      example: "She sounded confident during the call.",
    }],
    nextPractice: "Retell yesterday's events using five past-tense verbs.",
  };
}

function callableContext(uid = "user-a") {
  return {auth: {uid}, app: {appId: "test-app"}};
}

function payload(overrides = {}) {
  return {sessionId: "session-a", outputLocale: "ru", ...overrides};
}

function assertDomainError(error, domainCode) {
  assert.equal(error.details?.domainCode, domainCode);
  return true;
}

function seededDb(nowMillis, captionText) {
  return new FakeFirestore({
    "videoSessions/session-a": terminalSession(nowMillis),
    "videoSessions/session-a/captionLogs/one": caption(
      captionText,
      nowMillis - 19000,
    ),
  });
}

test("validates callable input, authentication, and App Check", async () => {
  assert.deepEqual(__private__.normalizeFeedbackRequest(payload()), payload());
  assert.throws(
    () => __private__.normalizeFeedbackRequest(payload({outputLocale: "de"})),
    (error) => assertDomainError(error, "invalid_request"),
  );
  assert.throws(
    () => __private__.normalizeFeedbackRequest({...payload(), extra: true}),
    (error) => assertDomainError(error, "invalid_request"),
  );

  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const handler = createGenerateCallFeedbackHandler({
    db: seededDb(nowMillis, "A transcript with enough useful words for a test."),
    now: () => nowMillis,
    isFeatureEnabled: () => true,
  });
  await assert.rejects(
    handler(payload(), {app: {appId: "test"}}),
    (error) => assertDomainError(error, "auth_required"),
  );
  await assert.rejects(
    handler(payload(), {auth: {uid: "user-a"}}),
    (error) => assertDomainError(error, "app_check_required"),
  );
});

test("enforces terminal, connected, participant, and fourteen-day eligibility", () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const snap = (data) => ({exists: true, data: () => data});
  assert.equal(
    __private__.assertFeedbackEligibility(
      snap(terminalSession(nowMillis)),
      "user-a",
      nowMillis,
    ).terminalAt,
    nowMillis - 20000,
  );
  assert.throws(
    () => __private__.assertFeedbackEligibility(
      snap(terminalSession(nowMillis, {status: "active"})),
      "user-a",
      nowMillis,
    ),
    (error) => assertDomainError(error, "session_not_finished"),
  );
  assert.throws(
    () => __private__.assertFeedbackEligibility(
      snap(terminalSession(nowMillis, {status: "cancelled"})),
      "user-a",
      nowMillis,
    ),
    (error) => assertDomainError(error, "session_not_connected"),
  );
  assert.throws(
    () => __private__.assertFeedbackEligibility(
      snap(terminalSession(nowMillis, {
        endedAt: admin.firestore.Timestamp.fromMillis(
          nowMillis - 15 * 24 * 60 * 60 * 1000,
        ),
      })),
      "user-a",
      nowMillis,
    ),
    (error) => assertDomainError(error, "feedback_window_expired"),
  );
  assert.throws(
    () => __private__.assertFeedbackEligibility(
      snap(terminalSession(nowMillis)),
      "outsider",
      nowMillis,
    ),
    (error) => assertDomainError(error, "session_access_denied"),
  );
});

test("builds a chronological, deduplicated transcript and measures sufficiency", () => {
  const docs = [
    caption("This is the newest useful learner sentence.", 3),
    caption("Repeated sentence.", 2, {utteranceId: "repeat"}),
    caption("  Repeated   sentence. ", 1, {utteranceId: "repeat"}),
    caption("Other speaker text must not be supplied by the query.", 0, {
      speakerId: "user-b",
    }),
  ].map((data) => ({data: () => data}));
  const transcript = __private__.buildTranscript(docs.slice(0, 3));
  assert.deepEqual(
    transcript.entries.map((entry) => entry.text),
    ["Repeated sentence.", "This is the newest useful learner sentence."],
  );
  assert.equal(transcript.entries.every((entry) => entry.role === "learner"), true);
  assert.equal(transcript.sufficient, false);
});

test("strictly validates Gemini feedback at every nesting level", () => {
  assert.deepEqual(__private__.validateFeedbackResult(validFeedback()), validFeedback());
  assert.throws(
    () => __private__.validateFeedbackResult({...validFeedback(), extra: true}),
  );
  assert.throws(
    () => __private__.validateFeedbackResult({
      ...validFeedback(),
      corrections: [{
        ...validFeedback().corrections[0],
        hidden: "not allowed",
      }],
    }),
  );
  assert.throws(
    () => __private__.validateFeedbackResult({
      ...validFeedback(),
      nextPractice: "invalid\ncontrol",
    }),
  );
});

test("keeps generation alive through the caption settling period", async () => {
  let nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = Array.from({length: 25}, (_, index) => `word${index}`).join(" ");
  const db = seededDb(nowMillis, text);
  db.documents.set(
    "videoSessions/session-a",
    terminalSession(nowMillis, {
      endedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 5000),
    }),
  );
  let providerCalls = 0;
  const waits = [];
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
    wait: async (delayMs) => {
      waits.push(delayMs);
      nowMillis += delayMs;
    },
    generateFeedback: async () => {
      providerCalls += 1;
      return validFeedback();
    },
  });
  const result = await handler(payload(), callableContext());
  assert.equal(result.status, "ready");
  assert.deepEqual(waits, [10000]);
  assert.equal(providerCalls, 1);
  assert.equal(
    db.read("videoSessions/session-a/aiFeedback/user-a").status,
    "ready",
  );
});

test("caps settling when the terminal timestamp is in the future", async () => {
  let nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = Array.from({length: 25}, (_, index) => `word${index}`).join(" ");
  const db = seededDb(nowMillis, text);
  db.documents.set(
    "videoSessions/session-a",
    terminalSession(nowMillis, {
      endedAt: admin.firestore.Timestamp.fromMillis(nowMillis + 60000),
    }),
  );
  const waits = [];
  let providerCalls = 0;
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
    logProviderFailure: () => {},
    wait: async (delayMs) => {
      waits.push(delayMs);
      nowMillis += delayMs;
    },
    generateFeedback: async () => {
      providerCalls += 1;
      if (providerCalls === 1) {
        const error = new Error("provider timeout");
        error.name = "TimeoutError";
        throw error;
      }
      return validFeedback();
    },
  });

  const result = await handler(payload(), callableContext());
  assert.equal(result.status, "ready");
  assert.deepEqual(waits, [15000]);
  assert.equal(providerCalls, 2);
  assert.ok(
    15000 +
      __private__.MAX_PROVIDER_CALLS_PER_ATTEMPT *
        __private__.PROVIDER_TIMEOUT_MS <
      __private__.FEEDBACK_TIMEOUT_SECONDS * 1000,
  );
});

test("persists insufficient text without consuming Gemini quota", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const db = seededDb(nowMillis, "Too short.");
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
    generateFeedback: async () => {
      throw new Error("provider must not run");
    },
  });
  const result = await handler(payload(), callableContext());
  assert.deepEqual(result, {
    status: "insufficient_text",
    generationVersion: 3,
  });
  assert.equal(
    db.read("videoSessions/session-a/aiFeedback/user-a").status,
    "insufficient_text",
  );
  assert.equal(db.read("aiFeedbackRateLimits/user-a"), undefined);
});

test("generates once, stores private structured feedback, and reuses it", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = [
    "Yesterday I spoke with a colleague about our new project and deadlines.",
    "I explained the main problem, suggested a solution, and answered questions.",
    "Then we agreed on the next steps and scheduled another meeting for Friday.",
  ].join(" ");
  const db = seededDb(nowMillis, text);
  let providerCalls = 0;
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    leaseIdFactory: () => "lease-a",
    isFeatureEnabled: () => true,
    generateFeedback: async ({transcript, outputLocale, analyzedLanguage}) => {
      providerCalls += 1;
      assert.equal(transcript.length, 1);
      assert.equal(outputLocale, "ru");
      assert.equal(analyzedLanguage, "en");
      return validFeedback();
    },
  });
  const first = await handler(payload(), callableContext());
  const second = await handler(payload(), callableContext());
  const stored = db.read("videoSessions/session-a/aiFeedback/user-a");
  assert.equal(first.status, "ready");
  assert.deepEqual(second, first);
  assert.equal(providerCalls, 1);
  assert.equal(stored.ownerUid, "user-a");
  assert.equal(stored.status, "ready");
  assert.equal(stored.generationVersion, 3);
  assert.equal(stored.leaseId, undefined);
  assert.equal(stored.result.score, 82);
  assert.equal(db.read("aiFeedbackRateLimits/user-a").attemptCount, 1);
});

test("failed provider attempts become terminal after three tries", async () => {
  let nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = Array.from(
    {length: 25},
    (_, index) => `usefulword${index}`,
  ).join(" ");
  const db = seededDb(nowMillis, text);
  let providerCalls = 0;
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    leaseIdFactory: () => `lease-${providerCalls + 1}`,
    isFeatureEnabled: () => true,
    generateFeedback: async () => {
      providerCalls += 1;
      throw new Error("simulated provider failure");
    },
  });

  for (let attempt = 1; attempt <= 2; attempt += 1) {
    await assert.rejects(
      handler(payload(), callableContext()),
      (error) => assertDomainError(error, "feedback_generation_failed"),
    );
    nowMillis += 60000;
  }
  const terminal = await handler(payload(), callableContext());
  assert.deepEqual(terminal, {
    status: "failed_terminal",
    errorCode: "feedback_generation_failed",
    generationVersion: 3,
  });
  assert.equal(providerCalls, 3);
  assert.equal(
    db.read("videoSessions/session-a/aiFeedback/user-a").status,
    "failed_terminal",
  );
  assert.equal(db.read("aiFeedbackRateLimits/user-a").attemptCount, 3);
});

test("daily provider limit is enforced before a lease is acquired", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = Array.from({length: 25}, (_, index) => `word${index}`).join(" ");
  const db = seededDb(nowMillis, text);
  db.documents.set("aiFeedbackRateLimits/user-a", {
    dayKey: "2026-08-04",
    attemptCount: 10,
  });
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
    generateFeedback: async () => validFeedback(),
  });
  await assert.rejects(
    handler(payload(), callableContext()),
    (error) => assertDomainError(error, "feedback_daily_limit"),
  );
  assert.equal(db.read("videoSessions/session-a/aiFeedback/user-a"), undefined);
});

test("retries the production GenAI boundary after malformed JSON", async () => {
  const requests = [];
  const responses = [
    {
      text: "{",
      candidates: [{finishReason: "STOP"}],
    },
    {
      text: JSON.stringify(validFeedback()),
      candidates: [{finishReason: "STOP"}],
    },
  ];
  const client = {
    models: {
      generateContent: async (request) => {
        requests.push(request);
        return responses.shift();
      },
    },
  };
  const logged = [];
  const result = await __private__.generateValidatedFeedback({
    generateFeedback: (request) => __private__.defaultGenerateFeedback({
      ...request,
      client,
    }),
    transcript: [{role: "learner", text: "A useful transcript."}],
    outputLocale: "ru",
    analyzedLanguage: "en",
    modelId: "test-model",
    logProviderFailure: (metadata) => logged.push(metadata),
  });

  assert.deepEqual(result, validFeedback());
  assert.equal(requests.length, 2);
  assert.equal(requests[0].model, "test-model");
  assert.equal(requests[0].config.maxOutputTokens, 4096);
  assert.deepEqual(requests[0].config.thinkingConfig, {
    thinkingLevel: "MINIMAL",
  });
  assert.equal(requests[0].config.responseMimeType, "application/json");
  assert.equal(
    requests[0].config.responseJsonSchema,
    __private__.feedbackResponseJsonSchema,
  );
  assert.deepEqual(requests[0].config.httpOptions, {
    timeout: 40000,
    retryOptions: {attempts: 1},
  });
  assert.match(
    requests[1].contents[0].parts[0].text,
    /Return only one complete JSON object/u,
  );
  assert.deepEqual(logged, [{
    errorType: "FeedbackProviderOutputError",
    providerAttempt: 1,
    responseCharacterCount: 1,
    finishReason: "STOP",
  }]);
});

test("internal provider retry consumes one logical session attempt", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = Array.from({length: 25}, (_, index) => `word${index}`).join(" ");
  const db = seededDb(nowMillis, text);
  let providerCalls = 0;
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    leaseIdFactory: () => "single-logical-attempt",
    isFeatureEnabled: () => true,
    logProviderFailure: () => {},
    generateFeedback: async () => {
      providerCalls += 1;
      if (providerCalls === 1) {
        throw new __private__.FeedbackProviderOutputError("invalid_json", {
          responseCharacterCount: 50,
          finishReason: "STOP",
        });
      }
      return validFeedback();
    },
  });

  const result = await handler(payload(), callableContext());
  const stored = db.read("videoSessions/session-a/aiFeedback/user-a");
  assert.equal(result.status, "ready");
  assert.equal(providerCalls, 2);
  assert.equal(stored.attemptCount, 1);
  assert.equal(db.read("aiFeedbackRateLimits/user-a").attemptCount, 1);
});

test("retries transient provider failures but not provider 4xx", async () => {
  let transientCalls = 0;
  const transient = await __private__.generateValidatedFeedback({
    generateFeedback: async () => {
      transientCalls += 1;
      if (transientCalls === 1) {
        const error = new Error("upstream unavailable");
        error.status = 503;
        throw error;
      }
      return validFeedback();
    },
    transcript: [],
    outputLocale: "ru",
    analyzedLanguage: "en",
    modelId: "test-model",
    logProviderFailure: () => {},
  });
  assert.deepEqual(transient, validFeedback());
  assert.equal(transientCalls, 2);

  let clientErrorCalls = 0;
  await assert.rejects(__private__.generateValidatedFeedback({
    generateFeedback: async () => {
      clientErrorCalls += 1;
      const error = new Error("quota exceeded");
      error.status = 429;
      throw error;
    },
    transcript: [],
    outputLocale: "ru",
    analyzedLanguage: "en",
    modelId: "test-model",
    logProviderFailure: () => {},
  }));
  assert.equal(clientErrorCalls, 1);
});

test("retries production-shaped Node fetch socket failures", async () => {
  let providerCalls = 0;
  const result = await __private__.generateValidatedFeedback({
    generateFeedback: async () => {
      providerCalls += 1;
      if (providerCalls === 1) {
        const cause = new Error("other side closed");
        cause.code = "UND_ERR_SOCKET";
        throw new TypeError("fetch failed", {cause});
      }
      return validFeedback();
    },
    transcript: [],
    outputLocale: "ru",
    analyzedLanguage: "en",
    modelId: __private__.DEFAULT_FEEDBACK_MODEL_ID,
    logProviderFailure: () => {},
  });

  assert.deepEqual(result, validFeedback());
  assert.equal(providerCalls, 2);
});

test("retries Node fetch failures even without a transport cause code", async () => {
  let providerCalls = 0;
  const result = await __private__.generateValidatedFeedback({
    generateFeedback: async () => {
      providerCalls += 1;
      if (providerCalls === 1) throw new TypeError("fetch failed");
      return validFeedback();
    },
    transcript: [],
    outputLocale: "ru",
    analyzedLanguage: "en",
    modelId: __private__.DEFAULT_FEEDBACK_MODEL_ID,
    logProviderFailure: () => {},
  });

  assert.deepEqual(result, validFeedback());
  assert.equal(providerCalls, 2);
});

test("accepts only complete STOP JSON responses", () => {
  assert.deepEqual(
    __private__.safeJsonText({
      text: '{"summary":"ok"}',
      candidates: [{finishReason: "STOP"}],
    }),
    {text: '{"summary":"ok"}', finishReason: "STOP"},
  );
  assert.throws(
    () => __private__.safeJsonText({
      text: "{",
      candidates: [{finishReason: "MAX_TOKENS"}],
    }),
    (error) => error instanceof __private__.FeedbackProviderOutputError &&
      error.finishReason === "MAX_TOKENS",
  );
  assert.throws(
    () => __private__.safeJsonText({
      text: "",
      candidates: [{finishReason: "STOP"}],
    }),
    (error) => error instanceof __private__.FeedbackProviderOutputError,
  );
});

test("uses the structured response contract and bounded provider budget", () => {
  assert.equal(__private__.FEEDBACK_GENERATION_VERSION, 3);
  assert.equal(
    __private__.DEFAULT_FEEDBACK_MODEL_ID,
    "gemini-3.1-flash-lite",
  );
  assert.equal(__private__.MAX_PROVIDER_CALLS_PER_ATTEMPT, 2);
  assert.equal(__private__.PROVIDER_MAX_OUTPUT_TOKENS, 4096);
  assert.equal(__private__.PROVIDER_TIMEOUT_MS, 40000);
  assert.equal(__private__.LEASE_DURATION_MS, 115000);
  assert.equal(__private__.feedbackResponseJsonSchema.type, "object");
  assert.equal(
    __private__.feedbackResponseJsonSchema.properties.corrections.type,
    "array",
  );
  assert.equal(
    __private__.feedbackResponseJsonSchema
      .properties.corrections.items.type,
    "object",
  );
});

test("uses only model-specific validated feedback configurations", () => {
  const previousModel = process.env.GEMINI_FEEDBACK_MODEL;
  try {
    delete process.env.GEMINI_FEEDBACK_MODEL;
    assert.equal(
      __private__.feedbackModelId(),
      "gemini-3.1-flash-lite",
    );
    assert.deepEqual(
      __private__.feedbackThinkingConfig("gemini-3.1-flash-lite"),
      {thinkingLevel: "MINIMAL"},
    );

    process.env.GEMINI_FEEDBACK_MODEL = "gemini-2.5-flash";
    assert.equal(__private__.feedbackModelId(), "gemini-2.5-flash");
    assert.deepEqual(
      __private__.feedbackThinkingConfig("gemini-2.5-flash"),
      {thinkingBudget: 0},
    );

    process.env.GEMINI_FEEDBACK_MODEL = "unsupported-model";
    assert.equal(
      __private__.feedbackModelId(),
      "gemini-3.1-flash-lite",
    );
  } finally {
    if (previousModel === undefined) {
      delete process.env.GEMINI_FEEDBACK_MODEL;
    } else {
      process.env.GEMINI_FEEDBACK_MODEL = previousModel;
    }
  }
});

test("migrates one older terminal failure into the version-three flow", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const text = Array.from({length: 25}, (_, index) => `word${index}`).join(" ");
  const db = seededDb(nowMillis, text);
  db.documents.set("videoSessions/session-a/aiFeedback/user-a", {
    ownerUid: "user-a",
    status: "failed_terminal",
    generationVersion: 2,
    attemptCount: 3,
    errorCode: "feedback_generation_failed",
    updatedAt: admin.firestore.Timestamp.fromMillis(nowMillis - 60000),
  });
  let providerCalls = 0;
  const handler = createGenerateCallFeedbackHandler({
    db,
    now: () => nowMillis,
    leaseIdFactory: () => "migration-lease",
    isFeatureEnabled: () => true,
    generateFeedback: async () => {
      providerCalls += 1;
      return validFeedback();
    },
  });

  const result = await handler(payload(), callableContext());
  const stored = db.read("videoSessions/session-a/aiFeedback/user-a");
  assert.equal(result.status, "ready");
  assert.equal(result.generationVersion, 3);
  assert.equal(providerCalls, 1);
  assert.equal(stored.status, "ready");
  assert.equal(stored.attemptCount, 1);
  assert.equal(stored.generationVersion, 3);
});

test("reuses legacy completed results and current terminal failures", async () => {
  const nowMillis = Date.UTC(2026, 7, 4, 12);
  const readyDb = seededDb(nowMillis, "Too short to regenerate.");
  readyDb.documents.set("videoSessions/session-a/aiFeedback/user-a", {
    status: "ready",
    result: validFeedback(),
  });
  const readyHandler = createGenerateCallFeedbackHandler({
    db: readyDb,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
    generateFeedback: async () => {
      throw new Error("must not regenerate ready feedback");
    },
  });
  const ready = await readyHandler(payload(), callableContext());
  assert.equal(ready.status, "ready");
  assert.equal(ready.generationVersion, 1);

  const terminalDb = seededDb(nowMillis, "Too short to regenerate.");
  terminalDb.documents.set("videoSessions/session-a/aiFeedback/user-a", {
    status: "failed_terminal",
    generationVersion: 3,
    errorCode: "feedback_generation_failed",
  });
  const terminalHandler = createGenerateCallFeedbackHandler({
    db: terminalDb,
    now: () => nowMillis,
    isFeatureEnabled: () => true,
  });
  const terminal = await terminalHandler(payload(), callableContext());
  assert.deepEqual(terminal, {
    status: "failed_terminal",
    errorCode: "feedback_generation_failed",
    generationVersion: 3,
  });
});
