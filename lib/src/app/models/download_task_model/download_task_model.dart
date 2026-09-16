import 'package:equatable/equatable.dart';

import '../download_engine_model/download_engine_model.dart';
import '../quality_model/quality_model.dart';
import '../video_info_model/video_info_model.dart';

part 'download_stream_model.dart';
part 'download_task_status.dart';

/// A video in the download queue: what is downloaded, in which quality,
/// where the task stands and how much is already downloaded
class DownloadTaskModel extends Equatable {
  final String id;

  /// Video without the quality list: the download needs only the selected one
  final VideoInfoModel video;
  final QualityModel quality;
  final DownloadTaskStatus status;
  final DownloadTaskSection section;

  /// Engine that downloads the video. Both engines keep unfinished streams
  /// alike, so the built-in one takes over if yt-dlp disappears
  final DownloadEngineModel engine;

  /// Position in the queue, starting from 0. For the active and finished ones: display order
  final int position;

  /// Streams selected on the first start: the download continues from the same
  /// place using them. Empty until the download has ever started
  final List<DownloadStreamModel> streams;

  /// Downloaded bytes of all streams
  final int downloadedBytes;

  /// Size of all streams. `null` until the streams are selected
  final int? totalBytes;

  /// Bytes per second. Only while downloading, not stored
  final num? speed;

  /// Remaining time in seconds. Only while downloading, not stored
  final num? eta;

  /// Finished file in the download folder
  final String? filePath;

  /// Size of the finished file in bytes
  final int? fileSizeBytes;

  /// Local copy of the thumbnail in the app folder. `null` until the video
  /// is downloaded or if the thumbnail could not be saved
  final String? thumbnailPath;

  /// When the download finished
  final DateTime? completedAt;

  final String? failureMessage;

  /// Signing in to YouTube (or refreshing the sign-in) will most likely help
  final bool failureNeedsSignIn;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DownloadTaskModel({
    required this.id,
    required this.video,
    required this.quality,
    required this.status,
    required this.section,
    required this.createdAt,
    required this.updatedAt,
    this.engine = DownloadEngineModel.builtIn,
    this.position = 0,
    this.streams = const [],
    this.downloadedBytes = 0,
    this.totalBytes,
    this.speed,
    this.eta,
    this.filePath,
    this.fileSizeBytes,
    this.thumbnailPath,
    this.completedAt,
    this.failureMessage,
    this.failureNeedsSignIn = false,
  });

  /// Size for progress: exact after the streams are selected, approximate before
  int? get expectedBytes => totalBytes ?? quality.size;

  /// Percent, from 0 to 100
  double get percent {
    if (status.isDone || status.isProcessing) return 100;

    final expected = expectedBytes;

    if (expected == null || expected <= 0) return 0;

    return (downloadedBytes / expected * 1000).floor().clamp(0, 1000) / 10;
  }

  bool get hasProgress => downloadedBytes > 0;

  /// An unfinished video with progress: the downloaded bytes are deleted with it,
  /// so removal must be confirmed. A finished file stays when removed
  bool get removalNeedsConfirmation => !status.isDone && hasProgress;

  bool get isRunning => status.isDownloading || status.isProcessing;

  @override
  List<Object?> get props => [
    id,
    video,
    quality,
    status,
    section,
    engine,
    position,
    streams,
    downloadedBytes,
    totalBytes,
    speed,
    eta,
    filePath,
    fileSizeBytes,
    thumbnailPath,
    completedAt,
    failureMessage,
    failureNeedsSignIn,
    createdAt,
    updatedAt,
  ];

  DownloadTaskModel copyWith({
    DownloadTaskStatus? status,
    DownloadTaskSection? section,
    DownloadEngineModel? engine,
    int? position,
    List<DownloadStreamModel>? streams,
    int? downloadedBytes,
    int? totalBytes,
    num? speed,
    num? eta,
    String? filePath,
    int? fileSizeBytes,
    String? thumbnailPath,
    DateTime? completedAt,
    String? failureMessage,
    bool? failureNeedsSignIn,
    DateTime? updatedAt,
    bool clearSpeed = false,
    bool clearFailure = false,
  }) => DownloadTaskModel(
    id: id,
    video: video,
    quality: quality,
    status: status ?? this.status,
    section: section ?? this.section,
    engine: engine ?? this.engine,
    position: position ?? this.position,
    streams: streams ?? this.streams,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    speed: clearSpeed ? null : speed ?? this.speed,
    eta: clearSpeed ? null : eta ?? this.eta,
    filePath: filePath ?? this.filePath,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    completedAt: completedAt ?? this.completedAt,
    failureMessage: clearFailure ? null : failureMessage ?? this.failureMessage,
    failureNeedsSignIn: clearFailure
        ? false
        : failureNeedsSignIn ?? this.failureNeedsSignIn,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
