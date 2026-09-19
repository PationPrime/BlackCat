import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/failure/failure.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/dependencies/module.dart';
import 'package:black_cat/src/modules/downloads/controllers/controllers.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// Video search by link and quality selection.
///
/// The added video starts downloading right away if the active download
/// slot is free, otherwise it goes to the end of the queue
@RoutePage()
class HomeScreen extends StatelessWidget implements AutoRouteWrapper {
  const HomeScreen({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<AddVideoController>(
        create: (context) => AddVideoController(
          videoRepository: context.read<VideoRepositoryInterface>(),
          ytDlpVideoRepository: context.read<YtDlpVideoRepositoryInterface>(),
          authorizationController: context.read<AuthorizationController>(),
        ),
      ),
      BlocProvider<DirectDownloadController>(
        create: (context) => DirectDownloadController(
          fileSystemService: context.read<FileSystemService>(),
        ),
      ),
    ],
    child: this,
  );

  @override
  Widget build(BuildContext context) => const _HomeView();
}

class _HomeView extends StatefulWidget {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;

  /// The field and the Search button go into one row from this width
  static const _searchRowBreakpoint = 420.0;

  /// Gap between the window title bar and the page header
  static const _minTopGap = 24.0;

  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  final _directUrlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _directUrlController.dispose();
    super.dispose();
  }

  void _search(String url) {
    if (url.trim().isEmpty) {
      _urlFocusNode.requestFocus();

      return;
    }

    context.read<AddVideoController>().fetchVideoInfo(
      url,
      engine: context.read<DependenciesController>().state.preferredEngine,
    );
  }

  void _addVideo(AddVideoState addVideoState) {
    final videoInfo = addVideoState.videoInfo;
    final quality = addVideoState.selectedQuality;

    if (videoInfo == null || quality == null) return;

    context.read<DownloadQueueController>().addTask(
      video: videoInfo,
      quality: quality,
      engine: addVideoState.engine,
    );
    context.read<AddVideoController>().completeAdding();

    _urlController.clear();
    _urlFocusNode.requestFocus();
  }

  void _clear() {
    context.read<AddVideoController>().clear();

    _urlController.clear();
    _urlFocusNode.requestFocus();
  }

  void _showDirectFileInFolder(DirectDownloadState directState) {
    final savePath = directState.savePath;

    if (savePath == null) return;

    context.read<FileSystemService>().revealInExplorer(savePath);
  }

  /// The search repeats on its own once cookies are imported
  void _importCookies() => context
      .read<AppNavigationController>()
      .openCookiesImport(returnTab: AppTabModel.home);

  /// Title of the button under an error that signing in to YouTube will fix
  String _signInActionTitle(AuthorizationState authorizationState) =>
      authorizationState.isInProgress
      ? LocaleKeys.app_authorization_waiting.tr()
      : authorizationState.isAuthorized
      ? LocaleKeys.app_downloader_buttons_refresh_sign_in_and_retry.tr()
      : LocaleKeys.app_downloader_buttons_sign_in_and_retry.tr();

  List<AppFailureBannerAction> _failureActions(
    Failure failure,
    AuthorizationState authorizationState,
  ) {
    if (failure is! VideoFailure || !failure.needsSignIn) {
      return const [];
    }

    return [
      AppFailureBannerAction(
        title: _signInActionTitle(authorizationState),
        onPressed: authorizationState.isBusy
            ? null
            : context.read<AddVideoController>().signInAndRetry,
      ),
      AppFailureBannerAction(
        title: LocaleKeys.app_downloader_buttons_import_cookies.tr(),
        onPressed: authorizationState.isBusy ? null : _importCookies,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveTask = context.select(
      (DownloadQueueController controller) => controller.state.hasActiveTask,
    );
    final hasRunningTask = context.select(
      (DownloadQueueController controller) => controller.state.hasRunningTask,
    );
    final dependenciesStatus = context.select(
      (DependenciesController controller) => controller.state.status,
    );

    return BlocListener<AuthorizationController, AuthorizationState>(
      /// Sign-in errors are shown in the page message
      listenWhen: (previous, current) =>
          current.failure != null && current.failure != previous.failure,
      listener: (context, authorizationState) => context
          .read<AddVideoController>()
          .showFailure(authorizationState.failure!),
      child: BlocBuilder<AuthorizationController, AuthorizationState>(
        builder: (context, authorizationState) =>
            BlocBuilder<AddVideoController, AddVideoState>(
              builder: (context, addVideoState) {
                final addVideoController = context.read<AddVideoController>();

                return AppScaffold(
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final verticalPadding =
                          constraints.maxWidth >=
                              _HomeView._wideLayoutBreakpoint
                          ? 64.0
                          : 40.0;

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,

                          /// The app title bar lies over the top of the page
                          math.max(
                            verticalPadding,
                            MediaQuery.paddingOf(context).top +
                                _HomeView._minTopGap,
                          ),
                          16,

                          /// The download footer lies over the bottom
                          verticalPadding +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _HomeView._contentMaxWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppPageHeader(
                                  title: LocaleKeys.app_home_title.tr(),
                                  subtitle: LocaleKeys.app_home_subtitle.tr(),
                                  trailing: AccountStatus(
                                    authorizationState: authorizationState,
                                    signOutEnabled: !hasRunningTask,
                                    onSignInPressed: context
                                        .read<AuthorizationController>()
                                        .signIn,
                                    onSignOutPressed: context
                                        .read<AuthorizationController>()
                                        .signOut,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                UrlSearchForm(
                                  controller: _urlController,
                                  focusNode: _urlFocusNode,
                                  loading: addVideoState.isInfoLoading,
                                  enabled: !addVideoState.isInfoLoading,
                                  rowBreakpoint: _HomeView._searchRowBreakpoint,
                                  onSubmitted: _search,
                                ),
                                const SizedBox(height: 8),
                                DependenciesHint(
                                  status: dependenciesStatus,
                                  onInstallPressed: () =>
                                      DependenciesInstallDialog.show(context),
                                ),
                                if (addVideoState.addedVideo
                                    case final addedVideo?) ...[
                                  const SizedBox(height: 16),
                                  AddedVideoNotice(
                                    title: addedVideo.title,
                                    onOpenDownloadsPressed: () => context
                                        .read<AppNavigationController>()
                                        .selectTab(AppTabModel.downloads),
                                    onDismissPressed:
                                        addVideoController.dismissAddedVideo,
                                  ),
                                ],

                                /// Error message; if signing in to YouTube
                                /// will help, with the sign-in and the cookies
                                /// import
                                if (addVideoState.failure
                                    case final failure?) ...[
                                  const SizedBox(height: 16),
                                  AppFailureBanner(
                                    message: failure.message,
                                    actions: _failureActions(
                                      failure,
                                      authorizationState,
                                    ),
                                  ),
                                ],
                                if (addVideoState.videoInfo
                                    case final videoInfo?) ...[
                                  const SizedBox(height: 20),
                                  VideoCard(
                                    videoInfo: videoInfo,
                                    children: [
                                      QualityPicker(
                                        qualities: videoInfo.qualities,
                                        selectedQualityId:
                                            addVideoState.selectedQualityId,
                                        onSelected:
                                            addVideoController.selectQuality,
                                      ),

                                      /// Buttons keep their width, like in a dialog
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          AppSecondaryButton(
                                            title: LocaleKeys.app_home_clear
                                                .tr(),
                                            onPressed: _clear,
                                          ),
                                          const SizedBox(width: 12),
                                          AppPrimaryButton(
                                            title: hasActiveTask
                                                ? LocaleKeys
                                                      .app_downloader_dialog_add_to_queue
                                                      .tr()
                                                : LocaleKeys
                                                      .app_downloader_dialog_download_now
                                                      .tr(),
                                            onPressed: addVideoState.canAdd
                                                ? () => _addVideo(addVideoState)
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 32),
                                BlocBuilder<
                                  DirectDownloadController,
                                  DirectDownloadState
                                >(
                                  builder: (context, directState) {
                                    final directDownloadController = context
                                        .read<DirectDownloadController>();

                                    return DirectDownloadSection(
                                      state: directState,
                                      controller: _directUrlController,
                                      onStartPressed:
                                          directDownloadController.start,
                                      onPausePressed:
                                          directDownloadController.pause,
                                      onResumePressed:
                                          directDownloadController.resume,
                                      onCancelPressed:
                                          directDownloadController.cancel,
                                      onShowInFolderPressed: () =>
                                          _showDirectFileInFolder(directState),
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
                );
              },
            ),
      ),
    );
  }
}
