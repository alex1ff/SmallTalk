const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

async function deleteUserIntegrationData({uid, firestore = admin.firestore()}) {
  const userRef = firestore.collection("users").doc(uid);
  const [lookupSnapshot, wordSnapshot, feedbackSnapshot] = await Promise.all([
    userRef.collection("translationLookups").get(),
    userRef
      .collection("userWords")
      .where("source", "==", "google_cloud_translation")
      .get(),
    firestore
      .collectionGroup("aiFeedback")
      .where("ownerUid", "==", uid)
      .get(),
  ]);

  const writer = firestore.bulkWriter();
  let deletedDocuments = 0;
  const scheduleDelete = (reference) => {
    writer.delete(reference);
    deletedDocuments += 1;
  };

  for (const document of lookupSnapshot.docs) scheduleDelete(document.ref);
  for (const document of feedbackSnapshot.docs) scheduleDelete(document.ref);
  for (const document of wordSnapshot.docs) {
    scheduleDelete(document.ref);
    scheduleDelete(userRef.collection("wordReviews").doc(document.id));
  }
  scheduleDelete(firestore.collection("translationRateLimits").doc(uid));
  scheduleDelete(firestore.collection("aiFeedbackRateLimits").doc(uid));

  await writer.close();
  return {deletedDocuments};
}

const cleanupUserCallIntegrationsOnDelete = functions
  .runWith({timeoutSeconds: 540, memory: "512MB"})
  .auth.user()
  .onDelete(async (user) => {
    const uid = String(user && user.uid || "").trim();
    if (!uid) return null;
    const result = await deleteUserIntegrationData({uid});
    console.log("Deleted user-owned call integration data", result);
    return result;
  });

module.exports = {
  cleanupUserCallIntegrationsOnDelete,
  __private__: {deleteUserIntegrationData},
};
