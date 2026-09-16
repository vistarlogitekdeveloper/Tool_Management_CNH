import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Spacing, radius and elevation scale — the prototype's 4px rhythm.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const radius = 10.0;
  static const radiusSm = 8.0;
  static const radiusLg = 14.0;
  static const chipRadius = 20.0;

  /// Page gutter, tightened on narrow screens.
  static double gutter(double width) => width < 720 ? 14 : 26;
}

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D101828), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const modal = <BoxShadow>[
    BoxShadow(color: Color(0x4D000000), blurRadius: 60, offset: Offset(0, 20)),
  ];
  static const popover = <BoxShadow>[
    BoxShadow(color: Color(0x2E000000), blurRadius: 44, offset: Offset(0, 16)),
  ];
}

abstract final class AppTheme {
  /// Segoe UI on Windows, Roboto elsewhere — matches the prototype's stack
  /// without shipping a font binary.
  static const _fontFamilyFallback = <String>[
    'Segoe UI', 'Roboto', '-apple-system', 'Helvetica Neue', 'Arial',
  ];

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        onPrimary: Colors.white,
        secondary: AppColors.green,
        error: AppColors.red,
        surface: AppColors.panel,
        onSurface: AppColors.ink,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      fontFamilyFallback: _fontFamilyFallback,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.radius),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
        labelStyle: const TextStyle(color: AppColors.label, fontSize: 13),
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.brand, width: 1.6),
        errorBorder: _border(AppColors.red),
        focusedErrorBorder: _border(AppColors.red, width: 1.6),
        disabledBorder: _border(AppColors.line2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.radiusSm)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.panel,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.radiusSm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.radiusLg)),
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          border: _border(AppColors.line),
          enabledBorder: _border(AppColors.line),
          focusedBorder: _border(AppColors.brand, width: 1.6),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.navBg,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navBg,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.radius)),
        insetPadding: const EdgeInsets.all(Insets.lg),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearMinHeight: 3,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(AppColors.slate.withValues(alpha: 0.35)),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(7),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Insets.radiusSm),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base) => base.copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontSize: 27, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink,
        ),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: 14, color: AppColors.ink),
        bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, color: AppColors.ink),
        bodySmall: base.bodySmall?.copyWith(fontSize: 11.5, color: AppColors.muted),
        labelLarge: base.labelLarge?.copyWith(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink,
        ),
        labelMedium: base.labelMedium?.copyWith(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.label,
        ),
        labelSmall: base.labelSmall?.copyWith(
          fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted,
          letterSpacing: 0.4,
        ),
      );
}

/// Column header style used across every data grid.
const kTableHeaderStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: AppColors.muted,
  letterSpacing: 0.4,
);

/// Monospaced treatment for tool codes, PO numbers and certificate numbers.
const kMonoStyle = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: <String>['Menlo', 'Courier New', 'monospace'],
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: AppColors.brandDark,
);
