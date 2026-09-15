import 'package:equatable/equatable.dart';

enum DownloadStage { downloading, processing }

extension DownloadStageX on DownloadStage {
  bool get isDownloading => this == DownloadStage.downloading;
  bool get isProcessing => this == DownloadStage.processing;
}

class DownloadProgressModel extends Equatable {
  final DownloadStage stage;

  /// Проценты, от 0 до 100
  final double percent;

  /// Байт в секунду
  final num? speed;

  /// Оставшееся время в секундах
  final num? eta;

  const DownloadProgressModel(this.stage, this.percent, {this.speed, this.eta});

  @override
  List<Object?> get props => [stage, percent, speed, eta];
}
