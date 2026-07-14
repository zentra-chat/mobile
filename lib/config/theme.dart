import 'package:flutter/material.dart';

// Zentra brand palette
class ZentraColors {
  static const primary = Color(0xFF00FFA9);
  static const primaryHover = Color(0xFF00E699);
  static const secondary = Color(0xFF01B985);
  static const accent = Color(0xFF073C3A);

  static const background = Color(0xFF0A1427);
  static const backgroundSecondary = Color(0xFF0D1A30);
  static const backgroundTertiary = Color(0xFF111F3A);
  static const surface = Color(0xFF131A2A);
  static const surfaceHover = Color(0xFF1A2540);
  static const surfaceActive = Color(0xFF1F2D4A);

  static const border = Color(0xFF1E3A5F);
  static const borderLight = Color(0xFF2A4A6F);

  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const info = Color(0xFF3B82F6);
  static const error = Color(0xFFF87171);

  static const onBright = Color(0xFF04140F);
}

// Dark theme built to match the Zentra web client
final ThemeData zentraTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    brightness: Brightness.dark,
    primary: ZentraColors.primary,
    onPrimary: ZentraColors.onBright,
    primaryContainer: ZentraColors.accent,
    onPrimaryContainer: ZentraColors.primary,
    secondary: ZentraColors.secondary,
    onSecondary: ZentraColors.onBright,
    tertiary: ZentraColors.primary,
    onTertiary: ZentraColors.onBright,
    error: ZentraColors.danger,
    onError: Colors.white,
    surface: ZentraColors.surface,
    onSurface: ZentraColors.textPrimary,
    surfaceContainerHighest: ZentraColors.backgroundTertiary,
    onSurfaceVariant: ZentraColors.textSecondary,
    outline: ZentraColors.border,
    outlineVariant: ZentraColors.borderLight,
    inverseSurface: ZentraColors.textPrimary,
    onInverseSurface: ZentraColors.background,
    inversePrimary: ZentraColors.secondary,
  ),
  scaffoldBackgroundColor: ZentraColors.background,
  canvasColor: ZentraColors.background,
  cardColor: ZentraColors.surface,
  dividerColor: ZentraColors.border,
  chipTheme: ChipThemeData(
    backgroundColor: ZentraColors.surface,
    selectedColor: ZentraColors.primary,
    secondarySelectedColor: ZentraColors.primary,
    labelStyle: const TextStyle(color: ZentraColors.textPrimary),
    secondaryLabelStyle: const TextStyle(color: ZentraColors.onBright),
    brightness: Brightness.dark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: ZentraColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ZentraColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ZentraColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ZentraColors.primary),
    ),
    labelStyle: const TextStyle(color: ZentraColors.textSecondary),
    hintStyle: const TextStyle(color: ZentraColors.textMuted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(ZentraColors.primary),
      foregroundColor: WidgetStatePropertyAll(ZentraColors.onBright),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(ZentraColors.textSecondary),
    ),
  ),
);
