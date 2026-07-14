import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/components/review_words_bar.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';

const _dueCount = 1000;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  test('review count stays numeric and caps only the visible value', () {
    expect(
      <int>[-1, 0, 1, 9, 10, 99, 100, 1000].map(reviewWordsVisibleCount),
      <String>['0', '0', '1', '9', '10', '99', '99+', '99+'],
    );
    expect(
      reviewWordsCountSemanticsLabel(count: 1, languageCode: 'ru'),
      '1 слово к повторению',
    );
    expect(
      reviewWordsCountSemanticsLabel(count: 2, languageCode: 'ru'),
      '2 слова к повторению',
    );
    expect(
      reviewWordsCountSemanticsLabel(count: 11, languageCode: 'ru'),
      '11 слов к повторению',
    );
    expect(
      reviewWordsCountSemanticsLabel(count: 21, languageCode: 'ru'),
      '21 слово к повторению',
    );
    expect(
      reviewWordsCountSemanticsLabel(count: 1000, languageCode: 'en'),
      '1000 words to review',
    );
  });

  testWidgets('review bar geometry stays fixed across content states',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      for (final locale in const <Locale>[Locale('ru'), Locale('en')]) {
        for (final enabled in <bool>[false, true]) {
          for (final width in <double>[208.0, 288.0, 358.0]) {
            for (final textScale in <double>[0.0, 1.0, 2.0, 3.0]) {
              await tester.pumpWidget(
                _buildReviewBarApp(
                  locale: locale,
                  width: width,
                  textScale: textScale,
                  onTap: enabled ? () {} : null,
                ),
              );
              await tester.pumpAndSettle();

              final surfaceFinder = find.byKey(reviewWordsBarSurfaceKey);
              final inkWellFinder = find.descendant(
                of: surfaceFinder,
                matching: find.byType(InkWell),
              );
              final countFinder = find.byKey(reviewWordsBarCountTextKey);
              final countSlotFinder = find.byKey(reviewWordsBarCountSlotKey);
              final surfaceRect = tester.getRect(surfaceFinder);
              final countRect = tester.getRect(countFinder);
              final countSlotRect = tester.getRect(countSlotFinder);
              final count = tester.widget<Text>(countFinder);

              expect(surfaceRect.size, Size(width, reviewWordsBarHeight));
              expect(tester.getRect(inkWellFinder), surfaceRect);
              expect(count.data, '99+');
              expect(count.maxLines, 1);
              expect(count.overflow, TextOverflow.ellipsis);
              expect(
                count.textScaler?.scale(16.0),
                16.0 * textScale.clamp(1.0, 2.0),
              );
              expect(
                countRect.left,
                greaterThanOrEqualTo(countSlotRect.left - 0.01),
              );
              expect(
                countRect.right,
                lessThanOrEqualTo(countSlotRect.right + 0.01),
              );
              expect(
                find.byIcon(Icons.auto_awesome_outlined),
                width < 272.0 ? findsNothing : findsOneWidget,
              );

              if (enabled) {
                final actionFinder = find.byKey(reviewWordsBarActionKey);
                final actionRect = tester.getRect(actionFinder);
                final expectedActionText =
                    locale.languageCode == 'ru' ? 'Повторить' : 'Review';
                final actionTextFinder = find.descendant(
                  of: actionFinder,
                  matching: find.text(expectedActionText),
                );
                final actionText = tester.widget<Text>(
                  actionTextFinder,
                );

                expect(
                  actionRect.size,
                  const Size(
                    reviewWordsBarActionWidth,
                    reviewWordsBarActionHeight,
                  ),
                );
                expect(
                  actionRect.top - surfaceRect.top,
                  (reviewWordsBarHeight - reviewWordsBarActionHeight) / 2,
                );
                expect(
                  actionRect.left,
                  greaterThanOrEqualTo(countSlotRect.right - 0.01),
                );
                expect(
                  actionRect.left,
                  greaterThanOrEqualTo(surfaceRect.left - 0.01),
                );
                expect(
                  actionRect.right,
                  lessThanOrEqualTo(surfaceRect.right + 0.01),
                );
                expect(
                  actionRect.top,
                  greaterThanOrEqualTo(surfaceRect.top - 0.01),
                );
                expect(
                  actionRect.bottom,
                  lessThanOrEqualTo(surfaceRect.bottom + 0.01),
                );
                expect(actionText.maxLines, 1);
                expect(actionText.overflow, TextOverflow.ellipsis);
                expect(
                  actionText.textScaler?.scale(16.0),
                  16.0 * textScale.clamp(1.0, 2.0),
                );
                final actionParagraph = tester.renderObject<RenderParagraph>(
                  find.descendant(
                    of: actionTextFinder,
                    matching: find.byType(RichText),
                  ),
                );
                expect(actionParagraph.didExceedMaxLines, isFalse);
              } else {
                expect(find.byKey(reviewWordsBarActionKey), findsNothing);
              }

              final paragraphs = tester.renderObjectList<RenderParagraph>(
                find.descendant(
                  of: surfaceFinder,
                  matching: find.byType(RichText),
                ),
              );
              for (final paragraph in paragraphs) {
                expect(
                  paragraph.textSize.height,
                  lessThanOrEqualTo(paragraph.size.height),
                );
              }
              final countParagraph = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: countFinder,
                  matching: find.byType(RichText),
                ),
              );
              expect(countParagraph.didExceedMaxLines, isFalse);
              expect(tester.takeException(), isNull);

              final semantics = tester.getSemantics(inkWellFinder);
              final expectedCountSemantics = reviewWordsCountSemanticsLabel(
                count: _dueCount,
                languageCode: locale.languageCode,
              );
              expect(semantics.label, contains(expectedCountSemantics));
              expect(semantics.label, isNot(contains('99+')));
              expect(
                semantics.getSemanticsData().hasAction(SemanticsAction.tap),
                enabled,
              );
            }
          }
        }
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('large review counts do not move or clip the action',
      (tester) async {
    Rect? baselineSurfaceRect;
    Rect? baselineActionRect;

    for (final dueCount in const <int>[1, 99, 100, 1000000000]) {
      await tester.pumpWidget(
        _buildReviewBarApp(
          locale: const Locale('ru'),
          width: 208.0,
          textScale: 2.0,
          dueCount: dueCount,
          onTap: () {},
        ),
      );
      await tester.pumpAndSettle();

      final surfaceRect = tester.getRect(
        find.byKey(reviewWordsBarSurfaceKey),
      );
      final actionRect = tester.getRect(find.byKey(reviewWordsBarActionKey));
      final countSlotRect = tester.getRect(
        find.byKey(reviewWordsBarCountSlotKey),
      );

      expect(
        tester.widget<Text>(find.byKey(reviewWordsBarCountTextKey)).data,
        reviewWordsVisibleCount(dueCount),
      );
      expect(surfaceRect.size, const Size(208.0, reviewWordsBarHeight));
      expect(
        actionRect.size,
        const Size(
          reviewWordsBarActionWidth,
          reviewWordsBarActionHeight,
        ),
      );
      expect(actionRect.left, greaterThanOrEqualTo(countSlotRect.right));
      expect(actionRect.right, lessThanOrEqualTo(surfaceRect.right));
      expect(actionRect.top, greaterThanOrEqualTo(surfaceRect.top));
      expect(actionRect.bottom, lessThanOrEqualTo(surfaceRect.bottom));
      expect(surfaceRect, baselineSurfaceRect ?? surfaceRect);
      expect(actionRect, baselineActionRect ?? actionRect);
      expect(tester.takeException(), isNull);

      baselineSurfaceRect ??= surfaceRect;
      baselineActionRect ??= actionRect;
    }
  });

  testWidgets('review bar keeps its rect when it becomes enabled',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _buildReviewBarApp(
        locale: const Locale('ru'),
        width: 320.0,
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();
    final disabledRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));

    await tester.tap(find.byKey(reviewWordsBarSurfaceKey));
    await tester.pump();
    expect(taps, 0);

    await tester.pumpWidget(
      _buildReviewBarApp(
        locale: const Locale('ru'),
        width: 320.0,
        textScale: 1.0,
        onTap: () {
          taps += 1;
        },
      ),
    );
    await tester.pumpAndSettle();
    final enabledRect = tester.getRect(find.byKey(reviewWordsBarSurfaceKey));

    expect(enabledRect, disabledRect);
    await tester.tap(find.byKey(reviewWordsBarSurfaceKey));
    await tester.pump();
    expect(taps, 1);
  });
}

Widget _buildReviewBarApp({
  required Locale locale,
  required double width,
  required double textScale,
  int dueCount = _dueCount,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390.0, 844.0),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: ReviewWordsBar(
              text: reviewWordsVisibleCount(dueCount),
              semanticsLabel: reviewWordsCountSemanticsLabel(
                count: dueCount,
                languageCode: locale.languageCode,
              ),
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}
