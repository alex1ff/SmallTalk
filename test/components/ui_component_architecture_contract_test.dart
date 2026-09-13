import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy component directories do not contain Dart components', () {
    const legacyDirectories = [
      'lib/authorization/components',
      'lib/authorization/acquaintance_n_s/widgets',
      'lib/authorization/acquaintance_s_t_u_d_e_n_t/widgets',
      'lib/shared_pages/edit_components',
      'lib/shared_pages/profile_components',
      'lib/shared_pages/nav_bar',
      'lib/students_pages/components',
      'lib/teachers_pages/components',
    ];

    final violations = <String>[];
    for (final directoryPath in legacyDirectories) {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        continue;
      }

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          violations.add(entity.path);
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
