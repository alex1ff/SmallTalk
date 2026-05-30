import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student dashboard delegates local controls to flat components', () {
    final source =
        File('lib/students_pages/students_dashboard/students_dashboard_widget.dart')
            .readAsStringSync();

    expect(source, contains("'/components/dashboard_floating_avatar.dart'"));
    expect(source, contains("'/components/dashboard_inline_filter_button.dart'"));
    expect(
      source,
      contains("'/components/student_availability_switch_control.dart'"),
    );
    expect(source, contains('StudentAvailabilitySwitchControl('));
    expect(source, contains('DashboardInlineFilterButton('));
    expect(source, contains('DashboardFloatingAvatar('));
    expect(source, isNot(contains('class _StudentAvailabilitySwitchControl')));
    expect(source, isNot(contains('class _DashboardInlineFilterButton')));
    expect(source, isNot(contains('class _DashboardFloatingAvatar')));
    expect(source, isNot(contains('size: 62.0')));
  });
}
