import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/errors/errors.dart';
import 'package:peeky_cat/src/app/services/services.dart';

class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);
}

void main() {
  late Directory root;

  setUp(
    () async => root = await Directory.systemTemp.createTemp('yt-dlp-service'),
  );

  tearDown(() => root.delete(recursive: true));

  test(
    'только программы приложения: без них yt-dlp не найден и не запускается',
    () async {
      final service = YtDlpServiceImpl(
        fileSystemService: _TestFileSystemService(root),
        environment: const {YtDlpServiceImpl.bundledOnlyVariable: '1'},
      );

      final setup = await service.setup();

      expect(setup.ytDlp, isNull);
      expect(setup.jsRuntime, isNull);
      expect(setup.isReady, isFalse);
      await expectLater(
        service.run(const ['--version']),
        throwsA(
          isA<VideoException>().having(
            (error) => error.code,
            'code',
            const VideoErrorCodes().ytDlpNotFound,
          ),
        ),
      );
    },
  );

  test(
    'YTDLP_PATH указывает на отсутствующую программу — yt-dlp не найден',
    () async {
      final service = YtDlpServiceImpl(
        fileSystemService: _TestFileSystemService(root),
        environment: {'YTDLP_PATH': p.join(root.path, 'missing', 'yt-dlp.exe')},
      );

      expect((await service.setup()).ytDlp, isNull);
    },
  );

  test('результат поиска хранится до refresh', () async {
    final service = YtDlpServiceImpl(
      fileSystemService: _TestFileSystemService(root),
      environment: const {YtDlpServiceImpl.bundledOnlyVariable: '1'},
    );

    expect(identical(service.setup(), service.setup()), isTrue);
    expect(identical(service.setup(), service.setup(refresh: true)), isFalse);
  });
}
