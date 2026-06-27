import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> _nonDeleteAvailabilityWrites(String source) {
  final writes = <String>[];
  writes.addAll(
    RegExp(r"""['"]availabilityToday['"]\s*:\s*(?!\s*FieldValue\.delete\(\))[^,\n]+""")
        .allMatches(source)
        .map((match) => match.group(0)!),
  );
  writes.addAll(
    RegExp(r"""\[\s*['"]availabilityToday['"]\s*\]\s*=\s*(?!\s*FieldValue\.delete\(\))[^;\n]+""")
        .allMatches(source)
        .map((match) => match.group(0)!),
  );
  return writes;
}

void main() {
  test('student dashboard delegates local controls to flat components', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();
    final modelSource = File(
            'lib/students_pages/students_dashboard/students_dashboard_model.dart')
        .readAsStringSync();

    expect(
        source, contains("'/components/dashboard_inline_filter_button.dart'"));
    expect(source, contains("'/components/orbiting_avatars_cta.dart'"));
    expect(
      source,
      isNot(contains("'/components/student_availability_switch_control.dart'")),
    );
    expect(
      File('lib/components/student_availability_switch_control.dart')
          .existsSync(),
      isFalse,
    );
    expect(source, isNot(contains('StudentAvailabilitySwitchControl(')));
    expect(source, isNot(contains('AvailabilitySwitchControl(')));
    expect(source, isNot(contains('_buildAvailabilitySwitch')));
    expect(source, isNot(contains('_handleAvailabilitySwitchChanged')));
    expect(source, contains('DashboardInlineFilterButton('));
    expect(source, contains('OrbitingAvatarsCta('));
    expect(source, isNot(contains('AvailabilityScheduleCard(')));
    expect(source, isNot(contains('Доступен сегодня')));
    expect(source, isNot(contains("'/components/add_inter_widget.dart'")));
    expect(source, isNot(contains('AddInterWidget(')));
    expect(source, isNot(contains('_buildAvailabilitySection')));
    expect(source, isNot(contains('_buildAnimatedAvailabilitySection')));
    expect(source, contains('_studentUserUpdate'));
    expect(source, contains("'availabilityToday': FieldValue.delete()"));
    expect(_nonDeleteAvailabilityWrites(source), isEmpty);
    expect(source, isNot(contains('createAvailabilityTodayStruct')));
    expect(source, isNot(contains('getIntervalsFirestoreData')));
    expect(source, isNot(contains('updateIntervalsStruct')));
    expect(source, isNot(contains('FieldValue.arrayRemove')));
    expect(modelSource, isNot(contains('switchValue')));
    expect(modelSource, isNot(contains('availabilityToday')));
    expect(modelSource, isNot(contains('AvailabilityTodayStruct')));
    expect(source, isNot(contains('class _StudentAvailabilitySwitchControl')));
    expect(source, isNot(contains('class _DashboardInlineFilterButton')));
    expect(source, isNot(contains('class _OrbitingAvatarsCta')));
    expect(source, isNot(contains('size: 62.0')));
  });

  test('student dashboard hides unavailable and empty partner count', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();

    expect(source, contains('count == null || count <= 0'));
    expect(source, isNot(contains('количество людей недоступно')));
    expect(source, isNot(contains('people count unavailable')));
  });

  test('student dashboard start search access checks stay ordered', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();

    expect(source, contains('Future<bool> _ensureStartSearchAccess'));
    expect(source, contains('currentUser?.loggedIn != true'));
    expect(source, contains('hasCurrentUserDocumentForUid(currentUserUid)'));
    expect(source, contains('canStartCall(user)'));
    expect(source, contains('if (user.isInCall)'));
    expect(source, contains('hasActiveCallSession'));
    expect(source, contains('_hasActiveCallSessionForAccess'));
    expect(source, contains('VideoSessionsRecord.getDocumentOnce'));
    expect(source, contains('usageLimitReachedChecker'));
    expect(source, contains('_hasKnownUsageLimitReached(user)'));
    expect(source, contains("collection('usage')"));
    expect(source, contains("'dayDurationSeconds'"));
    expect(source, contains("'weekDurationSeconds'"));
    expect(source, contains('ensureCameraAndMicrophonePermissions()'));
    expect(
      source,
      isNot(contains('hasActiveSubscription(currentUserDocument)')),
    );
  });

  test('student usage limit self-read is allowed by Firestore rules', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();

    expect(rules, contains('match /users/{userId}/usage/{usageId}'));
    expect(rules, contains('allow read: if isAdmin() || isSelf(userId);'));
    expect(rules, contains('allow create, update, delete: if isAdmin();'));
  });

  test('active start search CTA does not navigate to legacy waiting flow', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();
    final handlerStart =
        source.indexOf('Future<void> _handleStartConversation');
    final activeCtaEnd = source.indexOf('Widget _buildSearchCtaContent');

    expect(handlerStart, isNot(-1));
    expect(activeCtaEnd, greaterThan(handlerStart));
    expect(
      source.substring(handlerStart, activeCtaEnd),
      isNot(contains('WaitingForTeacherPageWidget.routeName')),
    );
  });

  test('manual stop search CTA calls backend stop without blocking UI', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();
    final handlerStart =
        source.indexOf('Future<void> _handleStartConversation');
    final activeCtaEnd = source.indexOf('Widget _buildSearchCtaContent');
    final handlerSource = source.substring(handlerStart, activeCtaEnd);

    expect(source, contains("httpsCallable('stopSearch')"));
    expect(source, contains('Future<void> _stopActiveSearchRequest'));
    expect(source, contains('bool _isStopSearchResponseSuccess'));
    expect(source, isNot(contains("reason == 'session_mismatch'")));
    expect(source, isNot(contains("reason == 'request_mismatch'")));
    expect(source, contains('debugStopSearchRequest'));
    expect(source, contains('_ignoreStopSearchUntilNextFrame'));
    expect(handlerSource, contains('unawaited('));
    expect(handlerSource, contains('_stopActiveSearchRequest('));
    expect(handlerSource, contains('_isStopSearchState(visibleSearchState)'));
    expect(handlerSource, contains('StudentDashboardSearchState.idle'));
  });

  test('active search sends backend heartbeat every thirty seconds', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();

    expect(source, contains("httpsCallable('startSearch')"));
    expect(source, contains("httpsCallable('heartbeatSearch')"));
    expect(source, contains('Duration(seconds: 30)'));
    expect(source, contains('Timer.periodic('));
    expect(source, contains('_activeSearchRequestId'));
    expect(source, contains("'requestId': requestId"));
  });

  test('student dashboard maps active video session status to search UI', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();

    expect(source, contains('currentSessionId'));
    expect(source, contains('VideoSessionsRecord.getDocument'));
    expect(source, contains("'pending_confirmation'"));
    expect(source, contains("'connecting'"));
    expect(source, contains("'no_tutors_available'"));
    expect(source, contains('StudentDashboardSearchState.noMatchFound'));
    expect(source, contains('StudentDashboardSearchState.error'));
    expect(source, contains('StudentDashboardSearchErrorReason'));
    expect(source, contains('Duration(minutes: 10)'));
    expect(
      source,
      contains('StudentDashboardSearchState.connecting'),
    );
  });

  test('student dashboard filters use design control radius', () {
    final source = File('lib/components/dashboard_inline_filter_button.dart')
        .readAsStringSync();

    expect(source, contains('ExpatlioDesign.controlRadius'));
    expect(source, isNot(contains('ExpatlioDesign.radiusCapsule')));
  });
}
