const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  endSession,
  __private__: {
    buildEndedSessionPairLockReleaseOptions,
    buildPreActiveSessionPairLockReleaseOptions,
    buildStudentCallCharge,
    hasConnectedCallEvidence,
    hasActiveSubscription,
    isExpiredEndReason,
    resolveTeacherEarningUserId,
    shouldProcessExpiredEndReason,
  },
} = require("./end_session");
const {
  incomingCallNotificationId,
} = require("./call_notifications");

const fakeDeleteField = Symbol("deleteField");
const fakeServerTimestamp = {__fakeFieldValue: "serverTimestamp"};

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function activeSearchRequest(userId, overrides = {}) {
  return {
    requestId: `request-${userId}`,
    userId,
    role: "student",
    language: "en",
    status: "matched",
    currentSessionId: null,
    activeSessionId: null,
    matchedSessionId: null,
    matchedUserId: null,
    matchedResponderId: null,
    matchedRole: null,
    pairAttemptId: null,
    lockOwner: null,
    lockExpiresAt: null,
    ...overrides,
  };
}

function studentUser(overrides = {}) {
  return {
    role: "student",
    currentSessionId: "",
    isInCall: false,
    isAvailable: true,
    giftMinutes: {
      minutes: 10,
      expiresAt: timestampFromMillis(Date.now() + 60 * 60 * 1000),
    },
    ...overrides,
  };
}

function callableSessionSeed({
  sessionId,
  firstStudentId,
  secondStudentId,
  status = "connecting",
  sessionMetadata = {},
  overrides = {},
}) {
  const pairAttemptId = `pair-${sessionId}-${firstStudentId}-${secondStudentId}`;
  return {
    [`users/${firstStudentId}`]: studentUser({
      currentSessionId: sessionId,
      isInCall: true,
      isAvailable: false,
    }),
    [`users/${secondStudentId}`]: studentUser({
      currentSessionId: sessionId,
      isInCall: true,
      isAvailable: false,
    }),
    [`searchRequests/${firstStudentId}`]: activeSearchRequest(firstStudentId, {
      currentSessionId: sessionId,
      activeSessionId: sessionId,
      matchedSessionId: sessionId,
      matchedUserId: secondStudentId,
      matchedResponderId: secondStudentId,
      matchedRole: "student",
      pairAttemptId,
      lockOwner: pairAttemptId,
      lockExpiresAt: timestampFromMillis(Date.now() + 45_000),
    }),
    [`searchRequests/${secondStudentId}`]: activeSearchRequest(secondStudentId, {
      currentSessionId: sessionId,
      activeSessionId: sessionId,
      matchedSessionId: sessionId,
      matchedUserId: firstStudentId,
      matchedResponderId: secondStudentId,
      matchedRole: "student",
      pairAttemptId,
      lockOwner: pairAttemptId,
      lockExpiresAt: timestampFromMillis(Date.now() + 45_000),
    }),
    [`videoSessions/${sessionId}`]: {
      status,
      language: "en",
      studentId: firstStudentId,
      tutorId: secondStudentId,
      requesterId: firstStudentId,
      requesterRole: "student",
      responderId: secondStudentId,
      responderRole: "student",
      currentTutorId: secondStudentId,
      currentResponderId: secondStudentId,
      currentResponderRole: "student",
      participantIds: [firstStudentId, secondStudentId],
      participantRoles: {
        [firstStudentId]: "student",
        [secondStudentId]: "student",
      },
      searchRequestIds: {
        requester: `request-${firstStudentId}`,
        responder: `request-${secondStudentId}`,
      },
      matchContext: {
        requesterRole: "student",
        acceptedResponderId: secondStudentId,
        acceptedResponderRole: "student",
      },
      sessionMetadata,
      ...overrides,
    },
  };
}

function applyFieldValue(target, key, value) {
  const segments = key.split(".");
  let cursor = target;
  for (let index = 0; index < segments.length - 1; index += 1) {
    const segment = segments[index];
    if (!cursor[segment] || typeof cursor[segment] !== "object") {
      cursor[segment] = {};
    }
    cursor = cursor[segment];
  }

  const leaf = segments[segments.length - 1];
  if (value === fakeDeleteField) {
    delete cursor[leaf];
    return;
  }
  if (value && typeof value === "object" && value.__fakeIncrement !== undefined) {
    cursor[leaf] = Number(cursor[leaf] || 0) + value.__fakeIncrement;
    return;
  }
  if (value && typeof value === "object" && value.__fakeArrayUnion) {
    const currentValues = Array.isArray(cursor[leaf]) ? cursor[leaf] : [];
    cursor[leaf] = Array.from(new Set([
      ...currentValues,
      ...value.__fakeArrayUnion,
    ]));
    return;
  }
  cursor[leaf] = value;
}

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));
  const writes = [];
  let autoId = 0;

  const makeSnapshot = (ref) => {
    const data = store.get(ref.path);
    return {
      exists: data !== undefined,
      ref,
      id: ref.id,
      data: () => data,
    };
  };

  const applySet = (ref, data, options = {}) => {
    const current = options.merge ? {...(store.get(ref.path) || {})} : {};
    for (const [key, value] of Object.entries(data || {})) {
      applyFieldValue(current, key, value);
    }
    store.set(ref.path, current);
    writes.push({type: "set", path: ref.path, data, options});
  };

  const applyUpdate = (ref, data) => {
    const current = {...(store.get(ref.path) || {})};
    for (const [key, value] of Object.entries(data || {})) {
      applyFieldValue(current, key, value);
    }
    store.set(ref.path, current);
    writes.push({type: "update", path: ref.path, data});
  };

  const makeRef = (pathValue) => ({
    path: pathValue,
    id: pathValue.split("/").pop(),
    collection(collectionId) {
      return makeCollection(`${pathValue}/${collectionId}`);
    },
    async get() {
      return makeSnapshot(this);
    },
    async set(data, options = {}) {
      applySet(this, data, options);
    },
    async update(data) {
      applyUpdate(this, data);
    },
    async delete() {
      store.delete(this.path);
      writes.push({type: "delete", path: this.path});
    },
  });

  const makeQuery = (collectionPath, filters = []) => ({
    where(field, operator, expectedValue) {
      return makeQuery(collectionPath, [
        ...filters,
        {field, operator, expectedValue},
      ]);
    },
    async get() {
      const baseDepth = collectionPath.split("/").length;
      const docs = Array.from(store.entries())
        .filter(([entryPath]) =>
          entryPath.startsWith(`${collectionPath}/`) &&
          entryPath.split("/").length === baseDepth + 1)
        .map(([entryPath, data]) => ({
          ref: makeRef(entryPath),
          id: entryPath.split("/").pop(),
          data: () => data,
        }))
        .filter((doc) => filters.every((filter) => {
          if (filter.operator !== "==") {
            return false;
          }
          return doc.data()?.[filter.field] === filter.expectedValue;
        }));
      return {
        empty: docs.length === 0,
        size: docs.length,
        docs,
        forEach(callback) {
          docs.forEach(callback);
        },
      };
    },
  });

  const makeCollection = (collectionPath) => ({
    doc(docId) {
      const resolvedId = docId || `auto-${autoId += 1}`;
      return makeRef(`${collectionPath}/${resolvedId}`);
    },
    async add(data) {
      const ref = this.doc();
      applySet(ref, data);
      return ref;
    },
    where(field, operator, expectedValue) {
      return makeQuery(collectionPath, [{field, operator, expectedValue}]);
    },
  });

  const db = {
    collection(collectionId) {
      return makeCollection(collectionId);
    },
    batch() {
      const operations = [];
      return {
        update(ref, data) {
          operations.push(() => applyUpdate(ref, data));
        },
        async commit() {
          operations.forEach((operation) => operation());
        },
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          return makeSnapshot(ref);
        },
        update(ref, data) {
          applyUpdate(ref, data);
        },
        set(ref, data, options = {}) {
          applySet(ref, data, options);
        },
        delete(ref) {
          store.delete(ref.path);
          writes.push({type: "delete", path: ref.path});
        },
      };
      return callback(transaction);
    },
  };

  const firestore = () => db;
  firestore.FieldValue = {
    arrayUnion: (...values) => ({__fakeArrayUnion: values}),
    delete: () => fakeDeleteField,
    increment: (value) => ({__fakeIncrement: value}),
    serverTimestamp: () => fakeServerTimestamp,
  };
  firestore.Timestamp = {
    fromMillis: timestampFromMillis,
  };

  return {db, firestore, store, writes};
}

async function withFakeFirestore(fakeFirestore, callback) {
  const originalFirestore = admin.firestore;
  Object.defineProperty(admin, "firestore", {
    value: fakeFirestore,
    configurable: true,
  });
  try {
    return await callback();
  } finally {
    Object.defineProperty(admin, "firestore", {
      value: originalFirestore,
      configurable: true,
    });
  }
}

test("expired end reasons are ignored when policy expiry moved into the future", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 600,
      },
    },
    endReason: "expired",
    requestTimestamp: Date.parse("2026-04-14T10:05:01Z"),
  });

  assert.equal(shouldProcess, false);
});

test("expired end reasons are honored once the stored limit is reached", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:05:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 300,
      },
    },
    endReason: "expired",
    requestTimestamp: Date.parse("2026-04-14T10:05:00Z"),
  });

  assert.equal(shouldProcess, true);
});

test("manual end reasons bypass the expiry guard", () => {
  const shouldProcess = shouldProcessExpiredEndReason({
    sessionData: {
      expiresAt: {
        toMillis: () => Date.parse("2026-04-14T10:10:00Z"),
      },
      sessionPolicy: {
        effectiveLimitSeconds: 600,
      },
    },
    endReason: "user_ended",
    requestTimestamp: Date.parse("2026-04-14T10:05:01Z"),
  });

  assert.equal(shouldProcess, true);
});

test("pre-active session helper requires connected call evidence", () => {
  assert.equal(hasConnectedCallEvidence({}), false);
  assert.equal(hasConnectedCallEvidence({
    sessionMetadata: {
      callConnectedAtTimestamp: Date.parse("2026-04-14T10:00:00Z"),
    },
  }), true);
  assert.equal(isExpiredEndReason("expired"), true);
  assert.equal(isExpiredEndReason("user_ended"), false);
});

test("pre-active end closes search without restoring participants", () => {
  const db = Symbol("db");
  const transaction = Symbol("transaction");
  const sessionData = {status: "connecting"};
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");

  const options = buildPreActiveSessionPairLockReleaseOptions({
    db,
    transaction,
    sessionId: "session-pre-active-test",
    sessionData,
    serverTimestamp,
    fieldDelete,
    searchRequestStatus: "expired",
    stopReason: "pre_active_expired",
  });

  assert.equal(options.db, db);
  assert.equal(options.transaction, transaction);
  assert.equal(options.sessionId, "session-pre-active-test");
  assert.equal(options.sessionData, sessionData);
  assert.equal(options.serverTimestamp, serverTimestamp);
  assert.equal(options.fieldDelete, fieldDelete);
  assert.equal(options.searchRequestStatus, "expired");
  assert.equal(options.stopReason, "pre_active_expired");
  assert.equal(options.releaseCallState, true);
  assert.equal(options.restoreLegacyAvailability, true);
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});

test("ended session closes search without restoring participants", () => {
  const db = Symbol("db");
  const transaction = Symbol("transaction");
  const sessionData = {status: "active"};
  const serverTimestamp = Symbol("serverTimestamp");
  const fieldDelete = Symbol("fieldDelete");

  const options = buildEndedSessionPairLockReleaseOptions({
    db,
    transaction,
    sessionId: "session-ended-test",
    sessionData,
    serverTimestamp,
    fieldDelete,
  });

  assert.equal(options.db, db);
  assert.equal(options.transaction, transaction);
  assert.equal(options.sessionId, "session-ended-test");
  assert.equal(options.sessionData, sessionData);
  assert.equal(options.serverTimestamp, serverTimestamp);
  assert.equal(options.fieldDelete, fieldDelete);
  assert.equal(options.searchRequestStatus, "stopped");
  assert.equal(options.stopReason, "session_ended");
  assert.equal(options.releaseCallState, true);
  assert.equal(options.restoreLegacyAvailability, true);
  assert.equal(options.restoreSearchParticipantIds, undefined);
  assert.equal(
    options.restoreSearchExcludedCandidateIdsByParticipantId,
    undefined,
  );
});

test("endSession callable stops both active search participants", async () => {
  const startedAtMillis = Date.now() - 120_000;
  const sessionId = "session-active-ended-search";
  const firstStudentId = "student-callable-a";
  const secondStudentId = "student-callable-b";
  const pairAttemptId = `pair-${sessionId}-${firstStudentId}-${secondStudentId}`;
  const {firestore, store} = createFakeFirestore({
    [`users/${firstStudentId}`]: studentUser({
      currentSessionId: sessionId,
      isInCall: true,
      isAvailable: false,
    }),
    [`users/${secondStudentId}`]: studentUser({
      currentSessionId: sessionId,
      isInCall: true,
      isAvailable: false,
    }),
    [`searchRequests/${firstStudentId}`]: activeSearchRequest(firstStudentId, {
      currentSessionId: sessionId,
      activeSessionId: sessionId,
      matchedSessionId: sessionId,
      matchedUserId: secondStudentId,
      matchedResponderId: secondStudentId,
      matchedRole: "student",
      pairAttemptId,
      lockOwner: pairAttemptId,
      lockExpiresAt: timestampFromMillis(Date.now() + 45_000),
    }),
    [`searchRequests/${secondStudentId}`]: activeSearchRequest(secondStudentId, {
      currentSessionId: sessionId,
      activeSessionId: sessionId,
      matchedSessionId: sessionId,
      matchedUserId: firstStudentId,
      matchedResponderId: secondStudentId,
      matchedRole: "student",
      pairAttemptId,
      lockOwner: pairAttemptId,
      lockExpiresAt: timestampFromMillis(Date.now() + 45_000),
    }),
    [`videoSessions/${sessionId}`]: {
      status: "active",
      language: "en",
      studentId: firstStudentId,
      tutorId: secondStudentId,
      requesterId: firstStudentId,
      requesterRole: "student",
      responderId: secondStudentId,
      responderRole: "student",
      currentTutorId: secondStudentId,
      currentResponderId: secondStudentId,
      currentResponderRole: "student",
      participantIds: [firstStudentId, secondStudentId],
      participantRoles: {
        [firstStudentId]: "student",
        [secondStudentId]: "student",
      },
      searchRequestIds: {
        requester: `request-${firstStudentId}`,
        responder: `request-${secondStudentId}`,
      },
      matchContext: {
        requesterRole: "student",
        acceptedResponderId: secondStudentId,
        acceptedResponderRole: "student",
      },
      createdAt: timestampFromMillis(startedAtMillis - 60_000),
      sessionMetadata: {
        callConnectedAtTimestamp: startedAtMillis,
      },
    },
  });

  const response = await withFakeFirestore(firestore, () =>
    endSession.run(
      {sessionId, endReason: "user_ended"},
      {auth: {uid: firstStudentId}},
    ));

  assert.equal(response.status, "ended");
  assert.equal(store.get(`videoSessions/${sessionId}`).status, "ended");
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).status,
    "stopped",
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).status,
    "stopped",
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).stopReason,
    "session_ended",
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).stopReason,
    "session_ended",
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).currentSessionId,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).currentSessionId,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).matchedSessionId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).matchedSessionId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).activeSessionId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).activeSessionId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).matchedUserId,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).matchedUserId,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).matchedResponderId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).matchedResponderId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).matchedRole,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).matchedRole,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).pairAttemptId,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).pairAttemptId,
    null,
  );
  assert.equal(store.get(`searchRequests/${firstStudentId}`).lockOwner, null);
  assert.equal(store.get(`searchRequests/${secondStudentId}`).lockOwner, null);
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).lockExpiresAt,
    null,
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).lockExpiresAt,
    null,
  );
  assert.equal(store.get(`users/${firstStudentId}`).currentSessionId, undefined);
  assert.equal(store.get(`users/${secondStudentId}`).currentSessionId, undefined);
  assert.equal(store.get(`users/${firstStudentId}`).isInCall, false);
  assert.equal(store.get(`users/${secondStudentId}`).isInCall, false);
  assert.equal(store.get(`users/${firstStudentId}`).isAvailable, true);
  assert.equal(store.get(`users/${secondStudentId}`).isAvailable, true);
});

test("endSession callable clears student-teacher call state and student queue", async () => {
  const startedAtMillis = Date.now() - 90_000;
  const sessionId = "session-active-ended-student-teacher";
  const studentId = "student-callable-teacher-cleanup";
  const teacherId = "teacher-callable-cleanup";
  const pairAttemptId = `pair-${sessionId}-${studentId}-${teacherId}`;
  const {firestore, store} = createFakeFirestore({
    [`users/${studentId}`]: studentUser({
      currentSessionId: sessionId,
      isInCall: true,
      isAvailable: false,
    }),
    [`users/${teacherId}`]: studentUser({
      role: "native_speaker",
      currentSessionId: sessionId,
      isInCall: true,
      isAvailable: false,
      balance_NS: 0,
    }),
    [`searchRequests/${studentId}`]: activeSearchRequest(studentId, {
      currentSessionId: sessionId,
      activeSessionId: sessionId,
      matchedSessionId: sessionId,
      matchedUserId: teacherId,
      matchedResponderId: teacherId,
      matchedRole: "native_speaker",
      pairAttemptId,
      lockOwner: pairAttemptId,
      lockExpiresAt: timestampFromMillis(Date.now() + 45_000),
    }),
    [`videoSessions/${sessionId}`]: {
      status: "active",
      language: "en",
      studentId,
      tutorId: teacherId,
      requesterId: studentId,
      requesterRole: "student",
      responderId: teacherId,
      responderRole: "native_speaker",
      currentTutorId: teacherId,
      currentResponderId: teacherId,
      currentResponderRole: "native_speaker",
      participantIds: [studentId, teacherId],
      participantRoles: {
        [studentId]: "student",
        [teacherId]: "native_speaker",
      },
      searchRequestIds: {
        requester: `request-${studentId}`,
      },
      matchContext: {
        requesterRole: "student",
        acceptedResponderId: teacherId,
        acceptedResponderRole: "native_speaker",
      },
      dailyRoomName: "room-student-teacher-cleanup",
      createdAt: timestampFromMillis(startedAtMillis - 60_000),
      sessionMetadata: {
        callConnectedAtTimestamp: startedAtMillis,
      },
    },
  });

  const response = await withFakeFirestore(firestore, () =>
    endSession.run(
      {sessionId, endReason: "user_ended"},
      {auth: {uid: teacherId}},
    ));

  assert.equal(response.status, "ended");
  assert.equal(response.endedBy, "responder");
  assert.equal(store.get(`videoSessions/${sessionId}`).status, "ended");
  assert.equal(
    store.get(`searchRequests/${studentId}`).status,
    "stopped",
  );
  assert.equal(
    store.get(`searchRequests/${studentId}`).stopReason,
    "session_ended",
  );
  assert.equal(store.get(`searchRequests/${studentId}`).currentSessionId, null);
  assert.equal(
    store.get(`searchRequests/${studentId}`).activeSessionId,
    undefined,
  );
  assert.equal(
    store.get(`searchRequests/${studentId}`).matchedSessionId,
    undefined,
  );
  assert.equal(store.get(`searchRequests/${studentId}`).matchedUserId, null);
  assert.equal(
    store.get(`searchRequests/${studentId}`).matchedResponderId,
    undefined,
  );
  assert.equal(store.get(`searchRequests/${studentId}`).matchedRole, null);
  assert.equal(store.get(`searchRequests/${studentId}`).pairAttemptId, null);
  assert.equal(store.get(`searchRequests/${studentId}`).lockOwner, null);
  assert.equal(store.get(`searchRequests/${studentId}`).lockExpiresAt, null);
  assert.equal(store.get(`searchRequests/${teacherId}`), undefined);
  assert.equal(store.get(`users/${studentId}`).currentSessionId, undefined);
  assert.equal(store.get(`users/${teacherId}`).currentSessionId, undefined);
  assert.equal(store.get(`users/${studentId}`).isInCall, false);
  assert.equal(store.get(`users/${teacherId}`).isInCall, false);
  assert.equal(store.get(`users/${studentId}`).isAvailable, true);
  assert.equal(store.get(`users/${teacherId}`).isAvailable, true);
});

test("endSession callable cancels pre-active user-ended sessions", async () => {
  const sessionId = "session-pre-active-cancelled";
  const firstStudentId = "student-pre-active-cancel-a";
  const secondStudentId = "student-pre-active-cancel-b";
  const {firestore, store} = createFakeFirestore(callableSessionSeed({
    sessionId,
    firstStudentId,
    secondStudentId,
    status: "connecting",
  }));

  const response = await withFakeFirestore(firestore, () =>
    endSession.run(
      {sessionId, endReason: "user_ended"},
      {auth: {uid: firstStudentId}},
    ));
  const sessionData = store.get(`videoSessions/${sessionId}`);

  assert.equal(response.status, "cancelled");
  assert.equal(sessionData.status, "cancelled");
  assert.equal(sessionData.cancelReason, "pre_active_cancelled");
  assert.notEqual(sessionData.status, "ended");
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).status,
    "cancelled",
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).status,
    "cancelled",
  );
});

test("pre-active protocol v2 end closes the exact peer CallKit surface", async () => {
  const sessionId = "session-pre-active-v2-cancelled";
  const firstStudentId = "student-pre-active-v2-a";
  const secondStudentId = "student-pre-active-v2-b";
  const pairAttemptId = "pair-pre-active-v2";
  const notificationId = incomingCallNotificationId(
    sessionId,
    secondStudentId,
    pairAttemptId,
  );
  const seed = callableSessionSeed({
    sessionId,
    firstStudentId,
    secondStudentId,
    status: "connecting",
    overrides: {
      matchProtocolVersion: 2,
      pairAttemptId,
      participantStates: {
        [firstStudentId]: {
          role: "student",
          surface: "in_app",
          decision: "accepted",
          delivery: "not_required",
          callKitId: "callkit-first",
        },
        [secondStudentId]: {
          role: "student",
          surface: "callkit",
          decision: "accepted",
          delivery: "sent",
          callKitId: "callkit-second",
        },
      },
    },
  });
  seed[`notifications/${notificationId}`] = {
    type: "incoming_call",
    sessionId,
    recipientId: secondStudentId,
    pairAttemptId,
    callKitId: "callkit-second",
    status: "sent",
  };
  const {firestore, store} = createFakeFirestore(seed);

  const response = await withFakeFirestore(firestore, () =>
    endSession.run(
      {sessionId, endReason: "user_ended"},
      {auth: {uid: firstStudentId}},
    ));

  assert.equal(response.status, "cancelled");
  assert.equal(
    store.get(`notifications/${notificationId}`).status,
    "cancelled",
  );
  assert.equal(
    store.get(`notifications/${notificationId}`).callKitId,
    "callkit-second",
  );
  assert.equal(
    store.get(`videoSessions/${sessionId}`).matchRecovery.status,
    "pending",
  );
});

test("endSession callable expires pre-active expired sessions", async () => {
  const sessionId = "session-pre-active-expired";
  const firstStudentId = "student-pre-active-expired-a";
  const secondStudentId = "student-pre-active-expired-b";
  const {firestore, store} = createFakeFirestore(callableSessionSeed({
    sessionId,
    firstStudentId,
    secondStudentId,
    status: "connecting",
  }));

  const response = await withFakeFirestore(firestore, () =>
    endSession.run(
      {sessionId, endReason: "expired"},
      {auth: {uid: firstStudentId}},
    ));
  const sessionData = store.get(`videoSessions/${sessionId}`);

  assert.equal(response.status, "expired");
  assert.equal(sessionData.status, "expired");
  assert.equal(sessionData.expireReason, "pre_active_expired");
  assert.notEqual(sessionData.status, "ended");
  assert.equal(
    store.get(`searchRequests/${firstStudentId}`).status,
    "expired",
  );
  assert.equal(
    store.get(`searchRequests/${secondStudentId}`).status,
    "expired",
  );
});

test("endSession callable keeps already terminal sessions terminal", async () => {
  for (const terminalStatus of ["cancelled", "expired"]) {
    const sessionId = `session-already-${terminalStatus}`;
    const firstStudentId = `student-already-${terminalStatus}-a`;
    const secondStudentId = `student-already-${terminalStatus}-b`;
    const {firestore, store} = createFakeFirestore(callableSessionSeed({
      sessionId,
      firstStudentId,
      secondStudentId,
      status: terminalStatus,
    }));

    const response = await withFakeFirestore(firestore, () =>
      endSession.run(
        {sessionId, endReason: "user_ended"},
        {auth: {uid: firstStudentId}},
      ));

    assert.equal(response.status, `already_${terminalStatus}`);
    assert.equal(store.get(`videoSessions/${sessionId}`).status, terminalStatus);
    assert.notEqual(store.get(`videoSessions/${sessionId}`).status, "ended");
  }
});

test("buildStudentCallCharge debits gift minutes for non-subscribers", () => {
  // 3-minute call against a 10-minute gift bucket → 7 minutes left.
  const charge = buildStudentCallCharge({
    userId: "student-a",
    duration: 180,
    formattedDuration: "3:00",
    giftRemainingMinutes: 10,
  });

  assert.equal(charge.subscriptionActive, false);
  assert.equal(charge.giftCovered, true);
  assert.equal(charge.giftMinutesUsed, 3);
  assert.equal(charge.newGiftMinutes, 7);
  assert.equal(charge.amountST, 0);
});

test("buildStudentCallCharge handles call longer than gift bucket", () => {
  // 5-minute call against 2-minute gift bucket → bucket drained to 0,
  // remainder is unbilled (the gate already let them in).
  const charge = buildStudentCallCharge({
    userId: "student-b",
    duration: 300,
    formattedDuration: "5:00",
    giftRemainingMinutes: 2,
  });

  assert.equal(charge.giftCovered, true);
  assert.equal(charge.giftMinutesUsed, 2);
  assert.equal(charge.newGiftMinutes, 0);
});

test("buildStudentCallCharge marks call uncovered when no gift bucket", () => {
  const charge = buildStudentCallCharge({
    userId: "student-c",
    duration: 120,
    formattedDuration: "2:00",
    giftRemainingMinutes: 0,
  });

  assert.equal(charge.subscriptionActive, false);
  assert.equal(charge.giftCovered, false);
  assert.equal(charge.giftMinutesUsed, 0);
});

test("resolveTeacherEarningUserId pays the teacher regardless of call direction", () => {
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "student-a",
      requesterRole: "student",
      responderId: "teacher-b",
      acceptedResponderRole: "native_speaker",
    }),
    "teacher-b",
  );
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "teacher-a",
      requesterRole: "native_speaker",
      responderId: "student-b",
      acceptedResponderRole: "student",
    }),
    "teacher-a",
  );
  assert.equal(
    resolveTeacherEarningUserId({
      requesterId: "student-a",
      requesterRole: "student",
      responderId: "student-b",
      acceptedResponderRole: "student",
    }),
    null,
  );
});

test("buildStudentCallCharge skips debit when subscription is active", () => {
  const charge = buildStudentCallCharge({
    userId: "student-a",
    duration: 1800, // 30 minutes
    formattedDuration: "30:00",
    subscriptionActive: true,
    giftRemainingMinutes: 10,
  });

  assert.equal(charge.subscriptionActive, true);
  assert.equal(charge.billableMinutes, 0);
  assert.equal(charge.amountST, 0);
  assert.equal(charge.giftCovered, false);
  // Gift bucket is preserved — subscription wins.
  assert.equal(charge.newGiftMinutes, 10);
  assert.equal(charge.giftMinutesUsed, 0);
});

test("hasActiveSubscription compares expiresAt against the current millis", () => {
  const now = Date.parse("2026-05-11T12:00:00Z");
  const futureTs = {
    toMillis: () => Date.parse("2026-05-15T00:00:00Z"),
  };
  const pastTs = {
    toMillis: () => Date.parse("2026-05-01T00:00:00Z"),
  };

  assert.equal(
      hasActiveSubscription({subscription: {expiresAt: futureTs}}, now),
      true,
  );
  assert.equal(
      hasActiveSubscription({subscription: {expiresAt: pastTs}}, now),
      false,
  );
  assert.equal(
      hasActiveSubscription({subscription: {}}, now),
      false,
  );
  assert.equal(hasActiveSubscription({}, now), false);
  assert.equal(hasActiveSubscription(null, now), false);
});

test("endSession source keeps the ignored_expired_end wrapper path", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "end_session.js"),
    "utf8",
  );

  assert.match(source, /shouldProcessExpiredEndReason\(\{/);
  assert.match(source, /status:\s*"ignored_expired_end"/);
  assert.match(source, /isPreActiveConnecting/);
  assert.match(source, /status:\s*terminalStatus/);
  assert.match(source, /source:\s*"endSession_pre_active_terminal"/);
  assert.match(source, /acceptedResponderRole === "student"/);
  assert.match(source, /acceptedResponderRole === "native_speaker"/);
  assert.match(source, /teacherEarningUserId/);
  assert.match(source, /txResult\.teacherEligibleForPayout/);
  assert.match(source, /getConnectedCallStartMillis\(sessionData\)/);
  assert.match(source, /acceptAttemptId: admin\.firestore\.FieldValue\.delete\(\)/);
  assert.doesNotMatch(source, /serverConnectedAt/);
  assert.match(
    source,
    /\.runWith\(\{secrets:\s*\[\.\.\.apnsSecrets,\s*\.\.\.dailySecrets\]\}\)/,
  );
  assert.match(source, /dailyRoomName:\s*resolveDailyRoomName\(sessionData\)/);
  assert.match(
    source,
    /backgroundTasks\.push\(deleteDailyRoomForSession\(\{/,
  );
  assert.match(source, /source:\s*"endSession_already_ended"/);
  assert.doesNotMatch(source, /serverConnectedAt/);
  assert.doesNotMatch(source, /startedAt\s*>\s*0/);
});
