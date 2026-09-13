const functions = require("firebase-functions/v1");
const { migrateLegacyVoipTokensBatch } = require("./voip_tokens");

function isAdmin(context) {
  return Boolean(context.auth?.token?.admin === true);
}

exports.migrateLegacyVoipTokens = functions.https.onCall(
  async (data, context) => {
    if (!isAdmin(context)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access is required",
      );
    }

    return migrateLegacyVoipTokensBatch(data?.limit);
  },
);

exports.scheduledLegacyVoipTokenMigration = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(() => migrateLegacyVoipTokensBatch());
