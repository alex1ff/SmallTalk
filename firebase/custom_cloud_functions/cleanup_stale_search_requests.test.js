const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  SEARCH_REQUEST_TIMING,
} = require("./search_requests");
const {
  __private__: {
    buildExpiredSearchRequestCleanupUpdate,
    buildStaleSearchRequestCleanupUpdate,
    cleanupStaleSearchRequestDocs,
    isExpiredUnmatchedSearchRequest,
    isStaleSearchRequest,
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
      status: "stopped",
      expiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
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

  assert.ok(hasSearchRequestIndex("heartbeatAt"));
  assert.ok(hasSearchRequestIndex("updatedAt"));
  assert.ok(hasSearchRequestIndex("expiresAt"));
});

test("deploy script includes stale cleanup indexes", () => {
  const packageJson = JSON.parse(fs.readFileSync(
    path.join(__dirname, "package.json"),
    "utf8",
  ));
  const deployScript = packageJson.scripts["deploy:readiness-functions"];

  assert.match(deployScript, /--only firestore:indexes,/);
});
