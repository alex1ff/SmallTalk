import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/flutter_flow_theme.dart';
import 'package:small_talk/components/basic_page_header.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

void main() {
  const appleTextSizes = <double>[
    34.0,
    28.0,
    22.0,
    20.0,
    17.0,
    16.0,
    15.0,
    13.0,
    12.0,
    11.0,
  ];

  const appleRadiusScale = <double>[
    0.0,
    8.0,
    12.0,
    16.0,
    20.0,
    28.0,
    999.0,
  ];

  const appleSpacingScale = <double>[
    0.0,
    4.0,
    8.0,
    12.0,
    16.0,
    20.0,
    24.0,
    32.0,
    40.0,
    48.0,
    56.0,
    64.0,
    80.0,
    96.0,
    112.0,
    136.0,
  ];

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
    final source =
        File('lib/components/basic_page_header.dart').readAsStringSync();

    expect(source, isNot(contains('backgroundColor')));
  });

  test('design spacing tokens define one app layout rhythm', () {
    expect(
      <double>[
        ExpatlioDesign.space0,
        ExpatlioDesign.space4,
        ExpatlioDesign.space8,
        ExpatlioDesign.space12,
        ExpatlioDesign.space16,
        ExpatlioDesign.space20,
        ExpatlioDesign.space24,
        ExpatlioDesign.space32,
        ExpatlioDesign.space40,
        ExpatlioDesign.space48,
        ExpatlioDesign.space56,
        ExpatlioDesign.space64,
        ExpatlioDesign.space80,
        ExpatlioDesign.space96,
        ExpatlioDesign.space112,
        ExpatlioDesign.space136,
      ],
      appleSpacingScale,
    );
    expect(ExpatlioDesign.pagePadding, ExpatlioDesign.space16);
    expect(ExpatlioDesign.compactSpacing, ExpatlioDesign.space8);
    expect(ExpatlioDesign.itemSpacing, ExpatlioDesign.space12);
    expect(ExpatlioDesign.sectionSpacing, ExpatlioDesign.space16);
    expect(ExpatlioDesign.sectionGap, ExpatlioDesign.space24);
    expect(ExpatlioDesign.titleContentGap, ExpatlioDesign.compactSpacing);
    expect(
      ExpatlioDesign.pageScrollPadding,
      const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.space16,
        ExpatlioDesign.space8,
        ExpatlioDesign.space16,
        ExpatlioDesign.space112,
      ),
    );
    expect(
      ExpatlioDesign.cardPadding,
      const EdgeInsets.all(ExpatlioDesign.space16),
    );
  });

  test('design radius tokens define one app shape scale', () {
    expect(ExpatlioDesign.radiusNone, 0.0);
    expect(ExpatlioDesign.radiusSmall, 8.0);
    expect(ExpatlioDesign.radiusMedium, 12.0);
    expect(ExpatlioDesign.radiusLarge, 16.0);
    expect(ExpatlioDesign.radiusExtraLarge, 20.0);
    expect(ExpatlioDesign.radiusSheet, 28.0);
    expect(ExpatlioDesign.radiusCapsule, 999.0);
    expect(
      <double>[
        ExpatlioDesign.radiusNone,
        ExpatlioDesign.radiusSmall,
        ExpatlioDesign.radiusMedium,
        ExpatlioDesign.radiusLarge,
        ExpatlioDesign.radiusExtraLarge,
        ExpatlioDesign.radiusSheet,
        ExpatlioDesign.radiusCapsule,
      ],
      appleRadiusScale,
    );
    expect(ExpatlioDesign.cardRadius, ExpatlioDesign.radiusLarge);
    expect(ExpatlioDesign.controlRadius, ExpatlioDesign.radiusMedium);
    expect(ExpatlioDesign.buttonRadius, ExpatlioDesign.radiusLarge);
    expect(ExpatlioDesign.sheetRadius, ExpatlioDesign.radiusSheet);
  });

  test('explicit text sizes use the Apple iOS typography scale', () {
    final fontSizePattern =
        RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)', multiLine: true);
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final source = entity.readAsStringSync();
      for (final match in fontSizePattern.allMatches(source)) {
        final rawSize = match.group(1)!;
        final size = double.parse(rawSize);
        if (!appleTextSizes.contains(size)) {
          violations.add('${entity.path}: fontSize $rawSize');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('explicit corner radii use shared design tokens', () {
    final literalRadiusPatterns = <RegExp>[
      RegExp(
        r'(?:BorderRadius|Radius)\.circular\(\s*(\d+(?:\.\d+)?)\s*\)',
      ),
      RegExp(r'borderRadius:\s*(\d+(?:\.\d+)?)\b'),
    ];
    final circularCallPattern = RegExp(
      r'(?:BorderRadius|Radius)\.circular\(([^)]*)\)',
      dotAll: true,
    );
    final numberPattern = RegExp(r'\b\d+(?:\.\d+)?\b');
    final geometricCirclePattern = RegExp(r'/\s*2(?:\.0)?\b');
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('/shared_pages/design/expatlio_design.dart')) {
        continue;
      }

      final source = entity.readAsStringSync();
      for (final pattern in literalRadiusPatterns) {
        for (final match in pattern.allMatches(source)) {
          final rawRadius = match.group(1)!;
          violations.add('${entity.path}: corner radius $rawRadius');
        }
      }
      for (final match in circularCallPattern.allMatches(source)) {
        final radiusExpression = match.group(1)!.trim();
        if (!numberPattern.hasMatch(radiusExpression)) {
          continue;
        }
        if (geometricCirclePattern.hasMatch(radiusExpression)) {
          continue;
        }

        violations.add(
          '${entity.path}: circular radius expression $radiusExpression',
        );
      }
    }

    expect(violations, isEmpty);
  });

  test('explicit layout spacing uses shared design tokens', () {
    String? callArguments(String source, int openParenIndex) {
      var depth = 0;
      for (var index = openParenIndex; index < source.length; index++) {
        final char = source[index];
        if (char == '(') {
          depth += 1;
        } else if (char == ')') {
          depth -= 1;
          if (depth == 0) {
            return source.substring(openParenIndex + 1, index);
          }
        }
      }

      return null;
    }

    final edgeInsetsCallPattern = RegExp(
      r'EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromSTEB|fromLTRB)\(',
    );
    final spacingPatterns = <RegExp>[
      RegExp(r'\bSizedBox\(\s*(?:height|width):\s*(\d+(?:\.\d+)?)\s*\)'),
      RegExp(
        r'\b(?:mainAxisSpacing|crossAxisSpacing|runSpacing|spacing):\s*(\d+(?:\.\d+)?)\b',
      ),
    ];
    final literalNumberPattern = RegExp(r'(?<![\w.])\d+(?:\.\d+)?(?![\w.])');
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('/shared_pages/design/expatlio_design.dart')) {
        continue;
      }

      final source = entity.readAsStringSync();
      for (final match in edgeInsetsCallPattern.allMatches(source)) {
        final expression = callArguments(source, match.end - 1);
        if (expression == null) {
          violations.add('${entity.path}: malformed EdgeInsets call');
          continue;
        }
        if (literalNumberPattern.hasMatch(expression)) {
          violations.add('${entity.path}: layout spacing $expression');
        }
      }
      for (final pattern in spacingPatterns) {
        for (final match in pattern.allMatches(source)) {
          final expression = match.group(1)!.trim();
          if (literalNumberPattern.hasMatch(expression)) {
            violations.add('${entity.path}: layout spacing $expression');
          }
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('app text theme follows the Apple iOS default text sizes', () {
    final textTheme = ExpatlioDesign.textTheme();

    expect(textTheme.displayLarge?.fontSize, 34.0);
    expect(textTheme.displayMedium?.fontSize, 28.0);
    expect(textTheme.displaySmall?.fontSize, 22.0);
    expect(textTheme.headlineLarge?.fontSize, 20.0);
    expect(textTheme.headlineMedium?.fontSize, 17.0);
    expect(textTheme.headlineSmall?.fontSize, 17.0);
    expect(textTheme.titleLarge?.fontSize, 17.0);
    expect(textTheme.titleMedium?.fontSize, 16.0);
    expect(textTheme.titleSmall?.fontSize, 15.0);
    expect(textTheme.bodyLarge?.fontSize, 17.0);
    expect(textTheme.bodyMedium?.fontSize, 17.0);
    expect(textTheme.bodySmall?.fontSize, 13.0);
    expect(textTheme.labelLarge?.fontSize, 17.0);
    expect(textTheme.labelMedium?.fontSize, 13.0);
    expect(textTheme.labelSmall?.fontSize, 12.0);
    expect(ExpatlioDesign.bottomSheetTitleSize, 22.0);
    expect(ExpatlioDesign.pageHeaderTitleSize, 17.0);
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
