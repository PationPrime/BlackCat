import 'dart:io';

import 'package:files_downloader/files_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/test_file_server.dart';

void main() {
  late Directory root;
  late TestFileServer server;

  final content = testContent(600 * 1000 + 11);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fds-isolate');
    server = TestFileServer()..files['/file'] = content;
    await server.start();
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  FilesDownloadRequest request() => FilesDownloadRequest(
    id: 'movie',
    stateDirectory: p.join(root.path, 'state'),
    options: const FilesDownloadOptions(
      sliceSize: 100 * 1000,
      progressInterval: Duration(milliseconds: 20),
      checkpointInterval: Duration(milliseconds: 20),
    ),
    files: [
      DownloadFileRequest(
        url: server.url('/file'),
        savePath: p.join(root.path, 'movie.bin'),
      ),
    ],
  );

  test(
    'загрузка идёт в отдельном изоляте: прогресс, пауза, продолжение и повторный старт',
    () async {
      final downloader = FilesDownloader();

      server.chunkDelay = const Duration(milliseconds: 5);

      final download = await downloader.start(request());

      expect(downloader['movie'], same(download));
      expect(() => downloader.start(request()), throwsStateError);

      final progress = <FilesDownloadProgress>[];

      download.progress.listen((value) {
        progress.add(value);

        if (value.downloadedBytes > 150 * 1000) download.pause();
      });

      final paused = await download.result;

      expect(paused, isA<FilesDownloadStopped>());
      expect(
        progress.map((value) => value.stage),
        contains(FilesDownloadStage.downloading),
      );
      expect(download.isFinished, isTrue);
      expect(downloader['movie'], isNull);

      final saved = await FilesDownloader.readState(
        p.join(root.path, 'state'),
        'movie',
      );

      expect(
        saved!.downloadedBytes,
        (paused as FilesDownloadStopped).downloadedBytes,
      );
      expect(saved.downloadedBytes, greaterThan(150 * 1000));

      /// Answers of the paused run are finished before the next one
      server.chunkDelay = Duration.zero;
      await server.idle();

      final resumed = await downloader.start(request());
      final result = await resumed.result;

      expect(result, isA<FilesDownloadCompleted>());
      expect(File(p.join(root.path, 'movie.bin')).readAsBytesSync(), content);
      expect(resumed.lastProgress!.downloadedBytes, content.length);
      expect(
        await FilesDownloader.readState(p.join(root.path, 'state'), 'movie'),
        isNull,
      );
    },
  );

  test(
    'отмена до готовности изолята и после: файлы и state удаляются',
    () async {
      final downloader = FilesDownloader();
      final early = await downloader.start(request());
      final cancelled = await early.cancel();

      expect(
        cancelled,
        isA<FilesDownloadStopped>().having(
          (s) => s.discarded,
          'discarded',
          isTrue,
        ),
      );
      expect(File(p.join(root.path, 'movie.bin')).existsSync(), isFalse);

      server.chunkDelay = const Duration(milliseconds: 5);

      final running = await downloader.start(request());

      running.progress.listen((value) {
        if (value.downloadedBytes > 0) running.cancel();
      });

      expect(
        await running.result,
        isA<FilesDownloadStopped>().having(
          (s) => s.discarded,
          'discarded',
          isTrue,
        ),
      );
      expect(File(p.join(root.path, 'movie.bin')).existsSync(), isFalse);
      expect(
        await FilesDownloader.readState(p.join(root.path, 'state'), 'movie'),
        isNull,
      );
    },
  );

  test(
    'ограничение скорости меняется на ходу, ошибка сервера приходит результатом',
    () async {
      final downloader = FilesDownloader();
      final download = await downloader.start(request());

      download.setSpeedLimit(50 * 1000);

      final stopwatch = Stopwatch()..start();

      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(download.isFinished, isFalse);

      download.setSpeedLimit(null);

      expect(await download.result, isA<FilesDownloadCompleted>());
      expect(
        stopwatch.elapsed,
        greaterThan(const Duration(milliseconds: 1400)),
      );

      server.statusFor = (served) => served.number > 3 ? 403 : null;
      File(p.join(root.path, 'movie.bin')).deleteSync();

      final failing = await downloader.start(request());
      final failed = await failing.result;

      expect(
        failed,
        isA<FilesDownloadFailed>().having(
          (f) => f.error.statusCode,
          'status',
          403,
        ),
      );
    },
  );
}
