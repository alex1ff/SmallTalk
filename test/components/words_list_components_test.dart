import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/dictionary_word_row.dart';

void main() {
  testWidgets('dictionary word row is flat and has no outline border',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DictionaryWordRow(
            sourceText: 'hello',
            translationText: 'привет',
            onTap: () async {},
          ),
        ),
      ),
    );

    final containers = tester.widgetList<Container>(find.byType(Container));
    final rowDecorations = containers
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();

    expect(
      rowDecorations.any((decoration) => decoration.border != null),
      isFalse,
    );
  });
}
