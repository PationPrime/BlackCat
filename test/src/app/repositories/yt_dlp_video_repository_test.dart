import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/constants/constants.dart';
import 'package:youtube_downloader/src/app/data_sources/data_sources.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/session/session_store.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

import '../../support/dash_stream_builder.dart';

const _url = 'https://www.youtube.com/watch?v=kgA8JPY2lIA';
const _title = 'Обзор через yt-dlp';

class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);

  @override
  Future<String> supportFolder() async => p.join(root.path, 'support');

  @override
  Future<String> defaultDownloadsFolder() async => p.join(root.path, 'Downloads');
}

/// Serves the streams with Range support, slowly enough to stop a download
/// midway, and remembers the requested ranges
final class _StreamServer {
  final Map<String, Uint8List> files;
  final ranges = <String, List<String?>>{};

  late final HttpServer _server;

  _StreamServer(this.files);

  String urlOf(String name) =>
      'http://${_server.address.host}:${_server.port}/$name?expire=${DateTime.now().add(const Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final name = request.uri.pathSegments.single;
      final content = files[name]!;
      final header = request.headers.value(HttpHeaders.rangeHeader);

      ranges.putIfAbsent(name, () => []).add(header);

      var start = 0;
      var end = content.length - 1;

      if (header case final range?) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        start = int.parse(match.group(1)!);
        end = match.group(2)!.isEmpty ? end : math.min(end, int.parse(match.group(2)!));
      }

      final response = request.response;

      if (start >= content.length) {
        response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */${content.length}');
        await response.close();

        return;
      }

      response
        ..statusCode = header == null ? HttpStatus.ok : HttpStatus.partialContent
        ..headers.contentType = ContentType('video', 'mp4')
        ..headers.contentLength = end - start + 1
        ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (header != null) {
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${content.length}');
      }

      try {
        for (var offset = start; offset <= end; offset += 64 * 1024) {
          response.add(content.sublist(offset, math.min(offset + 64 * 1024, end + 1)));
          await response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }

        await response.close();
      } on Object {
        /// yt-dlp was stopped midway
      }
    });
  }

  Future<void> close() => _server.close(force: true);
}

/// Real yt-dlp for downloads; the video info comes from the test instead
/// of YouTube, with links to the local server
final class _LocalInfoYtDlpService implements YtDlpService {
  final YtDlpService _ytDlpService;
  final String Function() infoJson;
  var extractions = 0;

  _LocalInfoYtDlpService(this._ytDlpService, this.infoJson);

  @override
  bool get isSupported => _ytDlpService.isSupported;

  @override
  Future<YtDlpSetupModel> setup({bool refresh = false}) => _ytDlpService.setup(refresh: refresh);

  @override
  Future<YtDlpRunResult> run(
    List<String> arguments, {
    ValueChanged<String>? onLine,
    DownloadCancellation? cancellation,
  }) async {
    if (arguments.contains('--dump-single-json')) {
      extractions++;

      return YtDlpRunResult(exitCode: 0, stdout: infoJson());
    }

    return _ytDlpService.run(arguments, onLine: onLine, cancellation: cancellation);
  }
}

String _info(_StreamServer server) => jsonEncode({
  'id': 'kgA8JPY2lIA',
  'title': _title,
  'channel': 'Канал',
  'duration': 478,
  'view_count': 1200,
  'extractor': 'youtube',
  'extractor_key': 'Youtube',
  'webpage_url': _url,
  'original_url': _url,
  'webpage_url_basename': 'watch',
  'webpage_url_domain': 'youtube.com',
  '_type': 'video',
  'epoch': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  'formats': [
    {
      'format_id': '137',
      'url': server.urlOf('video'),
      'ext': 'mp4',
      'protocol': 'https',
      'vcodec': 'avc1.640028',
      'acodec': 'none',
      'width': 1920,
      'height': 1080,
      'fps': 25,
      'tbr': 2500,
      'filesize': server.files['video']!.length,
      'http_headers': {'User-Agent': 'test'},
    },
    {
      'format_id': '140',
      'url': server.urlOf('audio'),
      'ext': 'm4a',
      'protocol': 'https',
      'vcodec': 'none',
      'acodec': 'mp4a.40.2',
      'abr': 129,
      'filesize': server.files['audio']!.length,
      'http_headers': {'User-Agent': 'test'},
    },
  ],
});

void main() {
  late Directory root;
  late _StreamServer server;
  late _LocalInfoYtDlpService ytDlpService;
  late YtDlpVideoRepository repository;
  String? skipReason;

  /// About 4 MiB of video: long enough to stop the download midway
  final video = dashStream(
    handler: 'vide',
    timescale: 1000,
    fragments: [
      (0, [('V' * (2 << 20), 1000, true, 0)]),
      (1000, [('W' * (2 << 20), 1000, true, 0)]),
    ],
  );
  final audio = dashStream(
    handler: 'soun',
    timescale: 44100,
    fragments: [
      (0, [('A0', 22050, true, 0), ('A1', 22050, true, 0)]),
    ],
  );

  setUpAll(() async {
    final tools = await Directory.systemTemp.createTemp('yt-dlp-tools');
    final setup = await YtDlpServiceImpl(fileSystemService: _TestFileSystemService(tools)).setup();

    await tools.delete(recursive: true);

    if (!setup.isReady) {
      skipReason = 'yt-dlp or a JavaScript runtime is not installed';
    }
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('yt-dlp-repository');
    server = _StreamServer({'video': video, 'audio': audio});
    await server.start();

    final fileSystemService = _TestFileSystemService(root);
    final localAuthenticationDataSource = LocalAuthenticationDataSourceImpl(fileSystemService: fileSystemService);

    ytDlpService = _LocalInfoYtDlpService(
      YtDlpServiceImpl(fileSystemService: fileSystemService),
      () => _info(server),
    );
    repository = YtDlpVideoRepository(
      ytDlpService: ytDlpService,
      mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
      fileSystemService: fileSystemService,
      sessionStore: SessionStore(localAuthenticationDataSource: localAuthenticationDataSource),
      localAuthenticationDataSource: localAuthenticationDataSource,
    );
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  List<String> topLevelBoxes(Uint8List file) {
    final types = <String>[];

    for (var offset = 0; offset + 8 <= file.length;) {
      types.add(String.fromCharCodes(file, offset + 4, offset + 8));
      offset += ByteData.sublistView(file).getUint32(offset);
    }

    return types;
  }

  test('yt-dlp скачивает видео и звук, приложение склеивает их в MP4', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);

    final info = await repository.getVideoInfo(_url);

    expect(info.failure, isNull, reason: info.failure?.message);
    expect(info.requireData.title, _title);
    expect([for (final quality in info.requireData.qualities) quality.id], ['1080', QualityModel.audioId]);

    final progress = <DownloadProgressModel>[];
    var streams = <DownloadStreamModel>[];

    final result = await repository.downloadVideo(
      taskId: 'task-1',
      url: _url,
      quality: '1080',
      onStreamsSelected: (selected) => streams = selected,
      onProgress: progress.add,
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(result.requireData.path, p.join(root.path, 'Downloads', '$_title.mp4'));
    expect(result.requireData.sizeBytes, await File(result.requireData.path).length());
    expect(topLevelBoxes(await File(result.requireData.path).readAsBytes()), ['ftyp', 'moov', 'mdat']);

    expect(streams, [
      DownloadStreamModel(role: DownloadStreamRole.video, itag: 137, contentLength: video.length),
      DownloadStreamModel(role: DownloadStreamRole.audio, itag: 140, contentLength: audio.length),
    ]);
    expect(progress.last.stage, DownloadStage.processing);
    expect(
      progress.where((item) => item.stage.isDownloading).last.downloadedBytes,
      video.length + audio.length,
    );

    /// The info of the search is reused: its links are still valid
    expect(ytDlpService.extractions, 1);
    expect(await Directory(p.join(root.path, StorageConstants.downloadWorkFolder, 'task-1')).exists(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('остановленная загрузка продолжается с места остановки', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);

    final cancellation = DownloadCancellation();
    var streams = <DownloadStreamModel>[];

    final stopped = await repository.downloadVideo(
      taskId: 'task-2',
      url: _url,
      quality: '1080',
      cancellation: cancellation,
      onStreamsSelected: (selected) => streams = selected,
      onProgress: (progress) {
        if ((progress.downloadedBytes ?? 0) > 512 * 1024) {
          cancellation.cancel();
        }
      },
    );

    expect(stopped.failure?.code, const VideoErrorCodes().canceled);

    final workDirectory = p.join(root.path, StorageConstants.downloadWorkFolder, 'task-2');
    final videoPart = File(DownloadPartFiles.path(workDirectory, streams.first));
    final stoppedAt = await videoPart.length();

    expect(stoppedAt, inInclusiveRange(512 * 1024, video.length - 1));

    final progress = <DownloadProgressModel>[];
    final resumed = await repository.downloadVideo(
      taskId: 'task-2',
      url: _url,
      quality: '1080',
      streams: streams,
      onProgress: progress.add,
    );

    expect(resumed.failure, isNull, reason: resumed.failure?.message);
    expect(progress.first.downloadedBytes, greaterThanOrEqualTo(stoppedAt));
    expect(server.ranges['video']!.last, startsWith('bytes=$stoppedAt-'));
    expect(topLevelBoxes(await File(resumed.requireData.path).readAsBytes()), ['ftyp', 'moov', 'mdat']);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
