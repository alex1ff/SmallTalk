const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CALL_HISTORY_BRANCH_PAGE_SIZE,
  CALL_HISTORY_QUERY_BRANCHES,
  canIncludeCallHistorySession,
  collectCallHistoryPaths,
  normalizeGetCallHistoryPayload,
  resolveSessionStartedAtMillis,
  selectCallHistoryPathEntries,
} = require("./get_call_history.js");

function doc(path, data) {
  return {
    ref: {path},
    data: () => data,
  };
}

function invalidArgumentError(error) {
  return error && error.code === "invalid-argument";
}

function fieldValue(data, field) {
  return field.split(".").reduce((value, key) => {
    if (!value || typeof value !== "object") {
      return undefined;
    }
    return value[key];
  }, data);
}

class FakeHistoryQuery {
  constructor(db, options = {}) {
    this.db = db;
    this.options = options;
  }

  where(field, operator, uid) {
    return new FakeHistoryQuery(this.db, {
      ...this.options,
      field,
      operator,
      uid,
    });
  }

  orderBy(_) {
    return this;
  }

  startAfter(afterDoc) {
    return new FakeHistoryQuery(this.db, {
      ...this.options,
      afterPath: afterDoc.ref.path,
    });
  }

  limit(limit) {
    return new FakeHistoryQuery(this.db, {
      ...this.options,
      limit,
    });
  }

  async get() {
    this.db.readCount += 1;
    let docs = [...this.db.docs].sort((left, right) =>
      left.ref.path.localeCompare(right.ref.path),
    );
    if (this.options.field) {
      docs = docs.filter((item) => {
        const value = fieldValue(item.data(), this.options.field);
        if (this.options.operator === "array-contains") {
          return Array.isArray(value) && value.includes(this.options.uid);
        }
        return value === this.options.uid;
      });
    }
    if (this.options.afterPath) {
      docs = docs.filter((item) => item.ref.path > this.options.afterPath);
    }
    return {
      docs: docs.slice(0, this.options.limit),
    };
  }
}

function fakeHistoryDb(docs) {
  return {
    docs,
    readCount: 0,
    collection(name) {
      assert.equal(name, "videoSessions");
      return new FakeHistoryQuery(this);
    },
  };
}

test("call history payload accepts only bounded limit", () => {
  assert.deepEqual(normalizeGetCallHistoryPayload(undefined), {limit: 100});
  assert.deepEqual(normalizeGetCallHistoryPayload({limit: 2}), {limit: 2});
  assert.throws(
      () => normalizeGetCallHistoryPayload({limit: 0}),
      invalidArgumentError,
  );
  assert.throws(
      () => normalizeGetCallHistoryPayload({limit: 201}),
      invalidArgumentError,
  );
  assert.throws(
      () => normalizeGetCallHistoryPayload({cursor: "x"}),
      invalidArgumentError,
  );
});

test("call history participant filter ignores stale legacy mirrors", () => {
  assert.equal(
      canIncludeCallHistorySession({
        status: "ended",
        studentId: "stale-user",
        tutorId: "stale-tutor",
        requesterId: "actual-requester",
        responderId: "actual-responder",
      }, "stale-user"),
      false,
  );
  assert.equal(
      canIncludeCallHistorySession({
        status: "ended",
        studentId: "legacy-student",
        tutorId: "legacy-tutor",
      }, "legacy-student"),
      true,
  );
  assert.equal(
      canIncludeCallHistorySession({
        status: "active",
        participantIds: ["current-user", "peer-user"],
      }, "current-user"),
      false,
  );
});

test("call history selector dedupes, filters, and sorts by connected time", () => {
  const selected = selectCallHistoryPathEntries([
    doc("videoSessions/old", {
      status: "ended",
      participantIds: ["current-user", "peer-user"],
      startedAt: new Date("2026-05-12T10:00:00.000Z"),
    }),
    doc("videoSessions/stale", {
      status: "ended",
      participantIds: ["actual-requester", "actual-responder"],
      studentId: "current-user",
      requesterId: "actual-requester",
      responderId: "actual-responder",
      startedAt: new Date("2026-05-15T10:00:00.000Z"),
    }),
    doc("videoSessions/new", {
      status: "ended",
      participantIds: ["requester-only"],
      matchContext: {
        requesterId: "requester-only",
        acceptedResponderId: "current-user",
      },
      sessionMetadata: {
        callConnectedAt: new Date("2026-05-13T12:00:00.000Z"),
      },
      startedAt: new Date("2026-05-13T11:00:00.000Z"),
    }),
    doc("videoSessions/old", {
      status: "ended",
      participantIds: ["current-user", "peer-user"],
      startedAt: new Date("2026-05-12T10:00:00.000Z"),
    }),
  ], "current-user", 10);

  assert.deepEqual(
      selected.map((entry) => entry.path),
      ["videoSessions/new", "videoSessions/old"],
  );
});

test("call history collection paginates past stale branch documents", async () => {
  const activeDocs = Array.from(
      {length: CALL_HISTORY_BRANCH_PAGE_SIZE + 5},
      (_, index) => doc(`videoSessions/active-${String(index).padStart(4, "0")}`, {
        status: "active",
        participantIds: ["current-user", "peer-user"],
      }),
  );
  const db = fakeHistoryDb([
    ...activeDocs,
    doc("videoSessions/zz-ended", {
      status: "ended",
      participantIds: ["current-user", "peer-user"],
      startedAt: new Date("2026-05-12T10:00:00.000Z"),
    }),
  ]);

  const paths = await collectCallHistoryPaths({
    db,
    uid: "current-user",
    limit: 1,
  });

  assert.deepEqual(paths, ["videoSessions/zz-ended"]);
  assert.equal(db.readCount, CALL_HISTORY_QUERY_BRANCHES.length + 1);
});

test("call history start timestamp supports legacy connected metadata shapes", () => {
  assert.equal(
      resolveSessionStartedAtMillis({
        sessionMetadata: {
          callConnectedAtTimestamp: "1780000000000",
        },
        startedAt: new Date("2026-05-12T10:00:00.000Z"),
      }),
      1780000000000,
  );
  assert.equal(
      resolveSessionStartedAtMillis({
        dailyWebhookConnectedAt: "2026-05-12T10:00:00.000Z",
      }),
      new Date("2026-05-12T10:00:00.000Z").getTime(),
  );
});
