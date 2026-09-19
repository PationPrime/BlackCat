import 'dart:io';

import 'package:files_downloader/files_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/data_sources/data_sources.dart';

import '../../support/slice_state.dart';

void main() {
  late Directory root;
  const dataSource = LocalDownloadStateDataSourceImpl();

  final video = [for (var i = 0; i < 2500; i++) i % 251];
  final audio = [for (var i = 0; i < 700; i++) i % 13];

  setUp(
    () async => root = await Directory.systemTemp.createTemp('download-state'),
  );
  tearDown(() => root.delete(recursive: true));

  void writeState() => writeSlicedDownload(
    workDirectory: root.path,
    downloadId: 'task-1',
    sliceSize: 1000,
    files: [
      (name: 'video-137-2500.part', content: video, counters: [1000, 300, 500]),
      (name: 'audio-140-700.part', content: audio, counters: [700]),
    ],
  );

  test('скачанные байты берутся из state загрузки, без state — null', () async {
    expect(
      await dataSource.downloadedBytes(
        workDirectory: root.path,
        downloadId: 'task-1',
      ),
      isNull,
    );

    writeState();

    expect(
      await dataSource.downloadedBytes(
        workDirectory: root.path,
        downloadId: 'task-1',
      ),
      {'video-137-2500.part': 1800, 'audio-140-700.part': 700},
    );
  });

  test(
    'скачанное из state считается только в пределах файлов на диске',
    () async {
      writeState();
      File(p.join(root.path, 'video-137-2500.part')).deleteSync();
      File(
          p.join(root.path, 'audio-140-700.part'),
        ).openSync(mode: FileMode.append)
        ..truncateSync(300)
        ..closeSync();

      expect(
        await dataSource.downloadedBytes(
          workDirectory: root.path,
          downloadId: 'task-1',
        ),
        {'video-137-2500.part': 0, 'audio-140-700.part': 300},
      );
    },
  );

  test(
    'укороченный файл не дополняется нулями при переходе на yt-dlp',
    () async {
      writeState();
      File(
          p.join(root.path, 'video-137-2500.part'),
        ).openSync(mode: FileMode.append)
        ..truncateSync(1100)
        ..closeSync();

      await dataSource.toSequentialParts(
        workDirectory: root.path,
        downloadId: 'task-1',
      );

      expect(
        File(p.join(root.path, 'video-137-2500.part')).readAsBytesSync(),
        video.sublist(0, 1100),
      );
    },
  );

  test(
    'для yt-dlp слайсы превращаются в непрерывное начало файла, state удаляется',
    () async {
      writeState();

      await dataSource.toSequentialParts(
        workDirectory: root.path,
        downloadId: 'task-1',
      );

      expect(
        File(p.join(root.path, 'video-137-2500.part')).readAsBytesSync(),
        video.sublist(0, 1300),
      );
      expect(
        File(p.join(root.path, 'audio-140-700.part')).readAsBytesSync(),
        audio,
      );
      expect(await FilesDownloader.readState(root.path, 'task-1'), isNull);
      expect(
        File(FilesDownloader.statePath(root.path, 'task-1')).existsSync(),
        isFalse,
      );

      /// Nothing to convert the second time
      await dataSource.toSequentialParts(
        workDirectory: root.path,
        downloadId: 'task-1',
      );

      expect(File(p.join(root.path, 'video-137-2500.part')).lengthSync(), 1300);
    },
  );

  test(
    'повреждённый state: файлам потоков нельзя верить, они удаляются',
    () async {
      writeState();
      File(p.join(root.path, 'notes.txt')).writeAsStringSync('keep');
      File(
        FilesDownloader.statePath(root.path, 'task-1'),
      ).writeAsStringSync('broken');

      await dataSource.toSequentialParts(
        workDirectory: root.path,
        downloadId: 'task-1',
      );

      expect(root.listSync().map((entity) => p.basename(entity.path)), [
        'notes.txt',
      ]);
    },
  );
}
