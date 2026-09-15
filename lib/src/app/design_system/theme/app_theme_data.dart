import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'app_theme_text_styles.dart';

abstract base class AppThemeData {
  /// Application light text selection theme data
  static final lightTextSelectionTheme = TextSelectionThemeData(
    cursorColor: AppThemeColors.light.textPrimary,
    selectionColor: AppThemeColors.light.textSelection,
    selectionHandleColor: AppThemeColors.light.accent,
  );

  /// Application dark text selection theme data
  static final darkTextSelectionTheme = TextSelectionThemeData(
    cursorColor: AppThemeColors.dark.textPrimary,
    selectionColor: AppThemeColors.dark.textSelection,
    selectionHandleColor: AppThemeColors.dark.accent,
  );

  /// Application light theme data
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppThemeColors.light.background,
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppThemeColors.light.accent,
      surface: AppThemeColors.light.surface,
    ),
    textSelectionTheme: lightTextSelectionTheme,
    extensions: <ThemeExtension<dynamic>>[
      AppThemeColors.light,
      AppThemeTextStyles.lightThemeTextStyles,
    ],
  );

  /// Application dark theme data
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppThemeColors.dark.background,
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: AppThemeColors.dark.accent,
      surface: AppThemeColors.dark.surface,
    ),
    textSelectionTheme: darkTextSelectionTheme,
    extensions: <ThemeExtension<dynamic>>[
      AppThemeColors.dark,
      AppThemeTextStyles.darkThemeTextStyles,
    ],
  );

  /// Application fallback theme
  static final fallbackTheme = darkTheme;
}
