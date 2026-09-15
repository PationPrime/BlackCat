part of 'add_video_controller.dart';

class AddVideoState extends Equatable {
  /// Link of the last search: the request is retried with it after signing in
  final String requestedUrl;

  /// Video info is being fetched
  final bool isInfoLoading;
  final VideoInfoModel? videoInfo;

  /// `1080`, `720`… or [QualityModel.audioId]
  final String selectedQualityId;
  final Failure? failure;

  const AddVideoState({
    this.requestedUrl = '',
    this.isInfoLoading = false,
    this.videoInfo,
    this.selectedQualityId = '',
    this.failure,
  });

  QualityModel? get selectedQuality => videoInfo?.qualities
      .where((quality) => quality.id == selectedQualityId)
      .firstOrNull;

  /// The video is found and a quality is selected: it can be added
  bool get canAdd => selectedQuality != null;

  @override
  List<Object?> get props => [
    requestedUrl,
    isInfoLoading,
    videoInfo,
    selectedQualityId,
    failure,
  ];

  AddVideoState copyWith({
    String? requestedUrl,
    bool? isInfoLoading,
    VideoInfoModel? videoInfo,
    String? selectedQualityId,
    Failure? failure,
    bool clearVideoInfo = false,
    bool clearFailure = false,
  }) => AddVideoState(
    requestedUrl: requestedUrl ?? this.requestedUrl,
    isInfoLoading: isInfoLoading ?? this.isInfoLoading,
    videoInfo: clearVideoInfo ? null : videoInfo ?? this.videoInfo,
    selectedQualityId: selectedQualityId ?? this.selectedQualityId,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class AddVideoInitialState extends AddVideoState {
  const AddVideoInitialState();
}
