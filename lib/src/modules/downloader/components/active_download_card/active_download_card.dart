import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../download_task_preview/download_task_preview.dart';

/// Active download: video, download progress, pause and removal
class ActiveDownloadCard extends StatelessWidget {
  final DownloadTaskModel task;
  final VoidCallback? onPausePressed;
  final VoidCallback? onResumePressed;
  final VoidCallback? onRemovePressed;

  const ActiveDownloadCard({
    super.key,
    required this.task,
    this.onPausePressed,
    this.onResumePressed,
    this.onRemovePressed,
  });

  /// Streams are not selected yet: YouTube has not responded, the size is unknown
  bool get _isPreparing => task.status.isDownloading && task.totalBytes == null;

  String? get _sizes {
    final downloaded = AppFileSize.format(task.downloadedBytes);
    final total = AppFileSize.format(task.totalBytes);

    if (downloaded == null || total == null) return null;

    return LocaleKeys.app_downloader_progress_downloaded.tr(
      namedArgs: {'downloaded': downloaded, 'total': total},
    );
  }

  String _details() {
    final percent = '${task.percent.floor()}';
    final speed = AppFileSize.format(task.speed);
    final eta = AppFormatters.duration(task.eta);

    final parts = switch (task.status) {
      DownloadTaskStatus.processing => [
        LocaleKeys.app_downloader_progress_processing.tr(),
      ],
      DownloadTaskStatus.paused => [
        LocaleKeys.app_downloader_task_paused.tr(
          namedArgs: {'percent': percent},
        ),
        ?_sizes,
      ],
      _ when _isPreparing => [LocaleKeys.app_downloader_progress_preparing.tr()],
      _ => [
        LocaleKeys.app_downloader_progress_downloading.tr(
          namedArgs: {'percent': percent},
        ),
        ?_sizes,
        if (speed != null)
          LocaleKeys.app_downloader_progress_speed.tr(
            namedArgs: {'value': speed},
          ),
        if (eta != null)
          LocaleKeys.app_downloader_progress_eta.tr(namedArgs: {'value': eta}),
      ],
    };

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: DownloadTaskPreview(task: task)),
            const SizedBox(width: 8),
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
                onPressed: task.status.isDownloading ? onPausePressed : null,
              ),
            AppIconButton(
              icon: Icons.close_rounded,
              tooltip: LocaleKeys.app_downloader_buttons_remove.tr(),
              onPressed: onRemovePressed,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _details(),
          style: context.text.captionRegular.copyWith(
            color: context.color.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        AppProgressBar(
          value: task.percent / 100,
          pulsing: task.status.isProcessing || _isPreparing,
        ),
      ],
    ),
  );
}
