const test = require("node:test");
const assert = require("node:assert/strict");
const {
  __private__: {
    buildWithdrawalDecision,
    normalizeCardId,
    readPositiveBalance,
  },
} = require("./request_withdrawal");

test("normalizeCardId accepts document ids and rejects paths", () => {
  assert.equal(normalizeCardId(" card-a "), "card-a");
  assert.equal(normalizeCardId("users/user-a/cards/card-a"), "");
  assert.equal(normalizeCardId(""), "");
  assert.equal(normalizeCardId(null), "");
});

test("readPositiveBalance returns only positive finite balances", () => {
  assert.equal(readPositiveBalance({balance_NS: 12.5}), 12.5);
  assert.equal(readPositiveBalance({balance_NS: 0}), 0);
  assert.equal(readPositiveBalance({balance_NS: -1}), 0);
  assert.equal(readPositiveBalance({balance_NS: "bad"}), 0);
});

test("withdrawal requires approved teacher, owned card, and balance", () => {
  const missingUser = buildWithdrawalDecision({
    userExists: false,
    userData: {},
    cardExists: true,
    cardId: "card-a",
  });
  const pendingTeacher = buildWithdrawalDecision({
    userExists: true,
    userData: {teacherAccreditationStatus: "pending", balance_NS: 10},
    cardExists: true,
    cardId: "card-a",
  });
  const missingCard = buildWithdrawalDecision({
    userExists: true,
    userData: {teacherAccreditationStatus: "approved", balance_NS: 10},
    cardExists: false,
    cardId: "card-a",
  });
  const noBalance = buildWithdrawalDecision({
    userExists: true,
    userData: {teacherAccreditationStatus: "approved", balance_NS: 0},
    cardExists: true,
    cardId: "card-a",
  });

  assert.equal(missingUser.ok, false);
  assert.equal(missingUser.code, "failed-precondition");
  assert.equal(pendingTeacher.ok, false);
  assert.equal(pendingTeacher.code, "permission-denied");
  assert.equal(missingCard.ok, false);
  assert.equal(missingCard.code, "failed-precondition");
  assert.equal(noBalance.ok, false);
  assert.equal(noBalance.code, "failed-precondition");
});

test("withdrawal decision returns exact server balance", () => {
  const decision = buildWithdrawalDecision({
    userExists: true,
    userData: {teacherAccreditationStatus: "approved", balance_NS: 42},
    cardExists: true,
    cardId: "card-a",
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.amount, 42);
  assert.deepEqual(decision.response, {
    status: "created",
    amount: 42,
  });
});
