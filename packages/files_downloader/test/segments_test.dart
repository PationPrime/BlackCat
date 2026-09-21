import 'dart:io';
import 'dart:typed_data';

import 'package:files_downloader/files_downloader.dart';
import 'package:files_downloader/src/engine/segments_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/test_file_server.dart';

const _options = FilesDownloadOptions(
  maxConnections: 3,
  maxRetries: 3,
  retryBaseDelay: Duration(milliseconds: 5),
  idleTimeout: Duration(seconds: 3),
  progressInterval: Duration(milliseconds: 20),
);

/// Free space a test decides
final class _DiskSpace implements DiskSpace {
  final int? available;

  const _DiskSpace(this.available);

  @override
  int? availableBytes(String path) => available;
}

void main() {
  late Directory root;
  late TestFileServer server;

  final segments = [
    for (var i = 0; i < 10; i++) testContent(40 * 1000 + i * 7919, seed: i),
  ];
  final total = segments.fold<int>(0, (sum, bytes) => sum + bytes.length);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fds-segments');
    server = TestFileServer();

    for (final (index, content) in segments.indexed) {
      server.files['/seg$index.ts'] = content;
    }

    await server.start();
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  String savePath(int index) => p.join(root.path, 'out', 'seg$index.ts');

  SegmentsDownloadRequest request({int? expectedBytes}) =>
      SegmentsDownloadRequest(
        id: 'task-1',
        options: _options,
        expectedBytes: expectedBytes,
        segments: [
          for (var i = 0; i < segments.length; i++)
            DownloadSegmentRequest(
              url: server.url('/seg$i.ts'),
              savePath: savePath(i),
            ),
        ],
      );

  Future<(FilesDownloadResult, List<FilesDownloadProgress>)> run(
    SegmentsDownloadRequest request, {
    DiskSpace diskSpace = const _DiskSpace(null),
    void Function(SegmentsDownloadEngine engine, FilesDownloadProgress)?
    onProgress,
  }) async {
    final progress = <FilesDownloadProgress>[];
    final client = DownloadApiClient(request.options);
    late final SegmentsDownloadEngine engine;

    engine = SegmentsDownloadEngine(
      request: request,
      client: client,
      diskSpace: diskSpace,
      onProgress: (value) {
        progress.add(value);
        onProgress?.call(engine, value);
      },
    );

    try {
      return (await engine.run(), progress);
    } finally {
      client.close();
    }
  }

  void expectSegments() {
    for (final (index, content) in segments.indexed) {
      expect(
        File(savePath(index)).readAsBytesSync(),
        content,
        reason: 'segment $index',
      );
    }

    expect(
      Directory(p.join(root.path, 'out')).listSync().where(
        (entity) => entity.path.endsWith(SegmentsDownloadEngine.partExtension),
      ),
      isEmpty,
    );
  }

  int getsOf(int index) => server.gets('/seg$index.ts').length;

  test(
    'сегменты качаются целиком по одному запросу, без запросов размера',
    () async {
      /// Slow answers let the connections overlap
      server.chunkDelay = const Duration(milliseconds: 2);

      final (result, progress) = await run(request());

      expect(result, isA<FilesDownloadCompleted>());
      expect(
        (result as FilesDownloadCompleted).files.map((file) => file.length),
        [for (final content in segments) content.length],
      );
      expectSegments();

      for (var i = 0; i < segments.length; i++) {
        expect(getsOf(i), 1, reason: 'segment $i');
        expect(server.gets('/seg$i.ts').single.rangeHeader, isNull);
      }

      expect(server.maxActive, inInclusiveRange(2, 3));
      expect(progress.last.downloadedBytes, total);
      expect(progress.last.totalBytes, total);
    },
  );

  test(
    'пауза оставляет готовые сегменты, продолжение качает только остальные',
    () async {
      server.chunkDelay = const Duration(milliseconds: 15);

      final (paused, _) = await run(
        request(),
        onProgress: (engine, progress) {
          if (progress.downloadedBytes > total ~/ 3) engine.stop();
        },
      );

      expect(paused, isA<FilesDownloadStopped>());

      final finished = [
        for (var i = 0; i < segments.length; i++)
          if (File(savePath(i)).existsSync()) i,
      ];

      expect(finished, isNotEmpty);
      expect(finished.length, lessThan(segments.length));
      expect(
        (paused as FilesDownloadStopped).downloadedBytes,
        finished.fold<int>(0, (sum, i) => sum + segments[i].length),
      );

      server.chunkDelay = Duration.zero;
      await server.idle();

      final (resumed, progress) = await run(request());

      expect(resumed, isA<FilesDownloadCompleted>());
      expectSegments();

      for (final i in finished) {
        expect(getsOf(i), 1, reason: 'finished segment $i is not asked again');
      }

      expect(progress.first.downloadedBytes, paused.downloadedBytes);
    },
  );

  test('403 значит, что ссылки устарели: ошибка сразу, без повторов', () async {
    server.statusFor = (served) => served.path == '/seg4.ts' ? 403 : null;

    final (result, _) = await run(request());

    expect(
      result,
      isA<FilesDownloadFailed>().having(
        (failed) => failed.error.statusCode,
        'status',
        403,
      ),
    );
    expect(getsOf(4), 1);
    expect(File(savePath(4)).existsSync(), isFalse);
  });

  test('503 повторяется, пока сервер не оживёт', () async {
    server.statusFor = (served) =>
        served.path == '/seg2.ts' && served.number <= 2 ? 503 : null;

    final (result, _) = await run(request());

    expect(result, isA<FilesDownloadCompleted>());
    expect(getsOf(2), 3);
    expectSegments();
  });

  test('обрыв посреди сегмента — сегмент качается заново целиком', () async {
    server.cutAfter = (served) =>
        served.path == '/seg1.ts' && served.number == 1 ? 10 * 1000 : null;

    final (result, _) = await run(request());

    expect(result, isA<FilesDownloadCompleted>());
    expect(getsOf(1), 2);
    expectSegments();
  });

  test('отмена удаляет сегменты', () async {
    server.chunkDelay = const Duration(milliseconds: 15);

    final (result, _) = await run(
      request(),
      onProgress: (engine, progress) {
        if (progress.downloadedBytes > total ~/ 3) engine.stop(discard: true);
      },
    );

    expect(
      result,
      isA<FilesDownloadStopped>().having(
        (stopped) => stopped.discarded,
        'discarded',
        isTrue,
      ),
    );
    expect(Directory(p.join(root.path, 'out')).listSync(), isEmpty);
  });

  test(
    'места под ожидаемый размер не хватает — загрузка не начинается',
    () async {
      final (result, _) = await run(
        request(expectedBytes: 50 * 1000 * 1000),
        diskSpace: const _DiskSpace(10 * 1000 * 1000),
      );

      expect(
        result,
        isA<FilesDownloadFailed>().having(
          (failed) => failed.error.type,
          'type',
          FilesDownloadErrorType.diskFull,
        ),
      );
      expect(server.requests, isEmpty);
    },
  );

  test('сегменты качаются в отдельном изоляте', () async {
    final download = await FilesDownloader().startSegments(request());
    final result = await download.result;

    expect(result, isA<FilesDownloadCompleted>());
    expect(download.lastProgress!.downloadedBytes, total);
    expectSegments();
  });

  test('ожидаемый размер виден, пока сегментов готово мало', () async {
    final expected = total + 12345;
    final (_, progress) = await run(request(expectedBytes: expected));

    expect(progress.first.totalBytes, expected);
    expect(progress.last.totalBytes, total);
    expect(
      Uint8List.fromList(File(savePath(0)).readAsBytesSync()),
      segments[0],
    );
  });
}
