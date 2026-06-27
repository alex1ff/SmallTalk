import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

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

List<String> _studentRoleCreateUserBlocks(String source) {
  final blocks = <String>[];
  var searchFrom = 0;
  while (true) {
    final start = source.indexOf('createUsersRecordData(', searchFrom);
    if (start == -1) {
      return blocks;
    }

    var depth = 0;
    var end = -1;
    for (var index = start; index < source.length; index += 1) {
      final char = source[index];
      if (char == '(') {
        depth += 1;
      } else if (char == ')') {
        depth -= 1;
        if (depth == 0) {
          end = index + 1;
          break;
        }
      }
    }

    if (end == -1) {
      return blocks;
    }
    final block = source.substring(start, end);
    if (block.contains('role: UserRole.student')) {
      blocks.add(block);
    }
    searchFrom = end;
  }
}

void main() {
  test('shared student surfaces do not render availability controls', () {
    final profile = _source('lib/shared_pages/profile/profile_widget.dart');
    final profileEdit =
        _source('lib/shared_pages/profile_edit/profile_edit_widget.dart');

    for (final source in [profile, profileEdit]) {
      expect(source, isNot(contains('AvailabilityScheduleCard(')));
      expect(source, isNot(contains('AvailabilitySwitchControl(')));
      expect(source, isNot(contains('StudentAvailabilitySwitchControl(')));
      expect(source, isNot(contains("'/components/add_inter_widget.dart'")));
      expect(source, isNot(contains('AddInterWidget(')));
      expect(source, isNot(contains('Доступен сегодня')));
    }
  });

  test('shared student surfaces only delete legacy availability data', () {
    final profile = _source('lib/shared_pages/profile/profile_widget.dart');
    final profileEdit =
        _source('lib/shared_pages/profile_edit/profile_edit_widget.dart');

    expect(profile, contains('availabilityToday:'));
    expect(profile, contains('role: UserRole.native_speaker'));
    expect(profile, contains("studentTrackUpdate['availabilityToday']"));
    expect(profile, contains('FieldValue.delete()'));
    expect(profileEdit, contains("'availabilityToday': FieldValue.delete()"));
    expect(_studentRoleCreateUserBlocks(profile), isNotEmpty);
    for (final block in _studentRoleCreateUserBlocks(profile)) {
      expect(block, isNot(contains('availabilityToday:')));
      expect(block, isNot(contains('createAvailabilityTodayStruct')));
    }
    expect(_nonDeleteAvailabilityWrites(profileEdit), isEmpty);
    expect(
      RegExp(
        r"""studentTrackUpdate\s*\[\s*['"]availabilityToday['"]\s*\]\s*=\s*(?!\s*FieldValue\.delete\(\))[^;\n]+""",
      ).allMatches(profile).map((match) => match.group(0)!).toList(),
      isEmpty,
    );

    for (final source in [profile, profileEdit]) {
      expect(source, isNot(contains('getIntervalsFirestoreData')));
      expect(source, isNot(contains('updateIntervalsStruct')));
      expect(source, isNot(contains('FieldValue.arrayRemove')));
    }
  });
}
