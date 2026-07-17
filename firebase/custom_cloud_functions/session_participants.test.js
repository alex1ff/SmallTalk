const assert = require("assert");
const {
  buildSessionParticipantIds,
  getSessionParticipantIds,
  isSessionParticipant,
} = require("./session_participants");

assert.deepStrictEqual(
  buildSessionParticipantIds(" student ", "tutor", "student", ""),
  ["student", "tutor"],
);

assert.deepStrictEqual(
  getSessionParticipantIds({
    participantIds: ["student", "tutor"],
    studentId: "legacy-student",
    tutorId: "legacy-tutor",
  }),
  ["student", "tutor", "legacy-student", "legacy-tutor"],
);

assert.deepStrictEqual(
  getSessionParticipantIds({
    studentId: "student",
    tutorId: "tutor",
  }),
  ["student", "tutor"],
);

assert.deepStrictEqual(
  getSessionParticipantIds({
    participantIds: ["student"],
    studentId: "student",
    tutorId: "tutor",
  }),
  ["student", "tutor"],
);

assert.strictEqual(
  isSessionParticipant({ participantIds: ["student", "tutor"] }, "tutor"),
  true,
);
assert.strictEqual(
  isSessionParticipant({ studentId: "student", tutorId: "tutor" }, "tutor"),
  true,
);
assert.strictEqual(
  isSessionParticipant({ participantIds: ["student"] }, "tutor"),
  false,
);

console.log("session_participants tests passed");
