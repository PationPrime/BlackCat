import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:files_downloader/files_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/api/api.dart';
import 'package:youtube_downloader/src/app/data_sources/data_sources.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

const _mib = 1024 * 1024;

/// googlevideo.com stand-in: serves `&range=start-end` with `200`, answers
/// `HEAD` with the size and remembers the asked ranges
final class _StreamServer {
  final Map<String, Uint8List> streams;
  final requestedRanges = <String, List<String>>{};

  Duration chunkDelay = Duration.zero;
  bool forbidden = false;

  late final HttpServer _server;

  _StreamServer(this.streams);

  String url(String itag) =>
      'http://${_server.address.host}:${_server.port}/videoplayback?itag=$itag&expire=1';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final response = request.response;

      try {
        final content = streams[request.uri.queryParameters['itag']]!;

        if (forbidden) {
          response.statusCode = 403;

          return;
        }

        if (request.method == 'HEAD') {
          response.contentLength = content.length;

          return;
        }

        final range = request.uri.queryParameters['range']!;
        final [start, end] = [for (final part in range.split('-')) int.parse(part)];
        final body = content.sublist(start, math.min(end + 1, content.length));

        requestedRanges.putIfAbsent(request.uri.queryParameters['itag']!, () => []).add(range);
        response.contentLength = body.length;

        for (var offset = 0; offset < body.length; offset += 256 * 1024) {
          response.add(body.sublist(offset, math.min(offset + 256 * 1024, body.length)));

          if (chunkDelay > Duration.zero) {
            await response.flush();
            await Future<void>.delayed(chunkDelay);
          }
        }
      } catch (_) {
        /// The downloader closed the connection
      } finally {
        try {
          await response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Directory root;
  late _StreamServer server;
  late RemoteMediaStreamDataSource dataSource;

  final video = Uint8List.fromList([for (var i = 0; i < 25 * _mib + 123; i++) i % 251]);
  final audio = Uint8List.fromList([for (var i = 0; i < 3 * _mib + 5; i++) i % 13]);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media-stream');
    server = _StreamServer({'137': video, '140': audio});
    await server.start();
    dataSource = RemoteMediaStreamDataSourceImpl(apiProvider: ApiProvider());
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  String partPath(String name) => p.join(root.path, name);

  List<MediaStreamTarget> targets() => [
    MediaStreamTarget(
      url: server.url('137'),
      path: partPath('video-137-${video.length}.part'),
      length: video.length,
      fingerprint: 'video-137-${video.length}.part',
    ),
    MediaStreamTarget(
      url: server.url('140'),
      path: partPath('audio-140-${audio.length}.part'),
      length: audio.length,
      fingerprint: 'audio-140-${audio.length}.part',
    ),
  ];

  Future<void> download({
    DownloadCancellation? cancellation,
    void Function(MediaStreamProgress progress)? onProgress,
  }) => dataSource.downloadStreams(
    downloadId: 'task-1',
    streams: targets(),
    stateDirectory: root.path,
    cancellation: cancellation,
    onProgress: onProgress ?? (_) {},
  );

  test('видео и звук качаются слайсами по 10 МиБ параллельно, state в конце удаляется', () async {
    final progress = <MediaStreamProgress>[];

    await download(onProgress: progress.add);

    expect(await File(targets().first.path).readAsBytes(), video);
    expect(await File(targets().last.path).readAsBytes(), audio);
    expect(server.requestedRanges['137'], unorderedEquals(['0-10485759', '10485760-20971519', '20971520-26214522']));
    expect(server.requestedRanges['140'], ['0-3145732']);
    expect(progress.last.downloadedBytes, video.length + audio.length);
    expect(progress.last.totalBytes, video.length + audio.length);
    expect(await FilesDownloader.readState(root.path, 'task-1'), isNull);
  });

  test('файл, записанный по порядку (yt-dlp или прежней версией), продолжается с его длины', () async {
    const alreadyDownloaded = 12 * _mib + 7;

    await File(targets().first.path).writeAsBytes(video.sublist(0, alreadyDownloaded));

    await download();

    expect(server.requestedRanges['137'], unorderedEquals(['$alreadyDownloaded-20971519', '20971520-26214522']));
    expect(await File(targets().first.path).readAsBytes(), video);
  });

  test('остановка сохраняет слайсы в state, продолжение докачивает только недостающее', () async {
    server.chunkDelay = const Duration(milliseconds: 20);

    final cancellation = DownloadCancellation();

    await expectLater(
      download(
        cancellation: cancellation,
        onProgress: (progress) {
          if (progress.downloadedBytes > 6 * _mib) cancellation.cancel();
        },
      ),
      throwsA(isA<VideoException>().having((error) => error.code, 'code', const VideoErrorCodes().canceled)),
    );

    final saved = (await FilesDownloader.readState(root.path, 'task-1'))!;

    expect(saved.downloadedBytes, greaterThan(6 * _mib));

    final savedVideo = saved.fileByIdentity('video-137-${video.length}.part')!;

    server
      ..chunkDelay = Duration.zero
      ..requestedRanges.clear();

    final progress = <MediaStreamProgress>[];

    await download(onProgress: progress.add);

    expect(await File(targets().first.path).readAsBytes(), video);
    expect(await File(targets().last.path).readAsBytes(), audio);
    expect(progress.first.downloadedBytes, saved.downloadedBytes);
    expect(server.requestedRanges['137'], unorderedEquals([
      for (var slice = 0; slice < 3; slice++)
        if (savedVideo.sliceCounters[slice] < math.min(10 * _mib, video.length - slice * 10 * _mib))
          '${slice * 10 * _mib + savedVideo.sliceCounters[slice]}-'
              '${math.min((slice + 1) * 10 * _mib, video.length) - 1}',
    ]));
  });

  test('403 значит, что ссылки устарели: прогресс остаётся для новых ссылок', () async {
    server.forbidden = true;

    await expectLater(download(), throwsA(isA<MediaStreamLinksExpiredException>()));

    server.forbidden = false;

    await download();

    expect(await File(targets().first.path).readAsBytes(), video);
  });
}
