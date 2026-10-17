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

/// Role colours arrive from the backend as hex strings, with or without an
/// alpha byte and with or without a leading hash.
Color? parseRoleColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) {
    final parsed = int.tryParse('ff$hex', radix: 16);
    return parsed == null ? null : Color(parsed);
  }
  if (hex.length == 8) {
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
  return null;
}

// Dark theme built to match the web client
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
  appBarTheme: const AppBarTheme(
    backgroundColor: ZentraColors.backgroundSecondary,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: ZentraColors.textSecondary),
    actionsIconTheme: IconThemeData(color: ZentraColors.textSecondary),
    titleTextStyle: TextStyle(
      color: ZentraColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    shape: Border(bottom: BorderSide(color: ZentraColors.border)),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: ZentraColors.textSecondary,
    textColor: ZentraColors.textPrimary,
  ),
  dividerTheme: const DividerThemeData(
    color: ZentraColors.border,
    thickness: 1,
    space: 1,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: ZentraColors.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: ZentraColors.backgroundSecondary,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: ZentraColors.surfaceHover,
    contentTextStyle: TextStyle(color: ZentraColors.textPrimary),
    behavior: SnackBarBehavior.floating,
  ),
);
