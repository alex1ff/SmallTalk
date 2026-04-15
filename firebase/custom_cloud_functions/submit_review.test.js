const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  __private__: {
    isMutualParticipantSession,
    resolveReviewParticipants,
  },
} = require("./submit_review");

test("resolveReviewParticipants uses generalized requester/responder fields", () => {
  const resolution = resolveReviewParticipants(
    {
      participantIds: ["user-a", "user-b"],
      matchContext: {
        requesterId: "user-a",
        acceptedResponderId: "user-b",
      },
    },
    "user-a",
  );

  assert.equal(resolution.isParticipant, true);
  assert.equal(resolution.isStudent, true);
  assert.equal(resolution.isTutor, false);
  assert.equal(resolution.targetUserId, "user-b");
});

test("resolveReviewParticipants falls back to unique counterpart from participantIds", () => {
  const resolution = resolveReviewParticipants(
    {
      participantIds: ["user-a", "user-b"],
    },
    "user-b",
  );

  assert.equal(resolution.isParticipant, true);
  assert.equal(resolution.isStudent, false);
  assert.equal(resolution.isTutor, false);
  assert.equal(resolution.targetUserId, "user-a");
});

test("resolveReviewParticipants ignores stale role fields outside the participant pair", () => {
  const resolution = resolveReviewParticipants(
    {
      participantIds: ["user-a", "user-b"],
      studentId: "user-a",
      matchContext: {
        acceptedResponderId: "user-c",
      },
    },
    "user-a",
  );

  assert.equal(resolution.targetUserId, "user-b");
});

test("resolveReviewParticipants fails closed when caller is not in session", () => {
  const resolution = resolveReviewParticipants(
    {
      participantIds: ["user-a", "user-b"],
      studentId: "user-a",
      tutorId: "user-b",
    },
    "user-c",
  );

  assert.equal(resolution.isParticipant, false);
  assert.equal(resolution.targetUserId, null);
});

test("isMutualParticipantSession accepts generalized two-person pair", () => {
  assert.equal(
    isMutualParticipantSession(
      {
        participantIds: ["user-a"],
        matchContext: {
          requesterId: "user-a",
          acceptedResponderId: "user-b",
        },
      },
      "user-a",
      "user-b",
    ),
    true,
  );
});

test("isMutualParticipantSession rejects incomplete or ambiguous participant sets", () => {
  assert.equal(
    isMutualParticipantSession(
      {
        participantIds: ["user-a"],
      },
      "user-a",
      "user-b",
    ),
    false,
  );
  assert.equal(
    isMutualParticipantSession(
      {
        participantIds: ["user-a", "user-b", "user-c"],
      },
      "user-a",
      "user-b",
    ),
    false,
  );
});

test("submitReview source includes participantIds lookup and shared review resolver", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "submit_review.js"),
    "utf8",
  );

  assert.match(
    source,
    /where\("participantIds",\s*"array-contains",\s*userId\)/,
  );
  assert.match(
    source,
    /const reviewParticipants = resolveReviewParticipants\(sessionData, userId\);/,
  );
  assert.match(
    source,
    /const targetUserId = reviewParticipants\.targetUserId;/,
  );
});
