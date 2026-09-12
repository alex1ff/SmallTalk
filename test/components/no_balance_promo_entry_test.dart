import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/no_balance_widget.dart';
import 'package:small_talk/components/promo_redeem_widget.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

Widget _buildHarness(
  Locale locale, {
  Widget? home,
  double textScaleFactor = 1,
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
    theme: ExpatlioDesign.lightTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: child ?? const SizedBox.shrink(),
    ),
    home: home ?? const Scaffold(body: NoBalanceWidget()),
  );
}

void main() {
  for (final scenario in <({Locale locale, String cta, String title})>[
    (
      locale: const Locale('ru'),
      cta: 'У меня есть промокод',
      title: 'Введите промокод',
    ),
    (
      locale: const Locale('en'),
      cta: 'I have a promo code',
      title: 'Enter a promo code',
    ),
  ]) {
    testWidgets(
      'promo redemption is reachable from no-balance sheet in '
      '${scenario.locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildHarness(scenario.locale));
        await tester.pumpAndSettle();

        expect(find.byKey(noBalancePromoCodeButtonKey), findsOneWidget);
        expect(find.text(scenario.cta), findsOneWidget);

        await tester.tap(find.byKey(noBalancePromoCodeButtonKey));
        await tester.pumpAndSettle();

        expect(find.byType(PromoRedeemWidget), findsOneWidget);
        expect(find.text(scenario.title), findsOneWidget);

        Navigator.of(tester.element(find.byType(PromoRedeemWidget))).pop();
        await tester.pumpAndSettle();

        expect(find.byType(PromoRedeemWidget), findsNothing);
        expect(find.byKey(noBalancePromoCodeButtonKey), findsOneWidget);
      },
    );
  }

  testWidgets(
    'server-confirmed promo closes both modal sheets when success is dismissed',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1704);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? noBalanceResult;
      var redeemCallCount = 0;
      final redemption = Completer<Map<dynamic, dynamic>>();
      await tester.pumpWidget(
        _buildHarness(
          const Locale('en'),
          textScaleFactor: 1.6,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  noBalanceResult = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => NoBalanceWidget(
                      promoRedeemOverride: (code) async {
                        redeemCallCount += 1;
                        expect(code, 'SPRING');
                        return redemption.future;
                      },
                    ),
                  );
                },
                child: const Text('Open no balance'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open no balance'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(noBalancePromoCodeButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(noBalancePromoCodeButtonKey));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'SPRING');
      await tester.ensureVisible(find.text('Redeem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem'));
      await tester.pump();

      expect(redeemCallCount, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(
        find.byType(PromoRedeemWidget),
        const Offset(0, 500),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(const Offset(8, 8));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PromoRedeemWidget), findsOneWidget);
      expect(redeemCallCount, 1);

      redemption.complete(<String, Object?>{
        'minutesGifted': 10,
        'remainingMinutes': 10,
      });
      await tester.pumpAndSettle();

      expect(find.text('Promo code redeemed'), findsOneWidget);

      await tester.drag(
        find.byType(PromoRedeemWidget),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      expect(find.text('Promo code redeemed'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PromoRedeemWidget), findsNothing);
      expect(find.byType(NoBalanceWidget), findsNothing);
      expect(noBalanceResult, isTrue);
    },
  );

  testWidgets('server promo errors are localized instead of leaking RU copy',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        const Locale('en'),
        home: Scaffold(
          body: PromoRedeemWidget(
            redeemOverride: (_) async => throw FirebaseFunctionsException(
              code: 'not-found',
              message: 'Промокод не найден',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'MISSING');
    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();

    expect(find.text('Promo code not found.'), findsOneWidget);
    expect(find.text('Промокод не найден'), findsNothing);
  });
}
