import 'package:flutter/material.dart';

class ExpatlioDesign {
  const ExpatlioDesign._();

  static const String fontFamily = 'sf pro display';
  static const String headingFontFamily = 'Cool';

  static const Color background = Color(0xFFF5F5F7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1D1D1F);
  static const Color muted = Color(0xFF6E6E73);
  static const Color inactive = Color(0xFFAEAEB2);
  static const Color border = Color(0xFFE5E5EA);
  static const Color mutedSurface = Color(0xFFF2F2F7);
  static const Color primary = Color(0xFF7430E8);
  static const Color primaryPressed = Color(0xFF5F24C8);
  static const Color primaryEnd = Color(0xFFB23DE8);
  static const Color danger = Color(0xFFEF4444);
  static const Color orange = Color(0xFFEA580C);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = primary;

  static const double pagePadding = 16.0;
  static const double pagePaddingLarge = 20.0;
  static const double compactSpacing = 8.0;
  static const double itemSpacing = 12.0;
  static const double sectionSpacing = 16.0;
  static const double sectionGap = 24.0;
  static const double titleContentGap = compactSpacing;
  static const double pageTopSpacing = compactSpacing;
  static const double pageBottomSpacing = 112.0;
  static const double cardRadius = 18.0;
  static const double controlRadius = 14.0;
  static const double buttonRadius = 16.0;
  static const double sheetRadius = 28.0;
  static const double pageHeaderHeight = 52.0;
  static const double pageHeaderTitleSize = 17.0;
  static const double buttonHeight = 52.0;
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
      EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 18.0);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 20.0,
      offset: Offset(0.0, 8.0),
    ),
  ];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryEnd],
    begin: AlignmentDirectional(-1.0, 0.0),
    end: AlignmentDirectional(1.0, 0.0),
  );

  static Border cardBorder({Color color = border}) => Border.all(color: color);

  static BoxDecoration cardDecoration({
    Color color = card,
    double radius = cardRadius,
    Color borderColor = border,
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
    return cardDecoration(radius: radius);
  }

  static BoxDecoration sheetDecoration() {
    return const BoxDecoration(
      color: card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
    );
  }

  static BoxDecoration softPrimaryDecoration({double radius = controlRadius}) {
    return BoxDecoration(
      color: primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
    );
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

  static TextStyle formTextStyle(
    BuildContext context, {
    bool enabled = true,
  }) {
    return textStyle(
      context,
      color: enabled ? text : inactive.withValues(alpha: 0.55),
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
      fillColor: enabled ? mutedSurface : background,
      hintText: hintText,
      hintStyle: formTextStyle(context, enabled: false),
      constraints: maxLines > 1
          ? const BoxConstraints(minHeight: 96.0)
          : const BoxConstraints.tightFor(height: formFieldHeight),
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        16.0,
        maxLines > 1 ? 14.0 : 12.0,
        16.0,
        maxLines > 1 ? 14.0 : 12.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: border, width: 1.0),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: border.withValues(alpha: 0.55),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: danger, width: 1.4),
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
    double size = 15,
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
      letterSpacing: 0,
      height: 1.18,
    );

    return TextTheme(
      displayLarge:
          headingBase.copyWith(fontSize: 40, fontWeight: FontWeight.w700),
      displayMedium:
          headingBase.copyWith(fontSize: 34, fontWeight: FontWeight.w700),
      displaySmall:
          headingBase.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      headlineLarge:
          headingBase.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium:
          headingBase.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      headlineSmall:
          headingBase.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge:
          headingBase.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium:
          headingBase.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall:
          headingBase.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: bodyBase.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: bodyBase.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodySmall: bodyBase.copyWith(fontSize: 13, fontWeight: FontWeight.w400),
      labelLarge: bodyBase.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: bodyBase.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      labelSmall: bodyBase.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: primaryEnd,
      tertiary: orange,
      surface: card,
      onSurface: text,
      error: danger,
    );

    final textTheme = ExpatlioDesign.textTheme();
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
      dividerColor: border,
      disabledColor: inactive,
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
          side: const BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
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
        fillColor: mutedSurface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: inactive),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          16.0,
          12.0,
          16.0,
          12.0,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: border.withValues(alpha: 0.55)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, buttonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(18.0, 0.0, 18.0, 0.0),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return inactive.withValues(alpha: 0.30);
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
            EdgeInsetsDirectional.fromSTEB(18.0, 0.0, 18.0, 0.0),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, buttonHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(18.0, 0.0, 18.0, 0.0),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          foregroundColor: const WidgetStatePropertyAll(text),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44.0)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          foregroundColor: const WidgetStatePropertyAll(primary),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
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
        backgroundColor: mutedSurface,
        selectedColor: primary.withValues(alpha: 0.12),
        disabledColor: inactive.withValues(alpha: 0.20),
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(color: primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: const BorderSide(color: border),
        ),
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: muted),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          16.0,
          4.0,
          16.0,
          4.0,
        ),
        shape: controlShape,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
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
