import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  /// Фон экранов
  final Color background;

  /// Свечение в шапке экрана
  final Color backgroundGlow;

  /// Поля ввода и панели поверх фона
  final Color surface;

  /// Карточки
  final Color card;

  final Color border;
  final Color borderHover;

  /// Подсветка прозрачных кнопок при наведении
  final Color hoverOverlay;

  /// Основной текст: заголовки карточек, ввод
  final Color textPrimary;

  /// Название приложения в шапке
  final Color textHeader;

  /// Второстепенный текст: подписи кнопок, прогресс
  final Color textSecondary;

  /// Метаданные: канал, длительность, статусы
  final Color textTertiary;

  /// Подсказки, заголовки групп, неактивное
  final Color textHint;

  final Color iconPrimary;
  final Color iconDisabled;

  /// Фирменный акцент: основная кнопка, выбор, прогресс
  final Color accent;
  final Color accentHover;

  /// Фон выбранного элемента
  final Color accentSubtle;

  /// Выделение текста
  final Color textSelection;

  /// Текст и иконки на акцентном фоне
  final Color onAccent;

  /// Нейтральная кнопка («Найти»)
  final Color buttonNeutral;
  final Color buttonNeutralHover;
  final Color onButtonNeutral;

  final Color errorBackground;
  final Color errorBorder;
  final Color errorText;

  /// Кнопка действия внутри сообщения об ошибке
  final Color errorActionText;
  final Color errorActionBorder;
  final Color errorActionHover;

  final Color transparent;

  const AppThemeColors({
    required this.background,
    required this.backgroundGlow,
    required this.surface,
    required this.card,
    required this.border,
    required this.borderHover,
    required this.hoverOverlay,
    required this.textPrimary,
    required this.textHeader,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.iconPrimary,
    required this.iconDisabled,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.textSelection,
    required this.onAccent,
    required this.buttonNeutral,
    required this.buttonNeutralHover,
    required this.onButtonNeutral,
    required this.errorBackground,
    required this.errorBorder,
    required this.errorText,
    required this.errorActionText,
    required this.errorActionBorder,
    required this.errorActionHover,
    required this.transparent,
  });

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? backgroundGlow,
    Color? surface,
    Color? card,
    Color? border,
    Color? borderHover,
    Color? hoverOverlay,
    Color? textPrimary,
    Color? textHeader,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? iconPrimary,
    Color? iconDisabled,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? textSelection,
    Color? onAccent,
    Color? buttonNeutral,
    Color? buttonNeutralHover,
    Color? onButtonNeutral,
    Color? errorBackground,
    Color? errorBorder,
    Color? errorText,
    Color? errorActionText,
    Color? errorActionBorder,
    Color? errorActionHover,
    Color? transparent,
  }) => AppThemeColors(
    background: background ?? this.background,
    backgroundGlow: backgroundGlow ?? this.backgroundGlow,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    border: border ?? this.border,
    borderHover: borderHover ?? this.borderHover,
    hoverOverlay: hoverOverlay ?? this.hoverOverlay,
    textPrimary: textPrimary ?? this.textPrimary,
    textHeader: textHeader ?? this.textHeader,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    textHint: textHint ?? this.textHint,
    iconPrimary: iconPrimary ?? this.iconPrimary,
    iconDisabled: iconDisabled ?? this.iconDisabled,
    accent: accent ?? this.accent,
    accentHover: accentHover ?? this.accentHover,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    textSelection: textSelection ?? this.textSelection,
    onAccent: onAccent ?? this.onAccent,
    buttonNeutral: buttonNeutral ?? this.buttonNeutral,
    buttonNeutralHover: buttonNeutralHover ?? this.buttonNeutralHover,
    onButtonNeutral: onButtonNeutral ?? this.onButtonNeutral,
    errorBackground: errorBackground ?? this.errorBackground,
    errorBorder: errorBorder ?? this.errorBorder,
    errorText: errorText ?? this.errorText,
    errorActionText: errorActionText ?? this.errorActionText,
    errorActionBorder: errorActionBorder ?? this.errorActionBorder,
    errorActionHover: errorActionHover ?? this.errorActionHover,
    transparent: transparent ?? this.transparent,
  );

  @override
  ThemeExtension<AppThemeColors> lerp(
    ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textHeader: Color.lerp(textHeader, other.textHeader, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconDisabled: Color.lerp(iconDisabled, other.iconDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      textSelection: Color.lerp(textSelection, other.textSelection, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      buttonNeutral: Color.lerp(buttonNeutral, other.buttonNeutral, t)!,
      buttonNeutralHover: Color.lerp(
        buttonNeutralHover,
        other.buttonNeutralHover,
        t,
      )!,
      onButtonNeutral: Color.lerp(onButtonNeutral, other.onButtonNeutral, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      errorActionText: Color.lerp(errorActionText, other.errorActionText, t)!,
      errorActionBorder: Color.lerp(
        errorActionBorder,
        other.errorActionBorder,
        t,
      )!,
      errorActionHover: Color.lerp(
        errorActionHover,
        other.errorActionHover,
        t,
      )!,
      transparent: Color.lerp(transparent, other.transparent, t)!,
    );
  }

  static const light = AppThemeColors(
    background: AppColors.stoneFAFAF9,
    backgroundGlow: AppColors.amberF59E0BAlpha12,
    surface: AppColors.white,
    card: AppColors.white,
    border: AppColors.black10,
    borderHover: AppColors.black30,
    hoverOverlay: AppColors.black5,
    textPrimary: AppColors.stone1C1917,
    textHeader: AppColors.stone0C0A09,
    textSecondary: AppColors.stone44403C,
    textTertiary: AppColors.stone57534E,
    textHint: AppColors.stoneA8A29E,
    iconPrimary: AppColors.stone44403C,
    iconDisabled: AppColors.stoneA8A29E,
    accent: AppColors.amberD97706,
    accentHover: AppColors.amberB45309,
    accentSubtle: AppColors.amberD97706Alpha10,
    textSelection: AppColors.amberF59E0BAlpha35,
    onAccent: AppColors.stone0C0A09,
    buttonNeutral: AppColors.stone1C1917,
    buttonNeutralHover: AppColors.stone292524,
    onButtonNeutral: AppColors.stoneFAFAF9,
    errorBackground: AppColors.redF87171Alpha10,
    errorBorder: AppColors.redF87171Alpha30,
    errorText: AppColors.redB91C1C,
    errorActionText: AppColors.red991B1B,
    errorActionBorder: AppColors.redB91C1CAlpha40,
    errorActionHover: AppColors.redF87171Alpha10,
    transparent: AppColors.transparent,
  );

  static const dark = AppThemeColors(
    background: AppColors.stone0C0A09,
    backgroundGlow: AppColors.amberF59E0BAlpha16,
    surface: AppColors.stone1C1917,
    card: AppColors.stone1C1917Alpha70,
    border: AppColors.white10,
    borderHover: AppColors.white30,
    hoverOverlay: AppColors.white5,
    textPrimary: AppColors.stoneFAFAF9,
    textHeader: AppColors.stoneF5F5F4,
    textSecondary: AppColors.stoneD6D3D1,
    textTertiary: AppColors.stoneA8A29E,
    textHint: AppColors.stone78716C,
    iconPrimary: AppColors.stoneD6D3D1,
    iconDisabled: AppColors.stone78716C,
    accent: AppColors.amberF59E0B,
    accentHover: AppColors.amberD97706,
    accentSubtle: AppColors.amberF59E0BAlpha10,
    textSelection: AppColors.amberF59E0BAlpha35,
    onAccent: AppColors.stone0C0A09,
    buttonNeutral: AppColors.stoneF5F5F4,
    buttonNeutralHover: AppColors.white,
    onButtonNeutral: AppColors.stone0C0A09,
    errorBackground: AppColors.redF87171Alpha10,
    errorBorder: AppColors.redF87171Alpha30,
    errorText: AppColors.redFECACA,
    errorActionText: AppColors.redFEE2E2,
    errorActionBorder: AppColors.redFCA5A5Alpha40,
    errorActionHover: AppColors.redF87171Alpha10,
    transparent: AppColors.transparent,
  );
}
