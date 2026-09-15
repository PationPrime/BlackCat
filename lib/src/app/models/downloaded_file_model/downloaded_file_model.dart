import 'package:equatable/equatable.dart';

/// Finished video file in the download folder
class DownloadedFileModel extends Equatable {
  final String path;

  /// File size in bytes
  final int sizeBytes;

  const DownloadedFileModel({required this.path, required this.sizeBytes});

  @override
  List<Object?> get props => [path, sizeBytes];
}
