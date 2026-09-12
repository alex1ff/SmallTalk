const test = require("node:test");
const assert = require("node:assert/strict");
const {
  findNextCallableCandidateInTransaction,
  readCandidateCallabilityInTransaction,
} = require("./call_candidate_tokens");

function snap(data) {
  return {
    exists: data !== null && data !== undefined,
    data: () => data,
  };
}

function fakeDb({usersById = {}, privateTokensById = {}, reads = []} = {}) {
  return {
    collection: (collectionName) => ({
      doc: (documentId) => ({
        collectionName,
        documentId,
        path: `${collectionName}/${documentId}`,
      }),
    }),
    readDoc: (ref) => {
      reads.push(ref.path);
      if (ref.collectionName === "users") {
        return snap(usersById[ref.documentId] ?? null);
      }
      if (ref.collectionName === "userPrivateTokens") {
        return snap(privateTokensById[ref.documentId] ?? null);
      }
      throw new Error(`Unexpected collection: ${ref.collectionName}`);
    },
  };
}

function fakeTransaction(db) {
  return {
    get: async (ref) => db.readDoc(ref),
  };
}

test("candidate callability requires tokens only for teachers", async () => {
  const reads = [];
  const db = fakeDb({
    reads,
    usersById: {
      "student-a": {role: "student", learningLanguage: {code: "en"}},
      "teacher-a": {
        role: "native_speaker",
        language_instruction_NS: {code: "en"},
      },
      "teacher-b": {
        role: "native_speaker",
        language_instruction_NS: {code: "en"},
      },
    },
    privateTokensById: {
      "teacher-b": {voipPushToken: " push-token "},
    },
  });
  const transaction = fakeTransaction(db);

  assert.deepEqual(
    await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId: "student-a",
      language: "en",
    }),
    {callable: true, reason: "token_not_required", role: "student"},
  );
  assert.equal(reads.includes("userPrivateTokens/student-a"), false);

  assert.equal(
    (await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId: "teacher-a",
      language: "en",
    })).callable,
    false,
  );
  assert.equal(
    (await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId: "teacher-b",
      language: "en",
    })).callable,
    true,
  );
});

test("candidate callability checks conversation language before tokens", async () => {
  const reads = [];
  const db = fakeDb({
    reads,
    usersById: {
      "student-fr": {role: "student", learningLanguage: {code: "fr"}},
      "teacher-es": {
        role: "native_speaker",
        language_instruction_NS: {code: "es"},
        native_language_NS: {code: "en"},
      },
    },
    privateTokensById: {
      "teacher-es": {voipToken: "teacher-fcm"},
    },
  });
  const transaction = fakeTransaction(db);

  assert.deepEqual(
    await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId: "student-fr",
      language: "en",
    }),
    {callable: false, reason: "language_mismatch", role: "student"},
  );
  assert.deepEqual(
    await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId: "teacher-es",
      language: "en",
    }),
    {
      callable: false,
      reason: "language_mismatch",
      role: "native_speaker",
    },
  );
  assert.equal(reads.includes("userPrivateTokens/teacher-es"), false);
  assert.equal(
    (await readCandidateCallabilityInTransaction({
      db,
      transaction,
      candidateId: "student-fr",
    })).reason,
    "missing_language",
  );
});

test(
  "next candidate skips tokenless teachers and keeps students callable",
  async () => {
    const reads = [];
    const db = fakeDb({
      reads,
      usersById: {
        "teacher-declined": {
          role: "native_speaker",
          language_instruction_NS: {code: "en"},
          voipToken: "legacy-fcm",
        },
        "teacher-tokenless": {
          role: "native_speaker",
          language_instruction_NS: {code: "en"},
        },
        "student-a": {role: "student", learningLanguage: {code: "en"}},
      },
    });

    const result = await findNextCallableCandidateInTransaction({
      db,
      transaction: fakeTransaction(db),
      candidateIds: ["teacher-declined", "teacher-tokenless", "student-a"],
      triedCandidateIds: ["teacher-declined"],
      language: "en",
    });

    assert.equal(result.candidateId, "student-a");
    assert.deepEqual(
      result.triedCandidateIds,
      ["teacher-declined", "teacher-tokenless"],
    );
    assert.deepEqual(result.skippedCandidateIds, ["teacher-tokenless"]);
    assert.equal(reads.includes("userPrivateTokens/student-a"), false);
  },
);

test("next candidate does not revive cleared legacy teacher token", async () => {
  const db = fakeDb({
    usersById: {
      "teacher-cleared": {
        role: "native_speaker",
        language_instruction_NS: {code: "en"},
        voipToken: "legacy-fcm",
      },
      "teacher-private": {
        role: "native_speaker",
        language_instruction_NS: {code: "en"},
      },
    },
    privateTokensById: {
      "teacher-cleared": {voipTokensClearedAt: true},
      "teacher-private": {voipToken: "private-fcm"},
    },
  });

  const result = await findNextCallableCandidateInTransaction({
    db,
    transaction: fakeTransaction(db),
    candidateIds: ["teacher-cleared", "teacher-private"],
    triedCandidateIds: [],
    language: "en",
  });

  assert.equal(result.candidateId, "teacher-private");
  assert.deepEqual(result.triedCandidateIds, ["teacher-cleared"]);
  assert.deepEqual(result.skippedCandidateIds, ["teacher-cleared"]);
});
