const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { sendApnsVoip } = require("./apns_voip");
const {
  createDailyRoom,
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

const apnsSecrets = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID"];
const dailySecrets = ["DAILY_API_KEY", "DAILY_DOMAIN"];
const STUDENT_REVIEW_FLAG_FIELD = "studentHasReviewed";
const TUTOR_REVIEW_FLAG_FIELD = "tutorHasReviewed";
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
const HIGH_LEVEL_TEACHER_PRIORITY_GROUP_SIZE = 5;
const HIGH_LEVEL_TEACHER_PRIORITY_TEACHER_SLOTS = 4;

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

function isTeacherBoostTargetLevel(level) {
  return readLevelValue(level).toLowerCase() === "fluent";
}

function getTeacherBoostScore(tutorProfile = {}, teacherBoostRankingApplied) {
  return teacherBoostRankingApplied && tutorProfile.approvedTeacher ? 1 : 0;
}

function orderCandidatesWithTeacherPriority(
  candidateIds = [],
  detailsById = {},
  teacherPriorityApplied = false,
) {
  const sortedCandidateIds = [...candidateIds].sort((a, b) =>
    compareCandidateDetails(a, b, detailsById));
  if (!teacherPriorityApplied) {
    return sortedCandidateIds;
  }

  const approvedTeachers = sortedCandidateIds.filter(
    (id) => detailsById[id]?.approvedTeacher === true,
  );
  const otherCandidates = sortedCandidateIds.filter(
    (id) => detailsById[id]?.approvedTeacher !== true,
  );
  if (approvedTeachers.length === 0 || otherCandidates.length === 0) {
    return sortedCandidateIds;
  }

  const ordered = [];
  let teacherIndex = 0;
  let otherIndex = 0;
  while (
    teacherIndex < approvedTeachers.length ||
    otherIndex < otherCandidates.length
  ) {
    for (
      let slot = 0;
      slot < HIGH_LEVEL_TEACHER_PRIORITY_TEACHER_SLOTS &&
      teacherIndex < approvedTeachers.length;
      slot += 1
    ) {
      ordered.push(approvedTeachers[teacherIndex]);
      teacherIndex += 1;
    }

    const groupHasOtherSlot =
      HIGH_LEVEL_TEACHER_PRIORITY_TEACHER_SLOTS <
      HIGH_LEVEL_TEACHER_PRIORITY_GROUP_SIZE;
    if (groupHasOtherSlot && otherIndex < otherCandidates.length) {
      ordered.push(otherCandidates[otherIndex]);
      otherIndex += 1;
    }

    if (teacherIndex >= approvedTeachers.length) {
      ordered.push(...otherCandidates.slice(otherIndex));
      break;
    }
    if (otherIndex >= otherCandidates.length) {
      ordered.push(...approvedTeachers.slice(teacherIndex));
      break;
    }
  }

  return ordered;
}

function compareCandidateDetails(leftId, rightId, detailsById) {
  const left = detailsById[leftId] || {};
  const right = detailsById[rightId] || {};

  if (left.locationMatch !== right.locationMatch) {
    return left.locationMatch ? -1 : 1;
  }

  const leftTeacherBoostScore = Number(left.teacherBoostScore) || 0;
  const rightTeacherBoostScore = Number(right.teacherBoostScore) || 0;
  if (leftTeacherBoostScore !== rightTeacherBoostScore) {
    return rightTeacherBoostScore - leftTeacherBoostScore;
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
        directTutorId: rawDirectTutorId,
        directUserId: rawDirectUserId,
      } = data;
      const directTutorId = String(
        rawDirectUserId || rawDirectTutorId || "",
      ).trim();
      const isDirectTutorCall = directTutorId.length > 0;
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
      const teacherBoostRankingApplied = isTeacherBoostTargetLevel(
        normalizedPreferredPartnerLevel,
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
        const tutorRole = normalizeRole(tutorData.role);
        if (!isSupportedSessionRole(tutorRole) || directTutorId === requesterId) {
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

        if (!isAvailable || tutorData.isInCall) {
          tutorFilterStats.unavailableOrInCall += 1;
          addTutorSample({
            tutorId: directTutorId,
            outcome: "skip",
            reason: "unavailable_or_in_call",
            isAvailable: !!isAvailable,
            isInCall: !!tutorData.isInCall,
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
          {bypassUserIds: repeatBypassUserIds},
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
        if (normalizedPreferredPartnerLevel && !candidateLevel) {
          tutorFilterStats.missingLevel += 1;
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }
        if (
          normalizedPreferredPartnerLevel &&
          candidateLevel !== normalizedPreferredPartnerLevel
        ) {
          tutorFilterStats.levelMismatch += 1;
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }
        const candidateCountry = readMatchCountry(tutorData);
        if (normalizedPreferredCountry && !candidateCountry) {
          tutorFilterStats.missingCountry += 1;
          return {
            status: "no_tutors_available",
            message: "Selected partner is not available right now",
          };
        }
        if (
          normalizedPreferredCountry &&
          candidateCountry !== normalizedPreferredCountry
        ) {
          tutorFilterStats.countryMismatch += 1;
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
          teacherBoostScore: getTeacherBoostScore(
            tutorProfile,
            teacherBoostRankingApplied,
          ),
          locationMatch:
            !normalizedPreferredCountry ||
            candidateCountry === normalizedPreferredCountry,
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

        repeatPreventionContext = await loadSameDayRepeatCandidateIds(
          db,
          requesterId,
          Array.from(candidateDocsById.keys()),
          {bypassUserIds: repeatBypassUserIds},
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
          if (!availabilityCheck.isAvailable || tutorData.isInCall) {
            tutorFilterStats.unavailableOrInCall += 1;
            addTutorSample({
              tutorId,
              outcome: "skip",
              reason: "unavailable_or_in_call",
              isAvailable: !!availabilityCheck.isAvailable,
              isInCall: !!tutorData.isInCall,
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

          availableTutors.push(tutorId);
          tutorFilterStats.matched += 1;
          tutorDetails[tutorId] = {
            role: tutorRole,
            country: candidateCountry || "unknown",
            ratingAverage: tutorProfile.ratingAverage,
            ratingCount: tutorProfile.ratingCount,
            level: candidateLevel || null,
            legacyPriorityScore: readMatchPriorityScore(tutorData),
            teacherBoostScore: getTeacherBoostScore(
              tutorProfile,
              teacherBoostRankingApplied,
            ),
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
        preferredPartnerLevel: normalizedPreferredPartnerLevel || "any",
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
        const orderedTutors = orderCandidatesWithTeacherPriority(
          availableTutors,
          tutorDetails,
          teacherBoostRankingApplied,
        );
        availableTutors.splice(0, availableTutors.length, ...orderedTutors);
        console.log("📊 Matched tutors after sorting", {
          count: availableTutors.length,
          topTutorPreview: availableTutors.slice(0, 3).map((id) => ({
            tutorId: id,
            locationMatch: tutorDetails[id].locationMatch,
            approvedTeacher: tutorDetails[id].approvedTeacher,
            teacherBoostScore: tutorDetails[id].teacherBoostScore,
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
          requesterId,
          requesterRole,
          requestedLanguage: normalizedLanguage,
          requestedLanguageSource: resolvedLanguage.source || null,
          directCandidateId: isDirectTutorCall ? directTutorId : null,
          requesterProfile,
          filters: {
            preferredCountry: normalizedPreferredCountry || null,
            preferredPartnerLevel: normalizedPreferredPartnerLevel || null,
          },
          ranking: {
            friendPriorityApplied: false,
            locationApplied: !!normalizedPreferredCountry,
            levelApplied: !!normalizedPreferredPartnerLevel,
            teacherBoostApplied:
              !isDirectTutorCall && teacherBoostRankingApplied,
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
            {bypassUserIds: repeatBypassUserIds},
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

        const finalSessionData = {
          ...sessionData,
          availableTutors: finalAvailableTutors,
          matchContext: {
            ...sessionData.matchContext,
            candidatePoolSize: finalAvailableTutors.length,
            candidateIds: finalAvailableTutors,
            candidateRoleCounts: buildCandidateRoleCounts(
              finalAvailableTutors,
              tutorDetails,
            ),
          },
        };
        transaction.set(sessionRef, finalSessionData);
        return {
          created: true,
          sessionData: finalSessionData,
          matchedTutors: finalAvailableTutors.length,
          repeatPreventionContext: finalRepeatPreventionContext,
        };
      });

      if (!creation.created) {
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

      // Уведомляем первого преподавателя
      await sendNotificationToNextTutor(sessionRef.id, creation.sessionData);

      return {
        status: "searching",
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
    const bundleId = process.env.IOS_BUNDLE_ID || "com.appwave.smalltalk";
    const voipTopic =
      process.env.IOS_VOIP_TOPIC ||
      (bundleId.endsWith(".voip") ? bundleId : `${bundleId}.voip`);
    const voipPushToken = tutorData.voipPushToken;
    const fcmToken = tutorData.voipToken;

    if (!voipPushToken && !fcmToken) {
      console.log("⚠️ Tutor has no push tokens saved");
      return;
    }

    if (voipPushToken) {
      const apnsPayload = {
        aps: { "content-available": 1 },
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || "",
        language: callData.language || "",
      };

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

    console.log("📱 FCM token found:", fcmToken.substring(0, 20) + "...");
    console.log("📦 Using apns-topic for FCM fallback:", bundleId);

    const message = {
      token: fcmToken,
      data: {
        type: "incoming_call",
        sessionId: callData.sessionId,
        callerName: callData.studentName,
        callerId: callData.studentId,
        callerPhoto: callData.studentPhoto || "",
        language: callData.language || "",
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
          "apns-topic": bundleId,
        },
        payload: {
          aps: {
            "content-available": 1,
            alert: {
              title: "Входящий звонок",
              body: `${callData.studentName} хочет попрактиковать ${callData.language}`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
      },
    };

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
  getTeacherBoostScore,
  isTeacherBoostTargetLevel,
  orderCandidatesWithTeacherPriority,
};

async function sendNotificationToNextTutor(sessionId, fallbackSessionData = {}) {
  try {
    const sessionRef = admin
      .firestore()
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
        if (status !== "searching") {
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
        const nextTutor = availableTutors.find(
          (tutorId) => !triedTutors.includes(tutorId),
        );

        if (!nextTutor) {
          transaction.update(sessionRef, {
            status: "no_tutors_available",
          });
          return {
            shouldNotify: false,
            skipReason: "no_available_tutors",
          };
        }

        transaction.update(sessionRef, {
          currentTutorId: nextTutor,
        });

        return {
          shouldNotify: true,
          nextTutor,
          sessionData: freshSessionData,
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
    const sessionData = assignment.sessionData || fallbackSessionData || {};
    const studentInfo = sessionData.studentInfo || fallbackSessionData.studentInfo || {};
    const studentName = studentInfo.name || "Student";
    const studentPhoto = studentInfo.photo || null;
    const studentId = sessionData.studentId || fallbackSessionData.studentId || "";
    const language = sessionData.language || fallbackSessionData.language || "";

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
      freshValidation.status !== "searching" ||
      freshValidation.currentTutorId !== nextTutor
    ) {
      console.log(
        "⏭️ Skipping tutor notification after validation. reason:",
        `status_${freshValidation.status || "unknown"}`,
        `currentTutor_${freshValidation.currentTutorId || "none"}`,
      );
      return;
    }

    // Создаём уведомление в Firestore
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + 45);

    const notificationData = {
      recipientId: nextTutor,
      sessionId,
      type: "incoming_call",
      status: "sent",
      title: "Входящий звонок",
      message: `${studentName} хочет попрактиковать ${language}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      studentInfo,
    };

    await admin.firestore().collection("notifications").add(notificationData);
    console.log("✅ Firestore notification created for tutor:", nextTutor);

    // 🔔 Отправляем VoIP push преподавателю
    console.log("📲 Sending VoIP push to tutor...");
    try {
      await sendVoipPushToTutor(nextTutor, {
        sessionId: sessionId,
        studentName: studentName,
        studentId: studentId,
        studentPhoto: studentPhoto,
        language: language,
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
