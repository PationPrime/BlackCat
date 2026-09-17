part of 'direct_download_controller.dart';

/// Where the single download of the section is
enum DirectDownloadStatus {
  /// No link is being downloaded
  idle,

  /// The isolate is starting: the server has not answered yet
  starting,
  downloading,
  paused,
  completed,
  failed,
}

extension DirectDownloadStatusX on DirectDownloadStatus {
  bool get isIdle => this == DirectDownloadStatus.idle;
  bool get isStarting => this == DirectDownloadStatus.starting;
  bool get isDownloading => this == DirectDownloadStatus.downloading;
  bool get isPaused => this == DirectDownloadStatus.paused;
  bool get isCompleted => this == DirectDownloadStatus.completed;
  bool get isFailed => this == DirectDownloadStatus.failed;
}

class DirectDownloadState extends Equatable {
  final DirectDownloadStatus status;

  /// Link being downloaded: a paused download continues with it
  final String url;

  /// Name the file is saved under, from the link
  final String fileName;

  /// Full path of the file; `null` until the download starts
  final String? savePath;
  final FilesDownloadStage stage;
  final int downloadedBytes;

  /// `null` while the server has not reported the size
  final int? totalBytes;

  /// Over the last seconds; `null` while too little is known
  final double? bytesPerSecond;

  /// Slices being downloaded right now
  final int activeConnections;

  /// Why the download failed, as the downloader put it
  final String? errorMessage;

  const DirectDownloadState({
    this.status = DirectDownloadStatus.idle,
    this.url = '',
    this.fileName = '',
    this.savePath,
    this.stage = FilesDownloadStage.probing,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.bytesPerSecond,
    this.activeConnections = 0,
    this.errorMessage,
  });

  /// The single slot is taken: another link cannot start
  bool get isBusy => status.isStarting || status.isDownloading;

  /// A stopped download continues from the bytes already on disk
  bool get canResume =>
      (status.isPaused || status.isFailed) && url.isNotEmpty && !isBusy;

  /// The progress line and the bar belong on the screen
  bool get hasProgress =>
      !status.isIdle && !(status.isFailed && downloadedBytes == 0);

  /// From 0 to 100; zero while the size is unknown
  double get percent {
    final total = totalBytes;

    if (total == null || total <= 0) return 0;

    return (downloadedBytes / total * 100).clamp(0, 100);
  }

  /// The bar blinks: there is nothing measurable to show yet
  bool get isIndeterminate =>
      isBusy && (totalBytes == null || stage != FilesDownloadStage.downloading);

  /// Seconds left at the current speed
  double? get remainingSeconds {
    final total = totalBytes;
    final speed = bytesPerSecond;

    if (total == null || speed == null || speed <= 0) return null;

    return (total - downloadedBytes) / speed;
  }

  @override
  List<Object?> get props => [
    status,
    url,
    fileName,
    savePath,
    stage,
    downloadedBytes,
    totalBytes,
    bytesPerSecond,
    activeConnections,
    errorMessage,
  ];

  DirectDownloadState copyWith({
    DirectDownloadStatus? status,
    String? url,
    String? fileName,
    String? savePath,
    FilesDownloadStage? stage,
    int? downloadedBytes,
    int? totalBytes,
    double? bytesPerSecond,
    int? activeConnections,
    String? errorMessage,
    bool clearTotalBytes = false,
    bool clearSpeed = false,
    bool clearErrorMessage = false,
  }) => DirectDownloadState(
    status: status ?? this.status,
    url: url ?? this.url,
    fileName: fileName ?? this.fileName,
    savePath: savePath ?? this.savePath,
    stage: stage ?? this.stage,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: clearTotalBytes ? null : totalBytes ?? this.totalBytes,
    bytesPerSecond: clearSpeed ? null : bytesPerSecond ?? this.bytesPerSecond,
    activeConnections: activeConnections ?? this.activeConnections,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
}
