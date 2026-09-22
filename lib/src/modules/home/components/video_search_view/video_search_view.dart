import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peeky_cat/src/app/failure/failure.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';
import 'package:peeky_cat/src/modules/downloads/controllers/controllers.dart';

import '../../controllers/controllers.dart';
import '../added_video_notice/added_video_notice.dart';
import '../quality_picker/quality_picker.dart';
import '../url_search_form/url_search_form.dart';
import '../video_card/video_card.dart';

/// Video search by link and quality selection on a page of a video site.
///
/// [AddVideoController] of the page searches; the page of a site fills in
/// the texts, the header actions and the actions of errors. The added video
/// starts downloading right away if the active download slot is free,
/// otherwise it goes to the end of the queue
class VideoSearchView extends StatefulWidget {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;

  /// The field and the Search button go into one row from this width
  static const _searchRowBreakpoint = 420.0;

  /// Gap between the window title bar and the page header
  static const _minTopGap = 24.0;

  final String title;
  final String subtitle;

  /// Example of a link of the site in the empty field
  final String? urlHint;

  /// Right of the title, e.g. the YouTube account
  final Widget? headerTrailing;

  /// Between the header and the link field, e.g. the advice to sign in
  /// with cookies
  final Widget? notice;

  /// Under the link field, e.g. the hint to install yt-dlp
  final Widget? formFooter;

  /// Buttons under an error, e.g. signing in to YouTube
  final List<AppFailureBannerAction> Function(Failure failure)? failureActions;

  const VideoSearchView({
    super.key,
    required this.title,
    required this.subtitle,
    this.urlHint,
    this.headerTrailing,
    this.notice,
    this.formFooter,
    this.failureActions,
  });

  @override
  State<VideoSearchView> createState() => _VideoSearchViewState();
}

class _VideoSearchViewState extends State<VideoSearchView> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
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

  @override
  Widget build(BuildContext context) {
    final hasActiveTask = context.select(
      (DownloadQueueController controller) => controller.state.hasActiveTask,
    );

    return BlocBuilder<AddVideoController, AddVideoState>(
      builder: (context, addVideoState) {
        final addVideoController = context.read<AddVideoController>();

        return AppScaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final verticalPadding =
                  constraints.maxWidth >= VideoSearchView._wideLayoutBreakpoint
                  ? 64.0
                  : 40.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,

                  /// The app title bar and the site tabs lie over the top
                  /// of the page
                  math.max(
                    verticalPadding,
                    MediaQuery.paddingOf(context).top +
                        VideoSearchView._minTopGap,
                  ),
                  16,

                  /// The download footer lies over the bottom
                  verticalPadding + MediaQuery.paddingOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: VideoSearchView._contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppPageHeader(
                          title: widget.title,
                          subtitle: widget.subtitle,
                          trailing: widget.headerTrailing,
                        ),
                        if (widget.notice case final notice?) ...[
                          const SizedBox(height: 20),
                          notice,
                        ],
                        const SizedBox(height: 32),
                        UrlSearchForm(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          loading: addVideoState.isInfoLoading,
                          enabled: !addVideoState.isInfoLoading,
                          rowBreakpoint: VideoSearchView._searchRowBreakpoint,
                          hintText: widget.urlHint,
                          onSubmitted: _search,
                        ),
                        if (widget.formFooter case final footer?) ...[
                          const SizedBox(height: 8),
                          footer,
                        ],
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
                        if (addVideoState.failure case final failure?) ...[
                          const SizedBox(height: 16),
                          AppFailureBanner(
                            message: failure.message,
                            actions:
                                widget.failureActions?.call(failure) ??
                                const [],
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
                                onSelected: addVideoController.selectQuality,
                              ),

                              /// Buttons keep their width, like in a dialog
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AppSecondaryButton(
                                    title: LocaleKeys.app_home_clear.tr(),
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
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
