import '/backend/backend.dart';

/// A one-shot reviews query together with the Firestore metadata needed to
/// decide whether it may replace previously confirmed UI data.
final class ReviewsLoadResult {
  const ReviewsLoadResult({
    required this.reviews,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  factory ReviewsLoadResult.authoritative(List<ReviewsRecord> reviews) =>
      ReviewsLoadResult(
        reviews: reviews,
        isFromCache: false,
        hasPendingWrites: false,
      );

  final List<ReviewsRecord> reviews;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get isAuthoritative => !isFromCache && !hasPendingWrites;
}

List<ReviewsRecord> mergeUnconfirmedReviews({
  required List<ReviewsRecord> previous,
  required List<ReviewsRecord> incoming,
}) {
  final merged = <ReviewsRecord>[];
  final seenPaths = <String>{};

  for (final review in incoming) {
    if (seenPaths.add(review.reference.path)) {
      merged.add(review);
    }
  }
  for (final review in previous) {
    if (seenPaths.add(review.reference.path)) {
      merged.add(review);
    }
  }

  return List<ReviewsRecord>.unmodifiable(merged);
}
