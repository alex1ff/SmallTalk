import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';
import 'package:small_talk/components/bottom_sheet_header.dart';
import 'package:small_talk/components/promo_redeem_widget.dart';
import 'package:small_talk/flutter_flow/flutter_flow_widgets.dart';

void main() {
  Widget buildHarness(Widget child) {
    return MaterialApp(
      theme: ExpatlioDesign.lightTheme(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('bottom sheet header action buttons are 48px', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        BottomSheetHeader(
          title: 'Title',
          onConfirm: () {},
        ),
      ),
    );

    final closeButton = find.ancestor(
      of: find.byIcon(Icons.close_rounded),
      matching: find.byType(InkWell),
    );
    final confirmButton = find.ancestor(
      of: find.byIcon(Icons.check_rounded),
      matching: find.byType(InkWell),
    );

    expect(closeButton, findsOneWidget);
    expect(confirmButton, findsOneWidget);
    expect(tester.getSize(closeButton), const Size(48.0, 48.0));
    expect(tester.getSize(confirmButton), const Size(48.0, 48.0));
  });

  testWidgets('promo sheet title matches the standard bottom sheet title',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const BottomSheetHeader(
          title: 'Standard title',
          showConfirm: false,
        ),
      ),
    );

    final standardTitleStyle =
        tester.widget<Text>(find.text('Standard title')).style;

    await tester.pumpWidget(
      buildHarness(const PromoRedeemWidget()),
    );

    final promoTitleStyle =
        tester.widget<Text>(find.text('Введите промокод')).style;

    expect(promoTitleStyle, standardTitleStyle);
  });

  testWidgets('promo sheet primary button uses visible white text',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(const PromoRedeemWidget()),
    );

    final button = tester.widget<FFButtonWidget>(find.byType(FFButtonWidget));

    expect(button.text, 'Активировать');
    expect(button.options.textStyle?.color, Colors.white);
  });

  testWidgets('bottom sheet header close button dismisses modal sheet',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ExpatlioDesign.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  context: context,
                  builder: (context) => BottomSheetHeader(
                    title: 'Title',
                    onConfirm: () {},
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheetHeader), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheetHeader), findsNothing);
  });

  test('modal bottom sheet theme uses rounded top corners', () {
    final bottomSheetTheme = ExpatlioDesign.lightTheme().bottomSheetTheme;
    final shape = bottomSheetTheme.shape as RoundedRectangleBorder;

    expect(
      shape.borderRadius,
      const BorderRadius.vertical(
        top: Radius.circular(ExpatlioDesign.sheetRadius),
      ),
    );
    expect(bottomSheetTheme.clipBehavior, Clip.antiAlias);
  });

  test('header circle button does not receive visual color overrides', () {
    final source =
        File('lib/components/bottom_sheet_header.dart').readAsStringSync();

    expect(source, isNot(contains('fillColor')));
    expect(source, isNot(contains('iconColor')));
  });
}
