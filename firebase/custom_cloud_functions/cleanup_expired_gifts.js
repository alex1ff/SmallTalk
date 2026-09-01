// cleanupExpiredGifts
//
// Scheduled task that zeroes out expired gift-minute buckets across the
// users collection. The runtime gating in create_video_session.js and
// the dashboard UI both filter by `giftMinutes.expiresAt > now` so this
// cleanup is not strictly required for correctness — its purpose is
// keeping the data clean for analytics and reducing the doc field count.
//
// Runs once a day at 03:00 UTC. Idempotent: a second pass over an
// already-cleaned doc is a no-op because the query filters on
// `minutes > 0`.

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const BATCH_WRITE_LIMIT = 400;

exports.cleanupExpiredGifts = functions
    .pubsub
    .schedule("every day 03:00")
    .timeZone("UTC")
    .onRun(async () => {
      console.log("🎁 Cleaning up expired gift-minute buckets...");

      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();

      let cleaned = 0;
      let scanned;

      try {
        // Firestore composite query: any user whose gift bucket has
        // positive minutes AND already expired.
        const expiredQuery = await db
            .collection("users")
            .where("giftMinutes.minutes", ">", 0)
            .where("giftMinutes.expiresAt", "<=", now)
            .get();

        scanned = expiredQuery.size;
        if (expiredQuery.empty) {
          console.log("🎁 No expired gift buckets to clean");
          return null;
        }

        let batch = db.batch();
        let batchSize = 0;

        for (const doc of expiredQuery.docs) {
          // Just zero the minutes field — keep expiresAt/source/totalGranted
          // intact for analytics ("how often does this gift expire unused?").
          batch.update(doc.ref, {
            "giftMinutes.minutes": 0,
            "giftMinutes.cleanedUpAt":
              admin.firestore.FieldValue.serverTimestamp(),
          });
          batchSize += 1;
          cleaned += 1;

          if (batchSize >= BATCH_WRITE_LIMIT) {
            await batch.commit();
            batch = db.batch();
            batchSize = 0;
          }
        }

        if (batchSize > 0) {
          await batch.commit();
        }

        console.log("🎁 cleanupExpiredGifts done", {scanned, cleaned});
        return null;
      } catch (err) {
        console.error("❌ cleanupExpiredGifts failed", err);
        // Don't throw — scheduler retry would just hammer the same docs.
        // Surface to logs and rely on next run.
        return null;
      }
    });
