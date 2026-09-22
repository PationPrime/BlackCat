import 'dart:async';
import 'dart:io';

import '../../constants/constants.dart';
import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import 'instagram_files.dart';
import 'video_repository_interface.dart';

/// A post video with its files, while their links are fresh
final class _ResolvedInstagramVideo {
  final InstagramVideoDto video;
  final DateTime resolvedAt;

  _ResolvedInstagramVideo(this.video) : resolvedAt = DateTime.now();

  /// The file links live for days; a fresh page is taken well before
  bool get expired =>
      DateTime.now().difference(resolvedAt) > const Duration(minutes: 30);
}

/// Instagram videos straight over HTTP (dio), without yt-dlp.
///
/// 1. The post page carries the post data: a ready MP4 file (H.264 with
///    audio) and a DASH manifest with more resolutions.
/// 2. The quality picks the ready file, or DASH video and audio.
/// 3. The files are downloaded in slices over several connections into the
///    download work folder; slice progress lives there, so a paused download
///    continues.
/// 4. DASH video and audio are muxed into MP4 in Dart
final class InstagramVideoRepository implements VideoRepositoryInterface {
  final RemoteInstagramDataSource _remoteInstagramDataSource;
  final MediaMuxerService _mediaMuxerService;
  final FileSystemService _fileSystemService;

  /// By the link the user gave and by the post code
  final _resolvedVideos = <String, _ResolvedInstagramVideo>{};

  InstagramVideoRepository({
    required this._remoteInstagramDataSource,
    required this._mediaMuxerService,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final link = _parse(url);
      final video = (await _resolve(link)).video;
      final qualities = InstagramQualities.build(video.streams);

      if (qualities.isEmpty) {
        throw VideoException(const VideoErrorCodes().streamFormat);
      }

      return ok(
        VideoInfoModel(
          id: video.code,
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

      var resolved = _resolvedVideos[_keyOf(link)];

      if (resolved == null || resolved.expired) {
        resolved = await _resolve(link);
      }

      _throwIfCancelled(cancellation);

      /// Streams of the latest attempt: a retry with fresh links continues
      /// the same files
      var selectedStreams = streams;

      Future<String> download(_ResolvedInstagramVideo resolved) => _download(
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

        /// The links are signed and expire: a fresh page gives new ones
        resolved = await _resolve(link);

        try {
          filePath = await download(resolved);
        } on MediaStreamLinksExpiredException {
          throw VideoException(
            const VideoErrorCodes().instagramHttpStatus,
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

  InstagramVideoLink _parse(String url) =>
      InstagramUrlParser.parse(url) ??
      (throw VideoException(const VideoErrorCodes().notInstagramUrl));

  static String _keyOf(InstagramVideoLink link) => link.code ?? link.url;

  Future<_ResolvedInstagramVideo> _resolve(InstagramVideoLink link) async {
    final resolved = _ResolvedInstagramVideo(
      await _remoteInstagramDataSource.getVideo(link),
    );

    _resolvedVideos[_keyOf(link)] = resolved;
    _resolvedVideos[resolved.video.code] = resolved;

    return resolved;
  }

  Future<String> _download(
    InstagramVideoDto video, {
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

    final choice = InstagramQualities.select(
      video.streams,
      quality: quality,
      previousVideoKey: previousStreams
          .where((stream) => stream.role == DownloadStreamRole.video)
          .firstOrNull
          ?.itag,
    );

    if (choice == null) {
      throw VideoException(codes.qualityUnavailable);
    }

    onStreamsSelected?.call(InstagramFiles.streamsOf(choice));

    final files = InstagramFiles.targetsOf(
      choice,
      workDirectory: workDirectory,
      prefix: InstagramConstants.filePrefix,
    );

    await InstagramFiles.deleteStale(
      workDirectory,
      prefix: InstagramConstants.filePrefix,
      files: files,
      deleteFile: _fileSystemService.deleteFile,
    );

    await _remoteInstagramDataSource.downloadStreams(
      downloadId: taskId,
      code: video.code,
      files: files,
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

    if (choice.video.kind == InstagramStreamKind.file) {
      return files.single.path;
    }

    return InstagramFiles.mux(
      files,
      workDirectory: workDirectory,
      mediaMuxerService: _mediaMuxerService,
      fileSystemService: _fileSystemService,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }
}
