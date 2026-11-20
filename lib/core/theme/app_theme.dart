import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Paper-clean Light Palette
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF191C1E);
  static const Color lightTextSecondary = Color(0xFF44474E);
  static const Color lightBorder = Color(0xFFE0E2EC);
  static const Color lightPrimary = Color(0xFF006399);

  // Focus-friendly Dark Palette
  static const Color darkBg = Color(0xFF111315);
  static const Color darkSurface = Color(0xFF1A1C1E);
  static const Color darkTextPrimary = Color(0xFFE2E2E5);
  static const Color darkTextSecondary = Color(0xFF8C9199);
  static const Color darkBorder = Color(0xFF2C2F33);
  static const Color darkPrimary = Color(0xFF90CAF9);

  // Accent Colors for actions
  static const Color deleteColor = Color(0xFFD32F2F);
  static const Color archiveColor = Color(0xFF2E7D32);
  static const Color starColor = Color(0xFFFFA000);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        primary: lightPrimary,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: lightTextPrimary,
          height: 1.6, // Optimal line height for distraction-free reading
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: lightTextSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        surface: darkSurface,
        primary: darkPrimary,
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: darkBorder),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkTextPrimary,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: darkTextSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
