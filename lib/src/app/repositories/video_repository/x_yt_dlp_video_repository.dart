import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

/// X info from `--dump-single-json`: the post video and its MP4 files, each
/// with the yt-dlp format that downloads it
final class _XYtDlpInfo {
  /// The info of the one video: `--load-info-json` downloads from it
  final String raw;
  final XVideoDto video;

  /// yt-dlp format of every file, by its link
  final Map<String, String> formatIds;
  final DateTime extractedAt;

  _XYtDlpInfo({required this.raw, required this.video, required this.formatIds})
    : extractedAt = DateTime.now();

  bool get expired =>
      DateTime.now().difference(extractedAt) > const Duration(minutes: 30);
}

/// X (Twitter) videos through yt-dlp.
///
/// yt-dlp reads the post (`--dump-single-json`) and downloads the chosen MP4
/// file (`--load-info-json`); `--continue` resumes it after a pause. Video
/// and audio come in one file: nothing is muxed
final class XYtDlpVideoRepository implements VideoRepositoryInterface {
  static const _infoFileName = 'yt-dlp-info.json';
  static const _filePrefix = '${XConstants.filePrefix}yt-dlp-';
  static const _progressInterval = Duration(milliseconds: 250);

  /// Short links X adds to the text: the media and the links in it
  static final _shortLinkPattern = RegExp(r'\s*https?://t\.co/\S+');

  final YtDlpService _ytDlpService;
  final RemoteXDataSource _remoteXDataSource;
  final FileSystemService _fileSystemService;

  final _infos = <XPostLink, _XYtDlpInfo>{};

  XYtDlpVideoRepository({
    required this._ytDlpService,
    required this._remoteXDataSource,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    try {
      final video = (await _extract(_parse(url))).video;
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
      final workDirectory = (await _fileSystemService.downloadWorkDirectory(
        taskId,
      )).path;

      var info = _infos[link];

      if (info == null || info.expired) {
        info = await _extract(link, cancellation: cancellation);
      }

      _throwIfCancelled(cancellation);

      var selectedStreams = streams;

      Future<String> download(_XYtDlpInfo info) => _download(
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

        /// The file was refused: the post is read again for its files
        info = await _extract(link, cancellation: cancellation);

        try {
          filePath = await download(info);
        } on _ExpiredLinksException {
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
          title: info.video.title,
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

  Future<_XYtDlpInfo> _extract(
    XPostLink link, {
    DownloadCancellation? cancellation,
  }) async {
    final result = await _run([
      '--dump-single-json',
      link.url,
    ], cancellation: cancellation);

    if (!result.isSuccess) {
      throw _failureOf(result.errorOutput);
    }

    final Map<dynamic, dynamic> json;

    try {
      json = videoInfoOf(jsonDecode(result.stdout.trim()));
    } on FormatException catch (error) {
      throw VideoException(
        const VideoErrorCodes().ytDlpFailed,
        args: {'error': error.message},
      );
    }

    final parsed = formatsOf(json);
    final sizes = await Future.wait([
      for (final format in parsed.formats)
        _remoteXDataSource.sizeOf(format.url),
    ]);
    final uploaderId = json['uploader_id'] as String?;
    final info = _XYtDlpInfo(
      raw: jsonEncode(json),
      video: XVideoDto(
        id: '${json['display_id'] ?? link.id}',
        title: _titleOf(json),
        formats: [
          for (final (index, format) in parsed.formats.indexed)
            format.withSize(sizes[index] ?? format.size),
        ],
        url: XPostLink(
          link.id,
          author: uploaderId ?? link.author,
          mediaIndex: link.mediaIndex,
        ).url,
        author: uploaderId,
        authorName: (json['uploader'] ?? uploaderId) as String?,
        durationSeconds: json['duration'] as num?,
        thumbnail: json['thumbnail'] as String?,
        viewCount: (json['view_count'] as num?)?.toInt(),
      ),
      formatIds: parsed.formatIds,
    );

    return _infos[link] = info;
  }

  /// The info of the video: a post of several videos is a playlist,
  /// and its first video is taken
  static Map<dynamic, dynamic> videoInfoOf(Object? json) {
    if (json is! Map) {
      throw const FormatException('yt-dlp printed no video');
    }

    if (json['entries'] case final List<dynamic> entries) {
      return entries.whereType<Map<dynamic, dynamic>>().firstOrNull ??
          (throw VideoException(const VideoErrorCodes().xNoVideo));
    }

    return json;
  }

  /// MP4 files of the info with the yt-dlp format of each by its link.
  /// HLS copies of the same video are left out
  static ({List<XFormatDto> formats, Map<String, String> formatIds}) formatsOf(
    Map<dynamic, dynamic> json,
  ) {
    final formats = <XFormatDto>[];
    final formatIds = <String, String>{};

    for (final format
        in (json['formats'] as List? ?? const []).whereType<Map>()) {
      final id = '${format['format_id'] ?? ''}';
      final url = '${format['url'] ?? ''}';

      if (id.isEmpty ||
          url.isEmpty ||
          '${format['protocol'] ?? ''}' != 'https' ||
          format['vcodec'] == 'none' ||
          formatIds.containsKey(url)) {
        continue;
      }

      final tbr = format['tbr'] as num?;
      final size = XQualities.sizeOfUrl(url);

      formatIds[url] = id;
      formats.add(
        XFormatDto(
          url: url,
          bitrate: tbr == null ? 0 : (tbr * 1000).round(),
          width: (format['width'] as num?)?.toInt() ?? size?.width,
          height: (format['height'] as num?)?.toInt() ?? size?.height,
          codec: XQualities.codecOfUrl(url),
          size: ((format['filesize'] ?? format['filesize_approx']) as num?)
              ?.toInt(),
        ),
      );
    }

    return (formats: formats, formatIds: formatIds);
  }

  /// The post text as the title, as with the built-in downloader: yt-dlp
  /// cuts it and puts the author before it
  static String _titleOf(Map<dynamic, dynamic> json) {
    final text = '${json['description'] ?? ''}'
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(_shortLinkPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final uploaderId = json['uploader_id'] as String?;
    final title = text.isNotEmpty
        ? text
        : 'X${uploaderId == null ? '' : ' @$uploaderId'}';

    /// yt-dlp numbers the videos of a post of several
    final number = RegExp(r' #(\d+)$').firstMatch('${json['title'] ?? ''}');

    return number == null ? title : '$title #${number.group(1)}';
  }

  /// The last yt-dlp error line; what X refuses gets its wording
  static VideoException _failureOf(String output) {
    const codes = VideoErrorCodes();
    final error = const LineSplitter()
        .convert(output)
        .where((line) => line.startsWith('ERROR:'))
        .lastOrNull;

    return switch (error) {
      final line?
          when line.contains('No video could be found') ||
              line.contains('is not a video') ||
              RegExp(r'Video #\d+ is unavailable').hasMatch(line) =>
        VideoException(codes.xNoVideo),
      final line?
          when line.contains('unavailable') ||
              line.contains('NSFW') ||
              line.contains('protected') ||
              line.contains('not authorized') ||
              line.contains('Twitter API says') ||
              line.contains('HTTP Error 404') =>
        VideoException(codes.xUnavailable),
      _ => VideoException(
        codes.ytDlpFailed,
        args: {'error': (error ?? output).replaceFirst('ERROR:', '').trim()},
      ),
    };
  }

  Future<String> _download(
    _XYtDlpInfo info, {
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
      info.video.formats,
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
        info.formatIds[format.url]!,
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
