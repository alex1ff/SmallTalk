const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

const projectId = process.env.GCLOUD_PROJECT || "demo-smalltalk-storage-rules";
const storageHostRaw =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
const [storageHost, storagePortText] = storageHostRaw.split(":");
const storagePort = Number.parseInt(storagePortText || "9199", 10);
const storageRules = fs.readFileSync(
    path.join(__dirname, "..", "storage.rules"),
    "utf8",
);

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    storage: {
      host: storageHost,
      port: storagePort,
      rules: storageRules,
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test("private user files are owner-only", async () => {
  const owner = testEnv.authenticatedContext("user-a").storage();
  const other = testEnv.authenticatedContext("user-b").storage();
  const guest = testEnv.unauthenticatedContext().storage();
  const ownFile = owner.ref("users/user-a/profile/photo.txt");

  await assertSucceeds(ownFile.putString("owner-content"));
  await assertSucceeds(ownFile.getDownloadURL());
  await assertFails(other.ref("users/user-a/profile/photo.txt").putString("x"));
  await assertFails(other.ref("users/user-a/profile/photo.txt").getDownloadURL());
  await assertFails(guest.ref("users/user-a/profile/photo.txt").putString("x"));
});

test("paths outside the user namespace stay server-only", async () => {
  const user = testEnv.authenticatedContext("user-a").storage();
  const guest = testEnv.unauthenticatedContext().storage();

  await assertFails(user.ref("public/unexpected.txt").putString("x"));
  await assertFails(guest.ref("public/unexpected.txt").putString("x"));
});
