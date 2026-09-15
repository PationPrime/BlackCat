import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/localization/lang/codegen_loader.g.dart';
import 'package:youtube_downloader/src/app/models/models.dart';

final _placeholderPattern = RegExp(r'\{(\w+)\}');

/// `{'app.title': 'YT Download', ...}` from nested translations
Map<String, String> _flatten(Map<String, dynamic> translations, [String prefix = '']) => {
  for (final MapEntry(:key, :value) in translations.entries)
    ...switch (value) {
      Map<String, dynamic> nested => _flatten(nested, '$prefix$key.'),
      _ => {'$prefix$key': '$value'},
    },
};

Set<String> _placeholders(String text) => {
  for (final match in _placeholderPattern.allMatches(text)) match.group(1)!,
};

void main() {
  final russian = _flatten(CodegenLoader.mapLocales['ru_RU']!);
  final english = _flatten(CodegenLoader.mapLocales['en_US']!);

  test('у каждого языка приложения есть переводы', () {
    for (final language in AppLanguageModel.values) {
      expect(CodegenLoader.mapLocales.keys, contains(language.locale.toString()));
    }
  });

  test('в английском те же ключи, что в русском', () {
    expect(english.keys.toSet(), russian.keys.toSet());
  });

  test('подстановки в переводах совпадают', () {
    for (final key in russian.keys) {
      expect(_placeholders(english[key]!), _placeholders(russian[key]!), reason: key);
    }
  });
}
