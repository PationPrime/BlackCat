import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/settings/module.dart';

import '../../controllers/controllers.dart';
import '../dependencies_hint/dependencies_hint.dart';
import '../dependencies_install_dialog/dependencies_install_dialog.dart';
import '../quality_picker/quality_picker.dart';
import '../url_search_form/url_search_form.dart';
import '../video_card/video_card.dart';

/// Add video dialog: search by link and quality selection.
///
/// The added video starts downloading right away if the active download
/// slot is free, otherwise it goes to the end of the queue
class AddVideoDialog extends StatefulWidget {
  static const _maxWidth = 560.0;

  /// The field and the Search button go into one row already at the dialog width
  static const _searchRowBreakpoint = 400.0;

  final String initialUrl;

  /// Searches [initialUrl] as soon as the dialog opens
  final bool searchOnOpen;

  const AddVideoDialog({
    super.key,
    this.initialUrl = '',
    this.searchOnOpen = false,
  });

  /// The dialog closes for the cookies import in the settings and opens again
  /// with the same link afterwards; the search is repeated if cookies were
  /// imported
  static Future<void> show(
    BuildContext context, {
    String initialUrl = '',
    bool searchOnOpen = false,
  }) async {
    final cookiesImportUrl = await AppDialog.show<String>(
      context,
      builder: (dialogContext) => BlocProvider<AddVideoController>(
        create: (_) => AddVideoController(
          videoRepository: dialogContext.read<VideoRepositoryInterface>(),
          ytDlpVideoRepository: dialogContext
              .read<YtDlpVideoRepositoryInterface>(),
          authorizationController: dialogContext
              .read<AuthorizationController>(),
        ),
        child: AddVideoDialog(
          initialUrl: initialUrl,
          searchOnOpen: searchOnOpen,
        ),
      ),
    );

    if (cookiesImportUrl == null || !context.mounted) return;

    final imported = await SettingsScreen.openCookiesImport(context);

    if (!context.mounted) return;

    await show(context, initialUrl: cookiesImportUrl, searchOnOpen: imported);
  }

  @override
  State<AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<AddVideoDialog> {
  late final _urlController = TextEditingController(text: widget.initialUrl);
  final _urlFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    if (widget.searchOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onUrlSubmitted(widget.initialUrl),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onUrlSubmitted(String url) {
    if (!mounted) return;

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

    Navigator.of(context).pop();
  }

  /// Title of the button under an error that signing in to YouTube will fix
  String _signInActionTitle(AuthorizationState authorizationState) =>
      authorizationState.isInProgress
      ? LocaleKeys.app_authorization_waiting.tr()
      : authorizationState.isAuthorized
      ? LocaleKeys.app_downloader_buttons_refresh_sign_in_and_retry.tr()
      : LocaleKeys.app_downloader_buttons_sign_in_and_retry.tr();

  @override
  Widget build(BuildContext context) {
    final hasActiveTask = context.select(
      (DownloadQueueController controller) => controller.state.hasActiveTask,
    );
    final dependenciesStatus = context.select(
      (DependenciesController controller) => controller.state.status,
    );

    return BlocListener<AuthorizationController, AuthorizationState>(
      /// Sign-in errors are shown in the dialog message
      listenWhen: (previous, current) =>
          current.failure != null && current.failure != previous.failure,
      listener: (context, authorizationState) => context
          .read<AddVideoController>()
          .showFailure(authorizationState.failure!),
      child: BlocBuilder<AuthorizationController, AuthorizationState>(
        builder: (context, authorizationState) =>
            BlocBuilder<AddVideoController, AddVideoState>(
              builder: (context, addVideoState) => AppDialog(
                title: LocaleKeys.app_downloader_dialog_title.tr(),
                maxWidth: AddVideoDialog._maxWidth,
                actions: [
                  AppSecondaryButton(
                    title: LocaleKeys.app_downloader_dialog_cancel.tr(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppPrimaryButton(
                    title: hasActiveTask
                        ? LocaleKeys.app_downloader_dialog_add_to_queue.tr()
                        : LocaleKeys.app_downloader_dialog_download_now.tr(),
                    onPressed: addVideoState.canAdd
                        ? () => _addVideo(addVideoState)
                        : null,
                  ),
                ],
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UrlSearchForm(
                        controller: _urlController,
                        focusNode: _urlFocusNode,
                        loading: addVideoState.isInfoLoading,
                        enabled: !addVideoState.isInfoLoading,
                        rowBreakpoint: AddVideoDialog._searchRowBreakpoint,
                        onSubmitted: _onUrlSubmitted,
                      ),
                      const SizedBox(height: 8),
                      DependenciesHint(
                        status: dependenciesStatus,
                        onInstallPressed: () =>
                            DependenciesInstallDialog.show(context),
                      ),

                      /// Error message; if signing in to YouTube will help,
                      /// with the sign-in and the cookies import
                      if (addVideoState.failure case final failure?) ...[
                        const SizedBox(height: 16),
                        AppFailureBanner(
                          message: failure.message,
                          actions: [
                            if (failure is VideoFailure &&
                                failure.needsSignIn) ...[
                              AppFailureBannerAction(
                                title: _signInActionTitle(authorizationState),
                                onPressed: authorizationState.isBusy
                                    ? null
                                    : context
                                          .read<AddVideoController>()
                                          .signInAndRetry,
                              ),
                              AppFailureBannerAction(
                                title: LocaleKeys
                                    .app_downloader_buttons_import_cookies
                                    .tr(),
                                onPressed: authorizationState.isBusy
                                    ? null
                                    : () => Navigator.of(
                                        context,
                                      ).pop(addVideoState.requestedUrl),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (addVideoState.videoInfo case final videoInfo?) ...[
                        const SizedBox(height: 20),
                        VideoCard(
                          videoInfo: videoInfo,
                          children: [
                            QualityPicker(
                              qualities: videoInfo.qualities,
                              selectedQualityId:
                                  addVideoState.selectedQualityId,
                              onSelected: context
                                  .read<AddVideoController>()
                                  .selectQuality,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
