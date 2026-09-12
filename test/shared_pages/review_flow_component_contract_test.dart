import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review submission helper does not keep local UI fallback widgets', () {
    final helperSource =
        File('lib/shared_pages/review_flow/review_submission_helper.dart')
            .readAsStringSync();
    final componentSource =
        File('lib/components/pair_review_content.dart').readAsStringSync();

    expect(helperSource, isNot(contains('class PairReviewContent')));
    expect(helperSource, isNot(contains('class _PairReviewFallbackCard')));
    expect(componentSource, contains('class PairReviewContent'));
    expect(componentSource, contains('class _PairReviewInfoCard'));
  });
}
