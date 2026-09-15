import 'package:flutter/material.dart';

import 'app_theme_data.dart';

part 'app_theme_type.dart';

class AppThemeConfig extends StatelessWidget {
  final AppThemeType type;
  final Widget child;

  const AppThemeConfig({super.key, required this.type, required this.child});

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData;

    if (type.isDark) {
      themeData = AppThemeData.darkTheme;
    } else if (type.isLight) {
      themeData = AppThemeData.lightTheme;
    } else if (type.isOSTheme) {
      final brightness = MediaQuery.platformBrightnessOf(context);

      themeData = brightness == Brightness.dark
          ? AppThemeData.darkTheme
          : AppThemeData.lightTheme;
    } else {
      themeData = AppThemeData.fallbackTheme;
    }

    return AppTheme(themeData: themeData, child: child);
  }
}

class AppTheme extends InheritedWidget {
  final ThemeData themeData;

  const AppTheme({super.key, required super.child, required this.themeData});

  static ThemeData of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppTheme>();

    return result?.themeData ?? AppThemeData.fallbackTheme;
  }

  @override
  bool updateShouldNotify(covariant AppTheme oldWidget) =>
      oldWidget.themeData != themeData;
}
