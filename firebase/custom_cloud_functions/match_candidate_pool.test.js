const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  MATCH_CANDIDATE_SOURCE,
  buildActiveStudentSearchRequestsQuery,
  buildAvailableTeachersQuery,
  buildStudentQueueCandidateFromDocs,
  buildTeacherAvailabilityCandidateFromDoc,
  collectMatchCandidatePool,
  isActiveStudentSearchRequest,
  mergeCandidatePools,
} = require("./match_candidate_pool");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");

const fixedNowMillis = Date.UTC(2026, 0, 1, 12, 0, 0);

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function doc(id, data, exists = true) {
  return {
    id,
    exists,
    data: () => data,
  };
}

function fakeQuery(docs, {limitCount = null, startAfterId = ""} = {}) {
  return {
    where: () => fakeQuery(docs, {limitCount, startAfterId}),
    orderBy: () => fakeQuery(docs, {limitCount, startAfterId}),
    limit: (count) => fakeQuery(docs, {limitCount: count, startAfterId}),
    startAfter: (lastDoc) => fakeQuery(docs, {
      limitCount,
      startAfterId: lastDoc?.id || "",
    }),
    get: async () => {
      const startIndex = startAfterId ?
        docs.findIndex((entry) => entry.id === startAfterId) + 1 :
        0;
      const pageDocs = docs.slice(Math.max(startIndex, 0));
      return {
        docs: limitCount ? pageDocs.slice(0, limitCount) : pageDocs,
      };
    },
  };
}

function fakeDb({studentRequestDocs = [], teacherDocs = [], userDocsById = {}}) {
  return {
    collection: (name) => {
      if (name === "searchRequests") {
        return fakeQuery(studentRequestDocs);
      }
      if (name === "users") {
        return {
          ...fakeQuery(teacherDocs),
          doc: (id) => ({
            get: async () => userDocsById[id] || doc(id, null, false),
          }),
        };
      }
      throw new Error(`Unexpected collection: ${name}`);
    },
  };
}

function activeRequest(overrides = {}) {
  return {
    requestId: "request-a",
    userId: "student-a",
    userRef: {id: "student-a"},
    role: "student",
    language: "en",
    filters: {preferredLevel: "B1", levelRank: 3},
    status: SEARCH_REQUEST_STATUS.ACTIVE,
    appState: "foreground",
    createdAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
    heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    expiresAt: timestampFromMillis(fixedNowMillis + 8 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: null,
    matchedUserId: null,
    matchedResponderId: null,
    matchedSessionId: null,
    matchedRole: null,
    pairAttemptId: null,
    lockOwner: null,
    ...overrides,
  };
}

function studentData(overrides = {}) {
  return {
    role: "student",
    display_name: "Student A",
    learningLanguage: {code: "en"},
    level: {value: "B1"},
    ...overrides,
  };
}

function teacherData(overrides = {}) {
  return {
    role: "native_speaker",
    display_name: "Teacher A",
    language_instruction_NS: {code: "en"},
    level: {value: "C1"},
    verif_NS: true,
    isAvailable: true,
    created_time: timestampFromMillis(fixedNowMillis - 300 * 1000),
    availableSince: timestampFromMillis(fixedNowMillis - 240 * 1000),
    ...overrides,
  };
}

test("active student candidates come only from fresh active search requests", () => {
  assert.equal(
    isActiveStudentSearchRequest(activeRequest(), fixedNowMillis),
    true,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      status: SEARCH_REQUEST_STATUS.MATCHING,
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      expiresAt: timestampFromMillis(fixedNowMillis),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      appState: "background",
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      lockOwner: "matcher-a",
    }), fixedNowMillis),
    false,
  );
});

test("student queue candidate carries neutral pool shape", () => {
  const candidate = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-a", activeRequest()),
    userDoc: doc("student-a", studentData()),
    language: "en",
    nowMillis: fixedNowMillis,
  });

  assert.equal(candidate.userId, "student-a");
  assert.equal(candidate.role, "student");
  assert.equal(
    candidate.source,
    MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE,
  );
  assert.equal(candidate.searchRequestId, "request-a");
  assert.equal(candidate.searchRequestDocId, "student-a");
  assert.equal(candidate.language, "en");
  assert.equal(candidate.availability.reason, "active_search_request");
  assert.equal(candidate.profile.role, "student");
});

test("student queue candidate rejects missing user and changed role", () => {
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-a", null, false),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-a", studentData({role: "native_speaker"})),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest({
        userRef: {id: "student-b"},
      })),
      userDoc: doc("student-a", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-b", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate requires approved available teacher", () => {
  const candidate = buildTeacherAvailabilityCandidateFromDoc({
    userDoc: doc("teacher-a", teacherData()),
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.equal(candidate.userId, "teacher-a");
  assert.equal(candidate.role, "native_speaker");
  assert.equal(candidate.source, MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY);
  assert.equal(candidate.searchRequestId, null);
  assert.equal(candidate.language, "en");
  assert.equal(candidate.availability.isAvailable, true);
  assert.equal(candidate.profile.approvedTeacher, true);

  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({verif_NS: false})),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({isAvailable: false})),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("candidate pool merge is ordered by waiting time, not role", () => {
  const candidates = mergeCandidatePools({
    studentCandidates: [
      {
        userId: "student-a",
        role: "student",
        source: MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE,
        joinedPoolAtMillis: fixedNowMillis - 60 * 1000,
      },
    ],
    teacherCandidates: [
      {
        userId: "teacher-a",
        role: "native_speaker",
        source: MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY,
        joinedPoolAtMillis: fixedNowMillis - 120 * 1000,
      },
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
});

test("candidate pool merge excludes requester and dedupes by user", () => {
  const candidates = mergeCandidatePools({
    requesterId: "student-a",
    studentCandidates: [
      {userId: "student-a", joinedPoolAtMillis: 1},
      {userId: "student-b", joinedPoolAtMillis: 2},
    ],
    teacherCandidates: [
      {userId: "student-b", joinedPoolAtMillis: 1},
      {userId: "teacher-a", joinedPoolAtMillis: 3},
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["student-b", "teacher-a"],
  );
});

test("collectMatchCandidatePool combines queue students and teachers", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-a", activeRequest({
        createdAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
      })),
    ],
    teacherDocs: [
      doc("teacher-a", teacherData({
        availableSince: timestampFromMillis(fixedNowMillis - 240 * 1000),
      })),
    ],
    userDocsById: {
      "student-a": doc("student-a", studentData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
  assert.deepEqual(result.stats, {
    studentRequestsScanned: 1,
    studentCandidates: 1,
    teacherUsersScanned: 1,
    teacherCandidates: 1,
    totalCandidates: 2,
  });
});

test("collectMatchCandidatePool excludes requester from unified pool", async () => {
  const db = fakeDb({
    studentRequestDocs: [doc("student-a", activeRequest())],
    teacherDocs: [doc("teacher-a", teacherData())],
    userDocsById: {
      "student-a": doc("student-a", studentData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    requesterId: "teacher-a",
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-a"],
  );
  assert.equal(result.stats.totalCandidates, 1);
});

test("collectMatchCandidatePool scans past invalid first page docs", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-stale", activeRequest({
        userId: "student-stale",
        userRef: {id: "student-stale"},
        heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
      })),
      doc("student-a", activeRequest()),
    ],
    teacherDocs: [
      doc("teacher-unavailable", teacherData({isAvailable: false})),
      doc("teacher-a", teacherData()),
    ],
    userDocsById: {
      "student-stale": doc("student-stale", studentData()),
      "student-a": doc("student-a", studentData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    studentLimit: 1,
    teacherLimit: 1,
    studentScanPageSize: 1,
    teacherScanPageSize: 1,
    studentMaxScanPages: 3,
    teacherMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
  assert.equal(result.stats.studentRequestsScanned, 2);
  assert.equal(result.stats.teacherUsersScanned, 2);
  assert.equal(result.stats.studentCandidates, 1);
  assert.equal(result.stats.teacherCandidates, 1);
});

test("candidate pool queries use canonical active queue and teacher sources", () => {
  const calls = [];
  const query = {
    where: (...args) => {
      calls.push(["where", ...args]);
      return query;
    },
    orderBy: (...args) => {
      calls.push(["orderBy", ...args]);
      return query;
    },
    limit: (...args) => {
      calls.push(["limit", ...args]);
      return query;
    },
  };
  const db = {
    collection: (name) => {
      calls.push(["collection", name]);
      return query;
    },
  };

  buildActiveStudentSearchRequestsQuery(db, {language: " EN ", limit: 10});
  buildAvailableTeachersQuery(db, {language: " EN ", limit: 20});

  assert.deepEqual(calls, [
    ["collection", "searchRequests"],
    ["where", "status", "==", "active"],
    ["where", "language", "==", "en"],
    ["orderBy", "createdAt", "asc"],
    ["limit", 10],
    ["collection", "users"],
    ["where", "role", "==", "native_speaker"],
    ["where", "language_instruction_NS.code", "==", "en"],
    ["limit", 20],
  ]);
});

test("candidate pool indexes support active search request queries", () => {
  const indexes = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "firestore.indexes.json"),
    "utf8",
  ));
  const hasStatusCreatedAtIndex = indexes.indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
    index.fields.some((field) => field.fieldPath === "status") &&
    index.fields.some((field) => field.fieldPath === "createdAt"),
  );
  const hasStatusLanguageCreatedAtIndex = indexes.indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
    index.fields.some((field) => field.fieldPath === "status") &&
    index.fields.some((field) => field.fieldPath === "language") &&
    index.fields.some((field) => field.fieldPath === "createdAt"),
  );

  assert.equal(hasStatusCreatedAtIndex, true);
  assert.equal(hasStatusLanguageCreatedAtIndex, true);
});
