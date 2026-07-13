import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/components/review_words_bar.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';

const _longCountText = '999999999999999999999999 words ready for review';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets('review bar geometry stays fixed across content states',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      for (final locale in const <Locale>[Locale('ru'), Locale('en')]) {
        for (final enabled in <bool>[false, true]) {
          for (final width in <double>[240.0, 320.0]) {
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
              final surfaceRect = tester.getRect(surfaceFinder);
              final count = tester.widget<Text>(countFinder);

              expect(surfaceRect.size, Size(width, reviewWordsBarHeight));
              expect(tester.getRect(inkWellFinder), surfaceRect);
              expect(count.maxLines, 1);
              expect(count.overflow, TextOverflow.ellipsis);
              expect(
                count.textScaler?.scale(16.0),
                16.0 * textScale.clamp(1.0, 2.0),
              );

              if (enabled) {
                final actionFinder = find.byKey(reviewWordsBarActionKey);
                final actionRect = tester.getRect(actionFinder);
                final expectedActionText =
                    locale.languageCode == 'ru' ? 'Повторить' : 'Review';
                final actionText = tester.widget<Text>(
                  find.descendant(
                    of: actionFinder,
                    matching: find.text(expectedActionText),
                  ),
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
                expect(actionText.maxLines, 1);
                expect(actionText.overflow, TextOverflow.ellipsis);
                expect(
                  actionText.textScaler?.scale(16.0),
                  16.0 * textScale.clamp(1.0, 2.0),
                );
              } else {
                expect(find.byKey(reviewWordsBarActionKey), findsNothing);
              }

              final paragraphs = tester.renderObjectList<RenderParagraph>(
                find.descendant(
                  of: surfaceFinder,
                  matching: find.byType(Text),
                ),
              );
              for (final paragraph in paragraphs) {
                expect(
                  paragraph.textSize.height,
                  lessThanOrEqualTo(paragraph.size.height),
                );
              }
              expect(tester.takeException(), isNull);

              final semantics = tester.getSemantics(inkWellFinder);
              expect(semantics.label, contains(_longCountText));
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
              text: _longCountText,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}
