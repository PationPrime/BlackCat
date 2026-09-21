import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:files_downloader/files_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/test_file_server.dart';

const _sliceSize = 100 * 1000;

const _options = FilesDownloadOptions(
  sliceSize: _sliceSize,
  maxConnections: 4,
  maxRetries: 4,
  retryBaseDelay: Duration(milliseconds: 5),
  idleTimeout: Duration(seconds: 3),
  progressInterval: Duration(milliseconds: 20),
  checkpointInterval: Duration(milliseconds: 20),
);

final class _Run {
  final FilesDownloadResult result;
  final List<FilesDownloadProgress> progress;

  const _Run(this.result, this.progress);
}

/// Free space a test decides
final class _DiskSpace implements DiskSpace {
  final int? Function(String path) _available;

  const _DiskSpace(this._available);

  @override
  int? availableBytes(String path) => _available(path);
}

void main() {
  late Directory root;
  late String stateDirectory;
  late TestFileServer server;

  final video = testContent(1000 * 1000 + 3);
  final audio = testContent(250 * 1000 + 7, seed: 3);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fds-engine');
    stateDirectory = p.join(root.path, 'state');
    server = TestFileServer()
      ..files['/video'] = video
      ..files['/audio'] = audio;
    await server.start();
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  String savePath(String name) => p.join(root.path, 'out', name);

  FilesDownloadRequest request({
    List<String> paths = const ['/video', '/audio'],
    FilesDownloadOptions options = _options,
    RangeRequestMode rangeMode = RangeRequestMode.header,
    int? Function(String path)? expectedLength,
    bool checkValidator = true,
  }) => FilesDownloadRequest(
    id: 'task-1',
    stateDirectory: stateDirectory,
    options: options,
    files: [
      for (final path in paths)
        DownloadFileRequest(
          url: server.url(path),
          savePath: savePath(p.basename(path)),
          rangeMode: rangeMode,
          expectedLength: expectedLength?.call(path),
          fingerprint: path,
          checkValidator: checkValidator,
        ),
    ],
  );

  Future<_Run> run(
    FilesDownloadRequest request, {
    DiskSpace diskSpace = const SystemDiskSpace(),
    void Function(DownloadEngine engine, FilesDownloadProgress progress)?
    onProgress,
  }) async {
    final progress = <FilesDownloadProgress>[];
    final client = DownloadApiClient(request.options);
    late final DownloadEngine engine;

    engine = DownloadEngine(
      request: request,
      client: client,
      onProgress: (value) {
        progress.add(value);
        onProgress?.call(engine, value);
      },
      diskSpace: diskSpace,
    );

    try {
      return _Run(await engine.run(), progress);
    } finally {
      client.close();
    }
  }

  File stateFile() => File(FilesDownloader.statePath(stateDirectory, 'task-1'));

  void expectFile(String name, Uint8List content) =>
      expect(File(savePath(name)).readAsBytesSync(), content, reason: name);

  test(
    'файлы качаются слайсами параллельно по Range в один state, в конце state удаляется',
    () async {
      server.chunkDelay = const Duration(milliseconds: 1);

      final states = <int>[];
      final outcome = await run(
        request(),
        onProgress: (_, progress) {
          if (progress.stage == FilesDownloadStage.downloading &&
              stateFile().existsSync()) {
            states.add(stateFile().lengthSync());
          }
        },
      );

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expect(
        (outcome.result as FilesDownloadCompleted).files.map((f) => f.length),
        [video.length, audio.length],
      );
      expectFile('video', video);
      expectFile('audio', audio);

      /// One probe and one request per slice: 11 + 3 slices
      expect(server.gets('/video'), hasLength(1 + 11));
      expect(server.gets('/audio'), hasLength(1 + 3));
      expect(
        server.gets('/video').skip(1).map((request) => request.rangeHeader),
        contains('bytes=500000-599999'),
      );
      expect(server.maxActive, inInclusiveRange(2, 4));

      /// One state file for both files, and it is gone at the end
      expect(states, isNotEmpty);
      expect(
        Directory(stateDirectory).listSync().map((e) => p.basename(e.path)),
        isEmpty,
      );

      final last = outcome.progress.last;

      expect(last.stage, FilesDownloadStage.finishing);
      expect(last.downloadedBytes, video.length + audio.length);
      expect(last.totalBytes, video.length + audio.length);
      expect(last.fraction, 1);
      expect(last.files.first.completedSlices, 11);
    },
  );

  test(
    'пауза сохраняет прогресс слайсов, продолжение качает только недостающее',
    () async {
      server.chunkDelay = const Duration(milliseconds: 4);

      final first = await run(
        request(),
        onProgress: (engine, progress) {
          if (progress.downloadedBytes > 400 * 1000) engine.stop();
        },
      );

      expect(first.result, isA<FilesDownloadStopped>());

      final stopped = first.result as FilesDownloadStopped;
      final saved = (await FilesDownloader.readState(
        stateDirectory,
        'task-1',
      ))!;

      expect(stopped.discarded, isFalse);
      expect(saved.downloadedBytes, stopped.downloadedBytes);
      expect(saved.downloadedBytes, greaterThan(400 * 1000));
      expect(saved.totalBytes, video.length + audio.length);

      /// Saved slices are really on disk
      final videoState = saved.fileByIdentity('/video')!;
      final onDisk = File(savePath('video')).readAsBytesSync();

      for (var slice = 0; slice < videoState.sliceCounters.length; slice++) {
        final start = slice * _sliceSize;
        final count = videoState.sliceCounters[slice];

        expect(
          onDisk.sublist(start, start + count),
          video.sublist(start, start + count),
          reason: 'slice $slice',
        );
      }

      server.chunkDelay = Duration.zero;
      await server.idle();
      server.servedBytes = 0;

      final firstProgress = <int>[];
      final second = await run(
        request(),
        onProgress: (_, progress) =>
            firstProgress.add(progress.downloadedBytes),
      );

      expect(second.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expectFile('audio', audio);

      /// Progress starts from the saved bytes, and only the rest was sent
      expect(firstProgress.first, saved.downloadedBytes);
      expect(
        server.servedBytes,
        lessThanOrEqualTo(
          video.length + audio.length - saved.downloadedBytes + 2,
        ),
      );

      final resumed = server.gets('/video').where((r) => r.number > 1).toList();

      expect(
        resumed.map((request) => request.askedStart),
        containsAll([
          for (var slice = 0; slice < videoState.sliceCounters.length; slice++)
            if (videoState.sliceCounters[slice] > 0 &&
                videoState.sliceCounters[slice] < _sliceSize)
              slice * _sliceSize + videoState.sliceCounters[slice],
        ]),
      );
    },
  );

  test(
    'state есть, а файла с данными нет или он короче — качается только то, чего нет на диске',
    () async {
      server.chunkDelay = const Duration(milliseconds: 4);

      final first = await run(
        request(paths: ['/audio', '/video']),
        onProgress: (engine, progress) {
          if (progress.downloadedBytes > 400 * 1000) engine.stop();
        },
      );

      expect(first.result, isA<FilesDownloadStopped>());

      final saved = (await FilesDownloader.readState(
        stateDirectory,
        'task-1',
      ))!;
      final savedAudio = saved.fileByIdentity('/audio')!;

      expect(saved.fileByIdentity('/video')!.downloadedBytes, greaterThan(0));

      /// The video file is gone, the audio file lost its tail
      File(savePath('video')).deleteSync();
      File(savePath('audio')).openSync(mode: FileMode.append)
        ..truncateSync(120 * 1000)
        ..closeSync();

      final keptAudio = savedAudio.downloadedBytesWithin(120 * 1000);

      server.chunkDelay = Duration.zero;
      await server.idle();
      server.servedBytes = 0;

      final second = await run(request(paths: ['/audio', '/video']));

      expect(second.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expectFile('audio', audio);

      /// Old progress of the lost bytes is never shown
      expect(second.progress.first.downloadedBytes, keptAudio);
      expect(second.progress.first.files.last.downloadedBytes, 0);
      expect(
        second.progress.map((progress) => progress.downloadedBytes),
        everyElement(greaterThanOrEqualTo(keptAudio)),
      );

      /// The whole video and the lost audio bytes, plus two probe bytes
      expect(server.servedBytes, video.length + audio.length - keptAudio + 2);
      expect(
        server
            .gets('/video')
            .skip(1)
            .map((request) => request.askedStart! % _sliceSize),
        everyElement(0),
      );
    },
  );

  test(
    'сервер начинает часть раньше и заканчивает позже слайса и даже файла — лишнее отбрасывается',
    () async {
      server.bendRange = (served, start, end, total) {
        if (served.number == 1) return null;

        final earlier = (start - 1234).clamp(0, total - 1);

        return (
          start: earlier,
          end: total - 1,
          contentRange: 'bytes $earlier-${total + 5000}/$total',
        );
      };

      final outcome = await run(request(paths: ['/video']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expect(server.gets('/video'), hasLength(1 + 11));
    },
  );

  test(
    'сервер начинает часть позже запрошенного — попытка повторяется, файл цел',
    () async {
      final bent = <int>{};

      server.bendRange = (served, start, end, total) {
        if (served.number == 1 || !bent.add(start)) return null;

        return (
          start: start + 10,
          end: end,
          contentRange: 'bytes ${start + 10}-$end/$total',
        );
      };

      final outcome = await run(request(paths: ['/video']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expect(server.gets('/video'), hasLength(1 + 11 * 2));
    },
  );

  test(
    'сервер отдаёт меньше запрошенного — остаток слайса докачивается следующими запросами',
    () async {
      server.bendRange = (served, start, end, total) {
        final shorter = (start + 30 * 1000 - 1).clamp(start, end);

        return (
          start: start,
          end: shorter,
          contentRange: 'bytes $start-$shorter/$total',
        );
      };

      final outcome = await run(request(paths: ['/audio']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('audio', audio);
      expect(
        server.gets('/audio').skip(1).map((request) => request.rangeHeader),
        containsAll([
          'bytes=30000-99999',
          'bytes=60000-99999',
          'bytes=90000-99999',
        ]),
      );
    },
  );

  test(
    'обрыв соединения посреди слайса — повтор продолжает с места обрыва',
    () async {
      server.cutAfter = (served) =>
          served.number > 1 && served.number <= 4 ? 50 * 1000 : null;

      final outcome = await run(request(paths: ['/video']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);

      final gets = server.gets('/video');
      final cutStarts = [
        for (final request in gets)
          if (request.number > 1 && request.number <= 4) request.askedStart!,
      ];

      /// Each broken slice continues after the bytes it got, not from its start
      for (final start in cutStarts) {
        expect(
          gets.where(
            (request) =>
                request.number > 4 &&
                request.askedStart! > start &&
                request.askedStart! <= start + 50 * 1000,
          ),
          hasLength(1),
          reason: 'slice from $start',
        );
      }
    },
  );

  test(
    'сервер без поддержки Range: файл качается целиком одним запросом',
    () async {
      server.acceptRanges = false;

      final outcome = await run(request(paths: ['/video']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expect(server.gets('/video'), hasLength(2));
      expect(server.gets('/video').last.rangeHeader, isNull);
      expect(stateFile().existsSync(), isFalse);
    },
  );

  test('обрыв при скачивании без Range начинает файл заново', () async {
    server
      ..acceptRanges = false
      ..cutAfter = (served) => served.number == 2 ? 300 * 1000 : null;

    final outcome = await run(request(paths: ['/video']));

    expect(outcome.result, isA<FilesDownloadCompleted>());
    expectFile('video', video);
    expect(server.gets('/video'), hasLength(3));
  });

  test(
    'сервер вдруг игнорирует Range и шлёт весь файл — нужные байты вырезаются из него',
    () async {
      server.ignoreRange = (served) =>
          served.number > 1 && served.number.isEven;

      final outcome = await run(request(paths: ['/video']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
    },
  );

  test(
    'диапазон параметром range=, как у googlevideo: Range-заголовков нет',
    () async {
      server.queryRanges = true;

      final outcome = await run(
        request(
          rangeMode: RangeRequestMode.queryParameter,
          checkValidator: false,
        ),
      );

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expectFile('audio', audio);

      final gets = server.gets('/video');

      expect(gets, hasLength(11));
      expect(gets.every((request) => request.rangeHeader == null), isTrue);
      expect(
        gets.map((request) => request.rangeParameter),
        contains('900000-999999'),
      );
      expect(
        server.requests.where((r) => r.method == 'HEAD').map((r) => r.path),
        containsAll(['/video', '/audio']),
      );
    },
  );

  test('без HEAD размер берётся из известного заранее', () async {
    server
      ..queryRanges = true
      ..supportHead = false;

    final outcome = await run(
      request(
        paths: ['/audio'],
        rangeMode: RangeRequestMode.queryParameter,
        expectedLength: (_) => audio.length,
      ),
    );

    expect(outcome.result, isA<FilesDownloadCompleted>());
    expectFile('audio', audio);
  });

  test(
    'размер неизвестен (без Content-Length и Range) — файл качается потоком',
    () async {
      server
        ..acceptRanges = false
        ..chunked = true;

      final outcome = await run(request(paths: ['/audio']));

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expect(
        (outcome.result as FilesDownloadCompleted).files.single.length,
        audio.length,
      );
      expectFile('audio', audio);
      expect(outcome.progress.last.totalBytes, isNull);
    },
  );

  test(
    '403 останавливает загрузку ошибкой без повторов, прогресс сохраняется',
    () async {
      server.statusFor = (served) => served.number > 4 ? 403 : null;

      final outcome = await run(
        request(
          paths: ['/video'],
          options: const FilesDownloadOptions(
            sliceSize: _sliceSize,
            maxConnections: 1,
            retryBaseDelay: Duration(milliseconds: 5),
          ),
        ),
      );

      expect(
        outcome.result,
        isA<FilesDownloadFailed>().having(
          (failed) => failed.error,
          'error',
          isA<FilesDownloadError>()
              .having((e) => e.type, 'type', FilesDownloadErrorType.httpStatus)
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.isRetryable, 'retryable', isFalse),
        ),
      );
      expect(server.gets('/video'), hasLength(5));

      final saved = (await FilesDownloader.readState(
        stateDirectory,
        'task-1',
      ))!;

      expect(saved.downloadedBytes, 3 * _sliceSize);
      expect(
        (outcome.result as FilesDownloadFailed).downloadedBytes,
        3 * _sliceSize,
      );
    },
  );

  test('ответы 503 повторяются, пока сервер не оживёт', () async {
    server.statusFor = (served) =>
        served.number > 1 && served.number <= 4 ? 503 : null;

    final outcome = await run(
      request(
        paths: ['/audio'],
        options: const FilesDownloadOptions(
          sliceSize: _sliceSize,
          maxConnections: 1,
          retryBaseDelay: Duration(milliseconds: 5),
        ),
      ),
    );

    expect(outcome.result, isA<FilesDownloadCompleted>());
    expectFile('audio', audio);
  });

  test(
    'файл на сервере поменялся после паузы — state сбрасывается, качается новый файл',
    () async {
      server
        ..etag = '"v1"'
        ..chunkDelay = const Duration(milliseconds: 4);

      final first = await run(
        request(paths: ['/video']),
        onProgress: (engine, progress) {
          if (progress.downloadedBytes > 300 * 1000) engine.stop();
        },
      );

      expect(first.result, isA<FilesDownloadStopped>());
      expect(server.gets('/video').last.ifRange, '"v1"');

      final changed = testContent(video.length, seed: 99);

      server
        ..etag = '"v2"'
        ..chunkDelay = Duration.zero
        ..files['/video'] = changed;

      final second = await run(request(paths: ['/video']));

      expect(second.result, isA<FilesDownloadCompleted>());
      expectFile('video', changed);
    },
  );

  test(
    'файл поменялся посреди загрузки (If-Range не сошёлся) — ошибка и state удалён',
    () async {
      server.etag = '"v1"';
      server.statusFor = (served) {
        if (served.number == 3) server.etag = '"v2"';

        return null;
      };

      final outcome = await run(
        request(
          paths: ['/video'],
          options: const FilesDownloadOptions(
            sliceSize: _sliceSize,
            maxConnections: 1,
          ),
        ),
      );

      expect(
        outcome.result,
        isA<FilesDownloadFailed>().having(
          (failed) => failed.error.type,
          'type',
          FilesDownloadErrorType.sourceChanged,
        ),
      );
      expect(stateFile().existsSync(), isFalse);
    },
  );

  test(
    'Content-Range с другим размером файла или 416 — ошибка sourceChanged',
    () async {
      server.bendRange = (served, start, end, total) => served.number == 1
          ? null
          : (
              start: start,
              end: end,
              contentRange: 'bytes $start-$end/${total + 1}',
            );

      final resized = await run(request(paths: ['/audio']));

      expect(
        (resized.result as FilesDownloadFailed).error.type,
        FilesDownloadErrorType.sourceChanged,
      );

      server
        ..bendRange = null
        ..files['/short'] = testContent(10);

      final shrunk = await run(
        request(
          paths: ['/short'],
          rangeMode: RangeRequestMode.queryParameter,
          expectedLength: (_) => 10,
        ),
      );

      expect(shrunk.result, isA<FilesDownloadCompleted>());

      server.files['/short'] = testContent(5);

      File(savePath('short')).deleteSync();

      final truncated = await run(
        FilesDownloadRequest(
          id: 'short',
          stateDirectory: stateDirectory,
          options: _options,
          files: [
            DownloadFileRequest(
              url: server.url('/short'),
              savePath: savePath('short'),
            ),
          ],
        ),
      );

      expect(truncated.result, isA<FilesDownloadCompleted>());
      expectFile('short', testContent(5));
    },
  );

  test(
    'continuePrefix: начало файла от другого загрузчика не качается заново',
    () async {
      final existing = File(savePath('video'))..createSync(recursive: true);

      existing.writeAsBytesSync(video.sublist(0, 250 * 1000 + 17));
      server.servedBytes = 0;

      final outcome = await run(
        request(
          paths: ['/video'],
          options: const FilesDownloadOptions(
            sliceSize: _sliceSize,
            existingFilePolicy: ExistingFilePolicy.continuePrefix,
          ),
        ),
      );

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);

      /// The rest and the probe byte
      expect(server.servedBytes, video.length - (250 * 1000 + 17) + 1);
      expect(
        outcome.progress
            .firstWhere((p) => p.stage == FilesDownloadStage.downloading)
            .downloadedBytes,
        250 * 1000 + 17,
      );

      /// A finished file of the full size is not downloaded at all
      final again = await run(
        request(
          paths: ['/video'],
          options: const FilesDownloadOptions(
            sliceSize: _sliceSize,
            existingFilePolicy: ExistingFilePolicy.continuePrefix,
          ),
        ),
      );

      /// Slices 2…10 of the first run and nothing more
      expect(again.result, isA<FilesDownloadCompleted>());
      expect(
        server.gets('/video').where((r) => r.rangeHeader != 'bytes=0-0'),
        hasLength(9),
      );
    },
  );

  test('replace: чужой файл на месте загрузки качается заново', () async {
    File(savePath('audio'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(Uint8List(audio.length + 500));

    final outcome = await run(request(paths: ['/audio']));

    expect(outcome.result, isA<FilesDownloadCompleted>());
    expectFile('audio', audio);
  });

  test('отмена удаляет файлы и state', () async {
    server.chunkDelay = const Duration(milliseconds: 4);

    final outcome = await run(
      request(),
      onProgress: (engine, progress) {
        if (progress.downloadedBytes > 100 * 1000) engine.stop(discard: true);
      },
    );

    expect(
      outcome.result,
      isA<FilesDownloadStopped>().having(
        (s) => s.discarded,
        'discarded',
        isTrue,
      ),
    );
    expect(File(savePath('video')).existsSync(), isFalse);
    expect(File(savePath('audio')).existsSync(), isFalse);
    expect(stateFile().existsSync(), isFalse);
  });

  test('ограничение скорости растягивает загрузку', () async {
    final stopwatch = Stopwatch()..start();
    final outcome = await run(
      request(
        paths: ['/audio'],
        options: const FilesDownloadOptions(
          sliceSize: _sliceSize,
          speedLimit: 100 * 1000,
        ),
      ),
    );

    expect(outcome.result, isA<FilesDownloadCompleted>());
    expectFile('audio', audio);

    /// A second of burst, then 150 KB at 100 KB/s
    expect(stopwatch.elapsed, greaterThan(const Duration(milliseconds: 1300)));
  });

  test(
    'проверка файла в конце не прошла — ошибка, а state закрыт и остаётся для докачки',
    () async {
      final outcome = await run(
        request(paths: ['/audio']),
        onProgress: (_, progress) {
          /// Something shortened the file right before the check
          if (progress.stage == FilesDownloadStage.finishing) {
            File(savePath('audio')).openSync(mode: FileMode.append)
              ..truncateSync(1000)
              ..closeSync();
          }
        },
      );

      expect(
        outcome.result,
        isA<FilesDownloadFailed>().having(
          (failed) => failed.error.type,
          'type',
          FilesDownloadErrorType.fileSystem,
        ),
      );

      /// Windows does not rename a file that is still open
      final moved = '${stateFile().path}.moved';

      stateFile().renameSync(moved);
      File(moved).renameSync(stateFile().path);
      expect(
        (await FilesDownloader.readState(
          stateDirectory,
          'task-1',
        ))!.downloadedBytes,
        audio.length,
      );

      final resumed = await run(request(paths: ['/audio']));

      expect(resumed.result, isA<FilesDownloadCompleted>());
      expectFile('audio', audio);
    },
    testOn: 'windows',
  );

  test(
    'сохранить прогресс при паузе не удалось — результат ошибка, а не пауза',
    () async {
      server.chunkDelay = const Duration(milliseconds: 4);

      RandomAccessFile? lock;

      final outcome = await run(
        request(),
        onProgress: (engine, progress) {
          if (lock == null && progress.downloadedBytes > 300 * 1000) {
            /// Another handle locks the state: its counters cannot be written
            lock = stateFile().openSync(mode: FileMode.append)
              ..lockSync(FileLock.exclusive);
            engine.stop();
          }
        },
      );

      lock!
        ..unlockSync()
        ..closeSync();

      expect(
        outcome.result,
        isA<FilesDownloadFailed>().having(
          (failed) => failed.error.type,
          'type',
          FilesDownloadErrorType.fileSystem,
        ),
      );

      /// The engine closed its handle even though the write failed
      stateFile().deleteSync();
    },
    testOn: 'windows',
  );

  test('поврежденный state не мешает: загрузка начинается заново', () async {
    stateFile()
      ..createSync(recursive: true)
      ..writeAsStringSync('garbage');

    final outcome = await run(request(paths: ['/audio']));

    expect(outcome.result, isA<FilesDownloadCompleted>());
    expectFile('audio', audio);
  });

  test('404 при запросе размера — ошибка сразу', () async {
    final outcome = await run(request(paths: ['/missing']));

    expect(
      outcome.result,
      isA<FilesDownloadFailed>().having(
        (f) => f.error.statusCode,
        'status',
        404,
      ),
    );
    expect(server.gets('/missing'), hasLength(1));
  });

  Matcher failedWith(Matcher error) => isA<FilesDownloadFailed>().having(
    (failed) => failed.error,
    'error',
    error,
  );

  TypeMatcher<FilesDownloadError> errorOf(FilesDownloadErrorType type) =>
      isA<FilesDownloadError>().having((error) => error.type, 'type', type);

  test(
    'места на диске не хватает — загрузка не начинается и файлы не резервируются, после освобождения места идёт',
    () async {
      int? free = 100 * 1000;
      final diskSpace = _DiskSpace((_) => free);

      final full = await run(request(), diskSpace: diskSpace);

      expect(
        full.result,
        failedWith(
          errorOf(FilesDownloadErrorType.diskFull)
              .having(
                (e) => e.neededBytes,
                'needed',
                video.length + audio.length,
              )
              .having((e) => e.availableBytes, 'available', 100 * 1000)
              .having((e) => e.path, 'path', savePath('video'))
              .having((e) => e.isRetryable, 'retryable', isFalse),
        ),
      );
      expect(File(savePath('video')).existsSync(), isFalse);
      expect(File(savePath('audio')).existsSync(), isFalse);

      /// Only the probes reached the server
      expect(server.gets('/video'), hasLength(1));
      expect(server.gets('/audio'), hasLength(1));
      expect(full.progress.last.downloadedBytes, 0);

      free = 1 << 40;

      final freed = await run(request(), diskSpace: diskSpace);

      expect(freed.result, isA<FilesDownloadCompleted>());
      expectFile('video', video);
      expectFile('audio', audio);
    },
  );

  test(
    'система не знает свободное место — загрузка идёт без проверки',
    () async {
      final outcome = await run(
        request(paths: ['/audio']),
        diskSpace: _DiskSpace((_) => null),
      );

      expect(outcome.result, isA<FilesDownloadCompleted>());
      expectFile('audio', audio);
    },
  );

  test(
    'продолжение: на Windows занятое файлом место уже выделено, на macOS и Linux нужны только недостающие байты',
    () async {
      server.chunkDelay = const Duration(milliseconds: 4);

      final first = await run(
        request(),
        onProgress: (engine, progress) {
          if (progress.downloadedBytes > 300 * 1000) engine.stop();
        },
      );

      expect(first.result, isA<FilesDownloadStopped>());

      final saved = (await FilesDownloader.readState(
        stateDirectory,
        'task-1',
      ))!;

      server.chunkDelay = Duration.zero;
      await server.idle();

      final resumed = await run(request(), diskSpace: _DiskSpace((_) => 0));

      if (Platform.isWindows) {
        expect(resumed.result, isA<FilesDownloadCompleted>());
        expectFile('video', video);
        expectFile('audio', audio);
      } else {
        expect(
          resumed.result,
          failedWith(
            errorOf(FilesDownloadErrorType.diskFull).having(
              (e) => e.neededBytes,
              'needed',
              video.length + audio.length - saved.downloadedBytes,
            ),
          ),
        );
      }
    },
  );

  test(
    'на месте файла папка — ошибка файловой системы результатом, место не при чём',
    () async {
      Directory(savePath('audio')).createSync(recursive: true);

      final outcome = await run(
        request(paths: ['/audio']),
        diskSpace: _DiskSpace((_) => 1 << 40),
      );

      expect(
        outcome.result,
        failedWith(errorOf(FilesDownloadErrorType.fileSystem)),
      );
      expect(outcome.progress.last.stage, FilesDownloadStage.preparing);
    },
  );

  test(
    'на Windows место под файл выделяется сразу: если его не хватило — diskFull, а не падение',
    () async {
      final free = const SystemDiskSpace().availableBytes(root.path)!;

      /// An NTFS file is at most 16 TiB
      if (free > 8 << 40) {
        markTestSkipped('The disk is too big for a file that does not fit');

        return;
      }

      final claimed = free + (1 << 30);

      /// The probe says the file is bigger than the free space
      server.bendRange = (served, start, end, total) => served.number == 1
          ? (start: 0, end: 0, contentRange: 'bytes 0-0/$claimed')
          : null;

      var checks = 0;

      final outcome = await run(
        request(paths: ['/video']),

        /// Before the start the system cannot tell: the space runs out
        /// on the reservation
        diskSpace: _DiskSpace(
          (path) => checks++ == 0
              ? null
              : const SystemDiskSpace().availableBytes(path),
        ),
      );

      expect(
        outcome.result,
        failedWith(
          errorOf(FilesDownloadErrorType.diskFull)
              .having((e) => e.neededBytes, 'needed', claimed)
              .having((e) => e.availableBytes, 'available', lessThan(claimed)),
        ),
      );
      expect(File(savePath('video')).lengthSync(), 0);
    },
    testOn: 'windows',
  );
}
