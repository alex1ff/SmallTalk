const admin = require("firebase-admin");
const {
  getReadOnlyUserVoipTokenState,
} = require("./voip_tokens");
const {
  buildInitialSessionPolicyState,
  normalizeRole,
  readLevelValue,
} = require("./video_sessions_shared");
const {
  SEARCH_REQUEST_COLLECTION,
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");
const {
  buildCurrentMatchedStartSearchResponse,
  buildMatchedStartSearchResponse,
  buildStartSearchResponse,
  canAttemptStudentPairForSearchRequest,
  hasCurrentMatchedSession,
  hasSearchRequestSessionBinding,
  searchRequestBelongsToUser,
  timestampToMillis,
} = require("./start_search_request_policy");
const {
  MATCH_CANDIDATE_SOURCE,
  collectMatchCandidatePool,
} = require("./match_candidate_pool");
const {
  reserveMatchPair,
} = require("./match_pair_lock");
const {
  MATCH_PROTOCOL_VERSION,
} = require("./match_protocol_v2");
const {
  cancelProtocolV2NativeSurfaces,
  classifyProtocolV2RouteResult,
} = require("./match_delivery_v2");
const {
  reconcileProtocolV2TerminalSideEffects,
} = require("./match_recovery_v2");
const {
  maybeNotifyBackgroundStudentResponder,
  maybeNotifyTeacherResponder,
  readProtocolV2PostRouteOutcome,
  routeProtocolV2InitialMatch,
  shouldRouteProtocolV2InitialMatch,
  waitForForegroundStudentResponderResolution,
} = require("./start_search_delivery");
const {
  shouldRetryBackgroundStudentMatchAfterNotifyResult,
  shouldRetryTeacherMatchAfterNotifyResult,
} = require("./start_search_responder_policy");
const {
  releaseBackgroundStudentResponderMatchForRetry,
  releaseProtocolV2MatchAfterRouteFailure,
  releaseTeacherResponderMatchForRetry,
} = require("./start_search_recovery");
const {
  sendVoipPushToStudentResponder,
} = require("./start_search_push_transport");

const STUDENT_REVIEW_FLAG_FIELD = "studentHasReviewed";
const TUTOR_REVIEW_FLAG_FIELD = "tutorHasReviewed";

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function readErrorMessage(error, fallback = "") {
  if (error && typeof error === "object") {
    try {
      return normalizeString(error.message) || fallback;
    } catch (readError) {
      return fallback;
    }
  }
  try {
    return normalizeString(String(error)) || fallback;
  } catch (stringifyError) {
    return fallback;
  }
}

function readNestedObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value :
    {};
}

async function tryReadCurrentMatchedStartSearchResponse({
  db,
  userId,
  reused = false,
}) {
  const searchRequestSnapshot = await db
    .collection(SEARCH_REQUEST_COLLECTION)
    .doc(userId)
    .get();
  const requestData = searchRequestSnapshot.exists ?
    searchRequestSnapshot.data() || {} :
    {};

  if (
    !searchRequestSnapshot.exists ||
    !searchRequestBelongsToUser(requestData, userId) ||
    !hasCurrentMatchedSession(requestData)
  ) {
    return null;
  }

  return buildCurrentMatchedStartSearchResponse({
    userId,
    requestData,
    reused,
  });
}

function buildStudentPairSessionData({
  requesterId = "",
  requestData = {},
  selectedCandidate = {},
  studentCandidates = [],
  matchCandidates = studentCandidates,
  candidateStats = {},
  nowMillis = Date.now(),
  timestampFromDate = admin.firestore.Timestamp.fromDate,
}) {
  const candidateIds = matchCandidates
    .map((candidate) => normalizeString(candidate.userId))
    .filter(Boolean);
  const selectedResponderId = normalizeString(selectedCandidate.userId);
  const selectedResponderRole =
    normalizeRole(selectedCandidate.role) || "student";
  const sessionPolicyState = buildInitialSessionPolicyState(nowMillis);
  return {
    matchProtocolVersion:
      Number(requestData.matchProtocolVersion) >= MATCH_PROTOCOL_VERSION ?
        MATCH_PROTOCOL_VERSION :
        1,
    language: normalizeString(requestData.language),
    expiresAt: timestampFromDate(sessionPolicyState.expiresAt),
    sessionPolicy: sessionPolicyState.sessionPolicy,
    [STUDENT_REVIEW_FLAG_FIELD]: false,
    [TUTOR_REVIEW_FLAG_FIELD]: false,
    availableTutors: candidateIds,
    triedTutors: selectedResponderId ? [selectedResponderId] : [],
    matchContext: {
      requesterId,
      requesterRole: "student",
      requestedLanguage: normalizeString(requestData.language),
      filters: readNestedObject(requestData.filters),
      matcher: "startSearch",
      candidatePoolSize: candidateIds.length,
      candidateIds,
      candidateStats,
      selectedResponderId,
      selectedResponderRole,
      selectedResponderSource:
        normalizeString(selectedCandidate.source) || null,
      selectedResponderSearchRequestId:
        normalizeString(selectedCandidate.searchRequestId) || null,
    },
  };
}

async function tryCreateStudentPairForSearchRequest({
  db,
  userId,
  requesterData = {},
  requestData = {},
  reused = false,
  backgroundStudentResponderPushSender = sendVoipPushToStudentResponder,
  backgroundStudentResponderPrePushWait =
    waitForForegroundStudentResponderResolution,
  teacherResponderPushSender = sendVoipPushToStudentResponder,
  teacherResponderTokenReader = getReadOnlyUserVoipTokenState,
}) {
  if (!canAttemptStudentPairForSearchRequest(requestData)) {
    return {
      matched: false,
      response: null,
    };
  }

  const candidatePool = await collectMatchCandidatePool({
    db,
    requesterId: userId,
    requesterEmail: normalizeString(requesterData.email),
    language: requestData.language,
    requesterFilters: requestData.filters || {},
    requesterLevel: readLevelValue(requesterData.level),
    now: new Date(),
    nowMillis: Date.now(),
  });
  const normalizedRequesterId = normalizeString(userId);
  const matchCandidates = candidatePool.candidates.filter((candidate) => {
    const candidateUserId = normalizeString(candidate.userId);
    const candidateRole = normalizeRole(candidate.role);
    const candidateSource = normalizeString(candidate.source);
    if (!candidateUserId || candidateUserId === normalizedRequesterId) {
      return false;
    }
    return (
      candidateSource === MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE &&
        candidateRole === "student"
    ) || (
      candidateSource === MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY &&
        candidateRole === "native_speaker"
    );
  });

  const retryExcludedResponderIds = new Set();
  for (const candidate of matchCandidates) {
    if (retryExcludedResponderIds.has(normalizeString(candidate.userId))) {
      continue;
    }
    const currentMatchCandidates = matchCandidates.filter((matchCandidate) =>
      !retryExcludedResponderIds.has(normalizeString(matchCandidate.userId)),
    );
    const responderRole = normalizeRole(candidate.role);
    const isStudentQueueResponder =
      responderRole === "student" &&
      normalizeString(candidate.source) ===
        MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE;
    const isTeacherResponder =
      responderRole === "native_speaker" &&
      normalizeString(candidate.source) ===
        MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY;
    const lockNowMillis = Date.now();
    const lockResult = await reserveMatchPair({
      db,
      requesterId: userId,
      responderId: candidate.userId,
      responderRole,
      requesterSearchRequestId: requestData.requestId,
      responderSearchRequestId:
        isStudentQueueResponder ? candidate.searchRequestId : "",
      expectedLanguage: requestData.language,
      sessionData: buildStudentPairSessionData({
        requesterId: userId,
        requestData,
        selectedCandidate: candidate,
        matchCandidates: currentMatchCandidates,
        candidateStats: candidatePool.stats,
        nowMillis: lockNowMillis,
      }),
      nowMillis: lockNowMillis,
      now: Date.now,
    });

    if (lockResult.locked) {
      if (
        Number(lockResult.matchProtocolVersion) === MATCH_PROTOCOL_VERSION
      ) {
        let protocolV2RouteResult = {
          results: [],
          failedResult: null,
          retryPending: false,
        };
        if (shouldRouteProtocolV2InitialMatch(lockResult)) {
          try {
            protocolV2RouteResult = await routeProtocolV2InitialMatch({
              db,
              lockResult,
              requesterId: userId,
              responderRole,
              studentPushSender: backgroundStudentResponderPushSender,
              teacherPushSender: teacherResponderPushSender,
              studentPreDispatchWait:
                backgroundStudentResponderPrePushWait,
            });
          } catch (error) {
            protocolV2RouteResult = {
              results: [],
              failedResult: null,
              retryPending: true,
              error: readErrorMessage(error, "route_failed"),
            };
          }
        }

        if (protocolV2RouteResult.failedResult) {
          const failure = protocolV2RouteResult.failedResult;
          const failedParticipantId = normalizeString(
            failure.participantId,
          ) || normalizeString(lockResult.responderId);
          const failureState = failure.participantState || {};
          const failureOutcome = classifyProtocolV2RouteResult(failure);
          const releaseResult =
            await releaseProtocolV2MatchAfterRouteFailure({
              db,
              sessionId: lockResult.sessionId,
              pairAttemptId: lockResult.pairAttemptId,
              failedParticipantId,
              expectedDispatchId: failureState.dispatchId,
              expectedDelivery: failureState.delivery,
              expectedDeliveryFailureKind:
                failureState.deliveryFailureKind,
              requireResponseWindowClosed:
                failureOutcome === "response_window_closed",
              stopReason: failureOutcome === "response_window_closed" ?
                "protocol_v2_response_timeout" :
                "protocol_v2_push_failed",
          });
          if (releaseResult.released) {
            await reconcileReleasedProtocolV2Match({
              db,
              sessionId: lockResult.sessionId,
              pairAttemptId: lockResult.pairAttemptId,
              options: {
                participantPushSender:
                  backgroundStudentResponderPushSender,
                studentPreDispatchWait:
                  backgroundStudentResponderPrePushWait,
              },
            }).catch((error) => {
              console.warn("Protocol v2 terminal recovery deferred", {
                sessionId: lockResult.sessionId,
                pairAttemptId: lockResult.pairAttemptId,
                error: readErrorMessage(error, "recovery_deferred"),
              });
            });
            if (failedParticipantId === normalizeString(userId)) {
              return {
                matched: false,
                response: buildStartSearchResponse({
                  userId,
                  requestData: {
                    ...requestData,
                    status: SEARCH_REQUEST_STATUS.CANCELLED,
                    currentSessionId: null,
                    matchedSessionId: null,
                    pairAttemptId: null,
                  },
                  reused,
                }),
              };
            }
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
        }
        const postRouteOutcome = await readProtocolV2PostRouteOutcome({
          db,
          sessionId: lockResult.sessionId,
          pairAttemptId: lockResult.pairAttemptId,
        });
        if (postRouteOutcome.terminal) {
          const requesterSearchSnap = await db
            .collection(SEARCH_REQUEST_COLLECTION)
            .doc(userId)
            .get();
          const latestRequestData = requesterSearchSnap.exists ?
            requesterSearchSnap.data() || {} :
            {};
          if (
            latestRequestData.status === SEARCH_REQUEST_STATUS.ACTIVE &&
            !hasSearchRequestSessionBinding(latestRequestData)
          ) {
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
          return {
            matched: false,
            response: buildStartSearchResponse({
              userId,
              requestData: latestRequestData,
              reused,
            }),
          };
        }
      } else if (isStudentQueueResponder) {
        let backgroundStudentNotifyResult;
        try {
          backgroundStudentNotifyResult =
            await maybeNotifyBackgroundStudentResponder({
              db,
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              responderSearchRequestDocId: candidate.searchRequestDocId,
              requesterData,
              pushSender: backgroundStudentResponderPushSender,
              // The legacy notifier calls a zero-argument hook; the shared
              // foreground waiter needs the same match context as v2.
              prePushWait:
                typeof backgroundStudentResponderPrePushWait === "function" ?
                  () => backgroundStudentResponderPrePushWait({
                    db,
                    sessionId: lockResult.sessionId,
                    pairAttemptId: lockResult.pairAttemptId,
                    participantId: lockResult.responderId,
                  }) :
                  backgroundStudentResponderPrePushWait,
            });
        } catch (error) {
          console.error(
            "Failed to notify background student responder",
            {
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              error: readErrorMessage(error, "notify_failed"),
            },
          );
          backgroundStudentNotifyResult = {
            shouldNotify: false,
            reason: "notify_failed",
            error: readErrorMessage(error, "notify_failed"),
          };
        }

        if (
          shouldRetryBackgroundStudentMatchAfterNotifyResult(
            backgroundStudentNotifyResult,
          )
        ) {
          const releaseResult =
            await releaseBackgroundStudentResponderMatchForRetry({
              db,
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              requesterId: userId,
              notificationId: backgroundStudentNotifyResult?.notificationId,
              pairAttemptId: lockResult.pairAttemptId,
              stopReason:
                backgroundStudentNotifyResult?.pushResult?.sent === false ?
                  "background_student_push_failed" :
                  normalizeString(
                    backgroundStudentNotifyResult?.staleReason,
                  ) ||
                    normalizeString(backgroundStudentNotifyResult?.reason) ||
                    "background_student_notification_failed",
            });
          if (releaseResult.released) {
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
          if (releaseResult.reason !== "accept_finalization_in_progress") {
            const currentMatchedResponse =
              await tryReadCurrentMatchedStartSearchResponse({
                db,
                userId,
                reused,
              });
            if (currentMatchedResponse) {
              return {
                matched: true,
                response: currentMatchedResponse,
                lockResult,
              };
            }
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
        }
      } else if (isTeacherResponder) {
        let teacherNotifyResult;
        try {
          teacherNotifyResult = await maybeNotifyTeacherResponder({
            db,
            sessionId: lockResult.sessionId,
            responderId: lockResult.responderId,
            requesterData,
            pushSender: teacherResponderPushSender,
            tokenReader: teacherResponderTokenReader,
          });
        } catch (error) {
          console.error(
            "Failed to notify teacher responder",
            {
              sessionId: lockResult.sessionId,
              responderId: lockResult.responderId,
              error: readErrorMessage(error, "notify_failed"),
            },
          );
          teacherNotifyResult = {
            shouldNotify: false,
            reason: "notify_failed",
            error: readErrorMessage(error, "notify_failed"),
          };
        }

        if (shouldRetryTeacherMatchAfterNotifyResult(teacherNotifyResult)) {
          const releaseResult = await releaseTeacherResponderMatchForRetry({
            db,
            sessionId: lockResult.sessionId,
            responderId: lockResult.responderId,
            requesterId: userId,
            notificationId: teacherNotifyResult?.notificationId,
            pairAttemptId: lockResult.pairAttemptId,
            stopReason:
              teacherNotifyResult?.pushResult?.sent === false ?
                "teacher_push_failed" :
                normalizeString(teacherNotifyResult?.staleReason) ||
                  normalizeString(teacherNotifyResult?.reason) ||
                  "teacher_notification_failed",
          });
          if (releaseResult.released) {
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
          if (releaseResult.reason !== "accept_finalization_in_progress") {
            const currentMatchedResponse =
              await tryReadCurrentMatchedStartSearchResponse({
                db,
                userId,
                reused,
              });
            if (currentMatchedResponse) {
              return {
                matched: true,
                response: currentMatchedResponse,
                lockResult,
              };
            }
            retryExcludedResponderIds.add(normalizeString(candidate.userId));
            continue;
          }
        }
      }

      return {
        matched: true,
        response: buildMatchedStartSearchResponse({
          userId,
          requestData,
          matchResult: lockResult,
          reused,
        }),
        lockResult,
      };
    }

    if (String(lockResult.reason || "").startsWith("requester_")) {
      const currentMatchedResponse =
        await tryReadCurrentMatchedStartSearchResponse({
          db,
          userId,
          reused,
        });
      if (currentMatchedResponse) {
        return {
          matched: true,
          response: currentMatchedResponse,
          lockResult,
        };
      }
      break;
    }
  }

  return {
    matched: false,
    response: null,
  };
}

async function resumeRestoredStudentSearch({
  db,
  participantId,
  sessionId,
  pairAttemptId,
  options = {},
}) {
  const normalizedParticipantId = normalizeString(participantId);
  const normalizedSessionId = normalizeString(sessionId);
  const normalizedPairAttemptId = normalizeString(pairAttemptId);
  if (
    !normalizedParticipantId ||
    !normalizedSessionId ||
    !normalizedPairAttemptId
  ) {
    return {resumed: false, settled: false, reason: "resume_ids_missing"};
  }
  const [searchSnap, userSnap] = await Promise.all([
    db.collection(SEARCH_REQUEST_COLLECTION).doc(normalizedParticipantId).get(),
    db.collection("users").doc(normalizedParticipantId).get(),
  ]);
  if (!searchSnap.exists) {
    return {resumed: false, settled: true, reason: "search_missing"};
  }
  const requestData = searchSnap.data() || {};
  if (
    normalizeString(requestData.restoredFromSessionId) !==
      normalizedSessionId ||
    normalizeString(requestData.restoredFromPairAttemptId) !==
      normalizedPairAttemptId
  ) {
    return {resumed: false, settled: true, reason: "search_moved_on"};
  }
  if (
    requestData.status !== SEARCH_REQUEST_STATUS.ACTIVE ||
    hasSearchRequestSessionBinding(requestData)
  ) {
    return {resumed: false, settled: true, reason: "search_already_done"};
  }
  if (!userSnap.exists) {
    return {resumed: false, settled: false, reason: "user_missing"};
  }

  const trialAccessSnapshot = await db.collection("users")
      .doc(normalizedParticipantId)
      .collection("trialAccess")
      .doc("current")
      .get();
  const retryNotBeforeAt = timestampToMillis(
      trialAccessSnapshot.data()?.retryNotBeforeAt,
  );
  const waitMillis = retryNotBeforeAt == null ? 0 :
    Math.max(0, retryNotBeforeAt - Date.now());
  if (waitMillis > 0) {
    const wait = options.retryCooldownWait || ((millis) =>
      new Promise((resolve) => {
        setTimeout(resolve, millis);
      }));
    await wait(waitMillis);
    return resumeRestoredStudentSearch({
      db,
      participantId: normalizedParticipantId,
      sessionId: normalizedSessionId,
      pairAttemptId: normalizedPairAttemptId,
      options: {...options, retryCooldownWait: null},
    });
  }

  await tryCreateStudentPairForSearchRequest({
    db,
    userId: normalizedParticipantId,
    requesterData: userSnap.data() || {},
    requestData,
    reused: true,
    backgroundStudentResponderPushSender:
      options.participantPushSender || sendVoipPushToStudentResponder,
    teacherResponderPushSender:
      options.participantPushSender || sendVoipPushToStudentResponder,
    backgroundStudentResponderPrePushWait:
      options.studentPreDispatchWait ||
      waitForForegroundStudentResponderResolution,
  });
  return {resumed: true, settled: true, reason: "matching_restarted"};
}

async function reconcileReleasedProtocolV2Match({
  db,
  sessionId,
  pairAttemptId,
  options = {},
  cancelSurfaces = cancelProtocolV2NativeSurfaces,
  resumeSearch = resumeRestoredStudentSearch,
  ownerId,
  nowMillis,
}) {
  return reconcileProtocolV2TerminalSideEffects({
    db,
    sessionId,
    pairAttemptId,
    cancelSurfaces,
    resumeSearch: ({participantId}) => resumeSearch({
      db,
      participantId,
      sessionId,
      pairAttemptId,
      options,
    }),
    ownerId,
    nowMillis,
  });
}

module.exports = {
  tryReadCurrentMatchedStartSearchResponse,
  buildStudentPairSessionData,
  tryCreateStudentPairForSearchRequest,
  resumeRestoredStudentSearch,
  reconcileReleasedProtocolV2Match,
};
