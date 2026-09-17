import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/constants/constants.dart';
import 'package:youtube_downloader/src/app/data_sources/data_sources.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/storage/database/database.dart';
import 'package:youtube_downloader/src/app/storage/database/providers/providers.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

import '../../support/slice_state.dart';

class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);
}

/// Thumbnail server stand-in: returns fixed bytes and remembers requested links
class _FakeRemoteThumbnailDataSource implements RemoteThumbnailDataSource {
  final requestedUrls = <String>[];

  @override
  Future<Uint8List> getThumbnail(String url) async {
    requestedUrls.add(url);

    return Uint8List.fromList([1, 2, 3]);
  }
}

const _streams = [
  DownloadStreamModel(role: DownloadStreamRole.video, itag: 160, contentLength: 3000),
  DownloadStreamModel(role: DownloadStreamRole.audio, itag: 140, contentLength: 1000),
];

DownloadTaskModel _task(
  String id, {
  DownloadTaskStatus status = DownloadTaskStatus.paused,
  DownloadTaskSection section = DownloadTaskSection.active,
  int downloadedBytes = 0,
  List<DownloadStreamModel> streams = _streams,
  String? thumbnail,
}) => DownloadTaskModel(
  id: id,
  video: VideoInfoModel(
    id: 'video-$id',
    title: 'Видео $id',
    url: 'https://youtu.be/video-$id',
    qualities: const [],
    thumbnail: thumbnail,
  ),
  quality: const QualityModel(id: '144', kind: QualityKind.video, label: '144p', resolution: 144),
  status: status,
  section: section,
  streams: streams,
  downloadedBytes: downloadedBytes,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  late Directory root;
  late AppDatabase database;
  late FileSystemService fileSystemService;
  late DownloadQueueRepository repository;
  late _FakeRemoteThumbnailDataSource thumbnailDataSource;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('download-queue');
    database = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    fileSystemService = _TestFileSystemService(root);
    thumbnailDataSource = _FakeRemoteThumbnailDataSource();
    repository = DownloadQueueRepository(
      downloadTaskTableProvider: DownloadTaskTableProvider(databaseInstance: database),
      remoteThumbnailDataSource: thumbnailDataSource,
      localDownloadStateDataSource: const LocalDownloadStateDataSourceImpl(),
      fileSystemService: fileSystemService,
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  Future<void> writePart(String taskId, DownloadStreamModel stream, int length) async {
    final directory = await fileSystemService.downloadWorkDirectory(taskId);

    await File(DownloadPartFiles.path(directory.path, stream)).writeAsBytes(List.filled(length, 7));
  }

  test('restoreTasks берёт скачанные байты из длины недокачанных файлов', () async {
    /// Progress in the database lagged behind: the app was closed between saves
    await repository.saveTasks([_task('a', status: DownloadTaskStatus.downloading, downloadedBytes: 100)]);
    await writePart('a', _streams.first, 1200);
    await writePart('a', _streams.last, 1000);

    final tasks = (await repository.restoreTasks()).requireData;

    expect(tasks.single.downloadedBytes, 2200);
    expect(tasks.single.totalBytes, 4000);
    expect(tasks.single.percent, 55);
    expect(tasks.single.status, DownloadTaskStatus.downloading);
  });

  test('restoreTasks берёт скачанные байты слайсов из state встроенного загрузчика, а не из длины файлов', () async {
    await repository.saveTasks([_task('a', status: DownloadTaskStatus.downloading, downloadedBytes: 100)]);

    final directory = await fileSystemService.downloadWorkDirectory('a');

    writeSlicedDownload(
      workDirectory: directory.path,
      downloadId: 'a',
      sliceSize: 1000,
      files: [
        (
          name: DownloadPartFiles.fileName(_streams.first),
          content: List.filled(3000, 5),
          counters: [1000, 0, 400],
        ),
        (
          name: DownloadPartFiles.fileName(_streams.last),
          content: List.filled(1000, 6),
          counters: [250],
        ),
      ],
    );

    final task = (await repository.restoreTasks()).requireData.single;

    /// The files are of the full size, but only the slices count
    expect(task.downloadedBytes, 1650);
    expect(task.totalBytes, 4000);

    /// A deleted stream file does not keep its old progress
    await File(DownloadPartFiles.path(directory.path, _streams.first)).delete();

    expect((await repository.restoreTasks()).requireData.single.downloadedBytes, 250);
  });

  test('restoreTasks не засчитывает файл длиннее потока', () async {
    await repository.saveTasks([_task('a')]);
    await writePart('a', _streams.last, 5000);

    expect((await repository.restoreTasks()).requireData.single.downloadedBytes, 0);
  });

  test('restoreTasks стирает рабочие папки загрузок, которых нет в очереди, и готовых', () async {
    await repository.saveTasks([
      _task('paused', downloadedBytes: 1),
      _task('done', status: DownloadTaskStatus.done, section: DownloadTaskSection.finished, downloadedBytes: 4000),
    ]);
    await writePart('paused', _streams.first, 10);
    await writePart('done', _streams.first, 10);
    await writePart('orphan', _streams.first, 10);

    final result = await repository.restoreTasks();

    expect(result.failure, isNull);

    final workRoot = Directory(p.join(root.path, StorageConstants.downloadWorkFolder));
    final left = [await for (final entity in workRoot.list()) p.basename(entity.path)];

    expect(left, ['paused']);
    expect(result.requireData.firstWhere((task) => task.id == 'done').downloadedBytes, 4000);
  });

  test('removeTasks удаляет загрузку из базы вместе с недокачанными файлами', () async {
    await repository.saveTasks([_task('a'), _task('b', section: DownloadTaskSection.queue)]);
    await writePart('a', _streams.first, 10);

    await repository.removeTasks(['a']);

    final tasks = (await repository.restoreTasks()).requireData;

    expect([for (final task in tasks) task.id], ['b']);
    expect(await Directory(p.join(root.path, StorageConstants.downloadWorkFolder, 'a')).exists(), isFalse);
  });

  test('saveThumbnail сохраняет копию превью в папку приложения с расширением из ссылки', () async {
    final task = _task('a', thumbnail: 'https://i.ytimg.com/vi_webp/video-a/maxresdefault.webp?v=1');

    final path = (await repository.saveThumbnail(task)).requireData;

    expect(path, p.join(root.path, StorageConstants.thumbnailsFolder, 'a.webp'));
    expect(await File(path).readAsBytes(), [1, 2, 3]);
    expect(thumbnailDataSource.requestedUrls, [task.video.thumbnail]);
  });

  test('saveThumbnail без превью у видео ничего не скачивает', () async {
    expect((await repository.saveThumbnail(_task('a'))).data, isNull);
    expect(thumbnailDataSource.requestedUrls, isEmpty);
  });

  test('скачанное видео хранит размер, время завершения и путь к превью', () async {
    final completedAt = DateTime(2026, 9, 16, 14, 5);

    await repository.saveTasks([
      _task('a', status: DownloadTaskStatus.done, section: DownloadTaskSection.finished).copyWith(
        filePath: r'C:\Downloads\a.mp4',
        fileSizeBytes: 70000000,
        thumbnailPath: r'C:\Thumbnails\a.jpg',
        completedAt: completedAt,
      ),
    ]);

    final task = (await repository.restoreTasks()).requireData.single;

    expect(task.fileSizeBytes, 70000000);
    expect(task.thumbnailPath, r'C:\Thumbnails\a.jpg');
    expect(task.completedAt, completedAt);
  });

  test('removeTasks удаляет копию превью, restoreTasks — превью загрузок, которых нет', () async {
    await repository.saveTasks([
      _task('kept', thumbnail: 'https://i.ytimg.com/vi/kept/hq.jpg'),
      _task('removed', section: DownloadTaskSection.queue, thumbnail: 'https://i.ytimg.com/vi/removed/hq.jpg'),
    ]);

    final keptPath = (await repository.saveThumbnail(_task('kept', thumbnail: 'https://i.ytimg.com/vi/kept/hq.jpg'))).requireData;
    final removedPath = (await repository.saveThumbnail(_task('removed', thumbnail: 'https://i.ytimg.com/vi/removed/hq.jpg'))).requireData;
    final orphanPath = await fileSystemService.thumbnailPath('orphan', extension: 'jpg');

    await fileSystemService.writeFile(orphanPath, [9]);
    await repository.removeTasks(['removed']);

    expect(await File(removedPath).exists(), isFalse);

    await repository.restoreTasks();

    expect(await File(keptPath).exists(), isTrue);
    expect(await File(orphanPath).exists(), isFalse);
  });
}