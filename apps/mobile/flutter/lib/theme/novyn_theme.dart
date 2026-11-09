import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovynTheme {
  static const Color _primary   = Color(0xFF222222);
  static const Color _secondary = Color(0xFF777777);

  // ── Pastel color palette for splash & auth screens ────────────────────────
  static const Color pastelPurple    = Color(0xFFB8A6F3);  // Soft purple
  static const Color pastelPink      = Color(0xFFF4A8D6);  // Soft pink
  static const Color pastelTeal      = Color(0xFF7DD3D3);  // Soft teal
  static const Color pastelLavender  = Color(0xFFD4C4F8);  // Soft lavender
  static const Color pastelPeach     = Color(0xFFFAD7BB);  // Soft peach

  static final TextTheme _textTheme = GoogleFonts.outfitTextTheme(const TextTheme(
    displayLarge:  TextStyle(fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontWeight: FontWeight.bold),
    displaySmall:  TextStyle(fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(fontWeight: FontWeight.bold),
    headlineMedium:TextStyle(fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontWeight: FontWeight.w600),
    titleLarge:    TextStyle(fontWeight: FontWeight.w600),
    titleMedium:   TextStyle(fontWeight: FontWeight.w500),
    titleSmall:    TextStyle(fontWeight: FontWeight.w500),
  ));

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary:                _primary,
        secondary:              _secondary,
        surface:                Colors.white,
        surfaceContainerHighest:Color(0xFFF2F2F2),
        onSurface:              Color(0xFF111111),
        onSurfaceVariant:       Color(0xFF777777),
        outline:                Color(0xFFE5E5E5),
      ),
      // Cards
      cardColor: Colors.white,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E5F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
      // Divider
      dividerColor: const Color(0xFFE2E5F0),
      textTheme: _textTheme,
      useMaterial3: true,
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary:                _primary,
        secondary:              _secondary,
        surface:                Color(0xFF191919),
        surfaceContainerHighest:Color(0xFF252525),
        onSurface:              Color(0xFFF5F5F5),
        onSurfaceVariant:       Color(0xFF9E9E9E),
        outline:                Color(0xFF777777),
      ),
      cardColor: const Color(0xFF14121F),
      cardTheme: CardThemeData(
        color: const Color(0xFF14121F),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0B0B),
        foregroundColor: Color(0xFFF2F0FA),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF101010),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF888888)),
      ),
      dividerColor: const Color(0x1AFFFFFF),
      textTheme: _textTheme,
      useMaterial3: true,
    );
  }

  // ── Semantic color helpers (use these in screens) ─────────────────────────
  /// Card / tile background
  static Color cardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF14121F)
        : Colors.white;
  }

  /// Page / section background
  static Color pageBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0B0B0B)
        : const Color(0xFFF5F5F5);
  }

  /// Input field background
  static Color inputBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0B0A14)
        : const Color(0xFFF0F2FA);
  }

  /// Primary text
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF2F0FA)
        : const Color(0xFF1A1D2E);
  }

  /// Secondary text
  static Color textSecondary(BuildContext context) => const Color(0xFF94A3B8);

  /// Divider / border
  static Color divider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2D3142)
        : const Color(0xFFE2E5F0);
  }

  // ── Neomorphic Shadow Helpers ──────────────────────────────────────────────
  static Color neoLightShadow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.02)
        : Colors.white;
  }

  static Color neoDarkShadow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withOpacity(0.65)
        : const Color(0xFFA3B1C6).withOpacity(0.45);
  }
}
