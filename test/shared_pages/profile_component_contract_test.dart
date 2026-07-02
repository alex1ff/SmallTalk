import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile page delegates menu visuals to flat components', () {
    final source =
        File('lib/shared_pages/profile/profile_widget.dart').readAsStringSync();

    expect(source, contains("'/components/profile_dropdown_menu_item.dart'"));
    expect(source, contains("'/components/support_contact_menu.dart'"));
    expect(source, contains('ProfileDropdownMenuItem('));
    expect(source, contains('SupportContactMenu('));
    expect(source, contains("ruText: 'Мои события'"));
    expect(source, contains('EventHistoryWidget.routeName'));
    expect(source, isNot(contains('class _ProfileDropdownMenuItem')));
    expect(source, isNot(contains('class _SupportContactMenu')));
    expect(source, isNot(contains('class _SupportContactCard')));
  });
}
