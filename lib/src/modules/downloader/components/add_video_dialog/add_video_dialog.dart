import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../../controllers/controllers.dart';
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

  const AddVideoDialog({super.key});

  static Future<void> show(BuildContext context) => AppDialog.show<void>(
    context,
    builder: (dialogContext) => BlocProvider<AddVideoController>(
      create: (_) => AddVideoController(
        videoRepository: dialogContext.read<VideoRepositoryInterface>(),
        authorizationController: dialogContext.read<AuthorizationController>(),
      ),
      child: const AddVideoDialog(),
    ),
  );

  @override
  State<AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<AddVideoDialog> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onUrlSubmitted(String url) {
    if (url.trim().isEmpty) {
      _urlFocusNode.requestFocus();

      return;
    }

    context.read<AddVideoController>().fetchVideoInfo(url);
  }

  void _addVideo(AddVideoState addVideoState) {
    final videoInfo = addVideoState.videoInfo;
    final quality = addVideoState.selectedQuality;

    if (videoInfo == null || quality == null) return;

    context.read<DownloadQueueController>().addTask(
      video: videoInfo,
      quality: quality,
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

                      /// Error message; with a sign-in button if signing in to YouTube will help
                      if (addVideoState.failure case final failure?) ...[
                        const SizedBox(height: 16),
                        AppFailureBanner(
                          message: failure.message,
                          actionTitle:
                              failure is VideoFailure && failure.needsSignIn
                              ? _signInActionTitle(authorizationState)
                              : null,
                          onActionPressed: authorizationState.isBusy
                              ? null
                              : context
                                    .read<AddVideoController>()
                                    .signInAndRetry,
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
