import 'download_options.dart';

/// One piece of a segmented stream, e.g. an HLS segment
final class DownloadSegmentRequest {
  final String url;

  /// The finished segment. It is written to `<savePath>.part` first and
  /// renamed once complete, so a finished segment is never downloaded again
  final String savePath;

  const DownloadSegmentRequest({required this.url, required this.savePath});

  @override
  String toString() => 'DownloadSegmentRequest($savePath)';
}

/// A stream cut into many small files, like the segments of an HLS playlist.
///
/// Every segment comes whole in one request: no size requests and no slices.
/// Slices gain nothing on files of a few megabytes, and a size request costs
/// a round trip per segment. Progress needs no state file either: a segment
/// on disk under its own name is finished
final class SegmentsDownloadRequest {
  final String id;
  final List<DownloadSegmentRequest> segments;

  /// Size the caller expects, e.g. bitrate × duration of the playlist.
  /// The free space check and the progress use it until the finished
  /// segments show their real sizes
  final int? expectedBytes;

  /// [FilesDownloadOptions.sliceSize], `checkpointInterval`,
  /// `existingFilePolicy` and `deleteStateOnComplete` do not apply
  final FilesDownloadOptions options;

  const SegmentsDownloadRequest({
    required this.id,
    required this.segments,
    this.expectedBytes,
    this.options = const FilesDownloadOptions(),
  });

  @override
  String toString() =>
      'SegmentsDownloadRequest($id, ${segments.length} segments)';
}
