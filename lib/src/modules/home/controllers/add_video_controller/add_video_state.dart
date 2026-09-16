part of 'add_video_controller.dart';

class AddVideoState extends Equatable {
  /// Link of the last search: the request is retried with it after signing in
  final String requestedUrl;

  /// Engine the last search started with
  final DownloadEngineModel requestedEngine;

  /// Engine that did the last search: the video is downloaded with it
  final DownloadEngineModel engine;

  /// Video info is being fetched
  final bool isInfoLoading;
  final VideoInfoModel? videoInfo;

  /// `1080`, `720`… or [QualityModel.audioId]
  final String selectedQualityId;
  final Failure? failure;

  /// The video that has just been added to the downloads
  final VideoInfoModel? addedVideo;

  const AddVideoState({
    this.requestedUrl = '',
    this.requestedEngine = DownloadEngineModel.fallback,
    this.engine = DownloadEngineModel.fallback,
    this.isInfoLoading = false,
    this.videoInfo,
    this.selectedQualityId = '',
    this.failure,
    this.addedVideo,
  });

  QualityModel? get selectedQuality => videoInfo?.qualities
      .where((quality) => quality.id == selectedQualityId)
      .firstOrNull;

  /// The video is found and a quality is selected: it can be added
  bool get canAdd => selectedQuality != null;

  @override
  List<Object?> get props => [
    requestedUrl,
    requestedEngine,
    engine,
    isInfoLoading,
    videoInfo,
    selectedQualityId,
    failure,
    addedVideo,
  ];

  AddVideoState copyWith({
    String? requestedUrl,
    DownloadEngineModel? requestedEngine,
    DownloadEngineModel? engine,
    bool? isInfoLoading,
    VideoInfoModel? videoInfo,
    String? selectedQualityId,
    Failure? failure,
    VideoInfoModel? addedVideo,
    bool clearVideoInfo = false,
    bool clearFailure = false,
    bool clearAddedVideo = false,
  }) => AddVideoState(
    requestedUrl: requestedUrl ?? this.requestedUrl,
    requestedEngine: requestedEngine ?? this.requestedEngine,
    engine: engine ?? this.engine,
    isInfoLoading: isInfoLoading ?? this.isInfoLoading,
    videoInfo: clearVideoInfo ? null : videoInfo ?? this.videoInfo,
    selectedQualityId: selectedQualityId ?? this.selectedQualityId,
    failure: clearFailure ? null : failure ?? this.failure,
    addedVideo: clearAddedVideo ? null : addedVideo ?? this.addedVideo,
  );
}

final class AddVideoInitialState extends AddVideoState {
  const AddVideoInitialState();
}
