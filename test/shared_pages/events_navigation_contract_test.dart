import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';

void main() {
  test('event list route exposes the canonical shell tab route', () {
    expect(EventListWidget.routeName, 'events');
    expect(EventListWidget.routePath, '/events');
  });

  test('bottom navigation exposes events between home and existing tabs', () {
    final navBar =
        File('lib/components/nav_bar_widget.dart').readAsStringSync();
    final tabShell = File('lib/shared_pages/tab_shell/tab_shell_page.dart')
        .readAsStringSync();
    final router = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final index = File('lib/index.dart').readAsStringSync();

    expect(navBar, contains("ruText: 'События'"));
    expect(navBar, contains("enText: 'Events'"));
    expect(navBar, contains('FFIcons.kcalendar'));
    expect(
      navBar,
      contains(
        RegExp(
          r'void _handleTeacherTap[\s\S]*case 1:[\s\S]*EventListWidget\.routeName[\s\S]*case 2:[\s\S]*FavoriteWidget\.routeName[\s\S]*case 3:[\s\S]*ProfileWidget\.routeName',
        ),
      ),
    );
    expect(
      navBar,
      contains(
        RegExp(
          r'void _handleStudentTap[\s\S]*case 1:[\s\S]*EventListWidget\.routeName[\s\S]*case 2:[\s\S]*WordsWidget\.routeName[\s\S]*case 3:[\s\S]*FavoriteWidget\.routeName[\s\S]*case 4:[\s\S]*ProfileWidget\.routeName',
        ),
      ),
    );

    expect(
      tabShell,
      contains(
        RegExp(
          r'DashboardNSWidget\.routePath,[\s\S]*EventListWidget\.routePath,[\s\S]*FavoriteWidget\.routePath,[\s\S]*ProfileWidget\.routePath',
        ),
      ),
    );
    expect(
      tabShell,
      contains(
        RegExp(
          r'StudentsDashboardWidget\.routePath,[\s\S]*EventListWidget\.routePath,[\s\S]*WordsWidget\.routePath,[\s\S]*FavoriteWidget\.routePath,[\s\S]*ProfileWidget\.routePath',
        ),
      ),
    );
    expect(
      router,
      contains(
        RegExp(
          r'ShellRoute\([\s\S]*name: EventListWidget\.routeName,[\s\S]*path: EventListWidget\.routePath,[\s\S]*requireAuth: true,[\s\S]*noTransition: true',
        ),
      ),
    );
    expect(index,
        contains("export '/shared_pages/events/event_list_widget.dart'"));
  });
}
