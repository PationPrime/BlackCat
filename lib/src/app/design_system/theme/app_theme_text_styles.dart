import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'app_theme_colors.dart';

class AppThemeTextStyles extends ThemeExtension<AppThemeTextStyles> {
  // Headings

  /// Card title: video name
  final TextStyle header4Semibold;

  /// App name in the header
  final TextStyle header5Semibold;

  // Body

  /// Text in input fields
  final TextStyle bodyRegular;

  /// Primary button titles
  final TextStyle bodyMedium;

  // Caption

  /// Metadata, progress, error messages
  final TextStyle captionRegular;

  /// Small button titles
  final TextStyle captionMedium;

  /// Address in the sign-in window title bar
  final TextStyle footnoteRegular;

  // Overline

  /// Group titles ("QUALITY")
  final TextStyle overlineRegular;

  const AppThemeTextStyles({
    required this.header4Semibold,
    required this.header5Semibold,
    required this.bodyRegular,
    required this.bodyMedium,
    required this.captionRegular,
    required this.captionMedium,
    required this.footnoteRegular,
    required this.overlineRegular,
  });

  @override
  ThemeExtension<AppThemeTextStyles> copyWith({
    TextStyle? header4Semibold,
    TextStyle? header5Semibold,
    TextStyle? bodyRegular,
    TextStyle? bodyMedium,
    TextStyle? captionRegular,
    TextStyle? captionMedium,
    TextStyle? footnoteRegular,
    TextStyle? overlineRegular,
  }) => AppThemeTextStyles(
    header4Semibold: header4Semibold ?? this.header4Semibold,
    header5Semibold: header5Semibold ?? this.header5Semibold,
    bodyRegular: bodyRegular ?? this.bodyRegular,
    bodyMedium: bodyMedium ?? this.bodyMedium,
    captionRegular: captionRegular ?? this.captionRegular,
    captionMedium: captionMedium ?? this.captionMedium,
    footnoteRegular: footnoteRegular ?? this.footnoteRegular,
    overlineRegular: overlineRegular ?? this.overlineRegular,
  );

  @override
  ThemeExtension<AppThemeTextStyles> lerp(
    covariant ThemeExtension<AppThemeTextStyles>? other,
    double t,
  ) {
    if (other is! AppThemeTextStyles) {
      return this;
    }

    return AppThemeTextStyles(
      header4Semibold: TextStyle.lerp(header4Semibold, other.header4Semibold, t)!,
      header5Semibold: TextStyle.lerp(header5Semibold, other.header5Semibold, t)!,
      bodyRegular: TextStyle.lerp(bodyRegular, other.bodyRegular, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      captionRegular: TextStyle.lerp(captionRegular, other.captionRegular, t)!,
      captionMedium: TextStyle.lerp(captionMedium, other.captionMedium, t)!,
      footnoteRegular: TextStyle.lerp(footnoteRegular, other.footnoteRegular, t)!,
      overlineRegular: TextStyle.lerp(overlineRegular, other.overlineRegular, t)!,
    );
  }

  static AppThemeTextStyles _fromColors(AppThemeColors colors) =>
      AppThemeTextStyles(
        header4Semibold: AppTextStyles.segoeUISemibold.copyWith(
          color: colors.textPrimary,
          fontSize: 20,
          height: 1.375,
        ),
        header5Semibold: AppTextStyles.segoeUISemibold.copyWith(
          color: colors.textHeader,
          fontSize: 18,
          height: 28 / 18,
          letterSpacing: -0.45,
        ),
        bodyRegular: AppTextStyles.segoeUIRegular.copyWith(
          color: colors.textPrimary,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: AppTextStyles.segoeUIMedium.copyWith(
          color: colors.textPrimary,
          fontSize: 16,
          height: 1.5,
        ),
        captionRegular: AppTextStyles.segoeUIRegular.copyWith(
          color: colors.textSecondary,
        ),
        captionMedium: AppTextStyles.segoeUIMedium.copyWith(
          color: colors.textSecondary,
        ),
        footnoteRegular: AppTextStyles.segoeUIRegular.copyWith(
          color: colors.textTertiary,
          fontSize: 13,
          height: 18 / 13,
        ),
        overlineRegular: AppTextStyles.segoeUIRegular.copyWith(
          color: colors.textHint,
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: 1.2,
        ),
      );

  static final lightThemeTextStyles = _fromColors(AppThemeColors.light);

  static final darkThemeTextStyles = _fromColors(AppThemeColors.dark);
}
