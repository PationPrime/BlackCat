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

/// A video with its qualities, while its links are fresh
final class _ResolvedRuTubeVideo {
  final RuTubeVideoDto video;
  final List<HlsVariant> variants;
  final DateTime resolvedAt;

  _ResolvedRuTubeVideo(this.video, this.variants) : resolvedAt = DateTime.now();

  /// Playlist links live for days; a fresh copy is taken well before
  bool get expired =>
      DateTime.now().difference(resolvedAt) > const Duration(hours: 1);
}

/// RuTube videos straight over HTTP (dio), without yt-dlp.
///
/// 1. The player API gives the title and the HLS master playlist.
/// 2. The quality picks a variant of the playlist; its media playlist lists
///    the MPEG-TS segments.
/// 3. Segments are downloaded several at a time into the download work
///    folder under names of the variant; finished ones stay on disk, so
///    a paused download continues.
/// 4. The segments are remuxed into MP4 in Dart
final class RuTubeVideoRepository implements VideoRepositoryInterface {
  final RemoteRuTubeDataSource _remoteRuTubeDataSource;
  final MediaMuxerService _mediaMuxerService;
  final FileSystemService _fileSystemService;

  final _resolvedVideos = <String, _ResolvedRuTubeVideo>{};

  RuTubeVideoRepository({
    required this._remoteRuTubeDataSource,
    required this._mediaMuxerService,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final link = _parse(url);
      final resolved = _resolvedVideos[link.id] = await _resolve(link);
      final qualities = RuTubeQualities.build(
        resolved.variants,
        durationSeconds: resolved.video.durationSeconds,
      );

      if (qualities.isEmpty) {
        throw VideoException(const VideoErrorCodes().streamFormat);
      }

      return ok(
        VideoInfoModel(
          id: link.id,
          title: resolved.video.title,
          url: link.url,
          channel: resolved.video.author,
          duration: resolved.video.durationSeconds,
          thumbnail: resolved.video.thumbnail,
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

      var resolved = _resolvedVideos[link.id];

      if (resolved == null || resolved.expired) {
        resolved = _resolvedVideos[link.id] = await _resolve(link);
      }

      _throwIfCancelled(cancellation);

      /// Streams of the latest attempt: a retry with fresh links continues
      /// the same variant
      var selectedStreams = streams;

      Future<String> download(_ResolvedRuTubeVideo resolved) => _download(
        resolved,
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

        /// Links are signed and expire: take fresh ones and continue
        resolved = _resolvedVideos[link.id] = await _resolve(link);

        try {
          filePath = await download(resolved);
        } on MediaStreamLinksExpiredException {
          throw VideoException(
            const VideoErrorCodes().rutubeHttpStatus,
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

  RuTubeVideoLink _parse(String url) =>
      RuTubeUrlParser.parse(url) ??
      (throw VideoException(const VideoErrorCodes().notRuTubeUrl));

  Future<_ResolvedRuTubeVideo> _resolve(RuTubeVideoLink link) async {
    final video = await _remoteRuTubeDataSource.getVideo(link);
    final master = await _remoteRuTubeDataSource.getPlaylist(
      video.masterPlaylist,
    );

    try {
      return _ResolvedRuTubeVideo(
        video,
        HlsPlaylistParser.parseMaster(master, video.masterPlaylist),
      );
    } on FormatException {
      throw VideoException(const VideoErrorCodes().streamFormat);
    }
  }

  Future<String> _download(
    _ResolvedRuTubeVideo resolved, {
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

    final variant = RuTubeQualities.select(
      resolved.variants,
      quality: quality,
      previousBandwidth: previousStreams
          .where((stream) => stream.role == DownloadStreamRole.video)
          .firstOrNull
          ?.itag,
    );

    if (variant == null) {
      throw VideoException(codes.qualityUnavailable);
    }

    final HlsMediaPlaylist playlist;

    try {
      playlist = HlsPlaylistParser.parseMedia(
        await _remoteRuTubeDataSource.getPlaylist(variant.uri),
        variant.uri,
      );
    } on HlsUnsupportedException catch (error) {
      throw VideoException(switch (error.reason) {
        HlsUnsupportedReason.encrypted => codes.streamProtected,
        HlsUnsupportedReason.live => codes.rutubeLive,
        HlsUnsupportedReason.segmentFormat => codes.streamFormat,
      });
    } on FormatException {
      throw VideoException(codes.streamFormat);
    }

    final expected =
        RuTubeQualities.expectedBytes(
          variant,
          resolved.video.durationSeconds ?? playlist.duration,
        ) ??
        0;

    onStreamsSelected?.call([
      DownloadStreamModel(
        role: DownloadStreamRole.video,
        itag: variant.bandwidth,
        contentLength: expected,
      ),
    ]);

    await _deleteStaleSegments(workDirectory, variant);

    final segments = [
      for (final (index, segment) in playlist.segments.indexed)
        MediaSegmentTarget(
          url: segment.uri.toString(),
          path: _segmentPath(workDirectory, variant, index),
        ),
    ];

    await _remoteRuTubeDataSource.downloadSegments(
      downloadId: taskId,
      segments: segments,
      expectedBytes: expected == 0 ? null : expected,
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

    final downloaded = await Future.wait([
      for (final segment in segments)
        _fileSystemService.fileLength(segment.path),
    ]);
    final total = downloaded.fold<int>(0, (sum, bytes) => sum + bytes);
    final output = p.join(
      workDirectory,
      '${DownloadPartFiles.outputBaseName}.mp4',
    );

    onProgress?.call(
      DownloadProgressModel(
        DownloadStage.processing,
        100,
        downloadedBytes: total,
        totalBytes: total,
      ),
    );

    await _mediaMuxerService.remuxTsToMp4(
      inputs: [for (final segment in segments) segment.path],
      outputPath: output,
    );

    /// Segments are deleted only after the check: a cancelled download
    /// will remux the file again from the same segments
    _throwIfCancelled(cancellation);

    for (final segment in segments) {
      await _fileSystemService.deleteFile(segment.path);
    }

    return output;
  }

  static String _segmentPath(
    String workDirectory,
    HlsVariant variant,
    int index,
  ) => p.join(
    workDirectory,
    '${RuTubeConstants.segmentPrefix}${variant.bandwidth}-'
    '${index.toString().padLeft(5, '0')}.ts',
  );

  /// Wipes segments of another variant: another quality was chosen
  Future<void> _deleteStaleSegments(
    String workDirectory,
    HlsVariant variant,
  ) async {
    final actual = '${RuTubeConstants.segmentPrefix}${variant.bandwidth}-';

    await for (final entity in Directory(workDirectory).list()) {
      final name = p.basename(entity.path);

      if (entity is File &&
          name.startsWith(RuTubeConstants.segmentPrefix) &&
          !name.startsWith(actual)) {
        await _fileSystemService.deleteFile(entity.path);
      }
    }
  }
}
