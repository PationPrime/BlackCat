import 'download_error.dart';

/// A downloaded file
final class DownloadedFile {
  final String path;
  final int length;

  const DownloadedFile({required this.path, required this.length});

  @override
  String toString() => 'DownloadedFile($path, $length)';
}

/// How a download ended
sealed class FilesDownloadResult {
  final String id;

  const FilesDownloadResult(this.id);
}

/// Every file is on disk in full
final class FilesDownloadCompleted extends FilesDownloadResult {
  final List<DownloadedFile> files;

  const FilesDownloadCompleted(super.id, {required this.files});

  @override
  String toString() => 'FilesDownloadCompleted($id, $files)';
}

/// The download was stopped. Paused: the files and the state stay
/// for resuming. Discarded: both are deleted
final class FilesDownloadStopped extends FilesDownloadResult {
  final int downloadedBytes;
  final int? totalBytes;
  final bool discarded;

  const FilesDownloadStopped(
    super.id, {
    required this.downloadedBytes,
    required this.totalBytes,
    this.discarded = false,
  });

  @override
  String toString() =>
      'FilesDownloadStopped($id, $downloadedBytes/$totalBytes'
      '${discarded ? ', discarded' : ''})';
}

/// The download could not finish. Downloaded bytes stay for resuming,
/// unless the file changed on the server
final class FilesDownloadFailed extends FilesDownloadResult {
  final FilesDownloadError error;
  final int downloadedBytes;

  const FilesDownloadFailed(
    super.id, {
    required this.error,
    required this.downloadedBytes,
  });

  @override
  String toString() => 'FilesDownloadFailed($id, $error)';
}
