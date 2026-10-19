import 'package:flutter/material.dart';

class AppColors {
  static const turquoise = Color(0xFF3FA9A0);
  static const turquoiseLight = Color(0xFFD9F3F0);
  static const turquoiseDarkBg = Color(0xFF1C3533);
  static const text = Color(0xFF1F2D2C);
}

/// Цвет текста, читаемый на фоне текстовой сторис.
Color onTextStory(Color bg) =>
    bg.computeLuminance() > 0.45 ? AppColors.text : Colors.white;

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.turquoise,
        brightness: b,
      ).copyWith(
        primary: AppColors.turquoise,
        surface: dark ? const Color(0xFF121515) : Colors.white,
        onSurface: dark ? const Color(0xFFE8F0EF) : AppColors.text,
        primaryContainer: dark
            ? AppColors.turquoiseDarkBg
            : AppColors.turquoiseLight,
        onPrimaryContainer: dark
            ? const Color(0xFFBFEDE7)
            : const Color(0xFF1F5E58),
        surfaceContainerHighest: dark
            ? const Color(0xFF1E2423)
            : const Color(0xFFF3FAF9),
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.turquoise, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.turquoise,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 46),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 46),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
  );
}
