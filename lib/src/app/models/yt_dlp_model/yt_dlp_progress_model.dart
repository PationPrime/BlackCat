part of 'yt_dlp_setup_model.dart';

/// One progress line of a yt-dlp download
class YtDlpProgressModel extends Equatable {
  /// `downloading`, `finished` or `error`
  final String status;

  /// Bytes in the file, including the ones downloaded before a resume
  final int? downloadedBytes;
  final int? totalBytes;

  /// Bytes per second
  final num? speed;

  /// Remaining time in seconds
  final num? eta;

  const YtDlpProgressModel({
    required this.status,
    this.downloadedBytes,
    this.totalBytes,
    this.speed,
    this.eta,
  });

  bool get isFinished => status == 'finished';

  @override
  List<Object?> get props => [status, downloadedBytes, totalBytes, speed, eta];
}
