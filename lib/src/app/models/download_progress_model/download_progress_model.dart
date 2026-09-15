import 'package:equatable/equatable.dart';

enum DownloadStage { downloading, processing }

extension DownloadStageX on DownloadStage {
  bool get isDownloading => this == DownloadStage.downloading;
  bool get isProcessing => this == DownloadStage.processing;
}

class DownloadProgressModel extends Equatable {
  final DownloadStage stage;

  /// Percent, from 0 to 100
  final double percent;

  /// Bytes per second
  final num? speed;

  /// Remaining time in seconds
  final num? eta;

  /// Downloaded bytes of all streams, including those downloaded before a pause
  final int? downloadedBytes;

  /// Size of all streams
  final int? totalBytes;

  const DownloadProgressModel(
    this.stage,
    this.percent, {
    this.speed,
    this.eta,
    this.downloadedBytes,
    this.totalBytes,
  });

  @override
  List<Object?> get props => [
    stage,
    percent,
    speed,
    eta,
    downloadedBytes,
    totalBytes,
  ];
}
