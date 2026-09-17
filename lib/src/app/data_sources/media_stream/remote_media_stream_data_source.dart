import 'dart:async';

import 'package:files_downloader/files_downloader.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../errors/errors.dart';
import '../../tools/tools.dart';

/// A stream file of a download
final class MediaStreamTarget {
  final String url;
  final String path;

  /// Size of the stream from the YouTube response
  final int length;

  /// Stable name of the stream: its saved progress survives new links
  final String fingerprint;

  const MediaStreamTarget({
    required this.url,
    required this.path,
    required this.length,
    required this.fingerprint,
  });
}

final class MediaStreamProgress {
  final int downloadedBytes;
  final int totalBytes;

  /// `null` while too little is known
  final double? bytesPerSecond;

  const MediaStreamProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    this.bytesPerSecond,
  });
}

/// googlevideo.com refused the stream links: they expired, and new links
/// continue the same download
final class MediaStreamLinksExpiredException implements Exception {
  const MediaStreamLinksExpiredException();
}

/// Video and audio streams from googlevideo.com
abstract interface class RemoteMediaStreamDataSource {
  /// Downloads the streams into their files in 10 MiB slices over several
  /// connections, in a background isolate. Slice progress of all streams
  /// lives in `state_<downloadId>.fds` in [stateDirectory], so a stopped
  /// download continues from it. A stream file written in order, e.g. by
  /// yt-dlp, is continued after its bytes.
  ///
  /// Throws [MediaStreamLinksExpiredException] when the links are refused,
  /// and [VideoException] with [VideoErrorCodes.canceled] when stopped
  /// through [cancellation]
  Future<void> downloadStreams({
    required String downloadId,
    required List<MediaStreamTarget> streams,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  });
}

final class RemoteMediaStreamDataSourceImpl
    implements RemoteMediaStreamDataSource {
  static const _progressInterval = Duration(milliseconds: 250);

  final ApiProvider _apiProvider;
  final FilesDownloader _filesDownloader;

  RemoteMediaStreamDataSourceImpl({
    required this._apiProvider,
    FilesDownloader? filesDownloader,
  }) : _filesDownloader = filesDownloader ?? FilesDownloader();

  /// The media client settings go into the download isolate
  FilesDownloadOptions get _options {
    final client = _apiProvider.media;

    return FilesDownloadOptions(
      sliceSize: YouTubeConstants.streamChunkSize,
      maxConnections: YouTubeConstants.streamConnections,
      connectTimeout: client.connectTimeout,
      idleTimeout: client.receiveTimeout,
      progressInterval: _progressInterval,
      headers: {
        for (final header in client.headers.entries)
          header.key: '${header.value}',
      },
      existingFilePolicy: ExistingFilePolicy.continuePrefix,
    );
  }

  @override
  Future<void> downloadStreams({
    required String downloadId,
    required List<MediaStreamTarget> streams,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled ?? false) {
      throw VideoException(const VideoErrorCodes().canceled);
    }

    final total = streams.fold<int>(0, (sum, stream) => sum + stream.length);
    final download = await _filesDownloader.start(
      FilesDownloadRequest(
        id: downloadId,
        stateDirectory: stateDirectory,
        options: _options,
        files: [
          for (final stream in streams)
            DownloadFileRequest(
              url: stream.url,
              savePath: stream.path,
              expectedLength: stream.length,
              fingerprint: stream.fingerprint,

              /// googlevideo.com gives ranges by the link parameter,
              /// and its validators differ between links of one stream
              rangeMode: RangeRequestMode.queryParameter,
              checkValidator: false,
            ),
        ],
      ),
    );

    final subscription = download.progress.listen(
      (progress) => onProgress(
        MediaStreamProgress(
          downloadedBytes: progress.downloadedBytes,
          totalBytes: progress.totalBytes ?? total,
          bytesPerSecond: progress.bytesPerSecond,
        ),
      ),
    );

    unawaited(cancellation?.whenCancelled.then((_) => download.pause()));

    final result = await download.result;

    /// The progress stream is already closed
    unawaited(subscription.cancel());

    switch (result) {
      case FilesDownloadCompleted(:final files):
        for (final (index, file) in files.indexed) {
          if (file.length != streams[index].length) {
            throw VideoException(const VideoErrorCodes().streamInterrupted);
          }
        }
      case FilesDownloadStopped():
        throw VideoException(const VideoErrorCodes().canceled);
      case FilesDownloadFailed(:final error):
        throw _exceptionOf(error);
    }
  }

  static Exception _exceptionOf(FilesDownloadError error) {
    const codes = VideoErrorCodes();

    return switch (error) {
      FilesDownloadError(statusCode: 401 || 403 || 410) =>
        const MediaStreamLinksExpiredException(),
      FilesDownloadError(statusCode: 429) => VideoException(codes.rateLimited),
      FilesDownloadError(type: FilesDownloadErrorType.httpStatus) =>
        VideoException(
          codes.httpStatus,
          args: {'status': '${error.statusCode}'},
        ),
      FilesDownloadError(type: FilesDownloadErrorType.network) =>
        VideoException(codes.noConnection),
      FilesDownloadError(type: FilesDownloadErrorType.fileSystem) =>
        VideoException(codes.diskWrite, args: {'error': error.message}),
      _ => VideoException(codes.streamInterrupted),
    };
  }
}
