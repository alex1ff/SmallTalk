import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
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
}) {
  return <String, dynamic>{
    if (isTeacher) 'tutorHasReviewed': true,
    if (!isTeacher) 'studentHasReviewed': true,
    if (isTeacher && reviewRef != null) 'tutorReviewRef': reviewRef,
    if (!isTeacher && reviewRef != null) 'studentReviewRef': reviewRef,
  };
}

Future<void> syncSessionReviewState({
  required DocumentReference sessionRef,
  required bool isTeacher,
  DocumentReference? reviewRef,
}) async {
  try {
    await sessionRef.set(
      buildSessionReviewUpdate(
        isTeacher: isTeacher,
        reviewRef: reviewRef,
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
  );

  return ReviewSubmissionResult(
    status: (data['reviewStatus'] as String?) ?? 'ok',
    reviewId: reviewId,
    reviewRef: reviewRef,
  );
}

class PairReviewContent extends StatelessWidget {
  const PairReviewContent({
    super.key,
    required this.hasReviewed,
    required this.formContent,
    this.reviewContent,
    this.reviewNoteText,
    this.reviewFallbackText,
  });

  final bool hasReviewed;
  final Widget formContent;
  final Widget? reviewContent;
  final String? reviewNoteText;
  final String? reviewFallbackText;

  @override
  Widget build(BuildContext context) {
    if (!hasReviewed) {
      return formContent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reviewNoteText != null && reviewNoteText!.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: BorderRadius.circular(26.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                reviewNoteText!,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
        ],
        reviewContent ??
            _PairReviewFallbackCard(
              message: reviewFallbackText ?? reviewAlreadyLeftMessage(context),
            ),
      ],
    );
  }
}

class _PairReviewFallbackCard extends StatelessWidget {
  const _PairReviewFallbackCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                fontSize: 15.0,
                letterSpacing: 0.0,
              ),
        ),
      ),
    );
  }
}
