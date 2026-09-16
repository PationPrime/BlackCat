import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../data_sources/data_sources.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../session/session_store.dart';
import '../../tools/tools.dart';
import 'yt_dlp_video_repository_interface.dart';

part 'yt_dlp_video_info.dart';

typedef _RawPart = ({DownloadStreamModel stream, String formatId});

/// Videos through yt-dlp: installed on the computer or by the app.
///
/// yt-dlp finds the streams (`--dump-single-json`) and downloads each of them
/// (`--load-info-json`) into the download work folder under the names of
/// [DownloadPartFiles], so pausing, resuming and the queue work as with the
/// built-in downloader. Video and audio are muxed in Dart: ffmpeg is not
/// needed. The account cookies of the app go to yt-dlp as a copy, so yt-dlp
/// does not overwrite the app session file
final class YtDlpVideoRepository implements YtDlpVideoRepositoryInterface {
  static const _infoFileName = 'yt-dlp-info.json';
  static const _cookiesFileName = 'yt-dlp-cookies.txt';

  /// Folder in `%LOCALAPPDATA%\YT Download` for cookies of searches
  static const _searchFolder = 'yt-dlp';

  static const _progressInterval = Duration(milliseconds: 250);

  final YtDlpService _ytDlpService;
  final MediaMuxerService _mediaMuxerService;
  final FileSystemService _fileSystemService;
  final SessionStore _sessionStore;
  final LocalAuthenticationDataSource _localAuthenticationDataSource;

  final _infos = <String, _YtDlpVideoInfo>{};

  YtDlpVideoRepository({
    required this._ytDlpService,
    required this._mediaMuxerService,
    required this._fileSystemService,
    required this._sessionStore,
    required this._localAuthenticationDataSource,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final link = _parse(url);
      final info = _infos[link.id] = await _extract(
        link,
        workDirectory: await _fileSystemService.localAppFolder(_searchFolder),
      );

      final qualities = QualitySelector.buildQualities(
        QualitySelector.muxableRawFormats(info.formats),
        canMerge: true,
      );

      if (qualities.isEmpty) {
        throw VideoException(
          const VideoErrorCodes().streamsUnavailable,
          needsSignIn: !_sessionStore.signedIn,
        );
      }

      return ok(
        VideoInfoModel(
          id: link.id,
          title: info.title ?? link.id,
          url: link.url,
          channel: info.channel,
          duration: info.duration,
          thumbnail: info.thumbnail,
          viewCount: info.viewCount,
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
      final workDirectory = (await _fileSystemService.downloadWorkDirectory(
        taskId,
      )).path;

      var info = _infos[link.id];

      if (info == null || info.expired) {
        info = _infos[link.id] = await _extract(
          link,
          workDirectory: workDirectory,
          cancellation: cancellation,
        );
      }

      _throwIfCancelled(cancellation);

      /// Streams of the latest attempt: a retry after 403 continues the same ones
      var selectedStreams = streams;

      Future<String> download(_YtDlpVideoInfo info) => _download(
        info,
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
        filePath = await download(info);
      } on _ExpiredLinksException {
        _throwIfCancelled(cancellation);

        /// Links are bound to the session and expire: take fresh ones and continue
        info = _infos[link.id] = await _extract(
          link,
          workDirectory: workDirectory,
          cancellation: cancellation,
        );
        filePath = await download(info);
      }

      final destination =
          destinationDirectory ??
          await _fileSystemService.defaultDownloadsFolder();
      final String savedPath;

      try {
        savedPath = await _fileSystemService.moveToFolder(
          filePath,
          destination,
          title: info.title,
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

  /// Runs yt-dlp with a copy of the app account cookies, if the account
  /// is signed in. The copy lives in [workDirectory] only during the run
  Future<YtDlpRunResult> _runWithSession(
    List<String> arguments, {
    required String workDirectory,
    void Function(String line)? onLine,
    DownloadCancellation? cancellation,
  }) async {
    await _sessionStore.reload();

    final cookiesPath = p.join(
      workDirectory,
      '${DateTime.now().microsecondsSinceEpoch}-$_cookiesFileName',
    );
    final useCookies = _sessionStore.signedIn;

    if (useCookies) {
      await _fileSystemService.copyFile(
        await _localAuthenticationDataSource.cookiesFilePath(),
        cookiesPath,
      );
    }

    try {
      final result = await _ytDlpService.run(
        [
          if (useCookies) ...['--cookies', cookiesPath],
          ...arguments,
        ],
        onLine: onLine,
        cancellation: cancellation,
      );

      if (result.isCancelled) {
        throw VideoException(const VideoErrorCodes().canceled);
      }

      return result;
    } finally {
      if (useCookies) {
        await _fileSystemService.deleteFile(cookiesPath);
      }
    }
  }

  Future<_YtDlpVideoInfo> _extract(
    YouTubeVideoLink link, {
    required String workDirectory,
    DownloadCancellation? cancellation,
  }) async {
    final result = await _runWithSession(
      ['--no-playlist', '--dump-single-json', link.url],
      workDirectory: workDirectory,
      cancellation: cancellation,
    );

    if (!result.isSuccess) {
      throw _failureOf(result.errorOutput);
    }

    try {
      return _YtDlpVideoInfo.fromJson(result.stdout.trim());
    } on FormatException catch (error) {
      throw VideoException(
        const VideoErrorCodes().ytDlpFailed,
        args: {'error': error.message},
      );
    }
  }

  /// Errors that signing in fixes offer the sign-in, and its refresh
  /// when the account is already signed in
  VideoException _failureOf(String output) => YtDlpOutput.toException(output);

  /// Formats for the quality. If the download has started before, the same
  /// formats as last time are used: the downloaded bytes fit only them
  List<_RawPart> _selectParts(
    _YtDlpVideoInfo info, {
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

    final muxable = QualitySelector.muxableRawFormats(info.formats);

    /// Audio tracks of a dubbed video share the itag and differ in size
    RawFormat? formatOf(DownloadStreamModel stream) => muxable
        .where(
          (format) =>
              QualitySelector.itagOf(format) == stream.itag &&
              format['filesize'] == stream.contentLength,
        )
        .firstOrNull;

    final expectedRoles = quality == QualityModel.audioId
        ? {DownloadStreamRole.audio}
        : {DownloadStreamRole.video, DownloadStreamRole.audio};

    if (previousStreams.length == expectedRoles.length &&
        previousStreams.every(
          (stream) => expectedRoles.contains(stream.role),
        ) &&
        previousStreams.every((stream) => formatOf(stream) != null)) {
      return [
        for (final stream in previousStreams)
          (stream: stream, formatId: '${formatOf(stream)!['format_id']}'),
      ];
    }

    final ({RawFormat? video, RawFormat audio}) formats;

    try {
      formats = QualitySelector.selectRawStreams(info.formats, quality);
    } on ArgumentError {
      throw VideoException(errorCodes.qualityUnavailable);
    }

    _RawPart partOf(DownloadStreamRole role, RawFormat format) => (
      stream: DownloadStreamModel(
        role: role,
        itag: QualitySelector.itagOf(format)!,
        contentLength: format['filesize'] as int,
      ),
      formatId: '${format['format_id']}',
    );

    return [
      if (formats.video case final video?)
        partOf(DownloadStreamRole.video, video),
      partOf(DownloadStreamRole.audio, formats.audio),
    ];
  }

  /// yt-dlp keeps a finished stream without the `.part` extension
  static String _finishedPath(String partPath) => p.withoutExtension(partPath);

  /// Wipes stream files that are no longer downloaded
  Future<void> _deleteStaleParts(
    String workDirectory,
    List<_RawPart> parts,
  ) async {
    final actualNames = {
      for (final part in parts) DownloadPartFiles.fileName(part.stream),
    };

    await for (final entity in Directory(workDirectory).list()) {
      if (entity is! File) continue;

      final name = p.basename(entity.path);
      final partName = name.endsWith('.part') ? name : '$name.part';

      if (DownloadPartFiles.parse(partName) != null &&
          !actualNames.contains(partName)) {
        await _fileSystemService.deleteFile(entity.path);
      }
    }
  }

  Future<String> _download(
    _YtDlpVideoInfo info, {
    required String quality,
    required List<DownloadStreamModel> previousStreams,
    required String workDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    final parts = _selectParts(
      info,
      quality: quality,
      previousStreams: previousStreams,
    );

    onStreamsSelected?.call([for (final part in parts) part.stream]);

    await _deleteStaleParts(workDirectory, parts);

    final infoPath = p.join(workDirectory, _infoFileName);

    await _fileSystemService.writeFile(infoPath, utf8.encode(info.raw));

    String partPath(_RawPart part) =>
        DownloadPartFiles.path(workDirectory, part.stream);

    final total = parts.fold<int>(
      0,
      (sum, part) => sum + part.stream.contentLength,
    );
    final downloadedByPart = <_RawPart, int>{};

    /// A stream finished right before the app closed keeps the yt-dlp name
    for (final part in parts) {
      final finishedPath = _finishedPath(partPath(part));

      if (await _fileSystemService.fileLength(finishedPath) > 0) {
        await _fileSystemService.renameFile(finishedPath, partPath(part));
      }

      downloadedByPart[part] = DownloadPartFiles.resumableBytes(
        await _fileSystemService.fileLength(partPath(part)),
        part.stream,
      );
    }

    int received() =>
        downloadedByPart.values.fold(0, (sum, bytes) => sum + bytes);

    /// yt-dlp starts every chunk of a stream without a speed: the speed is
    /// measured over the bytes of the last seconds instead
    final speedMeter = SpeedMeter();
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);

    void report({num? fallbackSpeed, bool force = false}) {
      final now = DateTime.now();

      if (!force && now.difference(lastReport) < _progressInterval) return;

      lastReport = now;

      final downloaded = math.min(received(), total);
      final speed = speedMeter.bytesPerSecond(now: now) ?? fallbackSpeed;

      onProgress?.call(
        DownloadProgressModel(
          DownloadStage.downloading,
          total == 0 ? 0 : (downloaded / total * 1000).floor() / 10,
          speed: speed,
          eta: speed == null || speed == 0
              ? null
              : (total - downloaded) / speed,
          downloadedBytes: downloaded,
          totalBytes: total,
        ),
      );
    }

    report(force: true);

    for (final part in parts) {
      if (downloadedByPart[part] == part.stream.contentLength) continue;

      _throwIfCancelled(cancellation);

      final result = await _runWithSession(
        [
          '--load-info-json',
          infoPath,
          '--format',
          part.formatId,
          '--output',
          _finishedPath(partPath(part)).replaceAll('%', '%%'),
          '--continue',
          '--fixup',
          'never',
          '--no-mtime',
          '--newline',
          '--progress-template',
          YtDlpOutput.progressTemplate,
        ],
        workDirectory: workDirectory,
        cancellation: cancellation,
        onLine: (line) {
          final progress = YtDlpOutput.parseProgress(line);

          if (progress?.downloadedBytes case final bytes?) {
            final partBytes = math.min(bytes, part.stream.contentLength);
            final newBytes = partBytes - (downloadedByPart[part] ?? 0);

            if (newBytes > 0) {
              speedMeter.add(newBytes);
            }

            downloadedByPart[part] = partBytes;
            report(fallbackSpeed: progress!.speed, force: progress.isFinished);
          }
        },
      );

      if (!result.isSuccess) {
        if (result.errorOutput.contains('HTTP Error 403')) {
          throw const _ExpiredLinksException();
        }

        throw _failureOf(result.errorOutput);
      }

      /// The work folder keeps the format of the built-in downloader:
      /// a finished stream is a `.part` file of the full size
      await _fileSystemService.renameFile(
        _finishedPath(partPath(part)),
        partPath(part),
      );

      if (await _fileSystemService.fileLength(partPath(part)) !=
          part.stream.contentLength) {
        await _fileSystemService.deleteFile(partPath(part));

        throw VideoException(const VideoErrorCodes().streamInterrupted);
      }

      downloadedByPart[part] = part.stream.contentLength;
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

    await _mediaMuxerService.muxToMp4(
      inputs: [for (final part in parts) partPath(part)],
      outputPath: output,
      audioOnly: audioOnly,
    );

    _throwIfCancelled(cancellation);

    for (final part in parts) {
      await _fileSystemService.deleteFile(partPath(part));
    }

    await _fileSystemService.deleteFile(infoPath);

    return output;
  }
}

/// yt-dlp got 403: the stream links are no longer valid
final class _ExpiredLinksException implements Exception {
  const _ExpiredLinksException();
}
