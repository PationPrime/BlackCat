import 'download_options.dart';

/// How a slice asks the server for its bytes
enum RangeRequestMode {
  /// The standard `Range: bytes=start-end` header. The server answers
  /// `206 Partial Content` with a `Content-Range` header
  header,

  /// A `range=start-end` query parameter, as googlevideo.com expects.
  /// The server answers `200 OK` with exactly the bytes asked for
  queryParameter,
}

/// One file of a download: where it comes from and where it goes
final class DownloadFileRequest {
  final String url;

  /// The file is written here in place: slices fill it in any order
  final String savePath;

  /// Headers of this file's requests on top of [FilesDownloadOptions.headers]
  final Map<String, String> headers;

  /// Size the caller already knows. Used when the server does not report
  /// the size; the size the server reports wins
  final int? expectedLength;

  /// Tells this file apart in the state: a state made for another file
  /// is not reused. Defaults to [savePath]. Signed links change between
  /// sessions, so a stable name of the content fits best
  final String? fingerprint;

  final RangeRequestMode rangeMode;

  /// A state made when the server reported another `ETag` or
  /// `Last-Modified` is not reused, and ranges are asked with `If-Range`.
  /// Turn it off for servers whose validators change between links
  /// of the same content
  final bool checkValidator;

  const DownloadFileRequest({
    required this.url,
    required this.savePath,
    this.headers = const {},
    this.expectedLength,
    this.fingerprint,
    this.rangeMode = RangeRequestMode.header,
    this.checkValidator = true,
  });

  String get identity => fingerprint ?? savePath;

  @override
  String toString() => 'DownloadFileRequest($savePath)';
}

/// A download: one or more files that are downloaded, paused and resumed
/// together. Slice progress of all of them lives in one state file,
/// `state_<id>.fds` in [stateDirectory]
final class FilesDownloadRequest {
  final String id;
  final List<DownloadFileRequest> files;
  final String stateDirectory;
  final FilesDownloadOptions options;

  const FilesDownloadRequest({
    required this.id,
    required this.files,
    required this.stateDirectory,
    this.options = const FilesDownloadOptions(),
  });

  @override
  String toString() => 'FilesDownloadRequest($id, ${files.length} files)';
}
