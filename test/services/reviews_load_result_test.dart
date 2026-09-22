import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/reviews_load_result.dart';

ReviewsRecord _review(String id) => ReviewsRecord.getDocumentFromData(
      <String, dynamic>{'comment': id},
      ReviewsRecord.collection.doc(id),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('only confirmed server snapshots are authoritative', () {
    expect(
      const ReviewsLoadResult(
        reviews: <ReviewsRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      ).isAuthoritative,
      isTrue,
    );
    expect(
      const ReviewsLoadResult(
        reviews: <ReviewsRecord>[],
        isFromCache: true,
        hasPendingWrites: false,
      ).isAuthoritative,
      isFalse,
    );
    expect(
      const ReviewsLoadResult(
        reviews: <ReviewsRecord>[],
        isFromCache: false,
        hasPendingWrites: true,
      ).isAuthoritative,
      isFalse,
    );
  });

  test('unconfirmed rows augment but never delete the previous baseline', () {
    final previousA = _review('a');
    final previousB = _review('b');
    final incomingA = _review('a');
    final incomingC = _review('c');

    final merged = mergeUnconfirmedReviews(
      previous: <ReviewsRecord>[previousA, previousB],
      incoming: <ReviewsRecord>[incomingC, incomingA],
    );

    expect(
      merged.map((review) => review.reference.id),
      <String>['c', 'a', 'b'],
    );
    expect(merged[1], same(incomingA));
  });
}
