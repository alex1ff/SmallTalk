const admin = require("firebase-admin");
const {FieldPath} = require("firebase-admin/firestore");

const DEFAULT_PAGE_SIZE = 50;
const DEFAULT_MAX_PAGES = 20;

function normalizeText(value, maxLength) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || Array.from(normalized).length > maxLength) return null;
  return normalized;
}

function buildConversationParticipantInfoBackfillUpdate(
  conversationData = {},
  profilesByUserId = {},
) {
  const participantIds = Array.isArray(conversationData.participantIds) ?
    conversationData.participantIds
      .filter((uid) => typeof uid === "string" && uid.trim())
      .map((uid) => uid.trim()) :
    [];
  const existing = conversationData.participantInfoByUserId &&
      typeof conversationData.participantInfoByUserId === "object" ?
    conversationData.participantInfoByUserId : {};
  const next = {...existing};
  let changed = false;

  for (const uid of participantIds) {
    const current = existing[uid] && typeof existing[uid] === "object" ?
      existing[uid] : {};
    const profile = profilesByUserId[uid] &&
        typeof profilesByUserId[uid] === "object" ?
      profilesByUserId[uid] : null;
    if (!profile) continue;

    const nextInfo = {...current};
    if (!Object.prototype.hasOwnProperty.call(current, "displayName")) {
      nextInfo.displayName = normalizeText(
        profile.display_name ?? profile.displayName,
        70,
      );
      changed = true;
    }
    if (!Object.prototype.hasOwnProperty.call(current, "photoUrl")) {
      nextInfo.photoUrl = normalizeText(
        profile.photo_url ?? profile.photoUrl,
        2048,
      );
      changed = true;
    }
    next[uid] = nextInfo;
  }

  return changed ? {participantInfoByUserId: next} : null;
}

async function backfillConversationParticipantInfo({
  db = admin.firestore(),
  apply = false,
  pageSize = DEFAULT_PAGE_SIZE,
  maxPages = DEFAULT_MAX_PAGES,
  startAfterId = null,
} = {}) {
  if (!Number.isInteger(pageSize) || pageSize <= 0 || pageSize > 250) {
    throw new Error("pageSize must be an integer between 1 and 250");
  }
  if (!Number.isInteger(maxPages) || maxPages <= 0 || maxPages > 100) {
    throw new Error("maxPages must be an integer between 1 and 100");
  }

  let cursorId = normalizeText(startAfterId, 1500);
  let scanned = 0;
  let eligible = 0;
  let written = 0;
  let conflicts = 0;
  let pages = 0;
  let hasMore = false;
  const writer = apply ? db.bulkWriter() : null;

  try {
    while (pages < maxPages) {
      let query = db.collection("conversations")
        .orderBy(FieldPath.documentId())
        .limit(pageSize + 1);
      if (cursorId) query = query.startAfter(cursorId);
      const page = await query.get();
      if (page.empty) break;
      pages += 1;
      const conversations = page.docs.slice(0, pageSize);
      hasMore = page.docs.length > pageSize;

      const userIds = new Set();
      for (const conversation of conversations) {
        for (const uid of conversation.data().participantIds || []) {
          if (typeof uid === "string" && uid.trim()) userIds.add(uid.trim());
        }
      }
      const profileRefs = [...userIds].map((uid) =>
        db.collection("userPublicProfiles").doc(uid),
      );
      const profileSnaps = profileRefs.length ?
        await db.getAll(...profileRefs) : [];
      const profilesByUserId = Object.fromEntries(
        profileSnaps
          .filter((snapshot) => snapshot.exists)
          .map((snapshot) => [snapshot.id, snapshot.data() || {}]),
      );
      const pageWrites = [];

      for (const conversation of conversations) {
        scanned += 1;
        const update = buildConversationParticipantInfoBackfillUpdate(
          conversation.data(),
          profilesByUserId,
        );
        if (!update) continue;
        eligible += 1;
        if (writer) {
          pageWrites.push(
            writer.update(
              conversation.ref,
              update,
              {lastUpdateTime: conversation.updateTime},
            ).then(() => {
              written += 1;
            }).catch((error) => {
              if (error?.code === 9 || error?.code === "failed-precondition") {
                conflicts += 1;
                return;
              }
              throw error;
            }),
          );
        }
      }
      if (writer && pageWrites.length > 0) {
        await writer.flush();
      }
      await Promise.all(pageWrites);

      cursorId = conversations.at(-1).id;
      if (!hasMore) break;
    }
  } finally {
    if (writer) await writer.close();
  }
  return {
    apply,
    scanned,
    eligible,
    written,
    conflicts,
    pages,
    nextCursor: hasMore ? cursorId : null,
  };
}

async function main() {
  if (!admin.apps.length) admin.initializeApp();
  const apply = process.argv.includes("--apply");
  const pageSizeArgument = process.argv.find((value) =>
    value.startsWith("--page-size="),
  );
  const pageSize = pageSizeArgument ?
    Number(pageSizeArgument.split("=")[1]) :
    DEFAULT_PAGE_SIZE;
  const maxPagesArgument = process.argv.find((value) =>
    value.startsWith("--max-pages="),
  );
  const startAfterArgument = process.argv.find((value) =>
    value.startsWith("--start-after="),
  );
  const result = await backfillConversationParticipantInfo({
    apply,
    pageSize,
    maxPages: maxPagesArgument ?
      Number(maxPagesArgument.split("=")[1]) :
      DEFAULT_MAX_PAGES,
    startAfterId: startAfterArgument?.split("=").slice(1).join("=") || null,
  });
  console.log(JSON.stringify(result));
  if (!apply && result.eligible > 0) {
    console.log("Dry-run only. Re-run with --apply to write missing snapshots.");
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error("backfill_conversation_participant_info failed:", error);
    process.exitCode = 1;
  });
}

module.exports = {
  DEFAULT_PAGE_SIZE,
  DEFAULT_MAX_PAGES,
  backfillConversationParticipantInfo,
  buildConversationParticipantInfoBackfillUpdate,
};
