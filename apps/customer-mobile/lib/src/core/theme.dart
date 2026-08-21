import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class BhookColors {
  const BhookColors._();

  static const Color primary = Color(0xFF1D5FE9);
  static const Color primarySoft = Color(0xFFE8F0FF);
  static const Color accent = Color(0xFFE86A4A);
  static const Color action = Color(0xFFE86A4A);
  static const Color mustard = Color(0xFFF6BD4F);
  static const Color mint = Color(0xFFB9DCC8);
  static const Color sky = Color(0xFFAED7E6);
  static const Color tomato = Color(0xFFE86A4A);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);
  static const Color surface = Color(0xFFFFF5D9);
  static const Color card = Color(0xFFFFFDF7);
  static const Color divider = Color(0xFFE7D9B9);
  static const Color inkStrong = Color(0xFF20242D);
  static const Color ink = Color(0xFF343943);
  static const Color inkMuted = Color(0xFF70747D);
  static const Color inkFaint = Color(0xFFA1A3A8);
  static const Color danger = Color(0xFFDC2626);
}

class BhookSpacing {
  const BhookSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double screenPad = 20;
}

class BhookRadius {
  const BhookRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
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
    splashFactory: InkSparkle.splashFactory,
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: BhookColors.inkStrong),
      headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: BhookColors.inkStrong),
      headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: BhookColors.inkStrong),
      titleLarge: textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: BhookColors.inkStrong),
      titleMedium: textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, color: BhookColors.ink),
      bodyLarge: textTheme.bodyLarge?.copyWith(color: BhookColors.ink),
      bodyMedium: textTheme.bodyMedium?.copyWith(color: BhookColors.ink),
      bodySmall: textTheme.bodySmall?.copyWith(color: BhookColors.inkMuted),
      labelLarge: textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BhookColors.surface,
      foregroundColor: BhookColors.inkStrong,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: BhookColors.inkStrong),
      iconTheme: const IconThemeData(color: BhookColors.inkStrong),
    ),
    cardTheme: CardThemeData(
      color: BhookColors.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: BhookColors.divider, width: 0.8),
        borderRadius: BorderRadius.circular(BhookRadius.lg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BhookColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: BhookColors.inkFaint),
      labelStyle: textTheme.bodyMedium?.copyWith(color: BhookColors.inkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BhookRadius.md),
        borderSide: const BorderSide(color: BhookColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BhookRadius.md),
        borderSide: const BorderSide(color: BhookColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BhookRadius.md),
        borderSide: const BorderSide(color: BhookColors.action, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BhookColors.action,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BhookRadius.lg)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BhookColors.inkStrong,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: BhookColors.divider),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BhookRadius.md)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BhookColors.action,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: BhookColors.card,
      side: const BorderSide(color: BhookColors.divider),
      labelStyle: textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w600, color: BhookColors.ink),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BhookRadius.pill)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BhookColors.inkStrong,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BhookRadius.md)),
    ),
    dividerTheme: const DividerThemeData(
        color: BhookColors.divider, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BhookRadius.md)),
      iconColor: BhookColors.inkMuted,
      textColor: BhookColors.inkStrong,
    ),
  );
}
