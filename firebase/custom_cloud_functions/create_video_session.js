const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const {
  getReadOnlyUserVoipTokenState,
  getUserVoipTokens,
} = require("./voip_tokens");
const {
  createDailyRoom,
  deleteDailyRoom,
  DAILY_ROOM_CONFIG_VERSION,
} = require("./daily_room");
const { evaluateTutorAvailabilityWindow } = require("./availability");
const {
  buildInitialSessionPolicyState,
  buildMatchProfile,
  buildSessionUserInfo,
  extractBlockedIds,
  isSupportedSessionRole,
  normalizeRole,
  readCountryCode,
  readLanguageCode,
  readLevelValue,
  readMatchCountry,
  readMatchLevelValue,
  readMatchPriorityScore,
  resolveActiveConversationLanguage,
  supportsConversationLanguage,
  VIDEO_SESSION_STATUS,
} = require("./video_sessions_shared");
const {
  buildCandidateRoleCounts,
  buildRepeatPreventionLogContext,
  countExcludedRepeatCandidates,
  filterRepeatCandidates,
  getRepeatBypassUserIds,
  loadSameDayRepeatCandidateIds,
  loadSameDayRepeatCandidateIdsForTransaction,
} = require("./match_repeat_prevention");
const {
  buildTeacherIncomingCallApnsPayload,
  buildTeacherIncomingCallFcmMessage,
  createIncomingCallNotificationInTransaction,
} = require("./call_notifications");
const {
  findNextCallableCandidateInTransaction,
} = require("./call_candidate_tokens");
const {
  buildStudentCallAccessDecision,
  hasActiveCallState,
} = require("./call_access");
const {
  trialAccessRef,
} = require("./trial_access");
const {
  isActiveStudentSearchRequest,
} = require("./match_candidate_pool");
const {
  hasActiveAcceptLockForResponder,
} = require("./accept_lock_policy");
const {
  reserveDirectPairInTransaction,
  reserveMatchPairInTransaction,
} = require("./match_pair_lock");

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const STUDENT_REVIEW_FLAG_FIELD = "studentHasReviewed";
const TUTOR_REVIEW_FLAG_FIELD = "tutorHasReviewed";
const PENDING_RESPONSE_SESSION_STATUSES = new Set([
  VIDEO_SESSION_STATUS.SEARCHING,
  VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
]);
const matchDebugSampleRateRaw = Number.parseFloat(
  process.env.MATCH_DEBUG_SAMPLE_RATE || "0.1",
);
const MATCH_DEBUG_SAMPLE_RATE = Number.isFinite(matchDebugSampleRateRaw)
  ? Math.min(Math.max(matchDebugSampleRateRaw, 0), 1)
  : 0.1;
const MAX_TUTOR_DEBUG_SAMPLES = 8;
const CANDIDATE_QUERY_BUILDERS = [
  (db, languageCode) =>
    db.collection("users").where("learningLanguage.code", "==", languageCode),
  (db, languageCode) =>
    db
      .collection("users")
      .where("language_instruction_NS.code", "==", languageCode),
];
function buildCreateSessionPolicyFields(nowMillis = Date.now()) {
  const sessionPolicyState = buildInitialSessionPolicyState(nowMillis);
  return {
    expiresAt: admin.firestore.Timestamp.fromDate(
      sessionPolicyState.expiresAt,
    ),
    sessionPolicy: sessionPolicyState.sessionPolicy,
  };
}

function isAvailableAfterInFuture(userData = {}, now = new Date()) {
  const availableAfter = userData.availableAfter;
  if (!availableAfter || typeof availableAfter.toDate !== "function") {
    return false;
  }

  return availableAfter.toDate() > now;
}

function orderCandidatesByMatchQuality(
  candidateIds = [],
  detailsById = {},
) {
  return [...candidateIds].sort((a, b) =>
    compareCandidateDetails(a, b, detailsById));
}

async function hasCallableTeacherToken(
  userId,
  userData = {},
  db = admin.firestore(),
) {
  if (normalizeRole(userData.role) !== "native_speaker") {
    return true;
  }
  const tokenState = await getReadOnlyUserVoipTokenState(userId, userData, db);
  return tokenState.hasUsableToken === true &&
    (
      tokenState.hasFcmToken === true ||
      tokenState.hasVoipPushToken === true
    );
}

function compareCandidateDetails(leftId, rightId, detailsById) {
  const left = detailsById[leftId] || {};
  const right = detailsById[rightId] || {};

  if (left.locationMatch !== right.locationMatch) {
    return left.locationMatch ? -1 : 1;
  }

  if (left.ratingAverage !== right.ratingAverage) {
    return right.ratingAverage - left.ratingAverage;
  }

  if (left.ratingCount !== right.ratingCount) {
    return right.ratingCount - left.ratingCount;
  }

  if (left.legacyPriorityScore !== right.legacyPriorityScore) {
    return left.legacyPriorityScore - right.legacyPriorityScore;
  }

  return String(leftId).localeCompare(String(rightId));
}

/*
ОБНОВЛЁННАЯ ФУНКЦИЯ: createVideoSession
Теперь учитывает предпочтения студента по нативному языку и локации преподавателя
*/

exports.createVideoSession = functions
  .runWith({ secrets: [...apnsSecrets, ...dailySecrets] })
  .https.onCall(async (data, context) => {
    console.log("📹 createVideoSession started");

    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
        );
      }

      const requesterId = context.auth.uid;

      // Получаем параметры из вызова функции
      const {
        language,
        preferredCountry,
        preferredPartnerLevel,
        requestId: rawRequestId,
        searchRequestId: rawSearchRequestId,
        directTutorId: rawDirectTutorId,
        directUserId: rawDirectUserId,
      } = data;
      const requesterSearchRequestId = String(
        rawSearchRequestId || rawRequestId || "",
      ).trim();
      const directTutorId = String(
        rawDirectUserId || rawDirectTutorId || "",
      ).trim();
      const isDirectTutorCall = directTutorId.length > 0;
      if (!isDirectTutorCall && !requesterSearchRequestId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "requestId is required for search matching",
          {reason: "request_id_required"},
        );
      }
      const shouldSampleTutorDebug = Math.random() < MATCH_DEBUG_SAMPLE_RATE;
      const tutorDebugSamples = [];
      const tutorFilterStats = {
        totalCandidates: 0,
        selfExcluded: 0,
        unsupportedRole: 0,
        blockedByStudent: 0,
        blockedByTutor: 0,
        availableAfterInFuture: 0,
        unavailableOrInCall: 0,
        sameDayRepeat: 0,
        languageMismatch: 0,
        unapprovedTeacher: 0,
        missingCallToken: 0,
        missingLevel: 0,
        levelMismatch: 0,
        missingCountry: 0,
        countryMismatch: 0,
        matched: 0,
      };
      const addTutorSample = (payload) => {
        if (!shouldSampleTutorDebug) return;
        if (tutorDebugSamples.length >= MAX_TUTOR_DEBUG_SAMPLES) return;
        tutorDebugSamples.push(payload);
      };

      console.log("📹 createVideoSession params", {
        requesterId,
        requestedLanguage: readLanguageCode(language) || null,
        matchMode: isDirectTutorCall ? "direct" : "filtered",
        directTutorId: isDirectTutorCall ? directTutorId : null,
        preferredCountry: readCountryCode(preferredCountry) || "any",
        preferredPartnerLevel: readLevelValue(preferredPartnerLevel) || "any",
      });

      const requesterDoc = await admin
        .firestore()
        .collection("users")
        .doc(requesterId)
        .get();

      if (!requesterDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Requester not found");
      }

      const requesterData = requesterDoc.data() || {};
      const requesterRole = normalizeRole(requesterData.role);
      if (!isSupportedSessionRole(requesterRole)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "This user role cannot create video sessions",
        );
      }

      // Fast preflight. The same policy is repeated inside the session
      // creation transaction so concurrent requests cannot bypass trial use.
      if (requesterRole === "student") {
        const trialDoc = await trialAccessRef(
          admin.firestore(),
          requesterId,
        ).get();
        const accessDecision = buildStudentCallAccessDecision({
          userRole: requesterRole,
          userData: requesterData,
          trialData: trialDoc.exists ? trialDoc.data() || {} : null,
          nowMillis: Date.now(),
        });
        if (!accessDecision.allowed) {
          console.warn("🛑 createVideoSession blocked by access policy", {
            requesterId,
            reason: accessDecision.reason,
          });
          throw new functions.https.HttpsError(
            accessDecision.code || "failed-precondition",
            accessDecision.message || "Active subscription is required",
            {reason: accessDecision.reason},
          );
        }
      }

      const resolvedLanguage = resolveActiveConversationLanguage(
        requesterData,
        language,
      );
      const normalizedLanguage = resolvedLanguage.code;
      if (!normalizedLanguage) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Language is required",
        );
      }

      const normalizedPreferredCountry = readCountryCode(preferredCountry);
      const normalizedPreferredPartnerLevel = readLevelValue(
        preferredPartnerLevel,
      );
      const requesterBlockedIds = extractBlockedIds(requesterData.blockedUsers);
      const requesterInfo = buildSessionUserInfo(
        requesterData,
        requesterRole === "student" ? "Student" : "Caller",
      );
      const requesterProfile = buildMatchProfile(
        requesterId,
        requesterData,
        normalizedLanguage,
      );
      const db = admin.firestore();
      const repeatBypassUserIds = getRepeatBypassUserIds();

      const availableTutors = [];
      const tutorDetails = {};
      const candidateEmailsById = {};
      let totalQueriedCandidates = 0;
      let directTutorInfo = null;
      let repeatPreventionContext = null;

      if (isDirectTutorCall) {
        const directTutorDoc = await admin
          .firestore()
          .collection("users")
          .doc(directTutorId)
          .get();

        tutorFilterStats.totalCandidates = 1;
        totalQueriedCandidates = 1;

        if (!directTutorDoc.exists) {
          console.log("📹 createVideoSession direct tutor not found", {
            requesterId,
            directTutorId,
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        const tutorData = directTutorDoc.data() || {};
        candidateEmailsById[directTutorId] = tutorData.email;
        const tutorRole = normalizeRole(tutorData.role);
        if (tutorRole !== "native_speaker" || directTutorId === requesterId) {
          if (directTutorId === requesterId) {
            tutorFilterStats.selfExcluded += 1;
          } else {
            tutorFilterStats.unsupportedRole += 1;
          }
          console.log("📹 createVideoSession direct tutor has invalid role", {
            requesterId,
            directTutorId,
            role: tutorData.role || null,
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        if (requesterBlockedIds.includes(directTutorId)) {
          tutorFilterStats.blockedByStudent += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "blocked_by_student",
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        const tutorBlockedIds = extractBlockedIds(tutorData.blockedUsers || []);
        if (tutorBlockedIds.includes(requesterId)) {
          tutorFilterStats.blockedByTutor += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "blocked_by_tutor",
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        if (!supportsConversationLanguage(tutorData, normalizedLanguage)) {
          tutorFilterStats.languageMismatch += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "language_mismatch",
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        if (isAvailableAfterInFuture(tutorData)) {
          tutorFilterStats.availableAfterInFuture += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "available_after_in_future",
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        const availabilityCheck = evaluateTutorAvailabilityWindow(tutorData);
        const isAvailable = availabilityCheck.isAvailable;

        if (!isAvailable || hasActiveCallState(tutorData)) {
          tutorFilterStats.unavailableOrInCall += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "unavailable_or_in_call",
            isAvailable: !!isAvailable,
            isInCall: !!tutorData.isInCall,
            currentSessionId: tutorData.currentSessionId || null,
            availabilityReason: availabilityCheck.reason,
            tutorLocalTime: availabilityCheck.localTime || null,
            timezoneOffsetMinutes: availabilityCheck.timezoneOffsetMinutes ?? null,
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        repeatPreventionContext = await loadSameDayRepeatCandidateIds(
          db,
          requesterId,
          [directTutorId],
          {
            bypassUserIds: repeatBypassUserIds,
            requesterEmail: requesterData.email || context.auth.token.email,
            userEmailsById: candidateEmailsById,
          },
        );
        if (repeatPreventionContext.excludedCandidateIds.has(directTutorId)) {
          tutorFilterStats.sameDayRepeat += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "same_day_repeat",
            dayKey: repeatPreventionContext.dayKey,
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        const tutorProfile = buildMatchProfile(
          directTutorId,
          tutorData,
          normalizedLanguage,
        );
        if (tutorRole === "native_speaker" && !tutorProfile.approvedTeacher) {
          tutorFilterStats.unapprovedTeacher += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "unapproved_teacher",
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }
        const candidateLevel = readMatchLevelValue(tutorData);
        const candidateCountry = readMatchCountry(tutorData);
        if (!(await hasCallableTeacherToken(directTutorId, tutorData, db))) {
          tutorFilterStats.missingCallToken += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "missing_call_token",
          });
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }

        availableTutors.push(directTutorId);
        tutorFilterStats.matched = 1;
        tutorDetails[directTutorId] = {
          role: tutorRole,
          country: candidateCountry || "unknown",
          ratingAverage: tutorProfile.ratingAverage,
          ratingCount: tutorProfile.ratingCount,
          level: candidateLevel || null,
          legacyPriorityScore: readMatchPriorityScore(tutorData),
          locationMatch: true,
          approvedTeacher: tutorProfile.approvedTeacher,
          name: tutorData.display_name || "Partner",
        };
        directTutorInfo = buildSessionUserInfo(tutorData, "Partner");
        addTutorSample({
          tutorId: directTutorId,
          outcome: "match",
          direct: true,
        });
      } else {
        const candidateQueryResults = await Promise.all(
          CANDIDATE_QUERY_BUILDERS.map((buildQuery) =>
            buildQuery(db, normalizedLanguage).get().catch((queryError) => {
              console.error("❌ Candidate query failed:", queryError.message);
              throw new functions.https.HttpsError(
                "failed-precondition",
                "Candidate query failed. Ensure required Firestore indexes are deployed.",
              );
            }),
          ),
        );

        const candidateDocsById = new Map();
        for (const snapshot of candidateQueryResults) {
          snapshot.docs.forEach((doc) => {
            if (!candidateDocsById.has(doc.id)) {
              candidateDocsById.set(doc.id, doc);
            }
          });
        }

        totalQueriedCandidates = candidateDocsById.size;
        if (candidateDocsById.size === 0) {
          console.log("📹 createVideoSession found no candidates", {
            normalizedLanguage,
          });
          return {
            status: "no_tutors_available",
            message: "No partners available for this language right now",
          };
        }

        for (const [candidateId, doc] of candidateDocsById.entries()) {
          candidateEmailsById[candidateId] = (doc.data() || {}).email;
        }

        repeatPreventionContext = await loadSameDayRepeatCandidateIds(
          db,
          requesterId,
          Array.from(candidateDocsById.keys()),
          {
            bypassUserIds: repeatBypassUserIds,
            requesterEmail: requesterData.email || context.auth.token.email,
            userEmailsById: candidateEmailsById,
          },
        );

        for (const [tutorId, doc] of candidateDocsById.entries()) {
          tutorFilterStats.totalCandidates += 1;
          const tutorData = doc.data() || {};
          const tutorRole = normalizeRole(tutorData.role);

          if (tutorId === requesterId) {
            tutorFilterStats.selfExcluded += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "self_excluded",
            });
            continue;
          }

          if (!isSupportedSessionRole(tutorRole)) {
            tutorFilterStats.unsupportedRole += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "unsupported_role",
              role: tutorData.role || null,
            });
            continue;
          }

          if (requesterBlockedIds.includes(tutorId)) {
            tutorFilterStats.blockedByStudent += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "blocked_by_student",
            });
            continue;
          }

          const tutorBlockedIds = extractBlockedIds(tutorData.blockedUsers || []);
          if (tutorBlockedIds.includes(requesterId)) {
            tutorFilterStats.blockedByTutor += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "blocked_by_tutor",
            });
            continue;
          }

          if (!supportsConversationLanguage(tutorData, normalizedLanguage)) {
            tutorFilterStats.languageMismatch += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "language_mismatch",
            });
            continue;
          }

          let candidateSearchRequestId = "";
          if (tutorRole === "student") {
            const candidateSearchRequestSnap = await db
              .collection("searchRequests")
              .doc(tutorId)
              .get();
            const candidateSearchRequestData =
              candidateSearchRequestSnap.exists ?
                candidateSearchRequestSnap.data() || {} :
                {};
            if (
              !candidateSearchRequestSnap.exists ||
              !isActiveStudentSearchRequest(
                candidateSearchRequestData,
                Date.now(),
              ) ||
              readLanguageCode(candidateSearchRequestData.language) !==
                normalizedLanguage
            ) {
              tutorFilterStats.unavailableOrInCall += 1;
              addTutorSample({
                tutorId,
                outcome: "skip",
                reason: "student_not_in_active_queue_for_language",
              });
              continue;
            }
            candidateSearchRequestId = String(
              candidateSearchRequestData.requestId || "",
            ).trim();
            if (!candidateSearchRequestId) {
              tutorFilterStats.unavailableOrInCall += 1;
              addTutorSample({
                tutorId,
                outcome: "skip",
                reason: "missing_student_search_request_id",
              });
              continue;
            }
          }

          if (isAvailableAfterInFuture(tutorData)) {
            tutorFilterStats.availableAfterInFuture += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "available_after_in_future",
            });
            continue;
          }

          const availabilityCheck = evaluateTutorAvailabilityWindow(tutorData);
          if (!availabilityCheck.isAvailable || hasActiveCallState(tutorData)) {
            tutorFilterStats.unavailableOrInCall += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "unavailable_or_in_call",
              isAvailable: !!availabilityCheck.isAvailable,
              isInCall: !!tutorData.isInCall,
              currentSessionId: tutorData.currentSessionId || null,
              availabilityReason: availabilityCheck.reason,
              tutorLocalTime: availabilityCheck.localTime || null,
              timezoneOffsetMinutes:
                availabilityCheck.timezoneOffsetMinutes ?? null,
            });
            continue;
          }

          if (repeatPreventionContext.excludedCandidateIds.has(tutorId)) {
            tutorFilterStats.sameDayRepeat += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "same_day_repeat",
              dayKey: repeatPreventionContext.dayKey,
            });
            continue;
          }

          const tutorProfile = buildMatchProfile(
            tutorId,
            tutorData,
            normalizedLanguage,
          );
          if (tutorRole === "native_speaker" && !tutorProfile.approvedTeacher) {
            tutorFilterStats.unapprovedTeacher += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "unapproved_teacher",
            });
            continue;
          }
          const candidateLevel = readMatchLevelValue(tutorData);
          if (normalizedPreferredPartnerLevel && !candidateLevel) {
            tutorFilterStats.missingLevel += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "missing_level",
            });
            continue;
          }

          if (
            normalizedPreferredPartnerLevel &&
            candidateLevel !== normalizedPreferredPartnerLevel
          ) {
            tutorFilterStats.levelMismatch += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "level_mismatch",
              tutorLevel: candidateLevel || null,
            });
            continue;
          }
          const candidateCountry = readMatchCountry(tutorData);
          if (normalizedPreferredCountry && !candidateCountry) {
            tutorFilterStats.missingCountry += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "missing_country",
            });
            continue;
          }

          if (
            normalizedPreferredCountry &&
            candidateCountry !== normalizedPreferredCountry
          ) {
            tutorFilterStats.countryMismatch += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "country_mismatch",
              tutorCountry: candidateCountry || null,
            });
            continue;
          }
          if (!(await hasCallableTeacherToken(tutorId, tutorData, db))) {
            tutorFilterStats.missingCallToken += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "missing_call_token",
            });
            continue;
          }

          availableTutors.push(tutorId);
          tutorFilterStats.matched += 1;
          tutorDetails[tutorId] = {
            role: tutorRole,
            country: candidateCountry || "unknown",
            ratingAverage: tutorProfile.ratingAverage,
            ratingCount: tutorProfile.ratingCount,
            level: candidateLevel || null,
            legacyPriorityScore: readMatchPriorityScore(tutorData),
            searchRequestId: candidateSearchRequestId || null,
            locationMatch:
              !normalizedPreferredCountry ||
              candidateCountry === normalizedPreferredCountry,
            approvedTeacher: tutorProfile.approvedTeacher,
            name: tutorData.display_name || "Partner",
          };
          addTutorSample({
            tutorId,
            outcome: "match",
            legacyPriorityScore: tutorDetails[tutorId].legacyPriorityScore,
            ratingAverage: tutorDetails[tutorId].ratingAverage,
          });
        }
      }

      const totalTutorsQueried = totalQueriedCandidates;
      const filteringSummary = {
        requesterId,
        requesterRole,
        requestedLanguage: normalizedLanguage,
        matchMode: isDirectTutorCall ? "direct" : "filtered",
        directTutorId: isDirectTutorCall ? directTutorId : null,
        preferredCountry: isDirectTutorCall
          ? "skipped_for_direct_call"
          : (normalizedPreferredCountry || "any"),
        preferredPartnerLevel: isDirectTutorCall
          ? "skipped_for_direct_call"
          : (normalizedPreferredPartnerLevel || "any"),
        totalTutorsQueried,
        totalCandidatesChecked: tutorFilterStats.totalCandidates,
        matchedTutors: tutorFilterStats.matched,
        rejected: {
          selfExcluded: tutorFilterStats.selfExcluded,
          unsupportedRole: tutorFilterStats.unsupportedRole,
          blockedByStudent: tutorFilterStats.blockedByStudent,
          blockedByTutor: tutorFilterStats.blockedByTutor,
          availableAfterInFuture: tutorFilterStats.availableAfterInFuture,
          unavailableOrInCall: tutorFilterStats.unavailableOrInCall,
          sameDayRepeat: tutorFilterStats.sameDayRepeat,
          languageMismatch: tutorFilterStats.languageMismatch,
          unapprovedTeacher: tutorFilterStats.unapprovedTeacher,
          missingCallToken: tutorFilterStats.missingCallToken,
          missingLevel: tutorFilterStats.missingLevel,
          levelMismatch: tutorFilterStats.levelMismatch,
          missingCountry: tutorFilterStats.missingCountry,
          countryMismatch: tutorFilterStats.countryMismatch,
        },
        sampledDebugEnabled: shouldSampleTutorDebug,
      };
      if (repeatPreventionContext) {
        filteringSummary.sameDayRepeatPrevention =
          buildRepeatPreventionLogContext(repeatPreventionContext);
      }
      if (shouldSampleTutorDebug && tutorDebugSamples.length > 0) {
        filteringSummary.sample = tutorDebugSamples;
      }
      console.log("📊 Tutor filtering summary", filteringSummary);

      if (availableTutors.length === 0) {
        console.log("📹 createVideoSession no matching tutors after filtering", {
          requesterId,
          requestedLanguage: normalizedLanguage,
          matchMode: isDirectTutorCall ? "direct" : "filtered",
          directTutorId: isDirectTutorCall ? directTutorId : null,
          preferredCountry: normalizedPreferredCountry || "any",
          preferredPartnerLevel: normalizedPreferredPartnerLevel || "any",
        });
        return {
          status: "no_tutors_available",
          message: isDirectTutorCall
            ? "Selected partner is not available right now"
            : "No partners are available matching your preferences. Try adjusting your filters.",
        };
      }

      if (!isDirectTutorCall) {
        const orderedTutors = orderCandidatesByMatchQuality(
          availableTutors,
          tutorDetails,
        );
        availableTutors.splice(0, availableTutors.length, ...orderedTutors);
        console.log("📊 Matched tutors after sorting", {
          count: availableTutors.length,
          topTutorPreview: availableTutors.slice(0, 3).map((id) => ({
            tutorId: id,
            locationMatch: tutorDetails[id].locationMatch,
            approvedTeacher: tutorDetails[id].approvedTeacher,
            ratingAverage: tutorDetails[id].ratingAverage,
            legacyPriorityScore: tutorDetails[id].legacyPriorityScore,
          })),
        });
      }

      // Создаем videoSession
      const sessionPolicyFields = buildCreateSessionPolicyFields();

      let precreatedRoomUrl = null;
      let precreatedRoomName = null;
      let precreatedRoomCreatedAt = null;

      try {
        const dailyRoom = await createDailyRoom({
          language: normalizedLanguage,
          studentId: requesterId,
          tutorId: null,
          studentName: requesterInfo.name || "Caller",
          tutorName: "Tutor",
          expSeconds: 15 * 60,
        });

        precreatedRoomUrl = dailyRoom.url;
        precreatedRoomName = dailyRoom.name;
        precreatedRoomCreatedAt = Date.now();

        console.log("✅ Precreated Daily room for session", {
          roomName: precreatedRoomName,
          roomUrl: precreatedRoomUrl,
        });
      } catch (roomError) {
        console.error("⚠️ Failed to precreate Daily room:", roomError.message);
      }

      const sessionData = {
        studentId: requesterId,
        participantIds: [requesterId],
        language: normalizedLanguage,
        status: "searching",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ...sessionPolicyFields,

        // Предпочтения студента (для логов и аналитики)
        studentPreferences: {
          country: normalizedPreferredCountry || null,
        },

        // Для поиска
        triedTutors: [],
        availableTutors, // Уже отсортированный массив
        studentInfo: requesterInfo,
        matchContext: {
          version: "v2_all_to_all",
          matcher: isDirectTutorCall ? "directCall" : "createVideoSession",
          matchMode: isDirectTutorCall ? "direct" : "filtered",
          requesterId,
          requesterRole,
          requestedLanguage: normalizedLanguage,
          requestedLanguageSource: resolvedLanguage.source || null,
          directTutorId: isDirectTutorCall ? directTutorId : null,
          directCandidateId: isDirectTutorCall ? directTutorId : null,
          requesterProfile,
          filters: isDirectTutorCall ? null : {
            preferredCountry: normalizedPreferredCountry || null,
            preferredPartnerLevel: normalizedPreferredPartnerLevel || null,
          },
          ranking: {
            friendPriorityApplied: false,
            locationApplied:
              !isDirectTutorCall && !!normalizedPreferredCountry,
            levelApplied:
              !isDirectTutorCall && !!normalizedPreferredPartnerLevel,
            rolePriorityApplied: false,
            internalRankingScore: 0,
            legacyPriorityUsedAsTiebreaker: true,
          },
          candidatePoolSize: availableTutors.length,
          candidateIds: availableTutors,
          candidateRoleCounts: buildCandidateRoleCounts(
            availableTutors,
            tutorDetails,
          ),
        },

        [STUDENT_REVIEW_FLAG_FIELD]: false,
        [TUTOR_REVIEW_FLAG_FIELD]: false,
      };

      if (precreatedRoomUrl) {
        sessionData.dailyRoomUrl = precreatedRoomUrl;
      }
      if (precreatedRoomName) {
        sessionData.dailyRoomName = precreatedRoomName;
      }
      if (directTutorInfo) {
        sessionData.tutorInfo = directTutorInfo;
      }
      if (precreatedRoomCreatedAt) {
        sessionData.sessionMetadata = {
          roomCreatedAt: precreatedRoomCreatedAt,
          dailyRoomConfigVersion: DAILY_ROOM_CONFIG_VERSION,
        };
      }

      const sessionRef = db.collection("videoSessions").doc();
      const creation = await db.runTransaction(async (transaction) => {
        const finalRepeatPreventionContext =
          await loadSameDayRepeatCandidateIdsForTransaction(
            transaction,
            db,
            requesterId,
            availableTutors,
            {
              bypassUserIds: repeatBypassUserIds,
              requesterEmail: requesterData.email || context.auth.token.email,
              userEmailsById: candidateEmailsById,
            },
          );
        const finalAvailableTutors = filterRepeatCandidates(
          availableTutors,
          finalRepeatPreventionContext,
        );

        if (finalAvailableTutors.length === 0) {
          return {
            created: false,
            repeatPreventionContext: finalRepeatPreventionContext,
          };
        }

        if (isDirectTutorCall) {
          const selectedResponderId = finalAvailableTutors[0] || "";
          const selectedResponderRole =
            tutorDetails[selectedResponderId]?.role || "";
          const finalSessionData = {
            ...sessionData,
            availableTutors: finalAvailableTutors,
            triedTutors: [],
            currentTutorId: selectedResponderId,
            matchContext: {
              ...sessionData.matchContext,
              candidatePoolSize: finalAvailableTutors.length,
              candidateIds: finalAvailableTutors,
              selectedResponderId,
              selectedResponderRole,
              candidateRoleCounts: buildCandidateRoleCounts(
                finalAvailableTutors,
                tutorDetails,
              ),
            },
          };
          const directLockNowMillis = Date.now();
          const lockResult = await reserveDirectPairInTransaction({
            db,
            transaction,
            requesterId,
            responderId: selectedResponderId,
            responderRole: selectedResponderRole,
            sessionRef,
            sessionData: finalSessionData,
            nowMillis: directLockNowMillis,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            lockExpiresAt: admin.firestore.Timestamp.fromMillis(
              directLockNowMillis + 45 * 1000,
            ),
          });
          if (!lockResult.locked) {
            return {
              created: false,
              repeatPreventionContext: finalRepeatPreventionContext,
              lockFailure: lockResult,
            };
          }

          const notification = createIncomingCallNotificationInTransaction({
            db,
            transaction,
            sessionId: sessionRef.id,
            recipientId: selectedResponderId,
            sessionData: finalSessionData,
            studentNameFallback: "Student",
          });
          return {
            created: true,
            sessionData: finalSessionData,
            matchedTutors: finalAvailableTutors.length,
            selectedResponderId,
            selectedResponderRole,
            notificationId: notification.notificationId,
            pushPayload: notification.pushPayload,
            repeatPreventionContext: finalRepeatPreventionContext,
          };
        }

        let selectedResponderId = "";
        let selectedResponderRole = "";
        let selectedTriedTutors = [];
        let finalSessionData = null;
        let nextTriedTutors = [];
        let lockResult = null;
        const skippedLockCandidateIds = [];
        while (true) {
          const nextCandidate = await findNextCallableCandidateInTransaction({
            db,
            transaction,
            candidateIds: finalAvailableTutors,
            triedCandidateIds: nextTriedTutors,
            language: normalizedLanguage,
          });
          if (!nextCandidate.candidateId) {
            lockResult = {
              locked: false,
              reason: "no_callable_candidates",
            };
            nextTriedTutors = nextCandidate.triedCandidateIds;
            break;
          }

          const candidateResponderId = nextCandidate.candidateId;
          const candidateResponderRole =
            nextCandidate.role ||
            tutorDetails[candidateResponderId]?.role ||
            "";
          const candidateSessionData = {
            ...sessionData,
            availableTutors: finalAvailableTutors,
            triedTutors: nextCandidate.triedCandidateIds,
            currentTutorId: candidateResponderId,
            matchContext: {
              ...sessionData.matchContext,
              candidatePoolSize: finalAvailableTutors.length,
              candidateIds: finalAvailableTutors,
              selectedResponderId: candidateResponderId,
              selectedResponderRole: candidateResponderRole || null,
              candidateRoleCounts: buildCandidateRoleCounts(
                finalAvailableTutors,
                tutorDetails,
              ),
            },
          };
          const lockNowMillis = Date.now();
          lockResult = await reserveMatchPairInTransaction({
            db,
            transaction,
            requesterId,
            responderId: candidateResponderId,
            responderRole: candidateResponderRole,
            requesterSearchRequestId,
            responderSearchRequestId:
              tutorDetails[candidateResponderId]?.searchRequestId || "",
            expectedLanguage: normalizedLanguage,
            sessionRef,
            sessionData: candidateSessionData,
            nowMillis: lockNowMillis,
            serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            lockExpiresAt: admin.firestore.Timestamp.fromMillis(
              lockNowMillis + 45 * 1000,
            ),
          });
          if (lockResult.locked) {
            selectedResponderId = candidateResponderId;
            selectedResponderRole = candidateResponderRole;
            selectedTriedTutors = nextCandidate.triedCandidateIds;
            finalSessionData = candidateSessionData;
            break;
          }

          if (String(lockResult.reason || "").startsWith("requester_")) {
            break;
          }
          skippedLockCandidateIds.push({
            candidateId: candidateResponderId,
            reason: lockResult.reason,
          });
          nextTriedTutors = Array.from(new Set([
            ...nextCandidate.triedCandidateIds,
            candidateResponderId,
          ]));
        }
        if (skippedLockCandidateIds.length > 0) {
          console.log("⏭️ Skipped locked candidates:", skippedLockCandidateIds);
        }
        if (!lockResult?.locked || !selectedResponderId || !finalSessionData) {
          return {
            created: false,
            repeatPreventionContext: finalRepeatPreventionContext,
            lockFailure: lockResult || {
              locked: false,
              reason: "pair_lock_failed",
            },
          };
        }

        const notification = createIncomingCallNotificationInTransaction({
          db,
          transaction,
          sessionId: sessionRef.id,
          recipientId: selectedResponderId,
          sessionData: finalSessionData,
          studentNameFallback: "Student",
        });
        return {
          created: true,
          sessionData: finalSessionData,
          matchedTutors: finalAvailableTutors.length,
          selectedResponderId,
          selectedResponderRole,
          triedTutors: selectedTriedTutors,
          notificationId: notification.notificationId,
          pushPayload: notification.pushPayload,
          repeatPreventionContext: finalRepeatPreventionContext,
        };
      });

      if (!creation.created) {
        if (precreatedRoomName) {
          await deleteDailyRoom(precreatedRoomName);
        }
        const excludedCount = countExcludedRepeatCandidates(
          creation.repeatPreventionContext,
        );
        console.log("📹 createVideoSession final repeat guard blocked session", {
          requesterId,
          requestedLanguage: normalizedLanguage,
          matchMode: isDirectTutorCall ? "direct" : "filtered",
          excludedCount,
          sameDayRepeatPrevention: buildRepeatPreventionLogContext(
            creation.repeatPreventionContext,
          ),
        });
        return {
          status: "no_tutors_available",
          message: isDirectTutorCall
            ? "Selected partner is not available right now"
            : "No partners are available matching your preferences. Try adjusting your filters.",
        };
      }

      console.log("✅ Video session created:", sessionRef.id);

      if (creation.selectedResponderId && creation.pushPayload) {
        const freshValidationSnap = await sessionRef.get();
        const freshValidation = freshValidationSnap.exists ?
          freshValidationSnap.data() || {} :
          {};
        if (
          PENDING_RESPONSE_SESSION_STATUSES.has(freshValidation.status) &&
          freshValidation.currentTutorId === creation.selectedResponderId &&
          !hasActiveAcceptLockForResponder({
            sessionData: freshValidation,
            responderId: creation.selectedResponderId,
          })
        ) {
          await sendVoipPushToTutor(
            creation.selectedResponderId,
            creation.pushPayload,
          );
        }
      } else {
        console.log(
          "⏭️ Skipping legacy tutor notification fallback for locked session",
          sessionRef.id,
        );
      }

      return {
        status: isDirectTutorCall ? "calling" : "searching",
        sessionId: sessionRef.id,
        message: isDirectTutorCall
          ? "Calling selected partner..."
          : "Searching for available partner...",
        matchedTutors: creation.matchedTutors,
      };
    } catch (error) {
      console.error("❌ Error creating video session:", error);
      if (error.code) throw error;
      throw new functions.https.HttpsError("internal", error.message);
    }
  });

// 🔔 ОТПРАВКА VOIP PUSH ПРЕПОДАВАТЕЛЮ
async function sendVoipPushToTutor(tutorId, callData) {
  try {
    console.log("📲 Preparing VoIP push for tutor:", tutorId);

    const tutorDoc = await admin
      .firestore()
      .collection("users")
      .doc(tutorId)
      .get();

    if (!tutorDoc.exists) {
      console.log("⚠️ Tutor document not found:", tutorId);
      return;
    }

    const tutorData = tutorDoc.data();
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.expatlio";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const { voipPushToken, voipToken: fcmToken } =
      await getUserVoipTokens(tutorId, tutorData);

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Tutor has no push tokens saved");
      return;
    }

    if (voipPushToken) {
      const apnsPayload = buildTeacherIncomingCallApnsPayload(callData);

      try {
        await sendApnsVoip({
          deviceToken: voipPushToken,
          topic: voipTopic,
          payload: apnsPayload,
        });
        console.log("✅ APNs VoIP push sent successfully");
        return;
      } catch (error) {
        console.error("❌ Error sending APNs VoIP push:", error.message);
      }
    }

    if (!fcmToken) {
      console.log("⚠️ No FCM token available for fallback");
      return;
    }

    console.log("📱 FCM token found");
    console.log("📦 Using apns-topic for FCM fallback:", bundleId);

    const message = buildTeacherIncomingCallFcmMessage({
      token: fcmToken,
      callData,
      bundleId,
    });

    const response = await admin.messaging().send(message);
    console.log("✅ FCM push sent successfully. Message ID:", response);

    return response;
  } catch (error) {
    console.error("❌ Error sending VoIP push to tutor:", error);
    return null;
  }
}

exports.__private__ = {
  buildCreateSessionPolicyFields,
  compareCandidateDetails,
  hasCallableTeacherToken,
  orderCandidatesByMatchQuality,
};

async function sendNotificationToNextTutor(sessionId, fallbackSessionData = {}) {
  try {
    const db = admin.firestore();
    const sessionRef = db
      .collection("videoSessions")
      .doc(sessionId);

    const assignment = await admin.firestore().runTransaction(
      async (transaction) => {
        const freshSessionSnap = await transaction.get(sessionRef);
        if (!freshSessionSnap.exists) {
          return {
            shouldNotify: false,
            skipReason: "session_not_found",
          };
        }

        const freshSessionData = freshSessionSnap.data() || {};
        const status = freshSessionData.status || "unknown";
        if (status !== VIDEO_SESSION_STATUS.SEARCHING) {
          return {
            shouldNotify: false,
            skipReason: `status_${status}`,
          };
        }

        if (freshSessionData.currentTutorId) {
          return {
            shouldNotify: false,
            skipReason: `tutor_already_assigned_${freshSessionData.currentTutorId}`,
          };
        }

        const availableTutors = freshSessionData.availableTutors || [];
        const triedTutors = freshSessionData.triedTutors || [];
        const nextCandidate = await findNextCallableCandidateInTransaction({
          db,
          transaction,
          candidateIds: availableTutors,
          triedCandidateIds: triedTutors,
          language: freshSessionData.language,
        });
        const nextTutor = nextCandidate.candidateId;
        const nextTriedTutors = nextCandidate.triedCandidateIds;

        if (!nextTutor) {
          transaction.update(sessionRef, {
            triedTutors: nextTriedTutors,
            status: VIDEO_SESSION_STATUS.CANCELLED,
            endedAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelReason: "no_available_responder",
          });
          return {
            shouldNotify: false,
            skipReason: "no_available_tutors",
          };
        }

        const notification = createIncomingCallNotificationInTransaction({
          db,
          transaction,
          sessionId,
          recipientId: nextTutor,
          sessionData: {
            ...freshSessionData,
            triedTutors: nextTriedTutors,
            currentTutorId: nextTutor,
          },
          studentNameFallback: "Student",
        });

        transaction.update(sessionRef, {
          triedTutors: nextTriedTutors,
          currentTutorId: nextTutor,
          status: VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
        });

        return {
          shouldNotify: true,
          nextTutor,
          sessionData: {
            ...freshSessionData,
            triedTutors: nextTriedTutors,
            currentTutorId: nextTutor,
            status: VIDEO_SESSION_STATUS.PENDING_CONFIRMATION,
          },
          notificationId: notification.notificationId,
          pushPayload: notification.pushPayload,
        };
      },
    );

    if (!assignment || !assignment.shouldNotify) {
      console.log(
        "⏭️ Skipping tutor notification for session",
        sessionId,
        "reason:",
        assignment?.skipReason || "unknown",
      );
      return;
    }

    const nextTutor = assignment.nextTutor;
    const pushPayload = assignment.pushPayload || {};

    const freshValidationSnap = await sessionRef.get();
    if (!freshValidationSnap.exists) {
      console.log(
        "⏭️ Skipping tutor notification. Session disappeared:",
        sessionId,
      );
      return;
    }

    const freshValidation = freshValidationSnap.data() || {};
    if (
      !PENDING_RESPONSE_SESSION_STATUSES.has(freshValidation.status) ||
      freshValidation.currentTutorId !== nextTutor ||
      hasActiveAcceptLockForResponder({
        sessionData: freshValidation,
        responderId: nextTutor,
      })
    ) {
      console.log(
        "⏭️ Skipping tutor notification after validation. reason:",
        `status_${freshValidation.status || "unknown"}`,
        `currentTutor_${freshValidation.currentTutorId || "none"}`,
      );
      return;
    }

    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        ...pushPayload,
        sessionId: pushPayload.sessionId || sessionId,
        studentName: pushPayload.studentName || "Student",
        studentId: pushPayload.studentId || "",
        studentPhoto: pushPayload.studentPhoto,
        language: pushPayload.language || "",
      });
      console.log("✅ VoIP push sent to tutor");
    } catch (pushError) {
      console.error(
        "⚠️ Failed to send VoIP push (non-critical):",
        pushError.message,
      );
    }
  } catch (error) {
    console.error("❌ Error sending notification:", error);
  }
}
