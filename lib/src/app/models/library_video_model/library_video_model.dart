import 'package:equatable/equatable.dart';

import '../../constants/constants.dart';

part 'local_video_file_model.dart';
part 'video_file_metadata_model.dart';

/// A video of the player library: a file in the download folder
/// and where the user stopped watching it
class LibraryVideoModel extends Equatable {
  /// Stable for the file path, whatever its letter case
  final String id;
  final String path;

  /// Title of the downloaded video or the file name
  final String title;

  /// File size in bytes
  final int sizeBytes;

  /// Last change of the file: a replaced file is read anew
  final DateTime modifiedAt;

  /// `null` while unknown: the system has not reported it and the video
  /// has not been played yet
  final Duration? duration;

  /// Where the user stopped watching
  final Duration position;

  /// Local thumbnail. `null`: the card shows a black plate
  final String? thumbnailPath;

  /// The system has been asked for the thumbnail and duration: whatever
  /// it gave, it is not asked again for the same file
  final bool isMetadataLoaded;

  /// When the video was last watched
  final DateTime? watchedAt;

  const LibraryVideoModel({
    required this.id,
    required this.path,
    required this.title,
    required this.sizeBytes,
    required this.modifiedAt,
    this.duration,
    this.position = Duration.zero,
    this.thumbnailPath,
    this.isMetadataLoaded = false,
    this.watchedAt,
  });

  /// Share of the video watched, from 0 to 1. `null` when there is nothing
  /// to show: not started or the duration is unknown
  double? get watchedFraction {
    final duration = this.duration;

    if (duration == null ||
        duration <= Duration.zero ||
        position <= Duration.zero) {
      return null;
    }

    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Watched to the end or almost
  bool get isWatched {
    final duration = this.duration;

    return duration != null &&
        position > Duration.zero &&
        duration - position <= PlayerConstants.resumeMargin;
  }

  /// Where playback starts: from the saved position, or from the beginning
  /// if the video was barely started or already watched
  Duration get resumePosition =>
      position <= PlayerConstants.resumeMargin || isWatched
      ? Duration.zero
      : position;

  LibraryVideoModel copyWith({
    String? title,
    Duration? duration,
    Duration? position,
    String? thumbnailPath,
    bool? isMetadataLoaded,
    DateTime? watchedAt,
  }) => LibraryVideoModel(
    id: id,
    path: path,
    title: title ?? this.title,
    sizeBytes: sizeBytes,
    modifiedAt: modifiedAt,
    duration: duration ?? this.duration,
    position: position ?? this.position,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    isMetadataLoaded: isMetadataLoaded ?? this.isMetadataLoaded,
    watchedAt: watchedAt ?? this.watchedAt,
  );

  @override
  List<Object?> get props => [
    id,
    path,
    title,
    sizeBytes,
    modifiedAt,
    duration,
    position,
    thumbnailPath,
    isMetadataLoaded,
    watchedAt,
  ];
}
