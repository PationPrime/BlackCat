import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/api/api.dart';
import 'package:peeky_cat/src/app/data_sources/data_sources.dart';

void main() {
  late HttpServer server;
  late Directory root;
  late RemoteDependencyDataSource dataSource;
  final program = List<int>.generate(300 * 1024, (index) => index % 251);
  final userAgents = <String?>[];

  String url(String path) =>
      'http://${server.address.host}:${server.port}$path';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('remote-dependency');
    dataSource = RemoteDependencyDataSourceImpl(apiProvider: ApiProvider());
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;

      userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));

      switch (request.uri.path) {
        /// GitHub answers `latest/download` with a redirect to the file storage
        case '/latest/download/yt-dlp.exe':
          response
            ..statusCode = HttpStatus.found
            ..headers.set(
              HttpHeaders.locationHeader,
              url('/assets/yt-dlp.exe'),
            );
        case '/assets/yt-dlp.exe':
          response
            ..headers.contentLength = program.length
            ..add(program);
        case '/latest/download/SHA2-256SUMS':
          response.write('abc  yt-dlp.exe\n');
        default:
          response.statusCode = HttpStatus.notFound;
      }

      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  test('скачивает файл по перенаправлению в ещё не созданную папку', () async {
    final path = p.join(root.path, 'Tools', 'yt-dlp.exe.download');
    final progress = <(int, int?)>[];

    await dataSource.downloadFile(
      url('/latest/download/yt-dlp.exe'),
      path: path,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(await File(path).readAsBytes(), program);
    expect(progress.last, (program.length, program.length));
    expect(
      await dataSource.fetchText(url('/latest/download/SHA2-256SUMS')),
      'abc  yt-dlp.exe\n',
    );

    /// GitHub needs the app name on its own requests; dart:io does not repeat
    /// it after the redirect, and the file storage does not need it
    expect(userAgents.first, 'YT-Download');
  });

  test('ответ с ошибкой не оставляет файла', () async {
    final path = p.join(root.path, 'Tools', 'deno.zip.download');

    await expectLater(
      dataSource.downloadFile(
        url('/missing.zip'),
        path: path,
        onProgress: (_, _) {},
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
    expect(await File(path).exists(), isFalse);
  });
}
