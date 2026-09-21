import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// Active download, the queue behind it and downloaded videos
@RoutePage()
class DownloadsScreen extends StatelessWidget {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;
  static const _minHorizontalPadding = 16.0;
  static const _tileSpacing = 8.0;

  /// Gap between the window title bar and the screen header
  static const _minTopGap = 24.0;

  const DownloadsScreen({super.key});

  /// An unfinished video is removed only after confirmation:
  /// its downloaded bytes are deleted from the device with it
  Future<void> _removeTask(BuildContext context, DownloadTaskModel task) async {
    final downloadQueueController = context.read<DownloadQueueController>();

    if (task.removalNeedsConfirmation) {
      final confirmed = await AppConfirmationDialog.show(
        context,
        title: LocaleKeys.app_downloader_remove_dialog_title.tr(),
        message: LocaleKeys.app_downloader_remove_dialog_message.tr(
          namedArgs: {
            'title': task.video.title,
            'percent': '${task.percent.floor()}',
          },
        ),
        confirmTitle: LocaleKeys.app_downloader_remove_dialog_confirm.tr(),
        cancelTitle: LocaleKeys.app_downloader_remove_dialog_cancel.tr(),
        destructive: true,
      );

      if (!confirmed) return;
    }

    await downloadQueueController.removeTask(task.id);
  }

  Future<void> _clearFinished(BuildContext context) async {
    final downloadQueueController = context.read<DownloadQueueController>();

    /// The videos themselves stay in the download folder, so the action
    /// is not destructive, but the whole list disappears at once
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: LocaleKeys.app_downloader_clear_finished_dialog_title.tr(),
      message: LocaleKeys.app_downloader_clear_finished_dialog_message.tr(),
      confirmTitle: LocaleKeys.app_downloader_clear_finished_dialog_confirm
          .tr(),
      cancelTitle: LocaleKeys.app_downloader_clear_finished_dialog_cancel.tr(),
    );

    if (!confirmed) return;

    await downloadQueueController.clearFinished();
  }

  /// Opens the cookies import in the settings. Downloads that needed
  /// signing in are retried once cookies are imported
  void _importCookies(BuildContext context) => context
      .read<AppNavigationController>()
      .openCookiesImport(returnTab: AppTabModel.downloads);

  /// Title of the button under an error that signing in to YouTube will fix
  String _signInActionTitle(AuthorizationState authorizationState) =>
      authorizationState.isInProgress
      ? LocaleKeys.app_authorization_waiting.tr()
      : authorizationState.isAuthorized
      ? LocaleKeys.app_downloader_buttons_refresh_sign_in_and_retry.tr()
      : LocaleKeys.app_downloader_buttons_sign_in_and_retry.tr();

  /// A dragged queue row is drawn over the screen:
  /// it needs its own Material for text styles
  Widget _dragProxy(Widget child, int index, Animation<double> animation) =>
      AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
          child: child,
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<AuthorizationController, AuthorizationState>(
    /// Sign-in and sign-out errors are shown in the common screen message
    listenWhen: (previous, current) =>
        current.failure != null && current.failure != previous.failure,
    listener: (context, authorizationState) => context
        .read<DownloadQueueController>()
        .showFailure(authorizationState.failure!),
    child: BlocBuilder<AuthorizationController, AuthorizationState>(
      builder: (context, authorizationState) =>
          BlocBuilder<DownloadQueueController, DownloadQueueState>(
            builder: (context, queueState) {
              final downloadQueueController = context
                  .read<DownloadQueueController>();
              final queue = queueState.queue;
              final failed = queueState.failed;
              final finished = queueState.finished;

              return AppScaffold(
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = math.max(
                      _minHorizontalPadding,
                      (constraints.maxWidth - _contentMaxWidth) / 2,
                    );
                    final verticalPadding =
                        constraints.maxWidth >= _wideLayoutBreakpoint
                        ? 64.0
                        : 40.0;

                    /// The app title bar lies over the top of the screen
                    final topPadding = math.max(
                      verticalPadding,
                      MediaQuery.paddingOf(context).top + _minTopGap,
                    );

                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            topPadding,
                            horizontalPadding,
                            12,
                          ),
                          sliver: SliverList.list(
                            children: [
                              AppPageHeader(
                                title: LocaleKeys.app_downloads_title.tr(),
                                subtitle: LocaleKeys.app_downloads_subtitle
                                    .tr(),
                                trailing: AppSecondaryButton(
                                  title: LocaleKeys.app_downloads_add_video
                                      .tr(),
                                  compact: true,
                                  onPressed: () => context
                                      .read<AppNavigationController>()
                                      .selectTab(AppTabModel.home),
                                ),
                              ),
                              if (queueState.failure case final failure?) ...[
                                const SizedBox(height: 16),
                                AppFailureBanner(
                                  message: failure.message,
                                  actions: [
                                    AppFailureBannerAction(
                                      title: LocaleKeys
                                          .app_downloader_buttons_hide
                                          .tr(),
                                      onPressed: downloadQueueController
                                          .dismissFailure,
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 32),
                              DownloadsSectionTitle(
                                title: LocaleKeys.app_downloader_sections_active
                                    .tr(),
                              ),
                              const SizedBox(height: 12),
                              if (queueState.activeTask case final task?)
                                ActiveDownloadCard(
                                  key: ValueKey(task.id),
                                  task: task,
                                  onPausePressed:
                                      downloadQueueController.pauseActiveTask,
                                  onResumePressed:
                                      downloadQueueController.resumeActiveTask,
                                  onRemovePressed: () =>
                                      _removeTask(context, task),
                                )
                              else if (!queueState.isRestoring)
                                DownloadsEmptyPlaceholder(
                                  message: LocaleKeys
                                      .app_downloader_empty_active
                                      .tr(),
                                ),
                              const SizedBox(height: 32),
                              DownloadsSectionTitle(
                                title: LocaleKeys.app_downloader_sections_queue
                                    .tr(),
                                count: queue.length,
                              ),
                              if (queue.isEmpty && !queueState.isRestoring) ...[
                                const SizedBox(height: 12),
                                DownloadsEmptyPlaceholder(
                                  message: LocaleKeys.app_downloader_empty_queue
                                      .tr(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          sliver: SliverReorderableList(
                            itemCount: queue.length,
                            onReorderItem:
                                downloadQueueController.moveQueuedTask,
                            proxyDecorator: _dragProxy,
                            itemBuilder: (context, index) {
                              final task = queue[index];

                              return Padding(
                                key: ValueKey(task.id),
                                padding: const EdgeInsets.only(
                                  bottom: _tileSpacing,
                                ),
                                child: QueuedDownloadTile(
                                  task: task,
                                  index: index,
                                  onStartPressed: () => downloadQueueController
                                      .startTask(task.id),
                                  onRemovePressed: () =>
                                      _removeTask(context, task),
                                ),
                              );
                            },
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            24,
                            horizontalPadding,
                            0,
                          ),
                          sliver: SliverList.list(
                            children: [
                              /// Shown only while something has failed
                              if (failed.isNotEmpty) ...[
                                DownloadsSectionTitle(
                                  title: LocaleKeys
                                      .app_downloader_sections_failed
                                      .tr(),
                                  count: failed.length,
                                ),
                                const SizedBox(height: 12),
                                for (final task in failed)
                                  Padding(
                                    key: ValueKey(task.id),
                                    padding: const EdgeInsets.only(
                                      bottom: _tileSpacing,
                                    ),
                                    child: FailedDownloadTile(
                                      task: task,
                                      onStartPressed: () =>
                                          downloadQueueController.startTask(
                                            task.id,
                                          ),
                                      onRemovePressed: () =>
                                          _removeTask(context, task),
                                      onRetryPressed: () =>
                                          downloadQueueController.retryTask(
                                            task.id,
                                          ),
                                      signInTitle: _signInActionTitle(
                                        authorizationState,
                                      ),
                                      onSignInPressed: authorizationState.isBusy
                                          ? null
                                          : () => downloadQueueController
                                                .signInAndRetry(task.id),
                                      onImportCookiesPressed:
                                          authorizationState.isBusy
                                          ? null
                                          : () => _importCookies(context),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                              ],
                              DownloadsSectionTitle(
                                title: LocaleKeys
                                    .app_downloader_sections_finished
                                    .tr(),
                                count: finished.length,
                                trailing: finished.isEmpty
                                    ? null
                                    : AppLinkButton(
                                        title: LocaleKeys
                                            .app_downloader_buttons_clear_finished
                                            .tr(),
                                        onPressed: () =>
                                            _clearFinished(context),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              if (finished.isEmpty && !queueState.isRestoring)
                                DownloadsEmptyPlaceholder(
                                  message: LocaleKeys
                                      .app_downloader_empty_finished
                                      .tr(),
                                ),
                              for (final task in finished)
                                Padding(
                                  key: ValueKey(task.id),
                                  padding: const EdgeInsets.only(
                                    bottom: _tileSpacing,
                                  ),
                                  child: DownloadedVideoTile(
                                    task: task,
                                    onShowInFolderPressed:
                                        task.filePath is String
                                        ? () => context
                                              .read<FileSystemService>()
                                              .revealInExplorer(task.filePath!)
                                        : null,
                                    onRemovePressed: () =>
                                        _removeTask(context, task),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        /// The download footer lies over the bottom
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                verticalPadding +
                                MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
    ),
  );
}
