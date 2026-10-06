import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovynTheme {
  static const Color _primary   = Color(0xFF7C6FF7);
  static const Color _secondary = Color(0xFFEC4899);

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
        surfaceContainerHighest:Color(0xFFEAECF5),
        onSurface:              Color(0xFF1A1D2E),
        onSurfaceVariant:       Color(0xFF94A3B8),
        outline:                Color(0xFFE2E5F0),
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
        fillColor: const Color(0xFFF0F2FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E5F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E5F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
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
        surface:                Color(0xFF0C0C14),
        surfaceContainerHighest:Color(0xFF1A1A28),
        onSurface:              Color(0xFFF8FAFC),
        onSurfaceVariant:       Color(0xFF94A3B8),
        outline:                Color(0xFF1A1A28),
      ),
      cardColor: const Color(0xFF1A1D2B),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1D2B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0C0C14),
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D3142),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D3142)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D3142)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      dividerColor: const Color(0xFF2D3142),
      textTheme: _textTheme,
      useMaterial3: true,
    );
  }

  // ── Semantic color helpers (use these in screens) ─────────────────────────
  /// Card / tile background
  static Color cardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E2235)
        : Colors.white;
  }

  /// Page / section background
  static Color pageBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0C0C14)
        : const Color(0xFFF0F2FA);
  }

  /// Input field background
  static Color inputBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF252840)
        : const Color(0xFFF0F2FA);
  }

  /// Primary text
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF8FAFC)
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
