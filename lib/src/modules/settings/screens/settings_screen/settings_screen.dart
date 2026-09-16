import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_downloader/src/app/constants/constants.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/router/app_router.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/downloader/controllers/controllers.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

@RoutePage()
class SettingsScreen extends StatelessWidget implements AutoRouteWrapper {
  /// Scrolls to the cookies card and highlights it
  final bool highlightCookies;

  const SettingsScreen({super.key, this.highlightCookies = false});

  /// Opens the settings at the cookies import. `true`: a cookies.txt
  /// was imported before the user came back
  static Future<bool> openCookiesImport(BuildContext context) async {
    final authorizationController = context.read<AuthorizationController>();
    final previousSession = authorizationController.state.session;

    await context.router.push(SettingsRoute(highlightCookies: true));

    final session = authorizationController.state.session;

    return session != null && session.isImported && session != previousSession;
  }

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<CookiesImportController>(
        create: (context) => CookiesImportController(
          authorizationController: context.read<AuthorizationController>(),
        ),
        child: this,
      );

  @override
  Widget build(BuildContext context) =>
      _SettingsView(highlightCookies: highlightCookies);
}

class _SettingsView extends StatefulWidget {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;

  /// Gap between the window title bar and the screen header
  static const _minTopGap = 24.0;

  final bool highlightCookies;

  const _SettingsView({required this.highlightCookies});

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _cookiesCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    if (widget.highlightCookies) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCookiesCard());
    }
  }

  void _showCookiesCard() {
    final cardContext = _cookiesCardKey.currentContext;

    if (cardContext == null || !cardContext.mounted) return;

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

    return BlocBuilder<SettingsController, SettingsState>(
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
                  MediaQuery.paddingOf(context).top + _SettingsView._minTopGap,
                ),
                16,
                verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _SettingsView._contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsHeader(
                        onBackPressed: () => context.router.maybePop(),
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
                      BlocBuilder<CookiesImportController, CookiesImportState>(
                        builder: (context, cookiesImportState) {
                          final cookiesImportController = context
                              .read<CookiesImportController>();

                          return CookiesCard(
                            key: _cookiesCardKey,
                            session: session,
                            highlighted: widget.highlightCookies,
                            isImporting: cookiesImportState.isImporting,
                            isImported: cookiesImportState.isImported,
                            failureMessage: cookiesImportState.failure?.message,
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
    );
  }
}
