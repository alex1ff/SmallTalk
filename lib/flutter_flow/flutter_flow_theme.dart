// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/shared_pages/design/expatlio_design.dart';

abstract class FlutterFlowTheme {
  static const double minTextScaleFactor = 1.0;
  static const double maxTextScaleFactor = 1.0;
  static const double defaultTextScaleFactor = 1.0;

  static FlutterFlowTheme of(BuildContext context) {
    return LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = ExpatlioDesign.primary;
  late Color secondary = ExpatlioDesign.primaryEnd;
  late Color tertiary = ExpatlioDesign.orange;
  late Color alternate = ExpatlioDesign.border;
  late Color primaryText = ExpatlioDesign.text;
  late Color secondaryText = ExpatlioDesign.muted;
  late Color primaryBackground = ExpatlioDesign.card;
  late Color secondaryBackground = ExpatlioDesign.background;
  late Color accent1 = const Color(0x1A7430E8);
  late Color accent2 = const Color(0x1AB23DE8);
  late Color accent3 = const Color(0x1AF97316);
  late Color accent4 = const Color(0xCCFFFFFF);
  late Color success = ExpatlioDesign.success;
  late Color warning = ExpatlioDesign.warning;
  late Color error = ExpatlioDesign.danger;
  late Color info = ExpatlioDesign.info;
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  TextStyle _style(
    Color color,
    double size,
    FontWeight weight, {
    double height = 1.24,
    String fontFamily = ExpatlioDesign.fontFamily,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      color: color,
      fontWeight: weight,
      fontSize: size,
      height: height,
      letterSpacing: 0,
    );
  }

  TextStyle _headingStyle(Color color, double size, FontWeight weight) {
    return _style(
      color,
      size,
      weight,
      height: 1.18,
      fontFamily: ExpatlioDesign.headingFontFamily,
    );
  }

  String get displayLargeFamily => ExpatlioDesign.headingFontFamily;
  bool get displayLargeIsCustom => true;
  TextStyle get displayLarge =>
      _headingStyle(theme.primaryText, 34.0, FontWeight.w700);
  String get displayMediumFamily => ExpatlioDesign.headingFontFamily;
  bool get displayMediumIsCustom => true;
  TextStyle get displayMedium =>
      _headingStyle(theme.primaryText, 28.0, FontWeight.w700);
  String get displaySmallFamily => ExpatlioDesign.headingFontFamily;
  bool get displaySmallIsCustom => true;
  TextStyle get displaySmall =>
      _headingStyle(theme.primaryText, 22.0, FontWeight.w700);
  String get headlineLargeFamily => ExpatlioDesign.headingFontFamily;
  bool get headlineLargeIsCustom => true;
  TextStyle get headlineLarge =>
      _headingStyle(theme.primaryText, 20.0, FontWeight.w700);
  String get headlineMediumFamily => ExpatlioDesign.headingFontFamily;
  bool get headlineMediumIsCustom => true;
  TextStyle get headlineMedium =>
      _headingStyle(theme.primaryText, 17.0, FontWeight.w600);
  String get headlineSmallFamily => ExpatlioDesign.headingFontFamily;
  bool get headlineSmallIsCustom => true;
  TextStyle get headlineSmall =>
      _headingStyle(theme.primaryText, 17.0, FontWeight.w600);
  String get titleLargeFamily => ExpatlioDesign.headingFontFamily;
  bool get titleLargeIsCustom => true;
  TextStyle get titleLarge =>
      _headingStyle(theme.primaryText, 17.0, FontWeight.w600);
  String get titleMediumFamily => ExpatlioDesign.headingFontFamily;
  bool get titleMediumIsCustom => true;
  TextStyle get titleMedium =>
      _headingStyle(theme.primaryText, 16.0, FontWeight.w600);
  String get titleSmallFamily => ExpatlioDesign.headingFontFamily;
  bool get titleSmallIsCustom => true;
  TextStyle get titleSmall =>
      _headingStyle(theme.primaryText, 15.0, FontWeight.w600);
  String get labelLargeFamily => ExpatlioDesign.fontFamily;
  bool get labelLargeIsCustom => true;
  TextStyle get labelLarge =>
      _style(theme.secondaryText, 17.0, FontWeight.w600);
  String get labelMediumFamily => ExpatlioDesign.fontFamily;
  bool get labelMediumIsCustom => true;
  TextStyle get labelMedium =>
      _style(theme.secondaryText, 13.0, FontWeight.w500);
  String get labelSmallFamily => ExpatlioDesign.fontFamily;
  bool get labelSmallIsCustom => true;
  TextStyle get labelSmall =>
      _style(theme.secondaryText, 12.0, FontWeight.w500);
  String get bodyLargeFamily => ExpatlioDesign.fontFamily;
  bool get bodyLargeIsCustom => true;
  TextStyle get bodyLarge => _style(theme.primaryText, 17.0, FontWeight.w400);
  String get bodyMediumFamily => ExpatlioDesign.fontFamily;
  bool get bodyMediumIsCustom => true;
  TextStyle get bodyMedium => _style(theme.primaryText, 17.0, FontWeight.w400);
  String get bodySmallFamily => ExpatlioDesign.fontFamily;
  bool get bodySmallIsCustom => true;
  TextStyle get bodySmall => _style(theme.primaryText, 13.0, FontWeight.w400);
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
