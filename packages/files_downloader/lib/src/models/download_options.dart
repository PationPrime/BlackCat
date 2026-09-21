/// What to do with a file already at the save path when the download
/// has no state for it
enum ExistingFilePolicy {
  /// The file is downloaded anew
  replace,

  /// The file is the start of the target written in order, e.g. by another
  /// downloader: its bytes are kept and the download continues after them.
  /// A file of the full size counts as downloaded
  continuePrefix,
}

/// How a download runs
final class FilesDownloadOptions {
  static const defaultSliceSize = 10 * 1024 * 1024;

  /// Files are split into slices of this size; each slice is a separate
  /// request and the unit of the saved progress
  final int sliceSize;

  /// Slices downloaded at the same time across all files of the download
  final int maxConnections;

  /// Failed attempts in a row after which a slice fails the download.
  /// An attempt that brought bytes resets the count
  final int maxRetries;

  /// Delay before the first retry; every next one is twice as long
  final Duration retryBaseDelay;
  final Duration connectTimeout;

  /// A connection that brings no bytes this long is dropped and retried
  final Duration idleTimeout;

  /// Progress is reported no more often
  final Duration progressInterval;

  /// Written bytes are flushed to disk and the state file is updated
  /// no more often
  final Duration checkpointInterval;

  /// Bytes per second across all connections; `null` is no limit
  final int? speedLimit;

  /// Headers of every request, e.g. `User-Agent`
  final Map<String, String> headers;
  final ExistingFilePolicy existingFilePolicy;

  /// A finished download deletes its state file
  final bool deleteStateOnComplete;

  const FilesDownloadOptions({
    this.sliceSize = defaultSliceSize,
    this.maxConnections = 4,
    this.maxRetries = 6,
    this.retryBaseDelay = const Duration(milliseconds: 500),
    this.connectTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 30),
    this.progressInterval = const Duration(milliseconds: 500),
    this.checkpointInterval = const Duration(seconds: 2),
    this.speedLimit,
    this.headers = const {},
    this.existingFilePolicy = ExistingFilePolicy.replace,
    this.deleteStateOnComplete = true,
  }) : assert(sliceSize > 0),
       assert(maxConnections > 0),
       assert(maxRetries >= 0);
}
