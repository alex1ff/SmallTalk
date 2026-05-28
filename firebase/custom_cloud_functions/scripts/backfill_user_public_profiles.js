const admin = require("firebase-admin");
const {
  __private__: {
    PUBLIC_USER_PROFILE_COLLECTION,
    buildPublicUserProfile,
  },
} = require("../public_user_profiles");

if (!admin.apps.length) {
  admin.initializeApp();
}

async function backfillUserPublicProfiles({db = admin.firestore()} = {}) {
  const usersSnap = await db.collection("users").get();
  const writer = db.bulkWriter();
  let queued = 0;

  usersSnap.forEach((userDoc) => {
    writer.set(
      db.collection(PUBLIC_USER_PROFILE_COLLECTION).doc(userDoc.id),
      buildPublicUserProfile(userDoc.id, userDoc.data() || {}),
    );
    queued += 1;
  });

  await writer.close();
  return {queued};
}

async function main() {
  const result = await backfillUserPublicProfiles();
  console.log(`Backfilled ${result.queued} public user profiles.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error("backfill_user_public_profiles failed:", error);
    process.exitCode = 1;
  });
}

module.exports = {
  backfillUserPublicProfiles,
};
