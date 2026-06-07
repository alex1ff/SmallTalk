import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile edit page delegates visual form pieces to flat components', () {
    final source =
        File('lib/shared_pages/profile_edit/profile_edit_widget.dart')
            .readAsStringSync();

    expect(source, contains("'/components/profile_avatar_picker.dart'"));
    expect(source, contains("'/components/profile_edit_fields.dart'"));
    expect(source, contains('ProfileAvatarPicker('));
    expect(source, contains('ProfileNameField('));
    expect(source, contains('ProfileReadOnlyField('));
    expect(source, contains('_nameSaveDebounce = Timer('));
    expect(source, contains('_saveNameIfNeeded('));
    expect(source, isNot(contains("'/components/profile_save_bar.dart'")));
    expect(source, isNot(contains('ProfileSaveBar(')));
    expect(source, isNot(contains('class _ProfileAvatar')));
    expect(source, isNot(contains('class _ProfileNameField')));
    expect(source, isNot(contains('class _ProfileReadOnlyField')));
    expect(source, isNot(contains('class _ProfileSaveBar')));
  });
}
