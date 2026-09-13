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
    expect(source, contains('_profileUserUpdate'));
    expect(source, contains("'availabilityToday': FieldValue.delete()"));
    expect(source, isNot(contains('AvailabilityScheduleCard(')));
    expect(source, isNot(contains('AvailabilitySwitchControl(')));
    expect(source, isNot(contains('StudentAvailabilitySwitchControl(')));
    expect(source, isNot(contains("'/components/add_inter_widget.dart'")));
    expect(source, isNot(contains('AddInterWidget(')));
    expect(source, isNot(contains('AddInterWidget()')));
    expect(source, isNot(contains('createAvailabilityTodayStruct')));
    expect(source, isNot(contains('getIntervalsFirestoreData')));
    expect(source, isNot(contains('updateIntervalsStruct')));
    expect(source, isNot(contains('FieldValue.arrayRemove')));
    expect(source, isNot(contains('Доступен сегодня')));
    expect(source, isNot(contains("'/components/profile_save_bar.dart'")));
    expect(source, isNot(contains('ProfileSaveBar(')));
    expect(source, isNot(contains('class _ProfileAvatar')));
    expect(source, isNot(contains('class _ProfileNameField')));
    expect(source, isNot(contains('class _ProfileReadOnlyField')));
    expect(source, isNot(contains('class _ProfileSaveBar')));
  });
}
