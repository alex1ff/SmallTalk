import 'package:flutter/material.dart';

class ExpatlioDesign {
  const ExpatlioDesign._();

  static const String fontFamily = 'sf pro display';
  static const String headingFontFamily = 'Cool';
  static const FontWeight headingFontWeight = FontWeight.normal;
  static const String chatIconAsset = 'assets/images/message-circle-01.svg';

  static const Color systemBackground = Color(0xFFFFFFFF);
  static const Color secondarySystemBackground = Color(0xFFF2F2F7);
  static const Color tertiarySystemBackground = Color(0xFFFFFFFF);
  static const Color systemGroupedBackground = Color(0xFFFAFAFA);
  static const Color secondarySystemGroupedBackground = Color(0xFFFFFFFF);
  static const Color tertiarySystemGroupedBackground = Color(0xFFF2F2F7);
  static const Color label = Color(0xFF000000);
  static const Color secondaryLabel = Color(0x993C3C43);
  static const Color tertiaryLabel = Color(0x4C3C3C43);
  static const Color quaternaryLabel = Color(0x2D3C3C43);
  static const Color placeholderText = Color(0x4C3C3C43);
  static const Color separator = Color(0xFFEBEBEB);
  static const Color opaqueSeparator = Color(0xFFEBEBEB);
  static const Color systemFill = Color(0x33787880);
  static const Color secondarySystemFill = Color(0x28787880);
  static const Color tertiarySystemFill = Color(0x1E767680);
  static const Color quaternarySystemFill = Color(0x14747480);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);
  static const Color systemRed = Color(0xFFFF383C);
  static const Color systemOrange = Color(0xFFFF8D28);
  static const Color systemYellow = Color(0xFFFFCC00);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemBlue = Color(0xFF0088FF);
  static const Color background = systemGroupedBackground;
  static const Color card = secondarySystemGroupedBackground;
  static const Color avatarFallbackBackground = Color(0xFFF5F5F5);
  static const Color avatarFallbackText = Color(0xFF8C8C8C);
  static const Color text = label;
  static const Color muted = secondaryLabel;
  static const Color inactive = systemGray;
  static const Color disabled = tertiaryLabel;
  static const Color border = opaqueSeparator;
  static const Color mutedSurface = secondarySystemFill;
  static const Color primary = Color(0xFF7430E8);
  static const Color primaryPressed = Color(0xFF5F24C8);
  static const Color primaryEnd = primary;
  static const Color ownMessageBubble = Color(0xFFEDE4FA);
  static const Color danger = systemRed;
  static const Color orange = systemOrange;
  static const Color success = systemGreen;
  static const Color warning = systemYellow;
  static const Color info = systemBlue;

  static const double space0 = 0.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;
  static const double space96 = 96.0;
  static const double space112 = 112.0;
  static const double space136 = 136.0;
  static const double pagePadding = space16;
  static const double pagePaddingLarge = space20;
  static const double compactSpacing = space8;
  static const double itemSpacing = space12;
  static const double sectionSpacing = space16;
  static const double sectionGap = space24;
  static const double titleContentGap = compactSpacing;
  static const double pageTopSpacing = compactSpacing;
  static const double pageBottomSpacing = space112;
  static const double radiusNone = 0.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 20.0;
  static const double radiusSheet = 28.0;
  static const double radiusCapsule = 999.0;
  static const double cardRadius = radiusLarge;
  static const double controlRadius = radiusMedium;
  static const double buttonRadius = radiusLarge;
  static const double sheetRadius = radiusSheet;
  static const double bottomSheetTitleSize = 22.0;
  static const double pageHeaderHeight = 52.0;
  static const double pageHeaderTitleSize = 17.0;
  static const double buttonHeight = 52.0;
  static const double buttonTextSize = 16.0;
  static const double formFieldHeight = 48.0;
  static const EdgeInsetsDirectional pageScrollPadding =
      EdgeInsetsDirectional.fromSTEB(
    pagePadding,
    pageTopSpacing,
    pagePadding,
    pageBottomSpacing,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(pagePadding);
  static const EdgeInsetsDirectional cardPaddingDirectional =
      EdgeInsetsDirectional.all(pagePadding);
  static const EdgeInsetsDirectional formGroupPadding =
      EdgeInsetsDirectional.fromSTEB(space16, space16, space16, space20);

  static double bottomBarSafePadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.viewInsets.bottom > 0) {
      return 0.0;
    }
    return mediaQuery.viewPadding.bottom;
  }

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 20.0,
      offset: Offset(0.0, 8.0),
    ),
  ];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryEnd],
    begin: AlignmentDirectional(-1.0, 0.0),
    end: AlignmentDirectional(1.0, 0.0),
  );

  static Border cardBorder({Color color = Colors.transparent}) =>
      Border.all(color: color);

  static BoxDecoration cardDecoration({
    Color color = card,
    double radius = cardRadius,
    Color borderColor = Colors.transparent,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: cardBorder(color: borderColor),
      boxShadow: shadow ? cardShadow : null,
    );
  }

  static BoxDecoration formGroupDecoration({double radius = cardRadius}) {
    return cardDecoration(radius: radius, borderColor: Colors.transparent);
  }

  static BoxDecoration sheetDecoration({Color color = background}) {
    return BoxDecoration(
      color: color,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(sheetRadius)),
    );
  }

  static BoxDecoration softPrimaryDecoration({double radius = controlRadius}) {
    return BoxDecoration(
      color: primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static String avatarInitial(String displayName) {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      return '?';
    }
    return normalizedName.characters.first.toUpperCase();
  }

  static TextStyle formLabelStyle(BuildContext context) {
    return textStyle(
      context,
      color: muted,
      size: 13.0,
      weight: FontWeight.w500,
    );
  }

  static TextStyle pageHeaderTitleStyle(BuildContext context) {
    return textStyle(
      context,
      size: pageHeaderTitleSize,
      weight: FontWeight.w700,
    );
  }

  static TextStyle bottomSheetTitleStyle(BuildContext context) {
    return textStyle(
      context,
      size: bottomSheetTitleSize,
      weight: headingFontWeight,
      height: 1.24,
    ).copyWith(fontFamily: headingFontFamily);
  }

  static TextStyle sectionTitleStyle(BuildContext context) {
    return textStyle(
      context,
      size: 20.0,
      weight: headingFontWeight,
    ).copyWith(fontFamily: headingFontFamily);
  }

  static TextStyle buttonTextStyle(
    BuildContext context, {
    Color color = Colors.white,
  }) {
    return textStyle(
      context,
      color: color,
      size: buttonTextSize,
      weight: FontWeight.w600,
    );
  }

  static TextStyle formTextStyle(
    BuildContext context, {
    bool enabled = true,
  }) {
    return textStyle(
      context,
      color: enabled ? text : disabled,
      size: 16.0,
      weight: FontWeight.w400,
    );
  }

  static InputDecoration formFieldDecoration(
    BuildContext context, {
    String? hintText,
    Widget? suffixIcon,
    bool enabled = true,
    double radius = controlRadius,
    int maxLines = 1,
  }) {
    final borderRadius = BorderRadius.circular(radius);
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: card,
      hintText: hintText,
      hintStyle: formTextStyle(context, enabled: false),
      constraints: maxLines > 1
          ? const BoxConstraints(minHeight: 96.0)
          : const BoxConstraints.tightFor(height: formFieldHeight),
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.space16,
        maxLines > 1 ? ExpatlioDesign.space16 : ExpatlioDesign.space12,
        ExpatlioDesign.space16,
        maxLines > 1 ? ExpatlioDesign.space16 : ExpatlioDesign.space12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: separator, width: 1.0),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: separator,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: separator, width: 1.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: separator, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: separator, width: 1.0),
      ),
      suffixIcon: suffixIcon,
      suffixIconColor: muted,
      suffixIconConstraints: suffixIcon == null
          ? null
          : const BoxConstraints.tightFor(
              width: formFieldHeight,
              height: formFieldHeight,
            ),
    );
  }

  static TextStyle textStyle(
    BuildContext context, {
    Color color = text,
    double size = 17,
    FontWeight weight = FontWeight.w400,
    double height = 1.28,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextTheme textTheme() {
    const bodyBase = TextStyle(
      fontFamily: fontFamily,
      color: text,
      letterSpacing: 0,
      height: 1.24,
    );
    const headingBase = TextStyle(
      fontFamily: headingFontFamily,
      color: text,
      fontWeight: headingFontWeight,
      letterSpacing: 0,
      height: 1.18,
    );

    return TextTheme(
      displayLarge: headingBase.copyWith(fontSize: 34.0),
      displayMedium: headingBase.copyWith(fontSize: 28.0),
      displaySmall: headingBase.copyWith(fontSize: 22.0),
      headlineLarge: headingBase.copyWith(fontSize: 20.0),
      headlineMedium: headingBase.copyWith(fontSize: 17.0),
      headlineSmall: headingBase.copyWith(fontSize: 17.0),
      titleLarge: headingBase.copyWith(fontSize: 17.0),
      titleMedium: headingBase.copyWith(fontSize: 16.0),
      titleSmall: headingBase.copyWith(fontSize: 15.0),
      bodyLarge: bodyBase.copyWith(fontSize: 17.0, fontWeight: FontWeight.w400),
      bodyMedium:
          bodyBase.copyWith(fontSize: 17.0, fontWeight: FontWeight.w400),
      bodySmall: bodyBase.copyWith(fontSize: 13.0, fontWeight: FontWeight.w400),
      labelLarge:
          bodyBase.copyWith(fontSize: 17.0, fontWeight: FontWeight.w600),
      labelMedium:
          bodyBase.copyWith(fontSize: 13.0, fontWeight: FontWeight.w500),
      labelSmall:
          bodyBase.copyWith(fontSize: 12.0, fontWeight: FontWeight.w500),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: info,
      tertiary: orange,
      surface: card,
      onSurface: text,
      error: danger,
    );

    final textTheme = ExpatlioDesign.textTheme();
    const themedButtonTextStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: buttonTextSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: separator,
      disabledColor: disabled,
      visualDensity: VisualDensity.standard,
      splashColor: primary.withValues(alpha: 0.08),
      highlightColor: primary.withValues(alpha: 0.05),
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        foregroundColor: text,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: text, size: 24),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: background,
        modalBackgroundColor: background,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(sheetRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: true,
        filled: true,
        fillColor: card,
        hintStyle: textTheme.bodyMedium?.copyWith(color: placeholderText),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space16,
          ExpatlioDesign.space12,
          ExpatlioDesign.space16,
          ExpatlioDesign.space12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: separator),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: separator),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: separator),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: separator),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, buttonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space20,
                ExpatlioDesign.space0,
                ExpatlioDesign.space20,
                ExpatlioDesign.space0),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(themedButtonTextStyle),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return tertiarySystemFill;
            }
            if (states.contains(WidgetState.pressed)) {
              return primaryPressed;
            }
            return primary;
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, buttonHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space20,
                ExpatlioDesign.space0,
                ExpatlioDesign.space20,
                ExpatlioDesign.space0),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(themedButtonTextStyle),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, buttonHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space20,
                ExpatlioDesign.space0,
                ExpatlioDesign.space20,
                ExpatlioDesign.space0),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          side: const WidgetStatePropertyAll(BorderSide(color: separator)),
          foregroundColor: const WidgetStatePropertyAll(text),
          textStyle: WidgetStatePropertyAll(themedButtonTextStyle),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44.0)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space12,
                ExpatlioDesign.space0,
                ExpatlioDesign.space12,
                ExpatlioDesign.space0),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          foregroundColor: const WidgetStatePropertyAll(primary),
          textStyle: WidgetStatePropertyAll(themedButtonTextStyle),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44.0, 44.0)),
          shape: WidgetStatePropertyAll(controlShape),
          foregroundColor: const WidgetStatePropertyAll(text),
          overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.08)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secondarySystemFill,
        selectedColor: primary.withValues(alpha: 0.12),
        disabledColor: tertiarySystemFill,
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(color: primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: const BorderSide(color: separator),
        ),
        side: const BorderSide(color: separator),
        padding: const EdgeInsets.symmetric(horizontal: ExpatlioDesign.space12),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: muted),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space16,
          ExpatlioDesign.space4,
          ExpatlioDesign.space16,
          ExpatlioDesign.space4,
        ),
        shape: controlShape,
      ),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 1.0,
        space: 1.0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: muted,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: mutedSurface,
        circularTrackColor: mutedSurface,
      ),
    );
  }
}
