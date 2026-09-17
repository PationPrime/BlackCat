part of 'video_library_controller.dart';

class VideoLibraryState extends Equatable {
  /// Download folder the list is read from; `null` until the settings
  /// are loaded
  final String? folder;

  /// The newest first
  final List<LibraryVideoModel> videos;

  /// The folder is read for the first time
  final bool isLoading;
  final Failure? failure;

  const VideoLibraryState({
    this.folder,
    this.videos = const [],
    this.isLoading = false,
    this.failure,
  });

  @override
  List<Object?> get props => [folder, videos, isLoading, failure];

  VideoLibraryState copyWith({
    List<LibraryVideoModel>? videos,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) => VideoLibraryState(
    folder: folder,
    videos: videos ?? this.videos,
    isLoading: isLoading ?? this.isLoading,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class VideoLibraryInitialState extends VideoLibraryState {
  const VideoLibraryInitialState() : super(isLoading: true);
}
