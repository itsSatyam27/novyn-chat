import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Novyn theme – ported from the web app (apps/web/src/styles/glass.css).
///
///  • Light : soft lavender glass, white surfaces, ink #24213F
///  • Dark  : near-black indigo (#08090D / #101021), ink #F0EFFF
///  • Accent: indigo #6D5DFC (hover #5746E8)
///  • Font  : Plus Jakarta Sans (bundled in assets/fonts)
class NovynTheme {
  static const String fontFamily = 'PlusJakartaSans';

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color indigo = Color(0xFF6D5DFC);
  static const Color indigoHover = Color(0xFF5746E8);
  static const Color indigoDeep = Color(0xFF4F46C8);

  // ── Pastel color palette for splash & auth screens ────────────────────────
  static const Color pastelPurple = Color(0xFFB8A6F3);
  static const Color pastelPink = Color(0xFFF4A8D6);
  static const Color pastelTeal = Color(0xFF7DD3D3);
  static const Color pastelLavender = Color(0xFFD4C4F8);
  static const Color pastelPeach = Color(0xFFFAD7BB);

  // ── Light tokens (web :root) ──────────────────────────────────────────────
  static const Color _lBg = Color(0xFFFBFAFF);
  static const Color _lSurface = Color(0xFFFFFFFF);
  static const Color _lMuted = Color(0xFFF7F6FF);
  static const Color _lField = Color(0xFFF5F3FF);
  static const Color _lInk = Color(0xFF24213F);
  static const Color _lMeta = Color(0xFF6D6A87);
  static const Color _lSoft = Color(0xFFECE9FF);
  static const Color _lBorder = Color(0x336D5DFC); // rgba(109,93,252,.2)
  static const Color _lDivider = Color(0x1F6D5DFC);

  // ── Dark tokens (web :root[data-color-mode="dark"]) ───────────────────────
  static const Color _dBg = Color(0xFF08090D);
  static const Color _dSurface = Color(0xFF101021);
  static const Color _dCard = Color(0xFF13141D);
  static const Color _dField = Color(0xFF161722);
  static const Color _dInk = Color(0xFFF0EFFF);
  static const Color _dMeta = Color(0xFFAAA8C6);
  static const Color _dSoft = Color(0xFF292457);
  static const Color _dBorder = Color(0x3D9A90FF); // rgba(154,144,255,.24)
  static const Color _dDivider = Color(0x21DAD6FF); // rgba(218,214,255,.13)
  static const Color _dRaised = Color(0xFF1B1A35); // header buttons

  static ThemeData lightTheme({Color accent = indigo, double fontScale = 1}) => _build(Brightness.light, accent, fontScale);
  static ThemeData darkTheme({Color accent = indigo, double fontScale = 1}) => _build(Brightness.dark, accent, fontScale);

  static ThemeData _build(Brightness brightness, Color accent, double fontScale) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? _dInk : _lInk;
    final meta = dark ? _dMeta : _lMeta;
    final surface = dark ? _dSurface : _lSurface;
    final field = dark ? _dField : _lField;
    final border = dark ? _dBorder : _lBorder;

    final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      primaryContainer: dark ? _dSoft : _lSoft,
      onPrimaryContainer: dark ? const Color(0xFFCFCAFF) : const Color(0xFF292056),
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: dark ? _dRaised : const Color(0xFFF5F3FF),
      onSurfaceVariant: meta,
      outline: meta,
      outlineVariant: border,
      error: const Color(0xFFFF5C7A),
    );

    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    ).apply(bodyColor: ink, displayColor: ink).copyWith(
      bodyLarge: base.bodyLarge?.copyWith(fontSize: (base.bodyLarge?.fontSize ?? 16) * fontScale),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: (base.bodyMedium?.fontSize ?? 14) * fontScale),
      bodySmall: base.bodySmall?.copyWith(fontSize: (base.bodySmall?.fontSize ?? 12) * fontScale),
      titleLarge: base.titleLarge?.copyWith(fontSize: (base.titleLarge?.fontSize ?? 22) * fontScale),
      titleMedium: base.titleMedium?.copyWith(fontSize: (base.titleMedium?.fontSize ?? 16) * fontScale),
      titleSmall: base.titleSmall?.copyWith(fontSize: (base.titleSmall?.fontSize ?? 14) * fontScale),
    );

    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: fontFamily,
      // Kept transparent like before – screens/backdrops paint their own bg.
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: scheme,
      cardColor: dark ? _dCard : _lSurface,
      cardTheme: CardThemeData(
        color: dark ? _dCard : _lSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(accent, 1.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: dark ? const Color(0xFF827F98) : meta),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent
              : (dark ? const Color(0xFF3A3955) : const Color(0xFFCFCBE8)),
        ),
      ),
      dividerColor: dark ? _dDivider : _lDivider,
      textTheme: base,
    );
  }

  // ── Semantic color helpers (use these in screens) ─────────────────────────
  /// Card / tile background
  static Color cardBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dCard : _lSurface;

  /// Page / section background
  static Color pageBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dBg : _lBg;

  /// Input field background
  static Color inputBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dField : _lField;

  /// Primary text
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dInk : _lInk;

  /// Secondary text
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dMeta : _lMeta;

  /// Divider / border
  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dDivider : _lDivider;

  // ── Neomorphic Shadow Helpers ──────────────────────────────────────────────
  static Color neoLightShadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.02)
          : Colors.white;

  static Color neoDarkShadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withOpacity(0.65)
          : const Color(0xFF3F358B).withOpacity(0.12);
}
