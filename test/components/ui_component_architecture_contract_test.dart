import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('private UI component classes stay inside flat components directory', () {
    final violations = <String>[];
    final privateWidgetPattern =
        RegExp(r'^class _[A-Z][A-Za-z0-9_]* extends (StatelessWidget|StatefulWidget)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.startsWith('lib/components/')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (privateWidgetPattern.hasMatch(lines[index])) {
          violations.add('${entity.path}:${index + 1}: ${lines[index]}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('standalone UI widgets stay in flat components directory', () {
    final publicWidgetPattern = RegExp(
      r'^class [A-Z][A-Za-z0-9_]* extends (StatelessWidget|StatefulWidget)',
      multiLine: true,
    );
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.startsWith('lib/components/') ||
          _isAllowedNonComponentWidgetFile(entity.path)) {
        continue;
      }

      final source = entity.readAsStringSync();
      if (publicWidgetPattern.hasMatch(source) &&
          !source.contains('static String routeName') &&
          !source.contains('static String routePath')) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

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

bool _isAllowedNonComponentWidgetFile(String path) {
  if (path == 'lib/main.dart' ||
      path.startsWith('lib/auth/') ||
      path.startsWith('lib/custom_code/') ||
      path.startsWith('lib/flutter_flow/')) {
    return true;
  }

  const screenShellFiles = {
    'lib/shared_pages/tab_shell/tab_shell_page.dart',
    'lib/students_pages/flashcard/flashcard_review_widget.dart',
    'lib/students_pages/words/word_detail_widget.dart',
  };

  return screenShellFiles.contains(path);
}
