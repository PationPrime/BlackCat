import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../../controllers/controllers.dart';

/// Ход загрузки: проценты, скорость, остаток времени и полоса прогресса
class DownloadProgressView extends StatelessWidget {
  final DownloadJob job;

  /// Для готового файла: открыть его в Проводнике
  final VoidCallback? onShowInFolderPressed;

  const DownloadProgressView({
    super.key,
    required this.job,
    this.onShowInFolderPressed,
  });

  String _details() {
    final speed = AppFileSize.format(job.speed);
    final eta = AppFormatters.duration(job.eta);

    final parts = switch (job.status) {
      DownloadJobStatus.downloading => [
        LocaleKeys.app_downloader_progress_downloading.tr(
          namedArgs: {'percent': '${job.percent.floor()}'},
        ),
        if (speed != null)
          LocaleKeys.app_downloader_progress_speed.tr(
            namedArgs: {'value': speed},
          ),
        if (eta != null)
          LocaleKeys.app_downloader_progress_eta.tr(namedArgs: {'value': eta}),
      ],
      DownloadJobStatus.processing => [
        LocaleKeys.app_downloader_progress_processing.tr(),
      ],
      DownloadJobStatus.done => [LocaleKeys.app_downloader_progress_done.tr()],
    };

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(_details(), style: context.text.captionRegular)),
          if (job.filePath is String) ...[
            const SizedBox(width: 16),
            AppLinkButton(
              title: LocaleKeys.app_downloader_buttons_show_in_folder.tr(),
              onPressed: onShowInFolderPressed,
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      AppProgressBar(
        value: job.percent / 100,
        pulsing: job.status.isProcessing,
      ),
    ],
  );
}
