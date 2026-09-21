/// What a download is doing
enum FilesDownloadStage {
  /// Asking the servers for sizes and range support
  probing,

  /// Reading the state and reserving the files on disk
  preparing,
  downloading,

  /// Checking the files and cleaning up the state
  finishing,
}

/// Progress of one file of a download
final class FileDownloadProgress {
  final String savePath;
  final int downloadedBytes;

  /// `null` while the size is unknown
  final int? totalBytes;
  final int completedSlices;
  final int sliceCount;

  const FileDownloadProgress({
    required this.savePath,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.completedSlices,
    required this.sliceCount,
  });

  @override
  String toString() =>
      'FileDownloadProgress($savePath: $downloadedBytes/$totalBytes, '
      'slices $completedSlices/$sliceCount)';
}

/// Progress of a download: bytes on disk, including the ones downloaded
/// before a pause
final class FilesDownloadProgress {
  final String id;
  final FilesDownloadStage stage;
  final int downloadedBytes;

  /// `null` while the size of any file is unknown
  final int? totalBytes;

  /// Over the last seconds; `null` while too little is known
  final double? bytesPerSecond;

  /// Slices being downloaded right now
  final int activeConnections;
  final List<FileDownloadProgress> files;

  const FilesDownloadProgress({
    required this.id,
    required this.stage,
    required this.downloadedBytes,
    required this.totalBytes,
    this.bytesPerSecond,
    this.activeConnections = 0,
    this.files = const [],
  });

  /// From 0 to 1; `null` while the size is unknown
  double? get fraction {
    final total = totalBytes;

    if (total == null) return null;

    return total == 0 ? 1 : (downloadedBytes / total).clamp(0.0, 1.0);
  }

  /// Time left at the current speed
  Duration? get remaining {
    final total = totalBytes;
    final speed = bytesPerSecond;

    if (total == null || speed == null || speed <= 0) return null;

    final seconds = (total - downloadedBytes) / speed;

    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  String toString() =>
      'FilesDownloadProgress($id, ${stage.name}, '
      '$downloadedBytes/$totalBytes, ${bytesPerSecond?.round()} B/s)';
}
