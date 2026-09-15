part of 'download_task_model.dart';

enum DownloadTaskStatus { queued, downloading, processing, paused, done, failed }

extension DownloadTaskStatusX on DownloadTaskStatus {
  bool get isQueued => this == DownloadTaskStatus.queued;
  bool get isDownloading => this == DownloadTaskStatus.downloading;
  bool get isProcessing => this == DownloadTaskStatus.processing;
  bool get isPaused => this == DownloadTaskStatus.paused;
  bool get isDone => this == DownloadTaskStatus.done;
  bool get isFailed => this == DownloadTaskStatus.failed;
}

/// Screen section the download belongs to
enum DownloadTaskSection { active, queue, finished }

extension DownloadTaskSectionX on DownloadTaskSection {
  bool get isActive => this == DownloadTaskSection.active;
  bool get isQueue => this == DownloadTaskSection.queue;
  bool get isFinished => this == DownloadTaskSection.finished;
}
