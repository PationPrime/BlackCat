import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Current download along the bottom of the window, like in Steam: the video,
/// its progress and a pause. The whole bar opens the downloads page
class DownloadFooter extends StatelessWidget {
  static const height = 72.0;
  static const _thumbnailWidth = 64.0;

  /// `null` when nothing is downloading
  final DownloadTaskModel? task;

  /// Videos waiting in the queue
  final int queuedCount;
  final VoidCallback? onOpenPressed;
  final VoidCallback? onPausePressed;
  final VoidCallback? onResumePressed;

  const DownloadFooter({
    super.key,
    this.task,
    this.queuedCount = 0,
    this.onOpenPressed,
    this.onPausePressed,
    this.onResumePressed,
  });

  String? get _queued => queuedCount > 0
      ? LocaleKeys.app_footer_queued.tr(namedArgs: {'count': '$queuedCount'})
      : null;

  Widget _preview(BuildContext context) => SizedBox(
    width: _thumbnailWidth,
    child: switch (task) {
      final task? => AppVideoThumbnail(
        url: task.video.thumbnail,
        filePath: task.thumbnailPath,
        borderRadius: BorderRadius.circular(6),
      ),
      null => Center(
        child: Icon(
          Icons.download_done_rounded,
          size: 22,
          color: context.color.iconDisabled,
        ),
      ),
    },
  );

  Widget _details(BuildContext context, DownloadTaskModel? task) {
    final status = [
      if (task != null) DownloadTaskText.progress(task),
      ?_queued,
    ].join(' · ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                task?.video.title ?? LocaleKeys.app_footer_idle.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.captionMedium.copyWith(
                  color: task == null
                      ? context.color.textTertiary
                      : context.color.textPrimary,
                ),
              ),
            ),
            if (task != null) ...[
              const SizedBox(width: 12),
              Text(
                '${task.percent.floor()}%',
                style: context.text.captionMedium.copyWith(
                  color: context.color.accent,
                ),
              ),
            ],
          ],
        ),
        if (task != null) ...[
          const SizedBox(height: 6),
          AppProgressBar(
            value: task.percent / 100,
            pulsing: DownloadTaskText.isIndeterminate(task),
            height: 4,
          ),
        ],
        if (status.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.footnoteRegular.copyWith(
              color: context.color.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = this.task;

    return Semantics(
      container: true,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.color.surface,
          border: Border(top: BorderSide(color: context.color.border)),
        ),
        child: AppPressable(
          onPressed: onOpenPressed,
          builder: (context, highlighted) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: highlighted
                ? context.color.hoverOverlay
                : context.color.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _preview(context),
                const SizedBox(width: 12),
                Expanded(child: _details(context, task)),
                const SizedBox(width: 12),
                if (task != null)
                  if (task.status.isPaused)
                    AppIconButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: LocaleKeys.app_downloader_buttons_resume.tr(),
                      iconColor: context.color.accent,
                      onPressed: onResumePressed,
                    )
                  else
                    AppIconButton(
                      icon: Icons.pause_rounded,
                      tooltip: LocaleKeys.app_downloader_buttons_pause.tr(),

                      /// Muxing video and audio cannot be interrupted
                      onPressed: task.status.isDownloading
                          ? onPausePressed
                          : null,
                    ),
                AppIconButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: LocaleKeys.app_footer_open_downloads.tr(),
                  onPressed: onOpenPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
