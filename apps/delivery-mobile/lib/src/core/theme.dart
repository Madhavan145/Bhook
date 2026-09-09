import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class BhookColors {
  const BhookColors._();
  static const Color primary = Color(0xFFA60F2D);
  static const Color primarySoft = Color(0xFFFBE7EC);
  static const Color accent = Color(0xFFA60F2D);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);
  static const Color surface = Color(0xFFFFF9EC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFF0E7D2);
  static const Color inkStrong = Color(0xFF191A1F);
  static const Color ink = Color(0xFF2E2F35);
  static const Color inkMuted = Color(0xFF6B6C74);
  static const Color inkFaint = Color(0xFF9A9BA3);
  static const Color danger = Color(0xFFDC2626);
}

class BhookSpacing {
  const BhookSpacing._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, screenPad = 20;
}

class BhookRadius {
  const BhookRadius._();
  static const double sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
}

ThemeData buildBhookTheme() {
  const seed = BhookColors.primary;
  final base = ColorScheme.fromSeed(
    seedColor: seed,
    primary: seed,
    onPrimary: Colors.white,
    surface: BhookColors.card,
    surfaceContainerHighest: BhookColors.surface,
    brightness: Brightness.light,
  );
  final textTheme = GoogleFonts.manropeTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: BhookColors.surface,
    dividerColor: BhookColors.divider,
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6, color: BhookColors.inkStrong),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BhookColors.inkStrong),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, color: BhookColors.inkStrong),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: BhookColors.inkStrong),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: BhookColors.ink),
      bodyLarge: textTheme.bodyLarge?.copyWith(color: BhookColors.ink),
      bodyMedium: textTheme.bodyMedium?.copyWith(color: BhookColors.ink),
      bodySmall: textTheme.bodySmall?.copyWith(color: BhookColors.inkMuted),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BhookColors.surface,
      foregroundColor: BhookColors.inkStrong,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: BhookColors.inkStrong),
      iconTheme: const IconThemeData(color: BhookColors.inkStrong),
    ),
    cardTheme: CardThemeData(
      color: BhookColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: BhookColors.divider),
        borderRadius: BorderRadius.circular(BhookRadius.lg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BhookColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: BhookColors.inkFaint),
      labelStyle: textTheme.bodyMedium?.copyWith(color: BhookColors.inkMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(BhookRadius.md), borderSide: const BorderSide(color: BhookColors.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BhookRadius.md), borderSide: const BorderSide(color: BhookColors.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BhookRadius.md), borderSide: const BorderSide(color: BhookColors.primary, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BhookColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BhookRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BhookColors.inkStrong,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: BhookColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BhookRadius.md)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BhookColors.primary,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: BhookColors.card,
      side: const BorderSide(color: BhookColors.divider),
      labelStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: BhookColors.ink),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BhookRadius.pill)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BhookColors.inkStrong,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BhookRadius.md)),
    ),
    dividerTheme: const DividerThemeData(color: BhookColors.divider, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BhookRadius.md)),
      iconColor: BhookColors.inkMuted,
      textColor: BhookColors.inkStrong,
    ),
  );
}
