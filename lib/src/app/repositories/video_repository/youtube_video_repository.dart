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

/// Информация о видео и загрузка напрямую с YouTube по HTTP (dio), без yt-dlp.
///
/// 1. Настройки встроенного плеера и `/youtubei/v1/player` дают список потоков.
/// 2. В ссылках на потоки есть задача `n` (иногда и зашифрованная подпись);
///    функции для их решения лежат в JavaScript плеера и исполняются
///    [ChallengeSolverService].
/// 3. Видео и звук качаются кусками по 10 МиБ и собираются в MP4 на Dart
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
  Future<OperationResult<String>> downloadVideo({
    required String url,
    required String quality,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    try {
      final link = _parse(url);
      final workDirectory = await _fileSystemService.createTempDirectory(
        'yt-download-',
      );

      try {
        var resolved = _resolvedVideos[link.id];

        if (resolved == null || resolved.expired) {
          resolved = _resolvedVideos[link.id] = await _resolve(link.id);
        }

        String filePath;

        try {
          filePath = await _download(
            resolved,
            quality: quality,
            outputDirectory: workDirectory.path,
            onProgress: onProgress,
          );
        } on DioException catch (error) {
          if (error.response?.statusCode != 403) {
            rethrow;
          }

          /// Ссылки привязаны к сессии и устаревают: берём свежие и пробуем ещё раз
          resolved = _resolvedVideos[link.id] = await _resolve(link.id);
          filePath = await _download(
            resolved,
            quality: quality,
            outputDirectory: workDirectory.path,
            onProgress: onProgress,
          );
        }

        return ok(
          await _fileSystemService.moveToDownloads(
            filePath,
            title: resolved.title,
          ),
        );
      } finally {
        await workDirectory
            .delete(recursive: true)
            .catchError((Object _) => workDirectory);
      }
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
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

  Future<String> _download(
    ResolvedVideoDto resolved, {
    required String quality,
    required String outputDirectory,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    const errorCodes = VideoErrorCodes();

    if (!QualitySelector.isValidQuality(quality)) {
      throw VideoException(
        errorCodes.unknownQuality,
        args: {'quality': quality},
      );
    }

    final ({StreamFormatDto? video, StreamFormatDto audio}) streams;

    try {
      streams = QualitySelector.selectStreams(resolved.formats, quality);
    } on ArgumentError {
      throw VideoException(errorCodes.qualityUnavailable);
    }

    final parts = [?streams.video, streams.audio];
    final total = parts.fold<int>(
      0,
      (sum, format) => sum + format.contentLength!,
    );
    final speedMeter = SpeedMeter();
    final cancelToken = CancelToken();
    var received = 0;
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);

    void onBytes(int bytes) {
      received += bytes;
      speedMeter.add(bytes);

      final now = DateTime.now();

      if (now.difference(lastReport) < const Duration(milliseconds: 250) &&
          received != total) {
        return;
      }

      lastReport = now;

      final speed = speedMeter.bytesPerSecond(now: now);

      onProgress?.call(
        DownloadProgressModel(
          DownloadStage.downloading,
          (received / total * 1000).floor() / 10,
          speed: speed,
          eta: speed == null || speed == 0 ? null : (total - received) / speed,
        ),
      );
    }

    String partPath(StreamFormatDto format) =>
        p.join(outputDirectory, '${resolved.id}.${parts.indexOf(format)}.part');

    try {
      await Future.wait([
        for (final format in parts)
          _remoteMediaStreamDataSource.downloadStream(
            resolved.urls[format]!,
            length: format.contentLength!,
            path: partPath(format),
            onBytes: onBytes,
            cancelToken: cancelToken,
          ),
      ], eagerError: true);
    } catch (_) {
      /// Один поток упал — останавливаем и второй
      cancelToken.cancel();

      rethrow;
    }

    final audioOnly = streams.video == null;
    final output = p.join(
      outputDirectory,
      '${resolved.id}.${audioOnly ? 'm4a' : 'mp4'}',
    );

    if (!audioOnly) {
      onProgress?.call(
        const DownloadProgressModel(DownloadStage.processing, 100),
      );
    }

    /// И для звука: DASH-потоки фрагментированы, а многие плееры понимают их плохо
    await _mediaMuxerService.muxToMp4(
      inputs: [for (final format in parts) partPath(format)],
      outputPath: output,
      audioOnly: audioOnly,
    );

    for (final format in parts) {
      await File(partPath(format)).delete();
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

    /// С запасом: долгая загрузка не должна начинаться на почти истёкших ссылках
    return expires == null
        ? DateTime.now().add(const Duration(hours: 1))
        : DateTime.fromMillisecondsSinceEpoch(
            expires * 1000,
          ).subtract(const Duration(minutes: 30));
  }
}
