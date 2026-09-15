import 'dart:ui';

/// App interface language
enum AppLanguageModel {
  russian(locale: Locale('ru', 'RU'), nativeName: 'Русский'),
  english(locale: Locale('en', 'US'), nativeName: 'English');

  /// Language used until the user chooses another one
  static const fallback = russian;

  final Locale locale;

  /// Name in the language itself: recognizable whatever language is on now
  final String nativeName;

  const AppLanguageModel({required this.locale, required this.nativeName});

  /// Code stored in the settings
  String get code => locale.languageCode;

  static List<Locale> get supportedLocales => [
    for (final language in values) language.locale,
  ];

  /// Language by the stored code; [fallback] for an unknown or missing code
  static AppLanguageModel fromCode(String? code) =>
      values.where((language) => language.code == code).firstOrNull ??
      fallback;
}
