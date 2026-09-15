import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/api/api.dart';
import 'package:youtube_downloader/src/app/data_sources/data_sources.dart';

/// Stream server: serves the requested `&range=start-end`
/// and remembers which ranges were requested
final class _StreamServer {
  final Uint8List content;
  final requestedRanges = <String>[];

  late final HttpServer _server;

  _StreamServer(this.content);

  String get url => 'http://${_server.address.host}:${_server.port}/videoplayback?itag=140';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final range = request.uri.queryParameters['range']!;
      final [start, end] = [for (final part in range.split('-')) int.parse(part)];

      requestedRanges.add(range);
      request.response.add(content.sublist(start, math.min(end + 1, content.length)));
      await request.response.close();
    });
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Directory root;
  late _StreamServer server;
  late RemoteMediaStreamDataSource dataSource;

  final content = Uint8List.fromList([for (var i = 0; i < 25 * 1024 * 1024 + 123; i++) i % 251]);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media-stream');
    server = _StreamServer(content);
    await server.start();
    dataSource = RemoteMediaStreamDataSourceImpl(apiProvider: ApiProvider());
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  test('продолжает поток с длины уже скачанного файла', () async {
    final path = p.join(root.path, 'audio-140-${content.length}.part');
    const alreadyDownloaded = 12 * 1024 * 1024 + 7;

    await File(path).writeAsBytes(content.sublist(0, alreadyDownloaded));

    var received = 0;

    await dataSource.downloadStream(
      server.url,
      length: content.length,
      path: path,
      onBytes: (bytes) => received += bytes,
    );

    expect(server.requestedRanges.first, startsWith('$alreadyDownloaded-'));
    expect(received, content.length - alreadyDownloaded);
    expect(await File(path).readAsBytes(), content);
  });

  test('файл длиннее потока качается заново', () async {
    final path = p.join(root.path, 'stale.part');

    await File(path).writeAsBytes(Uint8List(content.length + 10));

    await dataSource.downloadStream(server.url, length: content.length, path: path, onBytes: (_) {});

    expect(server.requestedRanges.first, startsWith('0-'));
    expect(await File(path).readAsBytes(), content);
  });

  test('отмена оставляет скачанные байты для продолжения', () async {
    final path = p.join(root.path, 'cancel.part');
    final cancelToken = CancelToken();
    var received = 0;

    await expectLater(
      dataSource.downloadStream(
        server.url,
        length: content.length,
        path: path,
        cancelToken: cancelToken,
        onBytes: (bytes) {
          received += bytes;

          if (received > 11 * 1024 * 1024) {
            cancelToken.cancel();
          }
        },
      ),
      throwsA(isA<DioException>().having((error) => error.type, 'type', DioExceptionType.cancel)),
    );

    final kept = await File(path).length();

    expect(kept, greaterThan(10 * 1024 * 1024));
    expect(await File(path).readAsBytes(), content.sublist(0, kept));
  });
}
