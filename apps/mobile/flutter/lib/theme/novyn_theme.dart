import 'package:flutter/material.dart';

class NovynTheme {
  static const background = Color(0xFF080B13);
  static const surface = Color(0xFF111827);
  static const raised = Color(0xFF172235);
  static const accent = Color(0xFF8B7CFF);
  static const teal = Color(0xFF55D6C2);
  static const text = Color(0xFFF4F6FC);
  static const muted = Color(0xFF9AA6B8);
  static const line = Color(0xFF283548);

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accent, secondary: teal, surface: surface,
      error: Color(0xFFFF7185),
    ),
    scaffoldBackgroundColor: background,
    textTheme: ThemeData.dark().textTheme.apply(bodyColor: text, displayColor: text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raised,
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: teal)),
    dividerColor: line,
  );
}
