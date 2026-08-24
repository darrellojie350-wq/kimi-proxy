import 'package:flutter/material.dart';
import 'tokens.dart';

/// iOS-style app theme — dark-first (Grok/iOS premium), light optional.
/// Uses the system SF font stack via [Tokens.fontStack] so it reads natively
/// on iOS, and degrades gracefully on Android/Web.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _base(Brightness.dark, darkColors());
  static ThemeData light() => _base(Brightness.light, lightColors());

  static ColorScheme darkColors() => const ColorScheme.dark(
        primary: Tokens.accent,
        onPrimary: Colors.white,
        secondary: Tokens.accent,
        onSecondary: Colors.white,
        surface: Tokens.darkCard,
        onSurface: Tokens.darkLabel,
        error: Tokens.danger,
        onError: Colors.white,
        outline: Tokens.darkHairline,
        surfaceContainerHighest: Tokens.darkFill,
        surfaceContainerHigh: Tokens.darkElevated,
      );

  static ColorScheme lightColors() => const ColorScheme.light(
        primary: Tokens.accent,
        onPrimary: Colors.white,
        secondary: Tokens.accent,
        onSecondary: Colors.white,
        surface: Tokens.lightCard,
        onSurface: Tokens.lightLabel,
        error: Tokens.danger,
        onError: Colors.white,
        outline: Tokens.lightHairline,
        surfaceContainerHighest: Tokens.lightFill,
        surfaceContainerHigh: Tokens.lightElevated,
      );

  static ThemeData _base(Brightness b, ColorScheme scheme) {
    final dark = b == Brightness.dark;
    final label = scheme.onSurface;
    final secondary = dark ? Tokens.darkSecondaryLabel : Tokens.lightSecondaryLabel;
    final hairline = dark ? Tokens.darkHairline : Tokens.lightHairline;
    final fill = scheme.surfaceContainerHighest;

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: Tokens.fontStack,
      scaffoldBackgroundColor: dark ? Tokens.darkGroupedBg : Tokens.lightGroupedBg,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: label,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: label,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, color: label),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          color: secondary,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: label,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? Tokens.darkGroupedBg : Tokens.lightGroupedBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: label,
          fontFamily: Tokens.fontStack,
        ),
        iconTheme: IconThemeData(color: Tokens.accent, size: 22),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.rCard),
          side: BorderSide(color: hairline, width: 0.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 0.5, space: 0.5),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: label,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.rLg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        hintStyle: TextStyle(color: secondary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.rMd),
          borderSide: BorderSide(color: hairline, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.rMd),
          borderSide: BorderSide(color: hairline, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.rMd),
          borderSide: const BorderSide(color: Tokens.accent, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: label, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.rLg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.rXl)),
        ),
        showDragHandle: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Tokens.accent : fill,
        ),
      ),
    );
  }
}
