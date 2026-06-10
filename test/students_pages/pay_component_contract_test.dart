import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pay page delegates visual sections to flat components', () {
    final pageSource =
        File('lib/students_pages/pay/pay_widget.dart').readAsStringSync();

    expect(pageSource, contains("'/components/student_pay_intro.dart'"));
    expect(pageSource, contains('StudentPayPlanCard('));
    expect(pageSource, contains('StudentPayBottomBar('));
    expect(pageSource, contains('StudentPayRestorePurchasesButton('));
    expect(
        pageSource, contains('mapSubscriptionPackagesByProductId(packages)'));
    expect(pageSource, isNot(contains('class _PlanCard')));
    expect(pageSource, isNot(contains('class _SelectionIndicator')));
    expect(pageSource, isNot(contains('class _FeatureLine')));
    expect(pageSource, isNot(contains('class _BottomBar')));
    expect(pageSource, isNot(contains('class _RestorePurchasesButton')));
  });

  test('pay bottom bar paints the bottom safe area', () {
    final bottomBarSource =
        File('lib/components/student_pay_bottom_bar.dart').readAsStringSync();

    expect(bottomBarSource, contains('return Container('));
    expect(bottomBarSource, contains('child: SafeArea('));
    expect(bottomBarSource, isNot(contains('return SafeArea(')));
  });
}
