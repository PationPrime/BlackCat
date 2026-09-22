import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../modules/modules.dart';
import 'design_system/design_system.dart';
import 'localization/lang/locale_keys.g.dart';
import 'localization/localization.dart';
import 'models/models.dart';
import 'router/app_router.dart';
import 'shared_controllers/shared_controllers.dart';
import 'widgets/widgets.dart';

class PeekyCatAppView extends StatelessWidget {
  final AppRouter appRouter;

  /// Language of the first frame: the one saved in the settings
  final AppLanguageModel initialLanguage;

  const PeekyCatAppView({
    required this.appRouter,
    required this.initialLanguage,
    super.key,
  });

  @override
  Widget build(BuildContext context) => AppLocalization(
    startLocale: initialLanguage.locale,
    builder: (BuildContext context) => MultiBlocListener(
      listeners: [
        BlocListener<SettingsController, SettingsState>(
          /// The language chosen in the settings is applied to the whole app
          listenWhen: (previous, current) =>
              previous.language != current.language,
          listener: (context, settingsState) =>
              context.setLocale(settingsState.language.locale),
        ),
        BlocListener<DownloadQueueController, DownloadQueueState>(
          /// The tray shows the title and progress of the active download
          listenWhen: (previous, current) =>
              previous.activeTask != current.activeTask,
          listener: (context, queueState) => context
              .read<SystemTrayController>()
              .showActiveDownload(queueState.activeTask),
        ),
      ],
      child: BlocBuilder<AppThemeController, AppThemeState>(
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
              builder: (context, child) => AppLocaleRebuilder(
                onLocaleApplied: (_) =>
                    context.read<SystemTrayController>().onLanguageApplied(),
                child: BlocBuilder<AppWindowController, AppWindowState>(
                  builder: (context, windowState) {
                    final appWindowController = context
                        .read<AppWindowController>();

                    return AppWindowFrame(
                      frame: windowState.frame,
                      isMaximized: windowState.isMaximized,
                      isFullScreen: windowState.isFullScreen,
                      onMinimizePressed: appWindowController.minimize,
                      onToggleMaximizePressed:
                          appWindowController.toggleMaximize,
                      onClosePressed: appWindowController.closeWindow,
                      onDragStarted: appWindowController.startDragging,
                      onResizeStarted: appWindowController.startResizing,
                      child: child ?? const SizedBox(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
