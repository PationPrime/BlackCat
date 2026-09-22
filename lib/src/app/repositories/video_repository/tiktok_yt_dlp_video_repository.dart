import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import 'video_repository_interface.dart';

/// TikTok info from `--dump-single-json`: the page, its cookies and the MP4
/// files, each with the yt-dlp format that downloads it
final class _TikTokYtDlpInfo {
  /// `h264_540p_593369-0`: the bitrate TikTok gives the file
  static final _bitratePattern = RegExp(r'_(\d+)-\d+$');

  final String raw;
  final String id;
  final String? title;
  final String? uploader;
  final String? webpageUrl;
  final num? duration;
  final String? thumbnail;
  final int? viewCount;
  final Map<TikTokFormatDto, String> formatIds;
  final DateTime extractedAt;

  _TikTokYtDlpInfo({
    required this.raw,
    required this.id,
    required this.formatIds,
    this.title,
    this.uploader,
    this.webpageUrl,
    this.duration,
    this.thumbnail,
    this.viewCount,
  }) : extractedAt = DateTime.now();

  /// The file links and cookies live for hours; fresh ones are taken well
  /// before
  bool get expired =>
      DateTime.now().difference(extractedAt) > const Duration(minutes: 30);

  List<TikTokFormatDto> get formats => formatIds.keys.toList();

  /// MP4 files with video and audio and a picture size. The watermarked
  /// `download` file and the `audio` track are left out; yt-dlp lists every
  /// file twice, once per mirror
  static _TikTokYtDlpInfo fromJson(String raw) {
    final json = jsonDecode(raw);

    if (json is! Map<String, dynamic>) {
      throw const FormatException('yt-dlp printed no video');
    }

    final formatIds = <TikTokFormatDto, String>{};

    for (final format
        in (json['formats'] as List? ?? const []).whereType<Map>()) {
      final id = '${format['format_id'] ?? ''}';
      final url = '${format['url'] ?? ''}';
      final vcodec = '${format['vcodec'] ?? 'none'}';
      final acodec = '${format['acodec'] ?? 'none'}';
      final width = (format['width'] as num?)?.toInt();
      final height = (format['height'] as num?)?.toInt();

      if (url.isEmpty ||
          vcodec == 'none' ||
          acodec == 'none' ||
          height == null ||
          '${format['format_note'] ?? ''}' == 'watermarked') {
        continue;
      }

      final bitrate =
          int.tryParse(_bitratePattern.firstMatch(id)?.group(1) ?? '') ??
          ((format['tbr'] as num? ?? 0) * 1000).round();

      final dto = TikTokFormatDto(
        urls: [url],
        bitrate: bitrate,
        codec: vcodec,
        width: width,
        height: height,
        size: (format['filesize'] as num?)?.toInt(),
      );

      if (formatIds.keys.every(
        (known) => known.bitrate != bitrate || known.codec != vcodec,
      )) {
        formatIds[dto] = id;
      }
    }

    return _TikTokYtDlpInfo(
      raw: raw,
      id: '${json['id']}',
      formatIds: formatIds,
      title: _titleOf(json),
      uploader: (json['channel'] ?? json['uploader']) as String?,
      webpageUrl: json['webpage_url'] as String?,
      duration: json['duration'] as num?,
      thumbnail: json['thumbnail'] as String?,
      viewCount: (json['view_count'] as num?)?.toInt(),
    );
  }

  /// yt-dlp cuts the title of a long description: the whole description
  /// is taken, as with the built-in downloader
  static String? _titleOf(Map<String, dynamic> json) {
    final description = '${json['description'] ?? ''}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return description.isNotEmpty ? description : json['title'] as String?;
  }
}

/// TikTok videos through yt-dlp.
///
/// yt-dlp reads the page (`--dump-single-json`) and downloads the chosen MP4
/// file with the page cookies it keeps in the info; `--continue` resumes it
/// after a pause. Video and audio come in one file: nothing is muxed
final class TikTokYtDlpVideoRepository implements VideoRepositoryInterface {
  static const _infoFileName = 'yt-dlp-info.json';
  static const _filePrefix = '${TikTokConstants.filePrefix}yt-dlp-';
  static const _progressInterval = Duration(milliseconds: 250);

  final YtDlpService _ytDlpService;
  final FileSystemService _fileSystemService;

  /// By the link the user gave and by the video id
  final _infos = <String, _TikTokYtDlpInfo>{};

  TikTokYtDlpVideoRepository({
    required this._ytDlpService,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final link = _parse(url);
      final info = await _extract(link);
      final qualities = TikTokQualities.build(info.formats);

      if (qualities.isEmpty) {
        throw VideoException(const VideoErrorCodes().streamFormat);
      }

      return ok(
        VideoInfoModel(
          id: info.id,
          title: info.title ?? info.id,
          url: info.webpageUrl ?? link.url,
          channel: info.uploader,
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

      var info = _infos[_keyOf(link)];

      if (info == null || info.expired) {
        info = await _extract(link, cancellation: cancellation);
      }

      _throwIfCancelled(cancellation);

      var selectedStreams = streams;

      Future<String> download(_TikTokYtDlpInfo info) => _download(
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

        /// The links and cookies expire: a fresh page gives new ones
        info = await _extract(link, cancellation: cancellation);

        try {
          filePath = await download(info);
        } on _ExpiredLinksException {
          throw VideoException(
            const VideoErrorCodes().tiktokHttpStatus,
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

  TikTokVideoLink _parse(String url) {
    final link =
        TikTokUrlParser.parse(url) ??
        (throw VideoException(const VideoErrorCodes().notTikTokUrl));

    if (link.isPhoto) {
      throw VideoException(const VideoErrorCodes().tiktokPhoto);
    }

    return link;
  }

  static String _keyOf(TikTokVideoLink link) => link.id ?? link.url;

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

  Future<_TikTokYtDlpInfo> _extract(
    TikTokVideoLink link, {
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

    final _TikTokYtDlpInfo info;

    try {
      info = _TikTokYtDlpInfo.fromJson(result.stdout.trim());
    } on FormatException catch (error) {
      throw VideoException(
        const VideoErrorCodes().ytDlpFailed,
        args: {'error': error.message},
      );
    }

    _infos[_keyOf(link)] = info;
    _infos[info.id] = info;

    return info;
  }

  /// The last yt-dlp error line; a video TikTok does not show gets
  /// the TikTok wording
  static VideoException _failureOf(String output) {
    const codes = VideoErrorCodes();
    final error = const LineSplitter()
        .convert(output)
        .where((line) => line.startsWith('ERROR:'))
        .lastOrNull;

    if (error != null &&
        (error.contains('Video not available') ||
            error.contains('status code 10204'))) {
      return VideoException(codes.tiktokUnavailable);
    }

    return VideoException(
      codes.ytDlpFailed,
      args: {'error': (error ?? output).replaceFirst('ERROR:', '').trim()},
    );
  }

  Future<String> _download(
    _TikTokYtDlpInfo info, {
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

    final format = TikTokQualities.select(
      info.formats,
      quality: quality,
      previousBitrate: previousStreams
          .where((stream) => stream.role == DownloadStreamRole.video)
          .firstOrNull
          ?.itag,
    );

    if (format == null) {
      throw VideoException(codes.qualityUnavailable);
    }

    final expected = format.size ?? 0;

    onStreamsSelected?.call([
      DownloadStreamModel(
        role: DownloadStreamRole.video,
        itag: format.bitrate,
        contentLength: expected,
      ),
    ]);

    final infoPath = p.join(workDirectory, _infoFileName);

    /// The file of the format: yt-dlp continues only its own part file
    final filePath = p.join(workDirectory, '$_filePrefix${format.bitrate}.mp4');

    await _deleteStaleFiles(workDirectory, keep: p.basename(filePath));
    await _fileSystemService.writeFile(infoPath, utf8.encode(info.raw));

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
        info.formatIds[format]!,
        '--output',
        filePath.replaceAll('%', '%%'),
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
      if (result.errorOutput.contains('HTTP Error 403') ||
          result.errorOutput.contains('HTTP Error 410')) {
        throw const _ExpiredLinksException();
      }

      throw _failureOf(result.errorOutput);
    }

    _throwIfCancelled(cancellation);

    await _fileSystemService.deleteFile(infoPath);

    return filePath;
  }

  /// Wipes the file of another quality: another one was chosen
  Future<void> _deleteStaleFiles(
    String workDirectory, {
    required String keep,
  }) async {
    await for (final entity in Directory(workDirectory).list()) {
      final name = p.basename(entity.path);

      if (entity is File &&
          name.startsWith(_filePrefix) &&
          name != keep &&
          name != '$keep.part') {
        await _fileSystemService.deleteFile(entity.path);
      }
    }
  }
}

/// yt-dlp got 403: the links are no longer valid
final class _ExpiredLinksException implements Exception {
  const _ExpiredLinksException();
}
