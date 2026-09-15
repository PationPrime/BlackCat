part of 'downloader_controller.dart';

enum DownloadJobStatus { downloading, processing, done }

extension DownloadJobStatusX on DownloadJobStatus {
  bool get isDownloading => this == DownloadJobStatus.downloading;
  bool get isProcessing => this == DownloadJobStatus.processing;
  bool get isDone => this == DownloadJobStatus.done;
}

/// Текущая загрузка видео
final class DownloadJob extends Equatable {
  final DownloadJobStatus status;

  /// Проценты, от 0 до 100
  final double percent;

  /// Байт в секунду
  final num? speed;

  /// Оставшееся время в секундах
  final num? eta;

  /// Готовый файл в «Загрузках»
  final String? filePath;

  const DownloadJob({
    required this.status,
    required this.percent,
    this.speed,
    this.eta,
    this.filePath,
  });

  bool get isActive => !status.isDone;

  @override
  List<Object?> get props => [status, percent, speed, eta, filePath];
}

class DownloaderState extends Equatable {
  /// Ссылка последнего поиска: по ней повторяется запрос после входа
  final String requestedUrl;

  /// Идёт получение информации о видео
  final bool isInfoLoading;
  final VideoInfoModel? videoInfo;

  /// `1080`, `720`… или [QualityModel.audioId]
  final String selectedQualityId;
  final DownloadJob? job;
  final Failure? failure;

  const DownloaderState({
    this.requestedUrl = '',
    this.isInfoLoading = false,
    this.videoInfo,
    this.selectedQualityId = '',
    this.job,
    this.failure,
  });

  bool get isJobActive => job?.isActive ?? false;

  /// Нельзя начать новый поиск, пока ищем или качаем
  bool get canSearch => !isInfoLoading && !isJobActive;

  bool get canDownload => videoInfo != null && selectedQualityId.isNotEmpty;

  @override
  List<Object?> get props => [
    requestedUrl,
    isInfoLoading,
    videoInfo,
    selectedQualityId,
    job,
    failure,
  ];

  DownloaderState copyWith({
    String? requestedUrl,
    bool? isInfoLoading,
    VideoInfoModel? videoInfo,
    String? selectedQualityId,
    DownloadJob? job,
    Failure? failure,
    bool clearVideoInfo = false,
    bool clearJob = false,
    bool clearFailure = false,
  }) => DownloaderState(
    requestedUrl: requestedUrl ?? this.requestedUrl,
    isInfoLoading: isInfoLoading ?? this.isInfoLoading,
    videoInfo: clearVideoInfo ? null : videoInfo ?? this.videoInfo,
    selectedQualityId: selectedQualityId ?? this.selectedQualityId,
    job: clearJob ? null : job ?? this.job,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class DownloaderInitialState extends DownloaderState {
  const DownloaderInitialState();
}
