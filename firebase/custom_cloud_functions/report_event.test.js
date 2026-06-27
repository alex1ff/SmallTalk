const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__: {
    buildEventReportId,
    executeReportEventTransaction,
    normalizeReportEventPayload,
    reportEventHandler,
  },
} = require("./report_event");

const fixedNow = new Date("2026-06-16T10:00:00.000Z");
const fixedTimestamp = {
  toMillis: () => fixedNow.getTime(),
  toDate: () => fixedNow,
};

function assertHttpsError(fn, code, domainCode, field, reason) {
  assert.throws(fn, (err) => {
    assert.equal(err.code, code);
    assert.equal(err.details?.domainCode, domainCode);
    if (field) {
      assert.equal(err.details?.field, field);
    }
    if (reason) {
      assert.equal(err.details?.reason, reason);
    }
    return true;
  });
}

async function assertRejectsHttpsError(
    promiseFactory,
    code,
    domainCode,
    reason,
) {
  await assert.rejects(promiseFactory, (err) => {
    assert.equal(err.code, code);
    assert.equal(err.details?.domainCode, domainCode);
    if (reason) {
      assert.equal(err.details?.reason, reason);
    }
    return true;
  });
}

function createFakeFirestore(seed = {}) {
  const store = new Map(Object.entries(seed));
  const reads = [];
  const writes = [];

  const makeRef = (path) => ({
    path,
    id: path.split("/").pop(),
    collection(name) {
      return makeCollection(`${path}/${name}`);
    },
    async get() {
      const data = store.get(path);
      return {
        exists: data !== undefined,
        data: () => data,
        ref: makeRef(path),
      };
    },
  });

  const makeCollection = (path) => ({
    doc(id) {
      return makeRef(`${path}/${id}`);
    },
  });

  const db = {
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      let hasWrites = false;
      const pendingWrites = [];
      const tx = {
        async get(ref) {
          if (hasWrites) {
            throw new Error("Firestore transactions require reads first");
          }
          reads.push(ref.path);
          return ref.get();
        },
        create(ref, data) {
          hasWrites = true;
          if (store.has(ref.path)) {
            throw new Error(`Document already exists: ${ref.path}`);
          }
          pendingWrites.push({type: "create", path: ref.path, data});
        },
      };
      const result = await callback(tx);
      for (const write of pendingWrites) {
        writes.push(write);
        store.set(write.path, write.data);
      }
      return result;
    },
  };

  return {db, reads, store, writes};
}

function activeEvent(overrides = {}) {
  return {
    organizerId: "organizer-1",
    status: "active",
    canceledAt: null,
    title: "Conversation club",
    startsAt: fixedTimestamp,
    countryCode: "RU",
    cityKey: "moscow",
    ...overrides,
  };
}

test("normalizeReportEventPayload accepts exact supported payload", () => {
  assert.deepEqual(
      normalizeReportEventPayload({
        eventId: " event-1 ",
        reasonCode: " UNSAFE ",
        details: "  Опасное место  ",
      }),
      {
        eventId: "event-1",
        reasonCode: "unsafe",
        details: "Опасное место",
      },
  );
  assert.deepEqual(
      normalizeReportEventPayload({
        eventId: "event-1",
        reasonCode: "spam",
      }),
      {
        eventId: "event-1",
        reasonCode: "spam",
        details: null,
      },
  );
});

test("normalizeReportEventPayload rejects invalid payloads", () => {
  const invalidCases = [
    {
      payload: null,
      field: "payload",
      reason: "invalid_type",
    },
    {
      payload: {eventId: "event-1"},
      field: "reasonCode",
      reason: "missing",
    },
    {
      payload: {eventId: "event-1", reasonCode: "spam", extra: true},
      field: "extra",
      reason: "unknown_key",
    },
    {
      payload: {eventId: "events/event-1", reasonCode: "spam"},
      field: "eventId",
      reason: "invalid_format",
    },
    {
      payload: {eventId: "event-1", reasonCode: "bad"},
      field: "reasonCode",
      reason: "unsupported",
    },
    {
      payload: {eventId: "event-1", reasonCode: "spam", details: 42},
      field: "details",
      reason: "invalid_type",
    },
    {
      payload: {
        eventId: "event-1",
        reasonCode: "spam",
        details: "a".repeat(501),
      },
      field: "details",
      reason: "too_long",
    },
  ];

  for (const currentCase of invalidCases) {
    assertHttpsError(
        () => normalizeReportEventPayload(currentCase.payload),
        "invalid-argument",
        "invalid_report_event_request",
        currentCase.field,
        currentCase.reason,
    );
  }
});

test("executeReportEventTransaction creates a private event report", async () => {
  const {db, reads, store, writes} = createFakeFirestore({
    "events/event-1": activeEvent(),
  });
  const expectedReportId = buildEventReportId({
    eventId: "event-1",
    reporterId: "student-1",
  });

  const result = await executeReportEventTransaction({
    db,
    eventId: "event-1",
    reporterId: "student-1",
    reasonCode: "unsafe",
    details: "Organizer asked for payment outside the app.",
    reportDate: fixedNow,
    reportTimestamp: fixedTimestamp,
  });

  assert.deepEqual(reads, [
    "events/event-1",
    `eventReports/${expectedReportId}`,
  ]);
  assert.deepEqual(result, {
    eventId: "event-1",
    reportId: expectedReportId,
    status: "submitted",
    reportedAt: "2026-06-16T10:00:00.000Z",
  });
  assert.equal(writes.length, 1);
  assert.equal(writes[0].type, "create");
  assert.equal(writes[0].path, `eventReports/${expectedReportId}`);

  const report = store.get(`eventReports/${expectedReportId}`);
  assert.equal(report.eventId, "event-1");
  assert.equal(report.eventPath, "events/event-1");
  assert.equal(report.eventRef.path, "events/event-1");
  assert.equal(report.reporterId, "student-1");
  assert.equal(report.reporterRef.path, "users/student-1");
  assert.equal(report.organizerId, "organizer-1");
  assert.equal(report.organizerRef.path, "users/organizer-1");
  assert.equal(report.reasonCode, "unsafe");
  assert.equal(report.details, "Organizer asked for payment outside the app.");
  assert.equal(report.status, "open");
  assert.equal(report.createdAt, fixedTimestamp);
  assert.deepEqual(report.eventSnapshot, {
    title: "Conversation club",
    status: "active",
    startsAt: fixedTimestamp,
    countryCode: "RU",
    cityKey: "moscow",
    organizerId: "organizer-1",
  });
});

test("executeReportEventTransaction is idempotent per user and event",
    async () => {
      const reportId = buildEventReportId({
        eventId: "event-1",
        reporterId: "student-1",
      });
      const existingReport = {
        eventId: "event-1",
        reporterId: "student-1",
        createdAt: fixedTimestamp,
      };
      const {db, store, writes} = createFakeFirestore({
        "events/event-1": activeEvent(),
        [`eventReports/${reportId}`]: existingReport,
      });

      const result = await executeReportEventTransaction({
        db,
        eventId: "event-1",
        reporterId: "student-1",
        reasonCode: "spam",
        reportDate: new Date("2026-06-17T10:00:00.000Z"),
        reportTimestamp: fixedTimestamp,
      });

      assert.deepEqual(result, {
        eventId: "event-1",
        reportId,
        status: "already_submitted",
        reportedAt: "2026-06-16T10:00:00.000Z",
      });
      assert.equal(writes.length, 0);
      assert.equal(store.get(`eventReports/${reportId}`), existingReport);
    });

test("executeReportEventTransaction rejects unreportable event state",
    async () => {
      const unreportableEvents = [
        {
          name: "canceled status",
          eventData: activeEvent({status: "canceled"}),
          domainCode: "event_not_reportable",
          reason: "not_active",
        },
        {
          name: "active with canceled timestamp",
          eventData: activeEvent({canceledAt: fixedTimestamp}),
          domainCode: "event_not_reportable",
          reason: "event_canceled",
        },
        {
          name: "missing organizer",
          eventData: activeEvent({organizerId: ""}),
          domainCode: "event_report_state_inconsistent",
          reason: "organizer_invalid",
        },
        {
          name: "path organizer",
          eventData: activeEvent({organizerId: "users/organizer-1"}),
          domainCode: "event_report_state_inconsistent",
          reason: "organizer_invalid",
        },
      ];

      for (const currentCase of unreportableEvents) {
        const {db, writes} = createFakeFirestore({
          "events/event-1": currentCase.eventData,
        });
        await assertRejectsHttpsError(
            () => executeReportEventTransaction({
              db,
              eventId: "event-1",
              reporterId: "student-1",
              reasonCode: "spam",
              reportTimestamp: fixedTimestamp,
            }),
            "failed-precondition",
            currentCase.domainCode,
            currentCase.reason,
        );
        assert.equal(writes.length, 0, currentCase.name);
      }
    });

test("executeReportEventTransaction rejects missing and self-reported events",
    async () => {
      await assertRejectsHttpsError(
          () => executeReportEventTransaction({
            db: createFakeFirestore({}).db,
            eventId: "event-1",
            reporterId: "student-1",
            reasonCode: "spam",
            reportTimestamp: fixedTimestamp,
          }),
          "not-found",
          "event_not_found",
      );

      await assertRejectsHttpsError(
          () => executeReportEventTransaction({
            db: createFakeFirestore({
              "events/event-1": activeEvent({organizerId: "student-1"}),
            }).db,
            eventId: "event-1",
            reporterId: "student-1",
            reasonCode: "spam",
            reportTimestamp: fixedTimestamp,
          }),
          "failed-precondition",
          "event_report_self",
      );
    });

test("reportEventHandler rejects missing auth", async () => {
  await assertRejectsHttpsError(
      () => reportEventHandler(
          {eventId: "event-1", reasonCode: "spam"},
          {},
          {
            db: createFakeFirestore({"events/event-1": activeEvent()}).db,
            reportDate: fixedNow,
            reportTimestamp: fixedTimestamp,
          },
      ),
      "unauthenticated",
      "auth_required",
  );
});
