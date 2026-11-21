import 'package:flutter/material.dart';

/// Available theme modes in CleanMail.
enum AppThemeMode {
  system(
    'System Default',
    'Follows your device light or dark appearance (Default)',
    Icons.brightness_auto_outlined,
  ),
  light(
    'Paper Light',
    'Minimalist daylight high-contrast reading',
    Icons.light_mode_outlined,
  ),
  dark(
    'Focus Dark',
    'Modern, low-glare deep dark theme',
    Icons.dark_mode_outlined,
  ),
  nerd(
    'Terminal Nerd',
    'Retro hacker console, CRT phosphor green & JetBrains Mono',
    Icons.terminal_outlined,
  );

  final String label;
  final String description;
  final IconData icon;

  const AppThemeMode(this.label, this.description, this.icon);

  static AppThemeMode fromString(String? val) {
    if (val == null) return AppThemeMode.system;
    return AppThemeMode.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => AppThemeMode.system,
    );
  }
}

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

  // Nerd / Terminal Palette (Retro CRT Phosphor Matrix)
  static const Color nerdBg = Color(0xFF050805);
  static const Color nerdSurface = Color(0xFF0A120A);
  static const Color nerdPrimary = Color(0xFF00FF66); // Electric CRT Phosphor Green
  static const Color nerdTextPrimary = Color(0xFF00FF66);
  static const Color nerdTextSecondary = Color(0xFF009E3F); // Dim Matrix Green
  static const Color nerdBorder = Color(0xFF003814); // Terminal Grid Border
  static const Color nerdAccentCyan = Color(0xFF00E5FF); // Terminal Cyan for archive/links
  static const Color nerdAccentRed = Color(0xFFFF3344); // Terminal Red for delete/errors
  static const Color nerdAccentYellow = Color(0xFFFFDD00); // Terminal Amber for warnings

  // Standard Accent Colors for actions
  static const Color deleteColor = Color(0xFFD32F2F);
  static const Color archiveColor = Color(0xFF2E7D32);
  static const Color starColor = Color(0xFFFFA000);

  // --------------------------------------------------------------------------
  // CONTEXT-AWARE THEME GETTERS
  // --------------------------------------------------------------------------

  /// Developer / terminal font used in Nerd mode.
  static const String nerdFontFamily = 'JetBrainsMono';

  static bool isNerd(BuildContext context) {
    return Theme.of(context).colorScheme.primary == nerdPrimary;
  }

  /// Returns JetBrains Mono if in Nerd theme, or null for default system sans-serif.
  static String? fontFamily(BuildContext context) {
    return isNerd(context) ? nerdFontFamily : null;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    final theme = Theme.of(context);
    if (isNerd(context)) {
      return nerdTextSecondary;
    }
    return theme.brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color background(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  // --------------------------------------------------------------------------
  // THEME DEFINITIONS
  // --------------------------------------------------------------------------

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
          height: 1.6,
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

  /// Retro Terminal / Hacker Nerd Theme with phosphor green matrix and JetBrains Mono developer typography.
  static ThemeData get nerdTheme {
    const monoFamily = nerdFontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: nerdBg,
      fontFamily: monoFamily,
      colorScheme: const ColorScheme.dark(
        surface: nerdSurface,
        primary: nerdPrimary,
        secondary: nerdAccentCyan,
        onSurface: nerdTextPrimary,
        outline: nerdBorder,
        error: nerdAccentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: nerdBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: monoFamily,
          color: nerdTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: nerdTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: nerdSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: nerdBorder, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: nerdSurface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: nerdPrimary, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: monoFamily,
          color: nerdTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: monoFamily,
          color: nerdTextSecondary,
          fontSize: 13.5,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: nerdSurface,
        selectedColor: const Color(0xFF003814),
        side: const BorderSide(color: nerdBorder),
        labelStyle: const TextStyle(
          fontFamily: monoFamily,
          color: nerdTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerTheme: const DividerThemeData(
        color: nerdBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: nerdSurface,
        filled: true,
        hintStyle: const TextStyle(
          fontFamily: monoFamily,
          color: nerdTextSecondary,
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          fontFamily: monoFamily,
          color: nerdTextPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: nerdBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: nerdBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: nerdPrimary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: nerdPrimary,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(
            fontFamily: monoFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: nerdPrimary,
          side: const BorderSide(color: nerdPrimary),
          textStyle: const TextStyle(
            fontFamily: monoFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: monoFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: nerdTextPrimary,
          letterSpacing: 0.5,
        ),
        titleMedium: TextStyle(
          fontFamily: monoFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: nerdTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: monoFamily,
          fontSize: 14.5,
          color: nerdTextPrimary,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: monoFamily,
          fontSize: 13,
          color: nerdTextSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontFamily: monoFamily,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: nerdTextPrimary,
        ),
      ),
    );
  }
}
