part of 'video_playback_controller.dart';

class VideoPlaybackState extends Equatable {
  final LibraryVideoModel video;
  final VideoPlaybackModel playback;

  /// The file is being opened
  final bool isOpening;
  final Failure? failure;

  const VideoPlaybackState({
    required this.video,
    this.playback = const VideoPlaybackModel(),
    this.isOpening = false,
    this.failure,
  });

  @override
  List<Object?> get props => [video, playback, isOpening, failure];

  VideoPlaybackState copyWith({
    VideoPlaybackModel? playback,
    bool? isOpening,
    Failure? failure,
    bool clearFailure = false,
  }) => VideoPlaybackState(
    video: video,
    playback: playback ?? this.playback,
    isOpening: isOpening ?? this.isOpening,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class VideoPlaybackInitialState extends VideoPlaybackState {
  const VideoPlaybackInitialState({required super.video})
    : super(isOpening: true);
}
