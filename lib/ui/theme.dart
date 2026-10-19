import 'package:flutter/material.dart';

import '../data/models.dart';

class AppColors {
  static const turquoise = Color(0xFF3FA9A0);
  static const turquoiseLight = Color(0xFFD9F3F0);
  static const turquoiseDarkBg = Color(0xFF1C3533);
  static const text = Color(0xFF1F2D2C);
  static const moodGood = Color(0xFF5CC48A);
  static const moodNeutral = Color(0xFFFFFFFF);
  static const moodBad = Color(0xFFE06B6B);
}

Color moodColor(Mood m) => switch (m) {
  Mood.good => AppColors.moodGood,
  Mood.neutral => AppColors.moodNeutral,
  Mood.bad => AppColors.moodBad,
};

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

/// Цвет и значок шаблона пометки.
({Color color, IconData icon}) noteStyle(NoteTemplate t) => switch (t) {
  NoteTemplate.moment => (
    color: const Color(0xFF9FE0D9),
    icon: Icons.bolt_outlined,
  ),
  NoteTemplate.thought => (
    color: const Color(0xFFD7C4F2),
    icon: Icons.psychology_outlined,
  ),
  NoteTemplate.gratitude => (
    color: const Color(0xFFF6E7B8),
    icon: Icons.volunteer_activism_outlined,
  ),
  NoteTemplate.joy => (
    color: const Color(0xFFFFD1B8),
    icon: Icons.sentiment_satisfied_alt_outlined,
  ),
  NoteTemplate.quote => (
    color: const Color(0xFFCFE0F5),
    icon: Icons.format_quote_outlined,
  ),
  NoteTemplate.plan => (
    color: const Color(0xFFBFE8C9),
    icon: Icons.event_outlined,
  ),
  NoteTemplate.free => (
    color: const Color(0xFFE6ECEB),
    icon: Icons.edit_note_outlined,
  ),
};
