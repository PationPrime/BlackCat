import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import 'video_repository_interface.dart';

/// RuTube info from `--dump-single-json`: the page and the HLS variants,
/// each with the yt-dlp format that downloads it
final class _RuTubeYtDlpInfo {
  final String raw;
  final String? title;
  final String? uploader;
  final num? duration;
  final String? thumbnail;
  final Map<HlsVariant, String> formats;
  final DateTime extractedAt;

  _RuTubeYtDlpInfo({
    required this.raw,
    required this.formats,
    this.title,
    this.uploader,
    this.duration,
    this.thumbnail,
  }) : extractedAt = DateTime.now();

  bool get expired =>
      DateTime.now().difference(extractedAt) > const Duration(hours: 1);

  List<HlsVariant> get variants => formats.keys.toList();

  /// HLS formats with video and audio together: yt-dlp lists every
  /// variant twice, as `default-*` and `m3u8-*`
  static _RuTubeYtDlpInfo fromJson(String raw) {
    final json = jsonDecode(raw);

    if (json is! Map<String, dynamic>) {
      throw const FormatException('yt-dlp printed no video');
    }

    final formats = <HlsVariant, String>{};

    for (final format
        in (json['formats'] as List? ?? const []).whereType<Map>()) {
      final protocol = '${format['protocol'] ?? ''}';
      final vcodec = '${format['vcodec'] ?? 'none'}';
      final acodec = '${format['acodec'] ?? 'none'}';
      final tbr = format['tbr'];

      if (!protocol.startsWith('m3u8') ||
          vcodec == 'none' ||
          acodec == 'none' ||
          tbr is! num) {
        continue;
      }

      final variant = HlsVariant(
        uri: Uri.parse('${format['url'] ?? ''}'),
        bandwidth: (tbr * 1000).round(),
        width: (format['width'] as num?)?.toInt(),
        height: (format['height'] as num?)?.toInt(),
        codecs: '$vcodec, $acodec',
        frameRate: (format['fps'] as num?)?.toDouble(),
      );

      /// The same bitrate from two CDNs is one quality
      if (formats.keys.every((known) => known.bandwidth != variant.bandwidth)) {
        formats[variant] = '${format['format_id']}';
      }
    }

    return _RuTubeYtDlpInfo(
      raw: raw,
      formats: formats,
      title: json['title'] as String?,
      uploader: json['uploader'] as String?,
      duration: json['duration'] as num?,
      thumbnail: json['thumbnail'] as String?,
    );
  }
}

/// RuTube videos through yt-dlp.
///
/// yt-dlp finds the HLS variants (`--dump-single-json`) and downloads the
/// chosen one as MPEG-TS into the download work folder, several fragments
/// at a time; `--continue` resumes it after a pause. The stream is remuxed
/// into MP4 in Dart, as with the built-in downloader: ffmpeg is not needed
final class RuTubeYtDlpVideoRepository implements VideoRepositoryInterface {
  static const _infoFileName = 'yt-dlp-info.json';
  static const _streamFileName = 'rutube-yt-dlp.ts';
  static const _progressInterval = Duration(milliseconds: 250);

  /// Fragments yt-dlp downloads at the same time
  static const _fragments = 8;

  final YtDlpService _ytDlpService;
  final MediaMuxerService _mediaMuxerService;
  final FileSystemService _fileSystemService;

  final _infos = <String, _RuTubeYtDlpInfo>{};

  RuTubeYtDlpVideoRepository({
    required this._ytDlpService,
    required this._mediaMuxerService,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final link = _parse(url);
      final info = _infos[link.id] = await _extract(link);
      final qualities = RuTubeQualities.build(
        info.variants,
        durationSeconds: info.duration,
      );

      if (qualities.isEmpty) {
        throw VideoException(const VideoErrorCodes().streamFormat);
      }

      return ok(
        VideoInfoModel(
          id: link.id,
          title: info.title ?? link.id,
          url: link.url,
          channel: info.uploader,
          duration: info.duration,
          thumbnail: info.thumbnail,
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
          cancellation: cancellation,
        );
      }

      _throwIfCancelled(cancellation);

      var selectedStreams = streams;

      Future<String> download(_RuTubeYtDlpInfo info) => _download(
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

        /// Links are signed and expire: take fresh ones and continue
        info = _infos[link.id] = await _extract(
          link,
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

  RuTubeVideoLink _parse(String url) =>
      RuTubeUrlParser.parse(url) ??
      (throw VideoException(const VideoErrorCodes().notRuTubeUrl));

  Future<YtDlpRunResult> _run(
    List<String> arguments, {
    void Function(String line)? onLine,
    DownloadCancellation? cancellation,
  }) async {
    final result = await _ytDlpService.run(
      arguments,
      onLine: onLine,
      cancellation: cancellation,
    );

    if (result.isCancelled) {
      throw VideoException(const VideoErrorCodes().canceled);
    }

    return result;
  }

  Future<_RuTubeYtDlpInfo> _extract(
    RuTubeVideoLink link, {
    DownloadCancellation? cancellation,
  }) async {
    final result = await _run([
      '--no-playlist',
      '--dump-single-json',
      link.url,
    ], cancellation: cancellation);

    if (!result.isSuccess) {
      throw _failureOf(result.errorOutput);
    }

    try {
      return _RuTubeYtDlpInfo.fromJson(result.stdout.trim());
    } on FormatException catch (error) {
      throw VideoException(
        const VideoErrorCodes().ytDlpFailed,
        args: {'error': error.message},
      );
    }
  }

  /// The last yt-dlp error line: RuTube errors have no special wording
  static VideoException _failureOf(String output) {
    final error = const LineSplitter()
        .convert(output)
        .where((line) => line.startsWith('ERROR:'))
        .lastOrNull;

    return VideoException(
      const VideoErrorCodes().ytDlpFailed,
      args: {'error': (error ?? output).replaceFirst('ERROR:', '').trim()},
    );
  }

  Future<String> _download(
    _RuTubeYtDlpInfo info, {
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
      info.variants,
      quality: quality,
      previousBandwidth: previousStreams
          .where((stream) => stream.role == DownloadStreamRole.video)
          .firstOrNull
          ?.itag,
    );

    if (variant == null) {
      throw VideoException(codes.qualityUnavailable);
    }

    final expected = RuTubeQualities.expectedBytes(variant, info.duration) ?? 0;

    onStreamsSelected?.call([
      DownloadStreamModel(
        role: DownloadStreamRole.video,
        itag: variant.bandwidth,
        contentLength: expected,
      ),
    ]);

    final infoPath = p.join(workDirectory, _infoFileName);
    final streamPath = p.join(workDirectory, _streamFileName);

    await _fileSystemService.writeFile(infoPath, utf8.encode(info.raw));

    /// yt-dlp starts every fragment without a speed: the speed is measured
    /// over the bytes of the last seconds instead
    final speedMeter = SpeedMeter();
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
    var received = 0;

    void report({num? fallbackSpeed, int? total, bool force = false}) {
      final now = DateTime.now();

      if (!force && now.difference(lastReport) < _progressInterval) return;

      lastReport = now;

      final size = math.max(total ?? expected, received);
      final speed = speedMeter.bytesPerSecond(now: now) ?? fallbackSpeed;

      onProgress?.call(
        DownloadProgressModel(
          DownloadStage.downloading,
          size == 0 ? 0 : (received / size * 1000).floor() / 10,
          speed: speed,
          eta: speed == null || speed == 0 ? null : (size - received) / speed,
          downloadedBytes: received,
          totalBytes: size,
        ),
      );
    }

    report(force: true);

    final result = await _run(
      [
        '--load-info-json',
        infoPath,
        '--format',
        info.formats[variant]!,
        '--output',
        streamPath.replaceAll('%', '%%'),
        '--hls-use-mpegts',
        '--concurrent-fragments',
        '$_fragments',
        '--continue',
        '--fixup',
        'never',
        '--no-mtime',
        '--newline',
        '--progress-template',
        YtDlpOutput.progressTemplate,
      ],
      cancellation: cancellation,
      onLine: (line) {
        final progress = YtDlpOutput.parseProgress(line);

        if (progress?.downloadedBytes case final bytes?) {
          if (bytes > received) speedMeter.add(bytes - received);

          received = bytes;
          report(
            fallbackSpeed: progress!.speed,
            total: progress.totalBytes,
            force: progress.isFinished,
          );
        }
      },
    );

    if (!result.isSuccess) {
      if (result.errorOutput.contains('HTTP Error 403')) {
        throw const _ExpiredLinksException();
      }

      throw _failureOf(result.errorOutput);
    }

    _throwIfCancelled(cancellation);

    final total = await _fileSystemService.fileLength(streamPath);
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
      inputs: [streamPath],
      outputPath: output,
    );

    _throwIfCancelled(cancellation);

    await _fileSystemService.deleteFile(streamPath);
    await _fileSystemService.deleteFile(infoPath);

    return output;
  }
}

/// yt-dlp got 403: the links are no longer valid
final class _ExpiredLinksException implements Exception {
  const _ExpiredLinksException();
}
