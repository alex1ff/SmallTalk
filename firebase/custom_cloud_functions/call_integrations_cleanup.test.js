const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __private__,
} = require("./cleanup_user_call_integrations");

class FakeReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  collection(name) {
    return new FakeQuery(this.firestore, `${this.path}/${name}`);
  }
}

class FakeQuery {
  constructor(firestore, path, filter = null, collectionGroup = false) {
    this.firestore = firestore;
    this.path = path;
    this.filter = filter;
    this.isCollectionGroup = collectionGroup;
  }

  doc(id) {
    return new FakeReference(this.firestore, `${this.path}/${id}`);
  }

  where(field, operator, value) {
    assert.equal(operator, "==");
    return new FakeQuery(
      this.firestore,
      this.path,
      {field, value},
      this.isCollectionGroup,
    );
  }

  async get() {
    const prefix = `${this.path}/`;
    const docs = [...this.firestore.documents.entries()]
      .filter(([documentPath, data]) => {
        const pathMatches = this.isCollectionGroup ?
          documentPath.split("/").at(-2) === this.path :
          documentPath.startsWith(prefix) &&
            !documentPath.slice(prefix.length).includes("/");
        return pathMatches &&
          (!this.filter || data[this.filter.field] === this.filter.value);
      })
      .map(([documentPath]) => ({
        id: documentPath.split("/").at(-1),
        ref: new FakeReference(this.firestore, documentPath),
      }));
    return {docs};
  }
}

class FakeFirestore {
  constructor(seed) {
    this.documents = new Map(Object.entries(seed));
  }

  collection(name) {
    return new FakeQuery(this, name);
  }

  collectionGroup(name) {
    return new FakeQuery(this, name, null, true);
  }

  bulkWriter() {
    const pending = [];
    return {
      delete: (reference) => pending.push(reference.path),
      close: async () => {
        for (const documentPath of pending) {
          this.documents.delete(documentPath);
        }
      },
    };
  }
}

test("auth deletion removes only the deleted user's integration data", async () => {
  const firestore = new FakeFirestore({
    "users/user-a/translationLookups/lookup-a": {ownerUid: "user-a"},
    "users/user-b/translationLookups/lookup-b": {ownerUid: "user-b"},
    "users/user-a/userWords/translated": {
      source: "google_cloud_translation",
    },
    "users/user-a/userWords/manual": {source: "manual"},
    "users/user-a/wordReviews/translated": {stage: 1},
    "users/user-a/wordReviews/manual": {stage: 2},
    "videoSessions/session-a/aiFeedback/user-a": {ownerUid: "user-a"},
    "videoSessions/session-b/aiFeedback/user-b": {ownerUid: "user-b"},
    "translationRateLimits/user-a": {attemptCount: 1},
    "translationRateLimits/user-b": {attemptCount: 1},
    "aiFeedbackRateLimits/user-a": {attemptCount: 1},
    "aiFeedbackRateLimits/user-b": {attemptCount: 1},
  });

  const result = await __private__.deleteUserIntegrationData({
    uid: "user-a",
    firestore,
  });

  assert.equal(result.deletedDocuments, 6);
  for (const deletedPath of [
    "users/user-a/translationLookups/lookup-a",
    "users/user-a/userWords/translated",
    "users/user-a/wordReviews/translated",
    "videoSessions/session-a/aiFeedback/user-a",
    "translationRateLimits/user-a",
    "aiFeedbackRateLimits/user-a",
  ]) {
    assert.equal(firestore.documents.has(deletedPath), false);
  }
  for (const preservedPath of [
    "users/user-a/userWords/manual",
    "users/user-a/wordReviews/manual",
    "videoSessions/session-b/aiFeedback/user-b",
    "translationRateLimits/user-b",
  ]) {
    assert.equal(firestore.documents.has(preservedPath), true);
  }
});
