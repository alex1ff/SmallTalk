const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

function readDirectCandidateFilterBranch(source) {
  const branchStart = source.indexOf(
    "if (isDirectTutorCall) {",
    source.indexOf("let repeatPreventionContext = null;"),
  );
  const branchEnd = source.indexOf(
    "} else {\n        const candidateQueryResults",
    branchStart,
  );

  assert.ok(branchStart > 0);
  assert.ok(branchEnd > branchStart);
  return source.slice(branchStart, branchEnd);
}

test("direct call sessions keep explicit direct match context", () => {
  const source = readFunctionSource("create_video_session.js");

  assert.match(source, /matcher:\s*isDirectTutorCall\s*\?\s*"directCall"\s*:\s*"createVideoSession"/);
  assert.match(source, /matchMode:\s*isDirectTutorCall\s*\?\s*"direct"\s*:\s*"filtered"/);
  assert.match(source, /directTutorId:\s*isDirectTutorCall\s*\?\s*directTutorId\s*:\s*null/);
  assert.match(source, /directCandidateId:\s*isDirectTutorCall\s*\?\s*directTutorId\s*:\s*null/);
  assert.match(source, /filters:\s*isDirectTutorCall\s*\?\s*null\s*:\s*\{/);
  assert.match(source, /locationApplied:\s*\n\s*!isDirectTutorCall && !!normalizedPreferredCountry/);
  assert.match(source, /levelApplied:\s*\n\s*!isDirectTutorCall && !!normalizedPreferredPartnerLevel/);
});

test("direct call candidate filtering is teacher-only and skips queue filters", () => {
  const source = readFunctionSource("create_video_session.js");
  const directBranchSource = readDirectCandidateFilterBranch(source);

  assert.match(directBranchSource, /tutorRole !== "native_speaker"/);
  assert.doesNotMatch(
    directBranchSource,
    /candidateLevel !== normalizedPreferredPartnerLevel/,
  );
  assert.doesNotMatch(
    directBranchSource,
    /candidateCountry !== normalizedPreferredCountry/,
  );
  assert.doesNotMatch(directBranchSource, /normalizedPreferredPartnerLevel &&/);
  assert.doesNotMatch(directBranchSource, /normalizedPreferredCountry &&/);
});

test("direct call creation uses direct lock instead of search request lock", () => {
  const source = readFunctionSource("create_video_session.js");
  const transactionIndex = source.indexOf(
    "const creation = await db.runTransaction",
  );
  const directBranchIndex = source.indexOf(
    "if (isDirectTutorCall) {",
    transactionIndex,
  );
  const directBranchEndIndex = source.indexOf(
    "let selectedResponderId = \"\";",
    directBranchIndex,
  );
  const directBranchSource = source.slice(directBranchIndex, directBranchEndIndex);

  assert.ok(transactionIndex > 0);
  assert.ok(directBranchIndex > transactionIndex);
  assert.ok(directBranchEndIndex > directBranchIndex);
  assert.match(directBranchSource, /reserveDirectPairInTransaction\(\{/);
  assert.match(directBranchSource, /createIncomingCallNotificationInTransaction\(\{/);
  assert.doesNotMatch(directBranchSource, /reserveMatchPairInTransaction\(\{/);
  assert.doesNotMatch(directBranchSource, /requesterSearchRequestId/);
  assert.doesNotMatch(directBranchSource, /responderSearchRequestId/);
  assert.doesNotMatch(directBranchSource, /searchRequests/);
  assert.doesNotMatch(directBranchSource, /SEARCH_REQUEST_COLLECTION/);
});

test("direct call response does not expose common search status", () => {
  const source = readFunctionSource("create_video_session.js");

  assert.match(source, /status:\s*isDirectTutorCall\s*\?\s*"calling"\s*:\s*"searching"/);
});

test("common search endpoint rejects direct call targets", () => {
  const source = readFunctionSource("start_search.js");

  assert.match(source, /function hasDirectCallTarget\(payload = \{\}\)/);
  assert.match(source, /payload\.directTutorId/);
  assert.match(source, /payload\.directUserId/);
  assert.match(source, /payload\.targetUserId/);
  assert.match(source, /payload\.targetTutorId/);
  assert.match(source, /payload\.teacherId/);
  assert.match(source, /payload\.tutorId/);
  assert.match(source, /direct_call_not_supported/);
});
