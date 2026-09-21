import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/constants/constants.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/downloads/controllers/controllers.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// Download folder, interface language and YouTube cookies
@RoutePage()
class SettingsScreen extends StatelessWidget implements AutoRouteWrapper {
  const SettingsScreen({super.key});

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<CookiesImportController>(
        create: (context) => CookiesImportController(
          authorizationController: context.read<AuthorizationController>(),
        ),
        child: this,
      );

  @override
  Widget build(BuildContext context) => const _SettingsView();
}

class _SettingsView extends StatefulWidget {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;

  /// Gap between the window title bar and the page header
  static const _minTopGap = 24.0;

  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _cookiesCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    /// The page is built for the first time right for the cookies import
    if (context.read<AppNavigationController>().state.cookiesImport != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCookiesCard());
    }
  }

  void _showCookiesCard() {
    final cardContext = _cookiesCardKey.currentContext;

    if (!mounted || cardContext == null || !cardContext.mounted) return;

    Scrollable.ensureVisible(
      cardContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  Future<void> _openCookiesGuide() async {
    final cookiesImportController = context.read<CookiesImportController>();
    final opened = await context.read<UrlLauncherService>().openUrl(
      DependencyConstants.cookiesGuideUrl,
    );

    if (!opened) {
      cookiesImportController.showFailure(
        SettingsFailure(
          message: LocaleKeys.app_settings_cookies_guide_failed.tr(
            namedArgs: {'url': DependencyConstants.cookiesGuideUrl},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.select(
      (AuthorizationController controller) => controller.state.session,
    );
    final hasRunningTask = context.select(
      (DownloadQueueController controller) => controller.state.hasRunningTask,
    );
    final cookiesImportRequested = context.select(
      (AppNavigationController controller) =>
          controller.state.cookiesImport != null,
    );

    return MultiBlocListener(
      listeners: [
        /// Every new request scrolls to the cookies card again
        BlocListener<AppNavigationController, AppNavigationState>(
          listenWhen: (previous, current) =>
              current.cookiesImport != null &&
              current.cookiesImport != previous.cookiesImport,
          listener: (context, _) => WidgetsBinding.instance
              .addPostFrameCallback((_) => _showCookiesCard()),
        ),

        /// Imported cookies return the user to the page that asked for them
        BlocListener<CookiesImportController, CookiesImportState>(
          listenWhen: (previous, current) =>
              current.isImported && !previous.isImported,
          listener: (context, _) =>
              context.read<AppNavigationController>().finishCookiesImport(),
        ),
      ],
      child: BlocBuilder<SettingsController, SettingsState>(
        builder: (context, settingsState) => AppScaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final verticalPadding =
                  constraints.maxWidth >= _SettingsView._wideLayoutBreakpoint
                  ? 64.0
                  : 40.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,

                  /// The app title bar lies over the top of the screen
                  math.max(
                    verticalPadding,
                    MediaQuery.paddingOf(context).top +
                        _SettingsView._minTopGap,
                  ),
                  16,

                  /// The download footer lies over the bottom
                  verticalPadding + MediaQuery.paddingOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _SettingsView._contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppPageHeader(
                          title: LocaleKeys.app_settings_title.tr(),
                          subtitle: LocaleKeys.app_settings_subtitle.tr(),
                        ),
                        const SizedBox(height: 32),
                        if (settingsState.failure case final failure?) ...[
                          AppFailureBanner(message: failure.message),
                          const SizedBox(height: 16),
                        ],
                        DownloadDirectoryCard(
                          downloadDirectory: settingsState.downloadDirectory,
                          onChangePressed: context
                              .read<SettingsController>()
                              .pickDownloadDirectory,
                          onResetPressed: context
                              .read<SettingsController>()
                              .resetDownloadDirectory,
                          onOpenPressed: () =>
                              switch (settingsState.downloadDirectory) {
                                final directory? =>
                                  context.read<FileSystemService>().openFolder(
                                    directory.path,
                                  ),
                                null => null,
                              },
                        ),
                        const SizedBox(height: 16),
                        LanguageCard(
                          selectedLanguage: settingsState.language,
                          onLanguageSelected: context
                              .read<SettingsController>()
                              .changeLanguage,
                        ),
                        const SizedBox(height: 16),
                        BlocBuilder<
                          CookiesImportController,
                          CookiesImportState
                        >(
                          builder: (context, cookiesImportState) {
                            final cookiesImportController = context
                                .read<CookiesImportController>();

                            return CookiesCard(
                              key: _cookiesCardKey,
                              session: session,
                              highlighted: cookiesImportRequested,
                              isImporting: cookiesImportState.isImporting,
                              isImported: cookiesImportState.isImported,
                              failureMessage:
                                  cookiesImportState.failure?.message,
                              removeEnabled: !hasRunningTask,
                              onChoosePressed:
                                  cookiesImportController.importCookies,
                              onRemovePressed:
                                  cookiesImportController.removeCookies,
                              onGuidePressed: _openCookiesGuide,
                              onDismissFailurePressed:
                                  cookiesImportController.dismissFailure,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
