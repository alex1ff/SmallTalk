import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
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
  required int stage,
  String? transcription,
  List<String> synonyms = const <String>[],
  String? exampleSource,
  String? exampleTranslation,
}) {
  return FlashcardSessionEntry(
    id: id,
    stage: stage,
    direction: flashcardDirectionForStage(stage),
    promptText: prompt,
    answerText: answer,
    sourceWord: prompt,
    translationWord: answer,
    sourceTranscription: transcription,
    sourceSynonyms: synonyms
        .map((text) => SynonymStruct(text: text))
        .toList(growable: false),
    exampleSource: exampleSource,
    exampleTranslation: exampleTranslation,
    selectedExampleText: exampleSource,
    selectedExampleTranslation: exampleTranslation,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets(
      'answer actions are available immediately and there is no reveal button',
      (tester) async {
    final rememberedIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(
              id: 'one',
              prompt: 'hello',
              answer: 'привет',
              stage: 1,
            ),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {
            rememberedIds.add(entry.id);
          },
        ),
      ),
    );

    expect(find.byKey(const Key('revealButton')), findsNothing);
    expect(find.byKey(const Key('answerVisibilityToggle')), findsOneWidget);
    expect(find.byKey(const Key('rememberButton')), findsOneWidget);
    expect(find.byKey(const Key('forgetButton')), findsOneWidget);
    expect(find.byKey(const Key('flashcardAnswerText')), findsNothing);

    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(rememberedIds, ['one']);
  });

  testWidgets('eye icon toggles only the translation', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(
              id: 'one',
              prompt: 'hello',
              answer: 'привет',
              stage: 1,
              transcription: 'həˈləʊ',
              synonyms: ['hi'],
              exampleSource: 'He said hello to everyone.',
              exampleTranslation: 'Он всем сказал привет.',
            ),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('flashcardAnswerText')), findsNothing);
    expect(find.byKey(const Key('sourceMetadata')), findsOneWidget);
    expect(find.byKey(const Key('sourceTranscriptionText')), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('sourceSynonym_hi')), findsOneWidget);
    expect(find.byKey(const Key('flashcardExampleBlock')), findsNothing);

    await tester.tap(find.byKey(const Key('answerVisibilityToggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flashcardAnswerText')), findsOneWidget);
    expect(find.text('привет'), findsOneWidget);
    expect(find.byKey(const Key('sourceMetadata')), findsOneWidget);
    expect(find.byKey(const Key('flashcardExampleBlock')), findsNothing);

    await tester.tap(find.byKey(const Key('answerVisibilityToggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flashcardAnswerText')), findsNothing);
    expect(find.byKey(const Key('sourceMetadata')), findsOneWidget);
    expect(find.byKey(const Key('flashcardExampleBlock')), findsNothing);
  });

  testWidgets('not remembered card is reinserted at the end of the queue',
      (tester) async {
    final rememberedIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(id: 'one', prompt: 'hello', answer: 'привет', stage: 1),
            _entry(id: 'two', prompt: 'bye', answer: 'пока', stage: 1),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {
            rememberedIds.add(entry.id);
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('forgetButton')));
    await tester.pumpAndSettle();

    expect(find.text('bye'), findsOneWidget);
    expect(find.text('hello'), findsNothing);

    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(rememberedIds, ['two']);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('session completes only after retried cards are cleared',
      (tester) async {
    final rememberedStates = <String, bool>{};
    var completedCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(id: 'one', prompt: 'hello', answer: 'привет', stage: 1),
            _entry(id: 'two', prompt: 'bye', answer: 'пока', stage: 1),
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

    await tester.tap(find.byKey(const Key('forgetButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(completedCount, 0);
    expect(rememberedStates['two'], isFalse);

    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(completedCount, 1);
    expect(rememberedStates['one'], isTrue);
  });

  testWidgets('source metadata stays visible while translation is hidden',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(
              id: 'one',
              prompt: 'hello',
              answer: 'привет',
              stage: 1,
              transcription: 'həˈləʊ',
              synonyms: ['hi'],
            ),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('sourceMetadata')), findsOneWidget);
    expect(find.byKey(const Key('flashcardAnswerText')), findsNothing);

    await tester.tap(find.byKey(const Key('answerVisibilityToggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sourceMetadata')), findsOneWidget);
    expect(find.byKey(const Key('sourceTranscriptionText')), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('sourceSynonym_hi')), findsOneWidget);
    expect(find.byKey(const Key('flashcardAnswerText')), findsOneWidget);
  });

  testWidgets('source metadata is visible immediately on en to ru cards',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(
              id: 'one',
              prompt: 'hello',
              answer: 'привет',
              stage: 2,
              transcription: 'həˈləʊ',
              synonyms: ['hi'],
            ),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('sourceMetadata')), findsOneWidget);
    expect(find.byKey(const Key('flashcardAnswerText')), findsNothing);
  });

  testWidgets('opened eye state persists across cards in one session',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FlashcardReviewWidget(
          entries: [
            _entry(id: 'one', prompt: 'hello', answer: 'привет', stage: 1),
            _entry(id: 'two', prompt: 'thanks', answer: 'спасибо', stage: 1),
          ],
          onRemembered: (entry, {required hadAnyMiss}) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('answerVisibilityToggle')));
    await tester.pumpAndSettle();
    expect(find.text('привет'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rememberButton')));
    await tester.pumpAndSettle();

    expect(find.text('спасибо'), findsOneWidget);
    expect(find.byKey(const Key('flashcardAnswerText')), findsOneWidget);
  });
}
