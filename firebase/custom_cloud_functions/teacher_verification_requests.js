const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const {
  readTeacherAccreditationStatusValue,
} = require("./video_sessions_shared");

function normalizeRequestStatus(data = {}) {
  return (
    readTeacherAccreditationStatusValue(data.status) ||
    readTeacherAccreditationStatusValue(data.teacherAccreditationStatus) ||
    readTeacherAccreditationStatusValue(data.teacherVerificationStatus) ||
    readTeacherAccreditationStatusValue(data.verificationStatus)
  );
}

function resolveRequestUserId(data = {}, fallbackUserId = "") {
  const explicitUserId = typeof data.userId === "string" ? data.userId.trim() : "";
  return explicitUserId || String(fallbackUserId || "").trim();
}

exports.syncTeacherVerificationRequest = functions.firestore
  .document("teacherVerificationRequests/{userId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) {
      return null;
    }

    const requestData = change.after.data() || {};
    const status = normalizeRequestStatus(requestData);
    if (!status) {
      console.warn("teacherVerificationRequests ignored unknown status", {
        requestPath: change.after.ref.path,
        status: requestData.status || null,
      });
      return null;
    }

    const userId = resolveRequestUserId(requestData, context.params.userId);
    if (!userId) {
      console.warn("teacherVerificationRequests ignored missing userId", {
        requestPath: change.after.ref.path,
      });
      return null;
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    await userRef.set(
      {
        teacherAccreditationStatus: status,
        teacherVerificationRequestRef: change.after.ref,
        teacherAccreditationUpdatedAt: FieldValue.serverTimestamp(),
        verif_NS: status === "approved",
      },
      {merge: true},
    );

    return null;
  });
