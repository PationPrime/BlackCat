import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../session/session_store.dart';
import '../../tools/tools.dart';
import 'video_repository_interface.dart';

typedef _StreamPart = ({DownloadStreamModel stream, StreamFormatDto format});

/// Video info and downloading straight from YouTube over HTTP (dio), without yt-dlp.
///
/// 1. The embedded player settings and `/youtubei/v1/player` give the stream list.
/// 2. Stream links contain the `n` challenge (sometimes an encrypted signature too);
///    the functions that solve them live in the player JavaScript and are run by
///    [ChallengeSolverService].
/// 3. Video and audio are downloaded in 10 MiB chunks into files of the
///    [DownloadPartFiles] format and muxed into MP4 in Dart
final class YouTubeVideoRepository implements VideoRepositoryInterface {
  final RemoteYouTubeDataSource _remoteYouTubeDataSource;
  final RemoteMediaStreamDataSource _remoteMediaStreamDataSource;
  final ChallengeSolverService _challengeSolverService;
  final MediaMuxerService _mediaMuxerService;
  final FileSystemService _fileSystemService;
  final SessionStore _sessionStore;

  final _resolvedVideos = <String, ResolvedVideoDto>{};

  YouTubeVideoRepository({
    required this._remoteYouTubeDataSource,
    required this._remoteMediaStreamDataSource,
    required this._challengeSolverService,
    required this._mediaMuxerService,
    required this._fileSystemService,
    required this._sessionStore,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final link = _parse(url);
      final resolved = _resolvedVideos[link.id] = await _resolve(link.id);

      return ok(
        VideoInfoModel(
          id: link.id,
          title: resolved.title,
          url: link.url,
          channel: resolved.channel,
          duration: resolved.durationSeconds,
          thumbnail: resolved.thumbnail,
          viewCount: resolved.viewCount,
          qualities: QualitySelector.buildStreamQualities(resolved.formats),
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

      /// The work folder lives until the download finishes: after a pause we continue in it
      final workDirectory = await _fileSystemService.downloadWorkDirectory(
        taskId,
      );

      var resolved = _resolvedVideos[link.id];

      if (resolved == null || resolved.expired) {
        resolved = _resolvedVideos[link.id] = await _resolve(link.id);
      }

      _throwIfCancelled(cancellation);

      /// Streams of the latest attempt: a retry after 403 continues the same ones
      var selectedStreams = streams;

      Future<String> download(ResolvedVideoDto resolved) => _download(
        resolved,
        quality: quality,
        previousStreams: selectedStreams,
        workDirectory: workDirectory.path,
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
      } on DioException catch (error) {
        if (error.response?.statusCode != 403) {
          rethrow;
        }

        _throwIfCancelled(cancellation);

        /// Links are bound to the session and expire: take fresh ones and continue
        resolved = _resolvedVideos[link.id] = await _resolve(link.id);
        filePath = await download(resolved);
      }

      final destination =
          destinationDirectory ??
          await _fileSystemService.defaultDownloadsFolder();
      final String savedPath;

      try {
        savedPath = await _fileSystemService.moveToFolder(
          filePath,
          destination,
          title: resolved.title,
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

  YouTubeVideoLink _parse(String url) =>
      YouTubeUrlParser.parse(url) ??
      (throw VideoException(const VideoErrorCodes().notYouTubeUrl));

  Future<ResolvedVideoDto> _resolve(String videoId) async {
    await _sessionStore.reload();

    final config = await _remoteYouTubeDataSource.getEmbedConfig(videoId);

    Future<String> playerJs() =>
        _remoteYouTubeDataSource.getPlayerJs(config.playerId);

    final player = await _remoteYouTubeDataSource.getPlayer(
      videoId,
      config,
      signatureTimestamp: RemoteYouTubeDataSourceImpl.signatureTimestampOf(
        await playerJs(),
      ),
    );
    final formats = player.formats;

    if (formats.isEmpty) {
      throw VideoException(
        const VideoErrorCodes().streamsUnavailable,
        needsSignIn: !_sessionStore.signedIn,
      );
    }

    final solutions = await _challengeSolverService.solve(
      playerId: config.playerId,
      playerJs: playerJs,
      n: {for (final format in formats) ?format.nChallenge},
      sig: {for (final format in formats) ?format.signature},
    );

    final urls = {
      for (final format in formats)
        format: format.resolvedUrl(n: solutions.n, sig: solutions.sig),
    };

    return ResolvedVideoDto(
      id: videoId,
      title: player.title ?? videoId,
      channel: player.author,
      durationSeconds: player.lengthSeconds,
      viewCount: player.viewCount,
      thumbnail: player.thumbnail,
      formats: formats,
      urls: urls,
      expiresAt: _expiry(urls.values),
    );
  }

  /// Streams for the quality. If the download has started before, the same streams
  /// as last time are used: the downloaded bytes fit only them. New streams
  /// are selected only if the previous ones are gone from the YouTube response
  List<_StreamPart> _selectParts(
    ResolvedVideoDto resolved, {
    required String quality,
    required List<DownloadStreamModel> previousStreams,
  }) {
    const errorCodes = VideoErrorCodes();

    if (!QualitySelector.isValidQuality(quality)) {
      throw VideoException(
        errorCodes.unknownQuality,
        args: {'quality': quality},
      );
    }

    final expectedRoles = quality == QualityModel.audioId
        ? {DownloadStreamRole.audio}
        : {DownloadStreamRole.video, DownloadStreamRole.audio};

    if (previousStreams.length == expectedRoles.length &&
        previousStreams.every((stream) => expectedRoles.contains(stream.role))) {
      final previousParts = [
        for (final stream in previousStreams)
          if (resolved.formats
                  .where(
                    (format) =>
                        format.itag == stream.itag &&
                        format.contentLength == stream.contentLength &&
                        (stream.role == DownloadStreamRole.video
                            ? format.hasVideo
                            : format.hasAudio && !format.hasVideo),
                  )
                  .firstOrNull
              case final format?)
            (stream: stream, format: format),
      ];

      if (previousParts.length == previousStreams.length) {
        return previousParts;
      }
    }

    final ({StreamFormatDto? video, StreamFormatDto audio}) streams;

    try {
      streams = QualitySelector.selectStreams(resolved.formats, quality);
    } on ArgumentError {
      throw VideoException(errorCodes.qualityUnavailable);
    }

    _StreamPart partOf(DownloadStreamRole role, StreamFormatDto format) => (
      stream: DownloadStreamModel(
        role: role,
        itag: format.itag,
        contentLength: format.contentLength!,
      ),
      format: format,
    );

    return [
      if (streams.video case final video?)
        partOf(DownloadStreamRole.video, video),
      partOf(DownloadStreamRole.audio, streams.audio),
    ];
  }

  /// Wipes unfinished files of streams that are no longer downloaded
  Future<void> _deleteStaleParts(
    String workDirectory,
    List<_StreamPart> parts,
  ) async {
    final actualNames = {
      for (final part in parts) DownloadPartFiles.fileName(part.stream),
    };

    await for (final entity in Directory(workDirectory).list()) {
      final name = p.basename(entity.path);

      if (entity is File &&
          DownloadPartFiles.parse(name) != null &&
          !actualNames.contains(name)) {
        await _fileSystemService.deleteFile(entity.path);
      }
    }
  }

  Future<String> _download(
    ResolvedVideoDto resolved, {
    required String quality,
    required List<DownloadStreamModel> previousStreams,
    required String workDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    final parts = _selectParts(
      resolved,
      quality: quality,
      previousStreams: previousStreams,
    );

    onStreamsSelected?.call([for (final part in parts) part.stream]);

    await _deleteStaleParts(workDirectory, parts);

    String partPath(_StreamPart part) =>
        DownloadPartFiles.path(workDirectory, part.stream);

    final total = parts.fold<int>(
      0,
      (sum, part) => sum + part.stream.contentLength,
    );
    var received = 0;

    /// Downloaded before the pause: the streams continue from these bytes
    for (final part in parts) {
      received += DownloadPartFiles.resumableBytes(
        await _fileSystemService.fileLength(partPath(part)),
        part.stream,
      );
    }

    final speedMeter = SpeedMeter();
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);

    void reportDownloading({required DateTime now}) {
      final speed = speedMeter.bytesPerSecond(now: now);

      onProgress?.call(
        DownloadProgressModel(
          DownloadStage.downloading,
          total == 0 ? 0 : (received / total * 1000).floor() / 10,
          speed: speed,
          eta: speed == null || speed == 0 ? null : (total - received) / speed,
          downloadedBytes: received,
          totalBytes: total,
        ),
      );
    }

    reportDownloading(now: DateTime.now());

    void onBytes(int bytes) {
      received += bytes;
      speedMeter.add(bytes);

      final now = DateTime.now();

      if (now.difference(lastReport) < const Duration(milliseconds: 250) &&
          received != total) {
        return;
      }

      lastReport = now;
      reportDownloading(now: now);
    }

    /// Own token: if one stream fails, the other one stops,
    /// while [cancellation] stays untouched
    final cancelToken = CancelToken();

    unawaited(cancellation?.whenCancelled.then((_) => cancelToken.cancel()));

    try {
      await Future.wait([
        for (final part in parts)
          _remoteMediaStreamDataSource.downloadStream(
            resolved.urls[part.format]!,
            length: part.stream.contentLength,
            path: partPath(part),
            onBytes: onBytes,
            cancelToken: cancelToken,
          ),
      ], eagerError: true);
    } catch (_) {
      cancelToken.cancel();

      rethrow;
    }

    _throwIfCancelled(cancellation);

    final audioOnly = parts.length == 1;
    final output = p.join(
      workDirectory,
      '${DownloadPartFiles.outputBaseName}.${audioOnly ? 'm4a' : 'mp4'}',
    );

    onProgress?.call(
      DownloadProgressModel(
        DownloadStage.processing,
        100,
        downloadedBytes: total,
        totalBytes: total,
      ),
    );

    /// Audio too: DASH streams are fragmented, and many players handle them poorly
    await _mediaMuxerService.muxToMp4(
      inputs: [for (final part in parts) partPath(part)],
      outputPath: output,
      audioOnly: audioOnly,
    );

    /// Streams are deleted only after the check: a cancelled download
    /// will mux the file again from the same streams
    _throwIfCancelled(cancellation);

    for (final part in parts) {
      await _fileSystemService.deleteFile(partPath(part));
    }

    return output;
  }

  static DateTime _expiry(Iterable<String> urls) {
    final expires = urls
        .map(
          (url) => int.tryParse(Uri.parse(url).queryParameters['expire'] ?? ''),
        )
        .whereType<int>()
        .fold<int?>(
          null,
          (earliest, value) =>
              earliest == null || value < earliest ? value : earliest,
        );

    /// With a margin: a long download must not start on almost expired links
    return expires == null
        ? DateTime.now().add(const Duration(hours: 1))
        : DateTime.fromMillisecondsSinceEpoch(
            expires * 1000,
          ).subtract(const Duration(minutes: 30));
  }
}
