import 'package:equatable/equatable.dart';

/// State of the video player
class VideoPlaybackModel extends Equatable {
  final Duration position;
  final Duration duration;

  /// How far the video is read ahead
  final Duration buffered;
  final bool isPlaying;

  /// Waiting for data: the picture stands still
  final bool isBuffering;

  /// Played to the end
  final bool isCompleted;

  /// Playback speed, 1 is normal
  final double rate;

  /// From 0 to 1
  final double volume;
  final bool isMuted;

  /// Message of the player when the video could not be played
  final String? error;

  const VideoPlaybackModel({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.rate = 1,
    this.volume = 1,
    this.isMuted = false,
    this.error,
  });

  /// Played share from 0 to 1
  double get progress => duration <= Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  /// Read-ahead share from 0 to 1
  double get bufferedProgress => duration <= Duration.zero
      ? 0
      : (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  VideoPlaybackModel copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    double? rate,
    double? volume,
    bool? isMuted,
    String? error,
    bool clearError = false,
  }) => VideoPlaybackModel(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    isPlaying: isPlaying ?? this.isPlaying,
    isBuffering: isBuffering ?? this.isBuffering,
    isCompleted: isCompleted ?? this.isCompleted,
    rate: rate ?? this.rate,
    volume: volume ?? this.volume,
    isMuted: isMuted ?? this.isMuted,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [
    position,
    duration,
    buffered,
    isPlaying,
    isBuffering,
    isCompleted,
    rate,
    volume,
    isMuted,
    error,
  ];
}
