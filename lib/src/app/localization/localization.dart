import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'lang/codegen_loader.g.dart';

part 'app_locale_rebuilder.dart';

class AppLocalization extends StatelessWidget {
  final WidgetBuilder builder;

  /// Language of the first frame: the one saved in the settings
  final Locale startLocale;

  const AppLocalization({
    super.key,
    required this.builder,
    required this.startLocale,
  });

  @override
  Widget build(BuildContext context) => EasyLocalization(
    path: 'assets/lang/',
    supportedLocales: AppLanguageModel.supportedLocales,
    fallbackLocale: AppLanguageModel.fallback.locale,
    startLocale: startLocale,
    assetLoader: const CodegenLoader(),

    /// The language is stored by the settings repository
    saveLocale: false,
    child: Builder(builder: builder),
  );
}
