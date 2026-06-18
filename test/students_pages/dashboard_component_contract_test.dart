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
    expect(source, isNot(contains('StudentAvailabilitySwitchControl(')));
    expect(source, isNot(contains('_buildAvailabilitySwitch')));
    expect(source, isNot(contains('_handleAvailabilitySwitchChanged')));
    expect(source, contains('DashboardInlineFilterButton('));
    expect(source, contains('OrbitingAvatarsCta('));
    expect(source, isNot(contains('AvailabilityScheduleCard(')));
    expect(source, isNot(contains('AddInterWidget()')));
    expect(source, isNot(contains('_buildAvailabilitySection')));
    expect(source, isNot(contains('_buildAnimatedAvailabilitySection')));
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

  test('student dashboard filters use design control radius', () {
    final source = File('lib/components/dashboard_inline_filter_button.dart')
        .readAsStringSync();

    expect(source, contains('ExpatlioDesign.controlRadius'));
    expect(source, isNot(contains('ExpatlioDesign.radiusCapsule')));
  });
}
