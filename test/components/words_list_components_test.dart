import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      expect(tester.getSize(rowFinder).height, dictionaryWordRowHeight);
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

  testWidgets('dictionary word row keeps a fixed height for long scaled text',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    const sourceText = 'extraordinarily long original dictionary entry';
    const translationText = 'исключительно длинный перевод словарной статьи';

    try {
      for (final textScale in <double>[0.0, 1.0, 2.0, 3.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(240.0, 640.0),
                textScaler: TextScaler.linear(textScale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 240.0,
                    child: DictionaryWordRow(
                      sourceText: sourceText,
                      translationText: translationText,
                      onTap: () async {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final rowFinder = find.byType(DictionaryWordRow);
        final inkWellFinder = find.descendant(
          of: rowFinder,
          matching: find.byType(InkWell),
        );
        final rowSize = tester.getSize(rowFinder);
        final inkWellSize = tester.getSize(inkWellFinder);
        final texts = tester.widgetList<Text>(
          find.descendant(of: rowFinder, matching: find.byType(Text)),
        );

        expect(rowSize, const Size(240.0, dictionaryWordRowHeight));
        expect(inkWellSize, rowSize);
        expect(texts, hasLength(2));
        expect(
          texts.every((text) => text.maxLines == (textScale <= 1.0 ? 2 : 1)),
          isTrue,
        );
        expect(
          texts.every((text) => text.overflow == TextOverflow.ellipsis),
          isTrue,
        );
        final paragraphs = tester.renderObjectList<RenderParagraph>(
          find.descendant(of: rowFinder, matching: find.byType(Text)),
        );
        expect(paragraphs, hasLength(2));
        for (final paragraph in paragraphs) {
          expect(
            paragraph.textSize.height,
            lessThanOrEqualTo(paragraph.size.height),
          );
          expect(paragraph.didExceedMaxLines, isTrue);
        }
        expect(tester.takeException(), isNull);

        final semantics = tester.getSemantics(inkWellFinder);
        expect(semantics.label, contains(sourceText));
        expect(semantics.label, contains(translationText));
      }
    } finally {
      semanticsHandle.dispose();
    }
  });
}
