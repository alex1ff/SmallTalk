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

  testWidgets('bottom sheet header uses handle and has no icon actions',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const BottomSheetHeader(title: 'Title'),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(BottomSheetHandle), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('bottom sheet header centers handle and title across full width',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const SizedBox(
          width: 320,
          child: BottomSheetHeader(title: 'Centered title'),
        ),
      ),
    );

    final sheetCenterX = tester.getCenter(find.byType(BottomSheetHeader)).dx;

    expect(tester.getSize(find.byType(BottomSheetHeader)).width, 320);
    expect(
      tester.getCenter(find.byType(BottomSheetHandle)).dx,
      moreOrLessEquals(sheetCenterX),
    );
    expect(
      tester.getCenter(find.text('Centered title')).dx,
      moreOrLessEquals(sheetCenterX),
    );
  });

  testWidgets('bottom sheet primary button spans available sheet width',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const SizedBox(
          width: 320,
          child: BottomSheetPrimaryButton(text: 'Done', onPressed: null),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BottomSheetPrimaryButton)).width, 320);
    expect(
      tester.getSize(find.byType(FFButtonWidget)).width,
      320 - ExpatlioDesign.space24 * 2,
    );
  });

  testWidgets('promo sheet title matches the standard bottom sheet title',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const BottomSheetHeader(title: 'Standard title'),
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

  testWidgets('bottom sheet primary button dismisses modal sheet',
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
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BottomSheetHeader(title: 'Title'),
                      BottomSheetPrimaryButton(
                        text: 'Done',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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

    await tester.tap(find.text('Done'));
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

  test('bottom sheet header does not use legacy circle icon actions', () {
    final source =
        File('lib/components/bottom_sheet_header.dart').readAsStringSync();

    expect(source, isNot(contains('Icons.close_rounded')));
    expect(source, isNot(contains('Icons.check_rounded')));
    expect(source, isNot(contains('CircleBorder')));
  });
}
