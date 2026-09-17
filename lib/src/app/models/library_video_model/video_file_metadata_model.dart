part of 'library_video_model.dart';

/// What the system knows about a video file
class VideoFileMetadataModel extends Equatable {
  /// `null`: the system does not know the duration
  final Duration? duration;

  /// The thumbnail was written to the requested path
  final bool hasThumbnail;

  const VideoFileMetadataModel({this.duration, this.hasThumbnail = false});

  @override
  List<Object?> get props => [duration, hasThumbnail];
}
