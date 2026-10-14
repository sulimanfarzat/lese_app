import 'package:flutter/material.dart';

/// Bunte, kindliche Farben – passend zur grünen Echse.
class KasemColors {
  static const green = Color(0xFF34B85A); // Echsen-Grün
  static const greenDark = Color(0xFF1F7A3A);
  static const yellow = Color(0xFFFFD23F); // Sonnen-Gelb (Punkte)
  static const sky = Color(0xFF4FC3F7); // Himmel-Blau (Rekord)
  static const pink = Color(0xFFFF6FAE); // Geschenke
  static const orange = Color(0xFFFF9F43);
  static const purple = Color(0xFF9C6ADE);
  static const cream = Color(0xFFFFF8E1); // Hintergrund
  static const ink = Color(0xFF3B2C4A); // Textfarbe (dunkles Lila statt Schwarz)
}

ThemeData kasemTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KasemColors.green,
    brightness: Brightness.light,
  ).copyWith(
    primary: KasemColors.green,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFC8F2D2),
    secondary: KasemColors.orange,
    tertiary: KasemColors.pink,
    tertiaryContainer: const Color(0xFFFFD6E8),
    surface: KasemColors.cream,
    onSurface: KasemColors.ink,
    surfaceContainerHighest: const Color(0xFFFFEFC2),
  );

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KasemColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: KasemColors.green,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        side: const BorderSide(color: KasemColors.pink, width: 3),
        foregroundColor: KasemColors.ink,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? KasemColors.yellow : Colors.white),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KasemColors.green,
      linearTrackColor: Color(0xFFFFE9A8),
    ),
    textTheme: Typography.blackMountainView.apply(
      bodyColor: KasemColors.ink,
      displayColor: KasemColors.ink,
    ),
  );
}
