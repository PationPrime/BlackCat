part of 'library_video_model.dart';

/// A video file found in the download folder
class LocalVideoFileModel extends Equatable {
  final String path;

  /// File size in bytes
  final int sizeBytes;
  final DateTime modifiedAt;

  const LocalVideoFileModel({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  @override
  List<Object?> get props => [path, sizeBytes, modifiedAt];
}
