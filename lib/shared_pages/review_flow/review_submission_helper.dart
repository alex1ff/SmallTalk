import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class PairReviewState {
  const PairReviewState({
    required this.hasReviewed,
    this.reviewRef,
  });

  final bool hasReviewed;
  final DocumentReference? reviewRef;
}

class LegacyReviewCandidate {
  const LegacyReviewCandidate({
    required this.reviewPath,
    required this.toUserPath,
    this.createdAt,
  });

  final String reviewPath;
  final String toUserPath;
  final DateTime? createdAt;
}

class PairReviewPathResolution {
  const PairReviewPathResolution({
    required this.canonicalPath,
    this.resolvedPath,
  });

  final String canonicalPath;
  final String? resolvedPath;

  bool get hasReviewed => resolvedPath != null;
}

class ReviewSubmissionResult {
  const ReviewSubmissionResult({
    required this.status,
    this.reviewId,
    this.reviewRef,
  });

  final String status;
  final String? reviewId;
  final DocumentReference? reviewRef;
}

class SessionReviewParticipantResolution {
  const SessionReviewParticipantResolution({
    required this.currentUserId,
    required this.participantIds,
    required this.isParticipant,
    this.requesterId,
    this.responderId,
    this.counterpartUserId,
  });

  final String currentUserId;
  final List<String> participantIds;
  final bool isParticipant;
  final String? requesterId;
  final String? responderId;
  final String? counterpartUserId;

  bool get isRequester => requesterId != null && requesterId == currentUserId;
  bool get isResponder => responderId != null && responderId == currentUserId;
  bool get hasCounterpart => counterpartUserId != null;
}

String _normalizeSessionParticipantId(dynamic rawValue) {
  if (rawValue is! String) {
    return '';
  }

  return rawValue.trim();
}

Map<String, dynamic> _sessionMatchContext(Map<String, dynamic> sessionData) {
  final rawMatchContext = sessionData['matchContext'];
  if (rawMatchContext is Map) {
    return rawMatchContext.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  return const <String, dynamic>{};
}

String? resolveSessionRequesterId(Map<String, dynamic> sessionData) {
  final matchContext = _sessionMatchContext(sessionData);
  for (final candidate in [
    sessionData['requesterId'],
    matchContext['requesterId'],
    sessionData['studentId'],
  ]) {
    final requesterId = _normalizeSessionParticipantId(candidate);
    if (requesterId.isNotEmpty) {
      return requesterId;
    }
  }
  return null;
}

String? resolveSessionResponderId(Map<String, dynamic> sessionData) {
  final matchContext = _sessionMatchContext(sessionData);
  for (final candidate in [
    sessionData['responderId'],
    matchContext['acceptedResponderId'],
    sessionData['currentResponderId'],
    matchContext['responderId'],
    matchContext['currentResponderId'],
    sessionData['tutorId'],
    sessionData['currentTutorId'],
  ]) {
    final responderId = _normalizeSessionParticipantId(candidate);
    if (responderId.isNotEmpty) {
      return responderId;
    }
  }
  return null;
}

List<String> resolveSessionParticipantIds(Map<String, dynamic> sessionData) {
  final participantIds = <String>[];

  void addParticipant(dynamic rawValue) {
    final normalizedValue = _normalizeSessionParticipantId(rawValue);
    if (normalizedValue.isEmpty || participantIds.contains(normalizedValue)) {
      return;
    }
    participantIds.add(normalizedValue);
  }

  final rawParticipantIds = sessionData['participantIds'];
  if (rawParticipantIds is Iterable) {
    for (final participantId in rawParticipantIds) {
      addParticipant(participantId);
    }
  }

  if (participantIds.length >= 2) {
    return participantIds;
  }

  addParticipant(resolveSessionRequesterId(sessionData));
  addParticipant(resolveSessionResponderId(sessionData));

  return participantIds;
}

SessionReviewParticipantResolution resolveSessionReviewParticipant({
  required Map<String, dynamic> sessionData,
  required String currentUserId,
}) {
  final normalizedCurrentUserId = currentUserId.trim();
  final participantIds = resolveSessionParticipantIds(sessionData);
  final requesterId = resolveSessionRequesterId(sessionData);
  final responderId = resolveSessionResponderId(sessionData);

  if (normalizedCurrentUserId.isEmpty ||
      !participantIds.contains(normalizedCurrentUserId)) {
    return SessionReviewParticipantResolution(
      currentUserId: normalizedCurrentUserId,
      participantIds: participantIds,
      isParticipant: false,
      requesterId: requesterId,
      responderId: responderId,
    );
  }

  String? counterpartUserId;
  if (participantIds.length == 2) {
    counterpartUserId = participantIds.firstWhere(
      (participantId) => participantId != normalizedCurrentUserId,
      orElse: () => '',
    );
    if (counterpartUserId.isEmpty) {
      counterpartUserId = null;
    }
  }

  return SessionReviewParticipantResolution(
    currentUserId: normalizedCurrentUserId,
    participantIds: participantIds,
    isParticipant: true,
    requesterId: requesterId,
    responderId: responderId,
    counterpartUserId: counterpartUserId,
  );
}

String _encodePairReviewComponent(String userId) {
  return Uri.encodeComponent(userId.trim()).replaceAll('_', '%5F');
}

String buildCanonicalPairReviewId({
  required String fromUserId,
  required String toUserId,
}) {
  final normalizedFromUserId = fromUserId.trim();
  final normalizedToUserId = toUserId.trim();
  if (normalizedFromUserId.isEmpty || normalizedToUserId.isEmpty) {
    return '';
  }

  return '${_encodePairReviewComponent(normalizedFromUserId)}__${_encodePairReviewComponent(normalizedToUserId)}';
}

String buildCanonicalPairReviewPath({
  required String fromUserId,
  required String toUserId,
}) {
  final reviewId = buildCanonicalPairReviewId(
    fromUserId: fromUserId,
    toUserId: toUserId,
  );
  return reviewId.isEmpty ? '' : 'reviews/$reviewId';
}

int compareLegacyReviewCandidates(
  LegacyReviewCandidate left,
  LegacyReviewCandidate right,
) {
  final leftCreatedAt =
      left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final rightCreatedAt =
      right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final byCreatedAt = rightCreatedAt.compareTo(leftCreatedAt);
  if (byCreatedAt != 0) {
    return byCreatedAt;
  }

  return right.reviewPath.compareTo(left.reviewPath);
}

LegacyReviewCandidate? selectLatestLegacyReviewCandidate(
  Iterable<LegacyReviewCandidate> candidates, {
  required String targetUserPath,
}) {
  final normalizedTargetUserPath = targetUserPath.trim();
  LegacyReviewCandidate? latestCandidate;

  for (final candidate in candidates) {
    if (candidate.toUserPath.trim() != normalizedTargetUserPath) {
      continue;
    }

    if (latestCandidate == null ||
        compareLegacyReviewCandidates(candidate, latestCandidate) < 0) {
      latestCandidate = candidate;
    }
  }

  return latestCandidate;
}

PairReviewPathResolution resolvePairReviewPaths({
  required String fromUserId,
  required String toUserId,
  required bool canonicalExists,
  Iterable<LegacyReviewCandidate> legacyCandidates = const [],
}) {
  final canonicalPath = buildCanonicalPairReviewPath(
    fromUserId: fromUserId,
    toUserId: toUserId,
  );
  if (canonicalPath.isEmpty) {
    return const PairReviewPathResolution(canonicalPath: '');
  }

  if (canonicalExists) {
    return PairReviewPathResolution(
      canonicalPath: canonicalPath,
      resolvedPath: canonicalPath,
    );
  }

  final latestLegacyCandidate = selectLatestLegacyReviewCandidate(
    legacyCandidates,
    targetUserPath: 'users/${toUserId.trim()}',
  );

  return PairReviewPathResolution(
    canonicalPath: canonicalPath,
    resolvedPath: latestLegacyCandidate?.reviewPath,
  );
}

Future<PairReviewState> resolveCurrentUserPairReview({
  required DocumentReference currentUserRef,
  required DocumentReference targetUserRef,
}) async {
  final fromUserId = currentUserRef.id.trim();
  final toUserId = targetUserRef.id.trim();
  final canonicalReviewId = buildCanonicalPairReviewId(
    fromUserId: fromUserId,
    toUserId: toUserId,
  );
  if (canonicalReviewId.isEmpty) {
    return const PairReviewState(hasReviewed: false);
  }

  final canonicalReviewRef = ReviewsRecord.collection.doc(canonicalReviewId);
  final canonicalReviewDoc = await canonicalReviewRef.get();
  if (canonicalReviewDoc.exists && canonicalReviewDoc.data() != null) {
    return PairReviewState(
      hasReviewed: true,
      reviewRef: canonicalReviewRef,
    );
  }

  // Legacy fallback is kept only for the migration window while older
  // session-scoped reviews are still present in the collection.
  final authoredReviews = await queryReviewsRecordOnce(
    queryBuilder: (reviewsRecord) => reviewsRecord.where(
      'fromUserId',
      isEqualTo: currentUserRef,
    ),
  );
  final resolution = resolvePairReviewPaths(
    fromUserId: fromUserId,
    toUserId: toUserId,
    canonicalExists: false,
    legacyCandidates: authoredReviews
        .map(
          (review) => LegacyReviewCandidate(
            reviewPath: review.reference.path,
            toUserPath: review.toUserId?.path ?? '',
            createdAt: review.createdAt,
          ),
        )
        .toList(),
  );
  final resolvedPath = resolution.resolvedPath;

  return PairReviewState(
    hasReviewed: resolvedPath != null,
    reviewRef: resolvedPath != null && resolvedPath.isNotEmpty
        ? FirebaseFirestore.instance.doc(resolvedPath)
        : null,
  );
}

Map<String, dynamic> buildSessionReviewUpdate({
  required bool isTeacher,
  DocumentReference? reviewRef,
  bool? reviewedAsRequester,
}) {
  final markRequesterReviewed = reviewedAsRequester ?? !isTeacher;
  return <String, dynamic>{
    if (markRequesterReviewed) 'studentHasReviewed': true,
    if (!markRequesterReviewed) 'tutorHasReviewed': true,
    if (markRequesterReviewed && reviewRef != null)
      'studentReviewRef': reviewRef,
    if (!markRequesterReviewed && reviewRef != null)
      'tutorReviewRef': reviewRef,
  };
}

Future<void> syncSessionReviewState({
  required DocumentReference sessionRef,
  required bool isTeacher,
  DocumentReference? reviewRef,
  String? currentUserId,
}) async {
  bool? reviewedAsRequester;

  final normalizedCurrentUserId = (currentUserId ?? '').trim();
  if (normalizedCurrentUserId.isNotEmpty) {
    try {
      final sessionSnap = await sessionRef.get();
      final rawSessionData = sessionSnap.data();
      if (rawSessionData is Map) {
        final sessionData = rawSessionData.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final participantResolution = resolveSessionReviewParticipant(
          sessionData: sessionData,
          currentUserId: normalizedCurrentUserId,
        );
        if (participantResolution.isRequester) {
          reviewedAsRequester = true;
        } else if (participantResolution.isResponder) {
          reviewedAsRequester = false;
        }
      }
    } catch (error) {
      debugPrint(
          'Failed to resolve review side for ${sessionRef.path}: $error');
    }
  }

  try {
    await sessionRef.set(
      buildSessionReviewUpdate(
        isTeacher: isTeacher,
        reviewRef: reviewRef,
        reviewedAsRequester: reviewedAsRequester,
      ),
      SetOptions(merge: true),
    );
  } catch (error) {
    debugPrint('Failed to sync review state for ${sessionRef.path}: $error');
  }
}

String reviewCommentHintText(BuildContext context, int rating) {
  if (rating <= 3 && rating > 0) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Расскажтите, что пошло не так',
      enText: 'Tell us what went wrong',
    );
  }
  if (rating == 4) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Расскажтите, что могло бы быть лучше',
      enText: 'Tell us what could be better',
    );
  }
  if (rating == 5) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Расскажтите, что понравилось',
      enText: 'Tell us what you liked',
    );
  }

  return FFLocalizations.of(context).getVariableText(
    ruText: 'Отзыв на собеседника',
    enText: 'Feedback about your partner',
  );
}

String reviewErrorMessage(
  BuildContext context,
  FirebaseFunctionsException error,
) {
  switch (error.code) {
    case 'not-found':
      return FFLocalizations.of(context).getVariableText(
        ruText:
            'Не удалось найти сессию для отзыва. Попробуйте еще раз через несколько секунд.',
        enText:
            'We could not find the session for this review. Please try again in a few seconds.',
      );
    case 'permission-denied':
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Не удалось отправить отзыв для этого звонка.',
        enText: 'Unable to submit a review for this call.',
      );
    default:
      return error.message ??
          FFLocalizations.of(context).getVariableText(
            ruText: 'Не удалось отправить отзыв. Попробуйте снова.',
            enText: 'Failed to submit review. Please try again.',
          );
  }
}

String unexpectedReviewErrorMessage(BuildContext context) {
  return FFLocalizations.of(context).getVariableText(
    ruText: 'Не удалось отправить отзыв. Попробуйте снова.',
    enText: 'Failed to submit review. Please try again.',
  );
}

String reviewAlreadyLeftMessage(BuildContext context) {
  return FFLocalizations.of(context).getVariableText(
    ruText: 'Отзыв на собеседника уже оставлен.',
    enText: 'A review for this partner has already been submitted.',
  );
}

Future<ReviewSubmissionResult> submitSessionReview({
  required DocumentReference sessionRef,
  required DocumentReference toUserRef,
  required int rating,
  required bool isTeacher,
  String? comment,
}) async {
  final payload = <String, dynamic>{
    'sessionId': sessionRef.id,
    'sessionPath': sessionRef.path,
    'toUserId': toUserRef.id,
    'rating': rating,
  };
  final reviewComment = (comment ?? '').trim();
  if (reviewComment.isNotEmpty) {
    payload['comment'] = reviewComment;
  }

  final response = await FirebaseFunctions.instance
      .httpsCallable('submitReview')
      .call(payload);

  final data = response.data is Map
      ? (response.data as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        )
      : const <String, dynamic>{};

  final reviewPath = (data['reviewPath'] as String?)?.trim();
  final reviewId = (data['reviewId'] as String?)?.trim();
  final reviewRef = reviewPath != null && reviewPath.isNotEmpty
      ? FirebaseFirestore.instance.doc(reviewPath)
      : (reviewId != null && reviewId.isNotEmpty
          ? ReviewsRecord.collection.doc(reviewId)
          : null);

  await syncSessionReviewState(
    sessionRef: sessionRef,
    isTeacher: isTeacher,
    reviewRef: reviewRef,
    currentUserId: currentUserUid,
  );

  return ReviewSubmissionResult(
    status: (data['reviewStatus'] as String?) ?? 'ok',
    reviewId: reviewId,
    reviewRef: reviewRef,
  );
}
