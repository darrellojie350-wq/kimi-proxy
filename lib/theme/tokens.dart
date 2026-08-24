import 'package:flutter/material.dart';

/// Kimi Proxy design tokens — premium iOS-style system.
/// Grounded in the Grok iOS app analysis + Mobbin screen research + the
/// official Kimi Web design system (restrained, density-first, hairline).
class Tokens {
  Tokens._();

  // ---- Accent / status ---------------------------------------------------
  static const accent = Color(0xFF1A88FF); // Kimi blue
  static const accentSoft = Color(0x241A88FF);
  static const thinking = Color(0xFFF59E0B); // amber — thinking state
  static const success = Color(0xFF30D158); // iOS green
  static const warning = Color(0xFFFFD60A); // iOS yellow
  static const danger = Color(0xFFFF453A); // iOS red
  static const info = Color(0xFF64D2FF); // iOS cyan

  // ---- Dark (iOS dark palette) -------------------------------------------
  static const darkBg = Color(0xFF000000);
  static const darkGroupedBg = Color(0xFF0A0A0C);
  static const darkCard = Color(0xFF1C1C1E);
  static const darkFill = Color(0xFF2C2C2E);
  static const darkElevated = Color(0xFF242426);
  static const darkSeparator = Color(0xFF38383A);
  static const darkHairline = Color(0x1AFFFFFF);
  static const darkLabel = Color(0xFFFFFFFF);
  static const darkSecondaryLabel = Color(0xB3EBEBF5); // 70%
  static const darkTertiaryLabel = Color(0x4DEBEBF5); // 30%
  static const darkInputBg = Color(0xFF1C1C1E);

  // ---- Light (iOS light palette) ------------------------------------------
  static const lightBg = Color(0xFFFFFFFF);
  static const lightGroupedBg = Color(0xFFF2F2F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightFill = Color(0xFFE5E5EA);
  static const lightElevated = Color(0xFFFFFFFF);
  static const lightSeparator = Color(0xFFC6C6C8);
  static const lightHairline = Color(0x14000000);
  static const lightLabel = Color(0xFF000000);
  static const lightSecondaryLabel = Color(0xFF8E8E93);
  static const lightTertiaryLabel = Color(0xFFC7C7CC);
  static const lightInputBg = Color(0xFFF2F2F7);

  // ---- Spacing (4pt grid) ---------------------------------------------------
  static const sp1 = 4.0;
  static const sp2 = 8.0;
  static const sp3 = 12.0;
  static const sp4 = 16.0;
  static const sp5 = 20.0;
  static const sp6 = 24.0;
  static const sp8 = 32.0;
  static const sp10 = 40.0;

  // ---- Radius ---------------------------------------------------------------
  static const rSm = 8.0;
  static const rMd = 10.0;
  static const rLg = 14.0;
  static const rXl = 18.0;
  static const rCard = 20.0; // iOS cards / Grok mode cards
  static const rComposer = 28.0; // superellipse feel
  static const rFull = 999.0;

  // ---- Shadows (elevation only, no glow) ------------------------------------
  static const shadowCard = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static const shadowPop = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 40,
    offset: Offset(0, 16),
  );

  // ---- Motion -----------------------------------------------------------------
  static const durFast = Duration(milliseconds: 120);
  static const durBase = Duration(milliseconds: 160);
  static const durSlow = Duration(milliseconds: 260);

  // ---- Layout ------------------------------------------------------------------
  static const sidebarWidth = 300.0;
  static const contentMaxWidth = 760.0;
  static const headerHeight = 52.0;
  static const composerMaxHeight = 200.0;

  // ---- Fonts ---------------------------------------------------------------------
  static const fontStack = 'SF Pro Text, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';
  static const monoStack = 'SF Mono, ui-monospace, "JetBrains Mono", Menlo, Consolas, monospace';
}
