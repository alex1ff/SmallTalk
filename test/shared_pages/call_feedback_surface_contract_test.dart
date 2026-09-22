import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/shared_pages/call_details/call_details_widget.dart',
  ).readAsStringSync();

  test('call details gates AI feedback and places it above subtitles', () {
    final eligibilityIndex =
        source.indexOf('if (isCallFeedbackEligibleSession(session))');
    final feedbackIndex = source.indexOf('CallFeedbackCard(', eligibilityIndex);
    final captionsIndex = source.indexOf(
      '_buildCaptionLogsSection(context, session)',
      feedbackIndex,
    );

    expect(eligibilityIndex, greaterThanOrEqualTo(0));
    expect(feedbackIndex, greaterThan(eligibilityIndex));
    expect(captionsIndex, greaterThan(feedbackIndex));
  });

  test('subtitle toggle uses one clipped rounded material without a shadow',
      () {
    final start = source.indexOf('Widget _buildCaptionLogsToggleButton(');
    final end = source.indexOf(
      'Widget _buildCaptionLogsItemsColumn(',
      start,
    );
    final method = source.substring(start, end);

    expect(method, contains('color: ExpatlioDesign.card'));
    expect(method, contains('clipBehavior: Clip.antiAlias'));
    expect(
        method, contains('constraints: const BoxConstraints(minHeight: 44.0)'));
    expect(method, isNot(contains('BoxShadow(')));
    expect(method, isNot(contains('child: Ink(')));
  });
}
