import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('segmented tab bar uses Expatlio design tokens', () {
    final source =
        File('lib/components/segmented_tab_bar.dart').readAsStringSync();

    expect(source, contains('static const double height = 38.0;'));
    expect(source, contains('ExpatlioDesign.mutedSurface'));
    expect(source, contains('ExpatlioDesign.card'));
    expect(source, contains('ExpatlioDesign.text'));
    expect(source, contains('ExpatlioDesign.inactive'));
    expect(source, contains('ExpatlioDesign.controlRadius'));
  });

  test('chat and finance tabs use the shared segmented tab bar', () {
    for (final path in const [
      'lib/students_pages/favorite/favorite_widget.dart',
      'lib/teachers_pages/pay_copy/pay_copy_widget.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, contains("import '/components/segmented_tab_bar.dart';"));
      expect(source, contains('ExpatlioSegmentedTabBar('));
    }
  });
}
