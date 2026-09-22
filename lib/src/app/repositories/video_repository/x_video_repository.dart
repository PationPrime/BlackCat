import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import 'video_repository_interface.dart';

/// A post video with its qualities, while its links are fresh
final class _ResolvedXVideo {
  final XVideoDto video;
  final DateTime resolvedAt;

  _ResolvedXVideo(this.video) : resolvedAt = DateTime.now();

  /// A post may be edited or removed: it is read again after a while
  bool get expired =>
      DateTime.now().difference(resolvedAt) > const Duration(minutes: 30);
}

/// X (Twitter) videos straight over HTTP (dio), without yt-dlp.
///
/// 1. The embed API, which needs no account, gives the post and the MP4
///    files of its video.
/// 2. The quality picks one of the files: video and audio come together,
///    nothing is muxed.
/// 3. The file is downloaded in slices over several connections into the
///    download work folder; slice progress lives there, so a paused download
///    continues
final class XVideoRepository implements VideoRepositoryInterface {
  final RemoteXDataSource _remoteXDataSource;
  final FileSystemService _fileSystemService;

  final _resolvedVideos = <XPostLink, _ResolvedXVideo>{};

  XVideoRepository({
    required this._remoteXDataSource,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final video = (await _resolve(_parse(url))).video;
      final qualities = XQualities.build(video.formats);

      if (qualities.isEmpty) {
        throw VideoException(const VideoErrorCodes().streamFormat);
      }

      return ok(
        VideoInfoModel(
          id: video.id,
          title: video.title,
          url: video.url,
          channel: video.authorName,
          duration: video.durationSeconds,
          thumbnail: video.thumbnail,
          viewCount: video.viewCount,
          qualities: qualities,
        ),
      );
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<OperationResult<DownloadedFileModel>> downloadVideo({
    required String taskId,
    required String url,
    required String quality,
    List<DownloadStreamModel> streams = const [],
    String? destinationDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    try {
      final link = _parse(url);

      /// The work folder lives until the download finishes: after a pause
      /// we continue in it
      final workDirectory = (await _fileSystemService.downloadWorkDirectory(
        taskId,
      )).path;

      var resolved = _resolvedVideos[link];

      if (resolved == null || resolved.expired) {
        resolved = await _resolve(link);
      }

      _throwIfCancelled(cancellation);

      /// Streams of the latest attempt: a retry continues the same file
      var selectedStreams = streams;

      Future<String> download(_ResolvedXVideo resolved) => _download(
        resolved.video,
        taskId: taskId,
        quality: quality,
        previousStreams: selectedStreams,
        workDirectory: workDirectory,
        cancellation: cancellation,
        onStreamsSelected: (streams) {
          selectedStreams = streams;
          onStreamsSelected?.call(streams);
        },
        onProgress: onProgress,
      );

      String filePath;

      try {
        filePath = await download(resolved);
      } on MediaStreamLinksExpiredException {
        _throwIfCancelled(cancellation);

        /// The file was refused: the post is read again for its files
        resolved = await _resolve(link);

        try {
          filePath = await download(resolved);
        } on MediaStreamLinksExpiredException {
          throw VideoException(
            const VideoErrorCodes().xHttpStatus,
            args: const {'status': '403'},
          );
        }
      }

      final destination =
          destinationDirectory ??
          await _fileSystemService.defaultDownloadsFolder();
      final String savedPath;

      try {
        savedPath = await _fileSystemService.moveToFolder(
          filePath,
          destination,
          title: resolved.video.title,
        );
      } on FileSystemException catch (error) {
        throw VideoException(
          const VideoErrorCodes().destinationUnavailable,
          args: {'path': destination, 'error': error.message},
        );
      }

      await _fileSystemService.deleteDownloadWorkDirectory(taskId);

      return ok(
        DownloadedFileModel(
          path: savedPath,
          sizeBytes: await _fileSystemService.fileLength(savedPath),
        ),
      );
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  void _throwIfCancelled(DownloadCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw VideoException(const VideoErrorCodes().canceled);
    }
  }

  XPostLink _parse(String url) =>
      XUrlParser.parse(url) ??
      (throw VideoException(const VideoErrorCodes().notXUrl));

  Future<_ResolvedXVideo> _resolve(XPostLink link) async =>
      _resolvedVideos[link] = _ResolvedXVideo(
        await _remoteXDataSource.getVideo(link),
      );

  Future<String> _download(
    XVideoDto video, {
    required String taskId,
    required String quality,
    required List<DownloadStreamModel> previousStreams,
    required String workDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    const codes = VideoErrorCodes();

    if (!QualitySelector.isValidQuality(quality)) {
      throw VideoException(codes.unknownQuality, args: {'quality': quality});
    }

    final format = XQualities.select(
      video.formats,
      quality: quality,
      previousBitrate: previousStreams
          .where((stream) => stream.role == DownloadStreamRole.video)
          .firstOrNull
          ?.itag,
    );

    if (format == null) {
      throw VideoException(codes.qualityUnavailable);
    }

    onStreamsSelected?.call([
      DownloadStreamModel(
        role: DownloadStreamRole.video,
        itag: format.bitrate,
        contentLength: format.size ?? 0,
      ),
    ]);

    final path = p.join(
      workDirectory,
      '${XConstants.filePrefix}${format.bitrate}.mp4',
    );

    await _deleteStaleFiles(workDirectory, keep: p.basename(path));

    await _remoteXDataSource.downloadVideo(
      downloadId: taskId,
      format: format,
      path: path,
      stateDirectory: workDirectory,
      cancellation: cancellation,
      onProgress: (progress) {
        final received = progress.downloadedBytes;
        final total = progress.totalBytes;
        final speed = progress.bytesPerSecond;

        onProgress?.call(
          DownloadProgressModel(
            DownloadStage.downloading,
            total == 0 ? 0 : (received / total * 1000).floor() / 10,
            speed: speed,
            eta: speed == null || speed == 0
                ? null
                : (total - received) / speed,
            downloadedBytes: received,
            totalBytes: total,
          ),
        );
      },
    );

    _throwIfCancelled(cancellation);

    return path;
  }

  /// Wipes the file of another quality: another one was chosen
  Future<void> _deleteStaleFiles(
    String workDirectory, {
    required String keep,
  }) async {
    await for (final entity in Directory(workDirectory).list()) {
      final name = p.basename(entity.path);

      if (entity is File &&
          name.startsWith(XConstants.filePrefix) &&
          name != keep) {
        await _fileSystemService.deleteFile(entity.path);
      }
    }
  }
}
