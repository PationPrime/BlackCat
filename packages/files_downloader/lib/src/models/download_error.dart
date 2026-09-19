/// Why a download failed
enum FilesDownloadErrorType {
  /// No connection, a dropped connection or a timeout that retries
  /// did not fix
  network,

  /// The server answered with an error status
  httpStatus,

  /// The server does not give the bytes asked for: a wrong `Content-Range`
  /// or length
  invalidResponse,

  /// The file on the server is not the one the download started with:
  /// its size or validator changed. The state is dropped, the next start
  /// downloads the file anew
  sourceChanged,

  /// The disk has no room for the download: [FilesDownloadError.neededBytes]
  /// is how much it still needs, [FilesDownloadError.availableBytes]
  /// how much is free. Downloaded bytes stay: free some space and start
  /// the download again
  diskFull,

  /// Reading or writing files failed
  fileSystem,
  unknown,
}

final class FilesDownloadError implements Exception {
  /// Statuses a later attempt may get past
  static const _retryableStatuses = {408, 425, 429, 500, 502, 503, 504};

  final FilesDownloadErrorType type;
  final String message;
  final String? url;
  final int? statusCode;

  /// File the error is about, for disk errors
  final String? path;

  /// Bytes the download still needs on disk, when the disk is full
  final int? neededBytes;

  /// Free bytes on the disk, when the disk is full and the system tells
  final int? availableBytes;

  const FilesDownloadError(
    this.type,
    this.message, {
    this.url,
    this.statusCode,
    this.path,
    this.neededBytes,
    this.availableBytes,
  });

  /// Another attempt of the same request may succeed
  bool get isRetryable => switch (type) {
    FilesDownloadErrorType.network ||
    FilesDownloadErrorType.invalidResponse => true,
    FilesDownloadErrorType.httpStatus => _retryableStatuses.contains(
      statusCode,
    ),
    _ => false,
  };

  @override
  String toString() =>
      'FilesDownloadError(${type.name}${statusCode == null ? '' : ' $statusCode'}): '
      '$message${url == null ? '' : ' [$url]'}${path == null ? '' : ' [$path]'}';
}
