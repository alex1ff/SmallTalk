import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('my calls page delegates call row visuals to flat component', () {
    final pageSource = File('lib/shared_pages/my_calls/my_calls_widget.dart')
        .readAsStringSync();

    expect(pageSource, contains("'/components/call_history_card.dart'"));
    expect(pageSource, contains('CallHistoryCard('));
    expect(pageSource, isNot(contains('class _CallHistoryCard')));
    expect(pageSource, contains('AppLoadingIndicator()'));
  });

  test('my calls page queries sessions by participant membership', () {
    final pageSource = File('lib/shared_pages/my_calls/my_calls_widget.dart')
        .readAsStringSync();

    expect(pageSource, contains("'participantIds'"));
    expect(pageSource, contains('arrayContains: currentUserUid'));
    expect(
      pageSource,
      isNot(contains("final userField = _isTeacher ? 'tutorId' : 'studentId'")),
    );
  });

  test('call history card resolves counterpart independent of current role', () {
    final cardSource =
        File('lib/components/call_history_card.dart').readAsStringSync();

    expect(cardSource, contains('resolveSessionReviewParticipant('));
    expect(
      cardSource,
      isNot(
        contains(
          'isTeacher ? session.studentInfo.name : session.tutorInfo.name',
        ),
      ),
    );
  });

  test('my calls route uses a regular page route for iOS swipe back', () {
    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final shellRouteIndex = navSource.indexOf('ShellRoute(');
    final myCallsRouteNameIndex =
        navSource.indexOf('name: MyCallsWidget.routeName');

    expect(shellRouteIndex, greaterThan(0));
    expect(myCallsRouteNameIndex, greaterThan(0));
    expect(myCallsRouteNameIndex, lessThan(shellRouteIndex));

    final routeStart = navSource.lastIndexOf('FFRoute(', myCallsRouteNameIndex);
    final nextRouteStart = navSource.indexOf('FFRoute(', myCallsRouteNameIndex);
    final routeBlock = navSource.substring(routeStart, nextRouteStart);

    expect(routeBlock, isNot(contains('noTransition: true')));
  });
}
