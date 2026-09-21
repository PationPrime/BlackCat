import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/modules/home/controllers/controllers.dart';

import '../../support/test_localization.dart';

/// Only what the controller asks of the file system
class _FakeFileSystemService implements FileSystemService {
  final String root;

  _FakeFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => '$root/$name';

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);

    if (file.existsSync()) await file.delete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves one file with `Range` support, like an ordinary web server
Future<({HttpServer server, Uint8List body})> _startServer({
  int length = 256 * 1024,
}) async {
  final body = Uint8List.fromList([
    for (var i = 0; i < length; i++) (i * 31 + 7) % 256,
  ]);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  server.listen((request) async {
    final response = request.response..headers.set('accept-ranges', 'bytes');

    /// A status the downloader does not retry
    if (request.uri.path == '/missing') {
      response.statusCode = HttpStatus.notFound;
      await response.close();

      return;
    }

    if (request.method == 'HEAD') {
      response.contentLength = body.length;
      await response.close();

      return;
    }

    final range = RegExp(
      r'^bytes=(\d+)-(\d*)$',
    ).firstMatch(request.headers.value('range') ?? '');

    if (range == null) {
      response
        ..contentLength = body.length
        ..add(body);
      await response.close();

      return;
    }

    final start = int.parse(range.group(1)!);
    final end = math.min(
      range.group(2)!.isEmpty ? body.length - 1 : int.parse(range.group(2)!),
      body.length - 1,
    );

    response
      ..statusCode = HttpStatus.partialContent
      ..headers.set('content-range', 'bytes $start-$end/${body.length}')
      ..contentLength = end - start + 1
      ..add(Uint8List.sublistView(body, start, end + 1));

    await response.close();
  });

  return (server: server, body: body);
}

void main() {
  late Directory root;
  late HttpServer server;
  late Uint8List body;
  late DirectDownloadController controller;

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('direct_download');

    final started = await _startServer();

    server = started.server;
    body = started.body;
    controller = DirectDownloadController(
      fileSystemService: _FakeFileSystemService(root.path),
    );
  });

  tearDown(() async {
    await controller.close();
    await server.close(force: true);

    root.deleteSync(recursive: true);
  });

  String urlOf(String path) =>
      'http://${server.address.host}:${server.port}$path';

  test('downloads a file by its link and keeps every byte', () async {
    await controller.start(urlOf('/archive.zip'));

    final state = controller.state;

    expect(state.status, DirectDownloadStatus.completed);
    expect(state.fileName, 'archive.zip');
    expect(state.totalBytes, body.length);
    expect(state.downloadedBytes, body.length);
    expect(File(state.savePath!).readAsBytesSync(), body);
  });

  test('a link without a file name saves under a name of its own', () async {
    await controller.start(urlOf('/'));

    expect(controller.state.status, DirectDownloadStatus.completed);
    expect(controller.state.fileName, 'download.bin');
  });

  test('a link that is not http is refused before anything starts', () async {
    await controller.start('ftp://example.com/file.zip');

    expect(controller.state.status, DirectDownloadStatus.failed);
    expect(controller.state.errorMessage, isNotEmpty);
    expect(controller.state.savePath, isNull);
  });

  test('a failed download keeps the link so it can be tried again', () async {
    await controller.start(urlOf('/missing'));

    expect(controller.state.status, DirectDownloadStatus.failed);
    expect(controller.state.errorMessage, contains('404'));
    expect(controller.state.canResume, isTrue);
  });

  test('cancelling a finished download deletes the file', () async {
    await controller.start(urlOf('/archive.zip'));

    final savePath = controller.state.savePath!;

    await controller.cancel();

    expect(controller.state.status, DirectDownloadStatus.idle);
    expect(controller.state.savePath, isNull);
    expect(File(savePath).existsSync(), isFalse);
  });
}
