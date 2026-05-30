import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/flutter_flow_theme.dart';
import 'package:small_talk/components/basic_page_header.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

void main() {
  test('app theme uses Cool for headings and Apple font for body text', () {
    final textTheme = ExpatlioDesign.lightTheme().textTheme;

    expect(
        textTheme.displayLarge?.fontFamily, ExpatlioDesign.headingFontFamily);
    expect(
        textTheme.headlineLarge?.fontFamily, ExpatlioDesign.headingFontFamily);
    expect(textTheme.titleLarge?.fontFamily, ExpatlioDesign.headingFontFamily);
    expect(textTheme.bodyMedium?.fontFamily, ExpatlioDesign.fontFamily);
    expect(textTheme.labelLarge?.fontFamily, ExpatlioDesign.fontFamily);
  });

  test('basic page header uses shared title bar height', () {
    expect(BasicPageHeader.height, ExpatlioDesign.pageHeaderHeight);
  });

  test('basic page header does not expose visual color overrides', () {
    final source = File('lib/components/basic_page_header.dart')
        .readAsStringSync();

    expect(source, isNot(contains('backgroundColor')));
  });

  test('design spacing tokens define one app layout rhythm', () {
    expect(ExpatlioDesign.pagePadding, 16.0);
    expect(ExpatlioDesign.compactSpacing, 8.0);
    expect(ExpatlioDesign.itemSpacing, 12.0);
    expect(ExpatlioDesign.sectionSpacing, 16.0);
    expect(ExpatlioDesign.sectionGap, 24.0);
    expect(ExpatlioDesign.titleContentGap, ExpatlioDesign.compactSpacing);
    expect(
      ExpatlioDesign.pageScrollPadding,
      const EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 112.0),
    );
    expect(ExpatlioDesign.cardPadding, const EdgeInsets.all(16.0));
  });

  testWidgets('page header title style uses shared typography token',
      (tester) async {
    late TextStyle headerStyle;

    await tester.pumpWidget(
      MaterialApp(
        theme: ExpatlioDesign.lightTheme(),
        home: Builder(
          builder: (context) {
            headerStyle = ExpatlioDesign.pageHeaderTitleStyle(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(headerStyle.fontFamily, ExpatlioDesign.fontFamily);
    expect(headerStyle.fontSize, ExpatlioDesign.pageHeaderTitleSize);
    expect(headerStyle.fontWeight, FontWeight.w700);
  });

  testWidgets('FlutterFlow heading styles use Cool font family',
      (tester) async {
    late TextStyle titleStyle;
    late TextStyle bodyStyle;
    late TextStyle explicitCoolStyle;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            titleStyle = FlutterFlowTheme.of(context).titleLarge;
            bodyStyle = FlutterFlowTheme.of(context).bodyMedium;
            explicitCoolStyle = bodyStyle.override(fontFamily: 'Cool');
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(titleStyle.fontFamily, ExpatlioDesign.headingFontFamily);
    expect(bodyStyle.fontFamily, ExpatlioDesign.fontFamily);
    expect(explicitCoolStyle.fontFamily, ExpatlioDesign.headingFontFamily);
  });
}
