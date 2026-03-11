import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class SessionReviewState {
  const SessionReviewState({
    required this.hasReviewed,
    this.reviewRef,
  });

  final bool hasReviewed;
  final DocumentReference? reviewRef;
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

SessionReviewState currentUserReviewState(
  VideoSessionsRecord session, {
  required bool isTeacher,
}) {
  return SessionReviewState(
    hasReviewed:
        isTeacher ? session.tutorHasReviewed : session.studentHasReviewed,
    reviewRef: isTeacher ? session.tutorReviewRef : session.studentReviewRef,
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
