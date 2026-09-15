import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'lang/codegen_loader.g.dart';

class AppLocalization extends StatelessWidget {
  static const Locale _ru = Locale('ru', 'RU');
  static const List<Locale> _fallbackSupportedLocales = [_ru];
  static const Locale _defaultFallbackLocale = _ru;

  final WidgetBuilder builder;
  final List<Locale>? supportedLocales;
  final Locale? fallbackLocale;

  const AppLocalization({
    super.key,
    required this.builder,
    this.supportedLocales,
    this.fallbackLocale,
  });

  @override
  Widget build(BuildContext context) => EasyLocalization(
    path: 'assets/lang/',
    supportedLocales: supportedLocales ?? _fallbackSupportedLocales,
    fallbackLocale: fallbackLocale ?? _defaultFallbackLocale,
    startLocale: _defaultFallbackLocale,
    assetLoader: const CodegenLoader(),
    saveLocale: false,
    child: Builder(builder: builder),
  );
}
