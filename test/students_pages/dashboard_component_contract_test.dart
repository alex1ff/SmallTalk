import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student dashboard delegates local controls to flat components', () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
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
    expect(source, isNot(contains('_buildAvailabilitySwitch')));
    expect(source, isNot(contains('_handleAvailabilitySwitchChanged')));
    expect(source, contains('DashboardInlineFilterButton('));
    expect(source, contains('OrbitingAvatarsCta('));
    expect(source, isNot(contains('AvailabilityScheduleCard(')));
    expect(source, isNot(contains('AddInterWidget()')));
    expect(source, isNot(contains('_buildAvailabilitySection')));
    expect(source, isNot(contains('_buildAnimatedAvailabilitySection')));
    expect(source, contains('_studentUserUpdate'));
    expect(source, contains("'availabilityToday': FieldValue.delete()"));
    expect(source, isNot(contains('createAvailabilityTodayStruct')));
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

  test('student dashboard start search accepts subscription or gift minutes',
      () {
    final source = File(
            'lib/students_pages/students_dashboard/students_dashboard_widget.dart')
        .readAsStringSync();

    expect(
      RegExp(r'canStartCall\(\s*currentUserDocument\s*\)').allMatches(source),
      hasLength(2),
    );
    expect(
      source,
      isNot(contains('hasActiveSubscription(currentUserDocument)')),
    );
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
