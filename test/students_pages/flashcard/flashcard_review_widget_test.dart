import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/students_pages/flashcard/flashcard_review_logic.dart';
import 'package:small_talk/students_pages/flashcard/flashcard_review_widget.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [
      Locale('ru'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: Scaffold(body: child),
  );
}

FlashcardSessionEntry _entry({
  required String id,
  required String prompt,
  required String answer,
  int stage = 1,
}) {
  return FlashcardSessionEntry(
    id: id,
    stage: stage,
    direction: flashcardDirectionForStage(stage),
    promptText: prompt,
    answerText: answer,
    sourceWord: answer,
    translationWord: prompt,
    exampleSource: '$answer example',
    exampleTranslation: '$prompt example',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets('answer buttons stay hidden before reveal', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(
              id: 'one',
              prompt: 'привет',
              answer: 'hello',
            ),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('revealButton')), findsOneWidget);
    expect(find.byKey(const Key('rememberButton')), findsNothing);
    expect(find.byKey(const Key('forgetButton')), findsNothing);
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('show answer reveals the back side', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(
              id: 'one',
              prompt: 'привет',
              answer: 'hello',
            ),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('revealButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rememberButton')), findsOneWidget);
    expect(find.byKey(const Key('forgetButton')), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('not remembered card is reinserted at the end of the queue',
      (tester) async {
    final rememberedIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(id: 'one', prompt: 'привет', answer: 'hello'),
            _entry(id: 'two', prompt: 'пока', answer: 'bye'),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {
            rememberedIds.add(entry.id);
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('revealButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forgetButton')));
    await tester.pumpAndSettle();

    expect(find.text('пока'), findsOneWidget);
    expect(find.text('привет'), findsNothing);

    await tester.tap(find.byKey(const Key('revealButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(rememberedIds, ['two']);
    expect(find.text('привет'), findsOneWidget);
  });

  testWidgets('session completes only after retried cards are cleared',
      (tester) async {
    final rememberedStates = <String, bool>{};
    var completedCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(id: 'one', prompt: 'привет', answer: 'hello'),
            _entry(id: 'two', prompt: 'пока', answer: 'bye'),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {
            rememberedStates[entry.id] = hadAnyMiss;
          },
          onCompleted: () {
            completedCount++;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('revealButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forgetButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('revealButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(completedCount, 0);
    expect(rememberedStates['two'], isFalse);

    await tester.tap(find.byKey(const Key('revealButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(completedCount, 1);
    expect(rememberedStates['one'], isTrue);
  });
}
