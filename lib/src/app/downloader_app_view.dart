import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'design_system/design_system.dart';
import 'localization/lang/locale_keys.g.dart';
import 'localization/localization.dart';
import 'router/app_router.dart';

class DownloaderAppView extends StatelessWidget {
  final AppRouter appRouter;

  const DownloaderAppView({required this.appRouter, super.key});

  @override
  Widget build(BuildContext context) => AppLocalization(
    builder: (BuildContext context) =>
        BlocBuilder<AppThemeController, AppThemeState>(
          builder: (context, state) => AppThemeConfig(
            type: state.themeType,
            child: Builder(
              builder: (context) => MaterialApp.router(
                onGenerateTitle: (_) => LocaleKeys.app_title.tr(),
                theme: AppTheme.of(context),
                routerConfig: appRouter.config(),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                debugShowCheckedModeBanner: false,
              ),
            ),
          ),
        ),
  );
}
