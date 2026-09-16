import 'package:easy_localization/easy_localization.dart';

import '../localization/lang/locale_keys.g.dart';
import '../models/models.dart';
import 'app_formatters.dart';

/// Texts about a download shared by the downloads page and the footer
abstract final class DownloadTaskText {
  /// Quality label: resolution or "Audio only"
  static String quality(QualityModel quality) => switch (quality.kind) {
    QualityKind.video => quality.label,
    QualityKind.audio when quality.isAac =>
      LocaleKeys.app_downloader_video_audio_only_m4a.tr(),
    QualityKind.audio => LocaleKeys.app_downloader_video_audio_only.tr(),
  };

  /// Streams are not selected yet: YouTube has not responded, the size
  /// is unknown
  static bool isPreparing(DownloadTaskModel task) =>
      task.status.isDownloading && task.totalBytes == null;

  /// The progress bar blinks: the stage has no measurable progress
  static bool isIndeterminate(DownloadTaskModel task) =>
      task.status.isProcessing || isPreparing(task);

  /// `Downloading 42% · 12 MB of 30 MB · 2 MB/s · 0:09 left`
  static String progress(DownloadTaskModel task) {
    final percent = '${task.percent.floor()}';
    final speed = AppFileSize.format(task.speed);
    final eta = AppFormatters.duration(task.eta);
    final sizes = _sizes(task);

    final parts = switch (task.status) {
      DownloadTaskStatus.processing => [
        LocaleKeys.app_downloader_progress_processing.tr(),
      ],
      DownloadTaskStatus.paused => [
        LocaleKeys.app_downloader_task_paused.tr(
          namedArgs: {'percent': percent},
        ),
        ?sizes,
      ],
      _ when isPreparing(task) => [
        LocaleKeys.app_downloader_progress_preparing.tr(),
      ],
      _ => [
        LocaleKeys.app_downloader_progress_downloading.tr(
          namedArgs: {'percent': percent},
        ),
        ?sizes,
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

  static String? _sizes(DownloadTaskModel task) {
    final downloaded = AppFileSize.format(task.downloadedBytes);
    final total = AppFileSize.format(task.totalBytes);

    if (downloaded == null || total == null) return null;

    return LocaleKeys.app_downloader_progress_downloaded.tr(
      namedArgs: {'downloaded': downloaded, 'total': total},
    );
  }
}
