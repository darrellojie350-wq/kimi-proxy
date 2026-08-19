import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium lacquer design system — no generic AI slop.
/// Deep near-black, scarce teal accent, amber for thinking.
class KimiColors {
  static const Color lacquer = Color(0xFF0A0B0F);
  static const Color surface = Color(0xFF12141A);
  static const Color surfaceRaised = Color(0xFF1A1D26);
  static const Color surfaceHover = Color(0xFF22262F);

  static const Color textPrimary = Color(0xFFE8E9ED);
  static const Color textSecondary = Color(0xFF8B90A0);
  static const Color textDim = Color(0xFF5C6170);

  static const Color accent = Color(0xFF2DD4BF); // scarce teal
  static const Color accentDim = Color(0xFF1A9E8F);
  static const Color thinking = Color(0xFFF59E0B); // amber
  static const Color danger = Color(0xFFFB7185);
  static const Color success = Color(0xFF34D399);

  static const Color hairline = Color(0xFF2A2E3A);
  static const Color hairlineStrong = Color(0xFF3A4050);
}

class KimiTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: KimiColors.lacquer,
      colorScheme: const ColorScheme.dark(
        primary: KimiColors.accent,
        secondary: KimiColors.thinking,
        surface: KimiColors.surface,
        error: KimiColors.danger,
        onPrimary: KimiColors.lacquer,
        onSecondary: KimiColors.lacquer,
        onSurface: KimiColors.textPrimary,
        onError: KimiColors.lacquer,
      ),
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: KimiColors.lacquer,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: KimiColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: KimiColors.textSecondary, size: 20),
      ),
      dividerTheme: const DividerThemeData(
        color: KimiColors.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardTheme(
        color: KimiColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: KimiColors.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KimiColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KimiColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KimiColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KimiColors.accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
          color: KimiColors.textDim,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KimiColors.accent,
          foregroundColor: KimiColors.lacquer,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KimiColors.accent,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      iconTheme: const IconThemeData(color: KimiColors.textSecondary, size: 20),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KimiColors.surfaceRaised,
        contentTextStyle: GoogleFonts.inter(color: KimiColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: KimiColors.textPrimary,
        letterSpacing: -0.8,
        height: 1.15,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: KimiColors.textPrimary,
        letterSpacing: -0.4,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: KimiColors.textPrimary,
        letterSpacing: -0.2,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: KimiColors.textPrimary,
        height: 1.55,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: KimiColors.textSecondary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: KimiColors.textDim,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: KimiColors.textPrimary,
      ),
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: KimiColors.textSecondary,
      ),
    );
  }

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: KimiColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: KimiColors.textSecondary,
        height: 1.4,
      );
}
