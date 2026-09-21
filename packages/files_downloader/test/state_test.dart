import 'dart:io';

import 'package:files_downloader/files_downloader.dart';
import 'package:files_downloader/src/state/download_state_file.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('fds-state'));
  tearDown(() => root.delete(recursive: true));

  const entries = [
    StateFileEntry(
      identity: 'video-137-250',
      length: 250,
      acceptsRanges: true,
      validator: '"abc"',
    ),
    StateFileEntry(identity: 'audio', length: 100, acceptsRanges: true),
    StateFileEntry(identity: 'stream', length: null, acceptsRanges: false),
  ];

  test(
    'один state на все файлы загрузки: создаётся, правится на месте и читается обратно',
    () {
      final path = p.join(root.path, DownloadStateFile.fileName('task 1/2'));

      expect(p.basename(path), 'state_task_1_2.fds');

      final state = DownloadStateFile.createSync(
        path,
        sliceSize: 100,
        entries: entries,
        counters: [
          [100, 30],
        ],
      );

      expect([for (var i = 0; i < 3; i++) state.sliceCount(i)], [3, 1, 1]);
      expect(state.sliceRange(0, 2), const ByteRange(200, 249));
      expect(state.sliceRange(2, 0), isNull);
      expect(state.counters(0), [100, 30, 0]);

      state
        ..setCounter(0, 2, 50)
        ..setCounter(1, 0, 70)
        ..closeSync();

      final lengthBefore = File(path).lengthSync();
      final reopened = DownloadStateFile.readSync(path)!;

      expect(File(path).lengthSync(), lengthBefore);
      expect(reopened.entries.map((entry) => entry.identity), [
        'video-137-250',
        'audio',
        'stream',
      ]);
      expect(reopened.entries.first.validator, '"abc"');
      expect(reopened.entries[1].validator, isNull);
      expect(reopened.entries[2].length, isNull);
      expect(reopened.counters(0), [100, 30, 50]);
      expect(reopened.isSliceComplete(0, 0), isTrue);
      expect(reopened.isSliceComplete(0, 2), isTrue);
      expect(reopened.counters(1), [70]);

      final snapshot = reopened.snapshot();

      expect(snapshot.downloadedBytes, 250);
      expect(snapshot.totalBytes, isNull);
      expect(snapshot.fileByIdentity('video-137-250')!.contiguousBytes, 130);
      expect(snapshot.fileByIdentity('audio')!.contiguousBytes, 70);
      expect(snapshot.fileByIdentity('audio')!.isComplete, isFalse);
    },
  );

  test(
    'счётчик не выходит за пределы своего слайса, даже если записан с ошибкой',
    () {
      final path = p.join(root.path, 'state_x.fds');
      final state = DownloadStateFile.createSync(
        path,
        sliceSize: 100,
        entries: entries,
      );

      state
        ..setCounter(0, 2, 999)
        ..setCounter(0, 1, -5)
        ..closeSync();

      expect(DownloadStateFile.readSync(path)!.counters(0), [0, 0, 50]);

      /// A torn write leaves garbage in the first of the five counters
      final raw = File(path).readAsBytesSync();

      raw.setAll(raw.length - 5 * 8, List.filled(8, 0x7f));
      File(path).writeAsBytesSync(raw);

      expect(DownloadStateFile.readSync(path)!.counters(0), [100, 0, 50]);
    },
  );

  test('повреждённый или чужой файл не считается state', () {
    final path = p.join(root.path, 'state_x.fds');

    DownloadStateFile.createSync(path, sliceSize: 100, entries: entries);

    final raw = File(path).readAsBytesSync();

    /// A changed identity byte breaks the header checksum
    raw[45] ^= 0xff;
    File(path).writeAsBytesSync(raw);

    expect(DownloadStateFile.readSync(path), isNull);

    File(path).writeAsStringSync('not a state');
    expect(DownloadStateFile.readSync(path), isNull);

    File(path).writeAsBytesSync(raw.sublist(0, 20));
    expect(DownloadStateFile.readSync(path), isNull);
    expect(
      DownloadStateFile.readSync(p.join(root.path, 'missing.fds')),
      isNull,
    );
  });

  test('ContentRange разбирается, неверные заголовки отбрасываются', () {
    expect(
      ContentRange.parse('bytes 0-99/1000'),
      isA<ContentRange>()
          .having((range) => range.start, 'start', 0)
          .having((range) => range.end, 'end', 99)
          .having((range) => range.total, 'total', 1000),
    );
    expect(ContentRange.parse('Bytes  5 - 9 / *')!.total, isNull);
    expect(ContentRange.parse('bytes 9-5/100'), isNull);
    expect(ContentRange.parse('bytes */100'), isNull);
    expect(ContentRange.parse('items 0-1/2'), isNull);
    expect(ContentRange.parse(null), isNull);
    expect(ContentRange.unsatisfiedTotal('bytes */1234'), 1234);
    expect(ContentRange.unsatisfiedTotal('bytes 0-1/2'), isNull);
  });

  test('скачанное считается только в пределах файла на диске', () {
    const file = FileStateSnapshot(
      identity: 'video',
      length: 250,
      acceptsRanges: true,
      validator: null,
      sliceCounters: [100, 30, 50],
      sliceSize: 100,
    );

    expect(file.downloadedBytesWithin(250), 180);
    expect(file.downloadedBytesWithin(300), 180);
    expect(file.downloadedBytesWithin(0), 0);
    expect(file.downloadedBytesWithin(120), 120);
    expect(file.downloadedBytesWithin(210), 140);
  });

  test('SliceLayout: слайсы и счётчики для файла, скачанного по порядку', () {
    const layout = SliceLayout(fileLength: 250, sliceSize: 100);

    expect(layout.sliceCount, 3);
    expect(layout.slice(2), const ByteRange(200, 249));
    expect(layout.prefixCounters(0), [0, 0, 0]);
    expect(layout.prefixCounters(130), [100, 30, 0]);
    expect(layout.prefixCounters(250), [100, 100, 50]);
    expect(layout.prefixCounters(999), [100, 100, 50]);
    expect(const SliceLayout(fileLength: 0, sliceSize: 100).sliceCount, 0);
  });
}
