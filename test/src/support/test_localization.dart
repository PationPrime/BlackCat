// ignore_for_file: implementation_imports

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:peeky_cat/src/app/localization/lang/codegen_loader.g.dart';

/// Loads Russian translations without the EasyLocalization widget
void loadTestTranslations() {
  Localization.load(
    const Locale('ru', 'RU'),
    translations: Translations(CodegenLoader.mapLocales['ru_RU']!),
  );
}
