const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_APP_STATE,
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  __private__: {
    buildBackgroundExpiredSearchRequestCleanupUpdate,
    buildExpiredSearchRequestCleanupUpdate,
    buildStaleSearchRequestCleanupUpdate,
    cleanupBackgroundExpiredSearchRequestDocs,
    cleanupStaleSearchRequestDocs,
    isBackgroundExpiredSearchRequest,
    isExpiredUnmatchedSearchRequest,
    isSessionBoundMatchingSearchRequest,
    isStaleSearchRequest,
    queueBackgroundExpiredSearchRequestCleanup,
    queueExpiredSearchRequestCleanup,
    queueStaleSearchRequestCleanup,
  },
} = require("./cleanup_stale_search_requests");

if (!admin.apps.length) {
  admin.initializeApp({projectId: "demo-smalltalk"});
}

const fixedNowMillis = Date.parse("2026-06-21T10:00:00.000Z");
const serverTimestamp = Symbol("serverTimestamp");
const fieldDelete = Symbol("fieldDelete");

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function activeRequest(overrides = {}) {
  return {
    status: "active",
    requestId: "request-a",
    heartbeatAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
    expiresAt: timestampFromMillis(fixedNowMillis + 5 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: "session-a",
    matchedUserId: "student-b",
    matchedRole: "student",
    pairAttemptId: "pair-a",
    attemptExcludedCandidateIds: ["student-b"],
    lockOwner: "matcher-a",
    lockExpiresAt: timestampFromMillis(fixedNowMillis + 15 * 1000),
    stopReason: null,
    stoppedAt: null,
    lastError: null,
    ...overrides,
  };
}

test("stale search request cleanup uses heartbeat cutoff", () => {
  const cutoffMillis =
    fixedNowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;

  assert.equal(
    isStaleSearchRequest(activeRequest({
      heartbeatAt: timestampFromMillis(cutoffMillis - 1),
    }), fixedNowMillis),
    true,
  );
  assert.equal(
    isStaleSearchRequest(activeRequest({
      heartbeatAt: timestampFromMillis(cutoffMillis),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isStaleSearchRequest(activeRequest({status: "matched"}), fixedNowMillis),
    false,
  );
  assert.equal(
    isStaleSearchRequest(activeRequest({
      status: "matching",
      currentSessionId: "session-a",
      heartbeatAt: timestampFromMillis(cutoffMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isStaleSearchRequest(activeRequest({
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 60 * 1000),
      heartbeatAt: timestampFromMillis(cutoffMillis - 1),
    }), fixedNowMillis),
    true,
  );
});

test("90 seconds without heartbeat expires active search request", () => {
  const writerOperations = [];
  const writer = {
    update(ref, data) {
      writerOperations.push({type: "update", ref, data});
    },
  };
  const cutoffMillis =
    fixedNowMillis - SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS * 1000;

  const freshAtBoundaryResult = queueStaleSearchRequestCleanup({
    writer,
    doc: {
      id: "student-fresh-boundary",
      ref: {path: "searchRequests/student-fresh-boundary"},
      data: () => activeRequest({
        currentSessionId: null,
        heartbeatAt: timestampFromMillis(cutoffMillis),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });
  const expiredAfterBoundaryResult = queueStaleSearchRequestCleanup({
    writer,
    doc: {
      id: "student-expired-boundary",
      ref: {path: "searchRequests/student-expired-boundary"},
      data: () => activeRequest({
        activeSessionId: "session-a",
        currentSessionId: null,
        matchedSessionId: "session-a",
        matchedResponderId: "student-b",
        heartbeatAt: timestampFromMillis(cutoffMillis - 1),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(freshAtBoundaryResult.cleaned, false);
  assert.equal(expiredAfterBoundaryResult.cleaned, true);
  assert.equal(expiredAfterBoundaryResult.requestId, "request-a");
  assert.equal(writerOperations.length, 1);
  assert.equal(
    writerOperations[0].ref.path,
    "searchRequests/student-expired-boundary",
  );
  assert.equal(writerOperations[0].data.status, "expired");
  assert.equal(writerOperations[0].data.stopReason, "heartbeat_stale");
  assert.equal(writerOperations[0].data.stoppedAt, serverTimestamp);
  assert.equal(writerOperations[0].data.updatedAt, serverTimestamp);
  assert.equal(writerOperations[0].data.currentSessionId, null);
  assert.equal(writerOperations[0].data.activeSessionId, fieldDelete);
  assert.equal(writerOperations[0].data.matchedSessionId, fieldDelete);
  assert.equal(writerOperations[0].data.matchedResponderId, fieldDelete);
  assert.equal(writerOperations[0].data.matchedUserId, null);
  assert.equal(writerOperations[0].data.matchedRole, null);
  assert.equal(writerOperations[0].data.pairAttemptId, null);
  assert.deepEqual(writerOperations[0].data.attemptExcludedCandidateIds, []);
  assert.equal(writerOperations[0].data.lockOwner, null);
  assert.equal(writerOperations[0].data.lockExpiresAt, null);
  assert.deepEqual(writerOperations[0].data.lastError, {
    code: "heartbeat_stale",
    message: "Search request heartbeat is stale",
  });
});

test("closed background search request expires after 90 seconds without heartbeat", () => {
  const writerOperations = [];
  const writer = {
    update(ref, data) {
      writerOperations.push({type: "update", ref, data});
    },
  };
  const staleHeartbeatMillis =
    fixedNowMillis -
    (SEARCH_REQUEST_TIMING.HEARTBEAT_STALE_SECONDS + 1) * 1000;

  const result = queueStaleSearchRequestCleanup({
    writer,
    doc: {
      id: "student-background-closed",
      ref: {path: "searchRequests/student-background-closed"},
      data: () => activeRequest({
        appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 10 * 60_000),
        heartbeatAt: timestampFromMillis(staleHeartbeatMillis),
        currentSessionId: null,
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(result.cleaned, true);
  assert.equal(writerOperations.length, 1);
  assert.equal(writerOperations[0].data.status, "expired");
  assert.equal(writerOperations[0].data.stopReason, "heartbeat_stale");
});

test("stale search request cleanup marks request expired and clears locks", () => {
  const update = buildStaleSearchRequestCleanupUpdate({
    requestData: activeRequest({status: "matching"}),
    serverTimestamp,
    fieldDelete,
  });

  assert.deepEqual(update, {
    status: "expired",
    updatedAt: serverTimestamp,
    stoppedAt: serverTimestamp,
    stopReason: "heartbeat_stale",
    currentSessionId: null,
    matchedUserId: null,
    matchedRole: null,
    pairAttemptId: null,
    attemptExcludedCandidateIds: [],
    lockOwner: null,
    lockExpiresAt: null,
    lastError: {
      code: "heartbeat_stale",
      message: "Search request heartbeat is stale",
    },
    activeSessionId: fieldDelete,
    matchedSessionId: fieldDelete,
    matchedResponderId: fieldDelete,
  });
});

test("expired unmatched search request cleanup uses expiresAt cutoff", () => {
  assert.equal(
    isExpiredUnmatchedSearchRequest(activeRequest({
      expiresAt: timestampFromMillis(fixedNowMillis),
    }), fixedNowMillis),
    true,
  );
  assert.equal(
    isExpiredUnmatchedSearchRequest(activeRequest({
      expiresAt: timestampFromMillis(fixedNowMillis + 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isExpiredUnmatchedSearchRequest(activeRequest({
      status: "matched",
      expiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isExpiredUnmatchedSearchRequest(activeRequest({
      status: "matching",
      currentSessionId: "session-a",
      expiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isExpiredUnmatchedSearchRequest(activeRequest({
      status: "stopped",
      expiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
});

test("10 minutes without pair expires active search request", () => {
  const writerOperations = [];
  const writer = {
    update(ref, data) {
      writerOperations.push({type: "update", ref, data});
    },
  };
  const searchStartedAtMillis =
    fixedNowMillis - SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000;
  const searchExpiresAtMillis =
    searchStartedAtMillis + SEARCH_REQUEST_TIMING.MAX_SEARCH_SECONDS * 1000;

  const freshBeforeTimeoutResult = queueExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-search-fresh",
      ref: {path: "searchRequests/student-search-fresh"},
      data: () => activeRequest({
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        currentSessionId: null,
        activeSessionId: null,
        matchedSessionId: null,
        matchedUserId: null,
        matchedRole: null,
        pairAttemptId: null,
        heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
        createdAt: timestampFromMillis(searchStartedAtMillis),
        expiresAt: timestampFromMillis(fixedNowMillis + 1),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });
  const expiredWithoutPairResult = queueExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-search-timeout",
      ref: {path: "searchRequests/student-search-timeout"},
      data: () => activeRequest({
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        currentSessionId: null,
        activeSessionId: null,
        matchedSessionId: null,
        matchedUserId: null,
        matchedRole: null,
        pairAttemptId: null,
        heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
        createdAt: timestampFromMillis(searchStartedAtMillis),
        expiresAt: timestampFromMillis(searchExpiresAtMillis),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(searchExpiresAtMillis, fixedNowMillis);
  assert.equal(freshBeforeTimeoutResult.cleaned, false);
  assert.equal(expiredWithoutPairResult.cleaned, true);
  assert.equal(expiredWithoutPairResult.requestId, "request-a");
  assert.equal(writerOperations.length, 1);
  assert.equal(
    writerOperations[0].ref.path,
    "searchRequests/student-search-timeout",
  );
  assert.equal(writerOperations[0].data.status, "expired");
  assert.equal(writerOperations[0].data.stopReason, "search_timeout");
  assert.equal(writerOperations[0].data.stoppedAt, serverTimestamp);
  assert.equal(writerOperations[0].data.updatedAt, serverTimestamp);
  assert.equal(writerOperations[0].data.currentSessionId, null);
  assert.equal(writerOperations[0].data.activeSessionId, fieldDelete);
  assert.equal(writerOperations[0].data.matchedSessionId, fieldDelete);
  assert.equal(writerOperations[0].data.matchedResponderId, fieldDelete);
  assert.equal(writerOperations[0].data.matchedUserId, null);
  assert.equal(writerOperations[0].data.matchedRole, null);
  assert.equal(writerOperations[0].data.pairAttemptId, null);
  assert.deepEqual(writerOperations[0].data.attemptExcludedCandidateIds, []);
  assert.equal(writerOperations[0].data.lockOwner, null);
  assert.equal(writerOperations[0].data.lockExpiresAt, null);
  assert.deepEqual(writerOperations[0].data.lastError, {
    code: "search_timeout",
    message: "Search request expired without a match",
  });
});

test("expired unmatched cleanup marks request expired and clears locks", () => {
  const update = buildExpiredSearchRequestCleanupUpdate({
    requestData: activeRequest({status: "matching"}),
    serverTimestamp,
    fieldDelete,
  });

  assert.deepEqual(update, {
    status: "expired",
    updatedAt: serverTimestamp,
    stoppedAt: serverTimestamp,
    stopReason: "search_timeout",
    currentSessionId: null,
    matchedUserId: null,
    matchedRole: null,
    pairAttemptId: null,
    attemptExcludedCandidateIds: [],
    lockOwner: null,
    lockExpiresAt: null,
    lastError: {
      code: "search_timeout",
      message: "Search request expired without a match",
    },
    activeSessionId: fieldDelete,
    matchedSessionId: fieldDelete,
    matchedResponderId: fieldDelete,
  });
});

test("background expired search request cleanup uses background deadline", () => {
  assert.equal(
    isBackgroundExpiredSearchRequest(activeRequest({
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis),
    }), fixedNowMillis),
    true,
  );
  assert.equal(
    isBackgroundExpiredSearchRequest(activeRequest({
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isBackgroundExpiredSearchRequest(activeRequest({
      appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isBackgroundExpiredSearchRequest(activeRequest({
      status: "matched",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isBackgroundExpiredSearchRequest(activeRequest({
      status: "matching",
      currentSessionId: "session-a",
      appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
});

test("session-bound matching requests are left to session lifecycle", () => {
  assert.equal(
    isSessionBoundMatchingSearchRequest(activeRequest({
      status: "matching",
      currentSessionId: "session-a",
    })),
    true,
  );
  assert.equal(
    isSessionBoundMatchingSearchRequest(activeRequest({
      status: "matching",
      currentSessionId: null,
      activeSessionId: null,
      matchedSessionId: null,
    })),
    false,
  );
});

test("background expired cleanup marks request expired and clears locks", () => {
  const update = buildBackgroundExpiredSearchRequestCleanupUpdate({
    requestData: activeRequest({status: "matching"}),
    serverTimestamp,
    fieldDelete,
  });

  assert.deepEqual(update, {
    status: "expired",
    updatedAt: serverTimestamp,
    stoppedAt: serverTimestamp,
    stopReason: "background_timeout",
    currentSessionId: null,
    matchedUserId: null,
    matchedRole: null,
    pairAttemptId: null,
    attemptExcludedCandidateIds: [],
    lockOwner: null,
    lockExpiresAt: null,
    lastError: {
      code: "background_timeout",
      message: "Search request expired in background",
    },
    activeSessionId: fieldDelete,
    matchedSessionId: fieldDelete,
    matchedResponderId: fieldDelete,
  });
});

test("queue stale cleanup writes only stale active request", () => {
  const writerOperations = [];
  const writer = {
    update(ref, data) {
      writerOperations.push({type: "update", ref, data});
    },
  };
  const staleDoc = {
    id: "student-a",
    ref: {path: "searchRequests/student-a"},
    data: () => activeRequest({status: "searching"}),
  };

  const result = queueStaleSearchRequestCleanup({
    writer,
    doc: staleDoc,
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(result.cleaned, true);
  assert.equal(result.requestId, "request-a");
  assert.equal(writerOperations.length, 1);
  assert.equal(writerOperations[0].ref.path, "searchRequests/student-a");
  assert.equal(writerOperations[0].data.status, "expired");
  assert.equal(writerOperations[0].data.stopReason, "heartbeat_stale");

  const freshResult = queueStaleSearchRequestCleanup({
    writer,
    doc: {
      id: "student-b",
      ref: {path: "searchRequests/student-b"},
      data: () => activeRequest({
        heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(freshResult.cleaned, false);
  assert.equal(writerOperations.length, 1);

  const missingHeartbeatResult = queueStaleSearchRequestCleanup({
    writer,
    doc: {
      id: "student-c",
      ref: {path: "searchRequests/student-c"},
      data: () => activeRequest({
        heartbeatAt: undefined,
        updatedAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(missingHeartbeatResult.cleaned, true);
  assert.equal(writerOperations.length, 2);
  assert.equal(writerOperations[1].ref.path, "searchRequests/student-c");
  assert.equal(writerOperations[1].data.stopReason, "heartbeat_stale");
});

test("queue expired cleanup writes only expired unmatched request", () => {
  const writerOperations = [];
  const writer = {
    update(ref, data) {
      writerOperations.push({type: "update", ref, data});
    },
  };

  const result = queueExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-a",
      ref: {path: "searchRequests/student-a"},
      data: () => activeRequest({
        status: "matching",
        currentSessionId: null,
        activeSessionId: null,
        matchedSessionId: null,
        expiresAt: timestampFromMillis(fixedNowMillis),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(result.cleaned, true);
  assert.equal(result.requestId, "request-a");
  assert.equal(writerOperations.length, 1);
  assert.equal(writerOperations[0].data.status, "expired");
  assert.equal(writerOperations[0].data.stopReason, "search_timeout");

  const freshResult = queueExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-b",
      ref: {path: "searchRequests/student-b"},
      data: () => activeRequest({
        expiresAt: timestampFromMillis(fixedNowMillis + 1),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });
  const matchedResult = queueExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-c",
      ref: {path: "searchRequests/student-c"},
      data: () => activeRequest({
        status: "matched",
        expiresAt: timestampFromMillis(fixedNowMillis - 1),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(freshResult.cleaned, false);
  assert.equal(matchedResult.cleaned, false);
  assert.equal(writerOperations.length, 1);
});

test("queue background expired cleanup writes only background expired request", () => {
  const writerOperations = [];
  const writer = {
    update(ref, data) {
      writerOperations.push({type: "update", ref, data});
    },
  };

  const result = queueBackgroundExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-a",
      ref: {path: "searchRequests/student-a"},
      data: () => activeRequest({
        appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(result.cleaned, true);
  assert.equal(result.requestId, "request-a");
  assert.equal(writerOperations.length, 1);
  assert.equal(writerOperations[0].data.status, "expired");
  assert.equal(writerOperations[0].data.stopReason, "background_timeout");

  const foregroundResult = queueBackgroundExpiredSearchRequestCleanup({
    writer,
    doc: {
      id: "student-b",
      ref: {path: "searchRequests/student-b"},
      data: () => activeRequest({
        appState: SEARCH_REQUEST_APP_STATE.FOREGROUND,
        backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
      }),
    },
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(foregroundResult.cleaned, false);
  assert.equal(writerOperations.length, 1);
});

test("cleanup stale docs rereads transaction data and dedupes fallback hits", async () => {
  const updates = [];
  const staleDoc = {
    id: "student-a",
    ref: {path: "searchRequests/student-a"},
  };
  const db = {
    async runTransaction(callback) {
      return await callback({
        async get(ref) {
          return {
            exists: true,
            data: () => activeRequest({
              requestId: "request-fresh",
              heartbeatAt: undefined,
              updatedAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
              refPath: ref.path,
            }),
          };
        },
        update(ref, data) {
          updates.push({ref, data});
        },
      });
    },
  };
  const seenDocKeys = new Set();

  const firstPass = await cleanupStaleSearchRequestDocs({
    db,
    docs: [staleDoc],
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
    seenDocKeys,
  });
  const secondPass = await cleanupStaleSearchRequestDocs({
    db,
    docs: [staleDoc],
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
    seenDocKeys,
  });

  assert.equal(firstPass, 1);
  assert.equal(secondPass, 0);
  assert.equal(updates.length, 1);
});

test("background cleanup still runs after heartbeat-fresh stale pass skips same doc", async () => {
  const updates = [];
  const backgroundDoc = {
    id: "student-a",
    ref: {path: "searchRequests/student-a"},
  };
  const db = {
    async runTransaction(callback) {
      return await callback({
        async get() {
          return {
            exists: true,
            data: () => activeRequest({
              appState: SEARCH_REQUEST_APP_STATE.BACKGROUND,
              backgroundExpiresAt: timestampFromMillis(fixedNowMillis),
              heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
            }),
          };
        },
        update(ref, data) {
          updates.push({ref, data});
        },
      });
    },
  };
  const seenDocKeys = new Set();

  const stalePass = await cleanupStaleSearchRequestDocs({
    db,
    docs: [backgroundDoc],
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
    seenDocKeys,
  });
  const backgroundPass = await cleanupBackgroundExpiredSearchRequestDocs({
    db,
    docs: [backgroundDoc],
    nowMillis: fixedNowMillis,
    serverTimestamp,
    fieldDelete,
    seenDocKeys,
  });

  assert.equal(stalePass, 0);
  assert.equal(backgroundPass, 1);
  assert.equal(updates.length, 1);
  assert.equal(updates[0].data.stopReason, "background_timeout");
});

test("cleanupStaleSearchRequests is scheduled every minute", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "cleanup_stale_search_requests.js"),
    "utf8",
  );

  assert.match(source, /\.schedule\("every 1 minutes"\)/);
  assert.match(source, /collection\(SEARCH_REQUEST_COLLECTION\)/);
  assert.match(source, /where\("status", "in"/);
  assert.match(source, /where\("heartbeatAt", "<"/);
  assert.match(source, /where\("updatedAt", "<"/);
  assert.match(source, /where\("expiresAt", "<="/);
  assert.match(source, /where\("appState", "=="/);
  assert.match(source, /where\("backgroundExpiresAt", "<="/);
});

test("Firestore indexes support stale search request cleanup query", () => {
  const indexes = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "firestore.indexes.json"),
    "utf8",
  )).indexes;

  const hasSearchRequestIndex = (fieldPath) => indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
      index.queryScope === "COLLECTION" &&
      index.fields.some((field) =>
        field.fieldPath === "status" && field.order === "ASCENDING",
      ) &&
      index.fields.some((field) =>
        field.fieldPath === fieldPath && field.order === "ASCENDING",
      ));
  const hasSearchRequestIndexFields = (fieldPaths) => indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
      index.queryScope === "COLLECTION" &&
      fieldPaths.every((fieldPath) =>
        index.fields.some((field) =>
          field.fieldPath === fieldPath && field.order === "ASCENDING",
        ),
      ));

  assert.ok(hasSearchRequestIndex("heartbeatAt"));
  assert.ok(hasSearchRequestIndex("updatedAt"));
  assert.ok(hasSearchRequestIndex("expiresAt"));
  assert.ok(hasSearchRequestIndexFields([
    "status",
    "appState",
    "backgroundExpiresAt",
  ]));
});

test("deploy script includes stale cleanup indexes", () => {
  const packageJson = JSON.parse(fs.readFileSync(
    path.join(__dirname, "package.json"),
    "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.match(deployScript, /--only firestore:indexes,/);
});
