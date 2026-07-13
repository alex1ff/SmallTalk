import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/dictionary_word_row.dart';

void main() {
  testWidgets('dictionary word row is flat and has no outline border',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var taps = 0;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DictionaryWordRow(
              sourceText: 'hello',
              translationText: 'привет',
              onTap: () async {
                taps += 1;
              },
            ),
          ),
        ),
      );

      final rowFinder = find.byType(DictionaryWordRow);
      final materialFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(Material),
      );
      final inkWellFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(InkWell),
      );

      expect(find.byType(Card), findsNothing);
      expect(materialFinder, findsOneWidget);
      expect(inkWellFinder, findsOneWidget);

      final material = tester.widget<Material>(materialFinder);
      expect(material.color, Colors.transparent);
      expect(material.shape, isNull);
      expect(material.borderRadius, isNull);
      expect(material.elevation, 0.0);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final rowDecorations = containers
          .map((container) => container.decoration)
          .whereType<BoxDecoration>();

      expect(
        rowDecorations.any((decoration) => decoration.border != null),
        isFalse,
      );
      expect(tester.getSize(inkWellFinder), tester.getSize(rowFinder));

      final semantics = tester.getSemantics(inkWellFinder);
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(inkWellFinder);
      await tester.pump();
      expect(taps, 1);
    } finally {
      semanticsHandle.dispose();
    }
  });
}
