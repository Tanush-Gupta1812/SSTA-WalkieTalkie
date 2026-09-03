import 'package:flutter/material.dart';

class WalkieTheme {
  // Obsidian Audio Utility Design System Palette
  static const Color background = Color(0xFF121315);
  static const Color surfaceLowest = Color(0xFF0D0E10);
  static const Color surfaceCard = Color(0xFF1A1C20);
  static const Color surfaceCardElevated = Color(0xFF22252A);
  static const Color surfaceCardBorder = Color(0x1FFFFFFF);

  // Accents & Telemetry
  static const Color primaryAmber = Color(0xFFF59E0B);
  static const Color primaryAmberLight = Color(0xFFFFC174);
  static const Color readyEmerald = Color(0xFF10B981);
  static const Color alertCrimson = Color(0xFFEF4444);

  // Typography Tones
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAmber,
      colorScheme: const ColorScheme.dark(
        primary: primaryAmber,
        secondary: readyEmerald,
        surface: surfaceCard,
        error: alertCrimson,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceCardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: const Color(0xFF472A00),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }
}
