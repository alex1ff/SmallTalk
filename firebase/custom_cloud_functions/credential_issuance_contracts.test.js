const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

function readFunctionSource(fileName) {
  return fs.readFileSync(path.join(__dirname, fileName), "utf8");
}

test("getSessionTokens uses strict accepted-session credential eligibility", () => {
  const source = readFunctionSource("get_session_tokens.js");

  assert.match(source, /isAcceptedSessionCredentialParticipant/);
  assert.match(source, /isCredentialSessionJoinable/);
  assert.match(source, /getCredentialTtlSeconds/);
  assert.match(source, /runTransaction\(async \(transaction\) => \{/);
  assert.match(source, /await deleteDailyRoom\(replacementRoomName\)/);
  assert.match(source, /freshHasCurrentReplacement/);
  assert.match(source, /usedExistingReplacement/);
  assert.match(source, /sessionDoc = await sessionDoc\.ref\.get\(\)/);
  assert.doesNotMatch(source, /isSessionParticipant\(sessionData,\s*userId\)/);
});

test("getDeepgramToken never returns the raw API key as a client credential", () => {
  const source = readFunctionSource("get_deepgram_token.js");

  assert.match(source, /isAcceptedSessionCredentialParticipant/);
  assert.match(source, /isCredentialSessionJoinable/);
  assert.match(source, /getCredentialTtlSeconds/);
  assert.match(source, /refusing to expose API key/);
  assert.match(source, /deepgram_token_grant_forbidden/);
  assert.doesNotMatch(source, /credentialType:\s*"api_key_fallback"/);
  assert.doesNotMatch(source, /accessToken:\s*apiKey/);
});

test("acceptCall does not persist student Daily tokens in shared session docs", () => {
  const source = readFunctionSource("accept_call.js");

  assert.match(source, /isCredentialSessionJoinable/);
  assert.match(source, /getCredentialTtlSeconds/);
  assert.match(source, /let transientDailyRoomName = null/);
  assert.match(source, /await deleteDailyRoom\(transientDailyRoomName\)/);
  assert.doesNotMatch(source, /sessionUpdate\.studentMeetingToken/);
  assert.doesNotMatch(source, /studentMeetingToken\s*=\s*studentToken/);
});
