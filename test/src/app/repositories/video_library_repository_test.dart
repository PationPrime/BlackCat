import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/data_sources/data_sources.dart';
import 'package:black_cat/src/app/dto/dto.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/storage/database/database.dart';
import 'package:black_cat/src/app/storage/database/providers/providers.dart';

import '../../support/test_localization.dart';

/// App folders inside the test folder
final class _TempFileSystemService extends FileSystemServiceImpl {
  final String root;

  _TempFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root, 'app', name);
}

/// The system knows what the test tells it
final class _FakeVideoMetadataService implements VideoMetadataService {
  final durations = <String, Duration>{};
  final withThumbnail = <String>{};
  final requests = <(String, String?)>[];

  @override
  Future<VideoFileMetadataModel> read(
    String videoPath, {
    String? thumbnailPath,
  }) async {
    requests.add((p.basename(videoPath), thumbnailPath));

    final name = p.basename(videoPath);
    final hasThumbnail = thumbnailPath != null && withThumbnail.contains(name);

    if (hasThumbnail) {
      await File(thumbnailPath).create(recursive: true);
      await File(thumbnailPath).writeAsBytes([1, 2, 3]);
    }

    return VideoFileMetadataModel(
      duration: durations[name],
      hasThumbnail: hasThumbnail,
    );
  }
}

final class _Harness {
  final Directory root;
  final database = AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase.memory()),
  );
  final metadata = _FakeVideoMetadataService();

  late final libraryProvider = LibraryVideoTableProvider(
    databaseInstance: database,
  );
  late final downloadsProvider = DownloadTaskTableProvider(
    databaseInstance: database,
  );
  late final repository = VideoLibraryRepository(
    libraryVideoTableProvider: libraryProvider,
    downloadTaskTableProvider: downloadsProvider,
    localVideoLibraryDataSource: LocalVideoLibraryDataSourceImpl(
      fileSystemService: _TempFileSystemService(root.path),
    ),
    videoMetadataService: metadata,
    caseSensitivePaths: false,
  );

  _Harness(this.root);

  String get folder => p.join(root.path, 'Downloads');

  String get thumbnailsFolder => p.join(root.path, 'app', 'Library thumbnails');

  Future<File> addFile(
    String name, {
    int size = 100,
    required DateTime modified,
  }) async {
    final file = File(p.join(folder, name));

    await file.create(recursive: true);
    await file.writeAsBytes(List.filled(size, 7));
    await file.setLastModified(modified);

    return file;
  }

  Future<List<LibraryVideoModel>> sync() async {
    final response = await repository.syncVideos(folder);

    expect(response.failure, isNull);

    return response.requireData;
  }
}

void main() {
  setUpAll(loadTestTranslations);

  late _Harness harness;

  setUp(() async {
    harness = _Harness(await Directory.systemTemp.createTemp('video-library'));
  });

  tearDown(() async {
    await harness.database.close();
    await harness.root.delete(recursive: true);
  });

  test(
    'в библиотеку попадают только видео из самой папки, новые сверху; скачанное берёт название, длительность и превью загрузки',
    () async {
      await harness.addFile('a.mp4', modified: DateTime(2026, 9, 1, 10));
      await harness.addFile('b.MKV', modified: DateTime(2026, 9, 2, 10));
      await harness.addFile('notes.txt', modified: DateTime(2026, 9, 3));
      await harness.addFile(
        p.join('nested', 'c.mp4'),
        modified: DateTime(2026, 9, 3),
      );

      final downloadThumbnail = File(
        p.join(harness.root.path, 'app', 'Thumbnails', 'task-a.jpg'),
      );

      await downloadThumbnail.create(recursive: true);
      await downloadThumbnail.writeAsBytes([9, 9, 9]);
      await harness.downloadsProvider.saveTasks([
        DownloadTaskDto(
          id: 'task-a',
          videoId: 'video-a',
          videoUrl: 'https://www.youtube.com/watch?v=video-a',
          title: 'Обзор: часть 1',
          durationSeconds: 125,
          qualityId: '1080',
          qualityKind: QualityKind.video,
          status: DownloadTaskStatus.done,
          section: DownloadTaskSection.finished,

          /// Windows paths match whatever the letter case
          filePath: p.join(harness.folder, 'A.mp4'),
          thumbnailPath: downloadThumbnail.path,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      ]);

      final videos = await harness.sync();

      expect(
        [for (final video in videos) video.title],
        ['b', 'Обзор: часть 1'],
      );

      final [b, a] = videos;

      expect(a.duration, const Duration(seconds: 125));
      expect(a.isMetadataLoaded, isTrue);
      expect(p.dirname(a.thumbnailPath!), harness.thumbnailsFolder);
      expect(await File(a.thumbnailPath!).readAsBytes(), [9, 9, 9]);
      expect(b.duration, isNull);
      expect(b.thumbnailPath, isNull);
      expect(b.isMetadataLoaded, isFalse);
      expect(b.sizeBytes, 100);

      /// The download thumbnail goes away with the download, the copy stays
      await downloadThumbnail.delete();

      expect((await harness.sync()).last.thumbnailPath, a.thumbnailPath);
      expect(await File(a.thumbnailPath!).exists(), isTrue);
    },
  );

  test(
    'позиция просмотра переживает повторное чтение; пропавший файл удаляет запись и превью',
    () async {
      final fileA = await harness.addFile(
        'a.mp4',
        modified: DateTime(2026, 9, 1),
      );

      await harness.addFile('b.mp4', modified: DateTime(2026, 9, 2));
      harness.metadata.withThumbnail.add('a.mp4');

      final [_, a] = await harness.sync();
      final loaded = (await harness.repository.loadMetadata(a)).requireData;

      expect(loaded.thumbnailPath, isNotNull);
      expect(await File(loaded.thumbnailPath!).exists(), isTrue);

      await harness.repository.savePosition(
        a.copyWith(
          position: const Duration(minutes: 3, seconds: 25),
          duration: const Duration(minutes: 8),
        ),
      );

      final [_, again] = await harness.sync();

      expect(again.position, const Duration(minutes: 3, seconds: 25));
      expect(again.duration, const Duration(minutes: 8));
      expect(again.thumbnailPath, loaded.thumbnailPath);
      expect(again.watchedAt, isNotNull);

      await fileA.delete();

      final remaining = await harness.sync();

      expect(
        [for (final video in remaining) p.basename(video.path)],
        ['b.mp4'],
      );
      expect(
        [
          for (final video in await harness.libraryProvider.getVideos())
            p.basename(video.path),
        ],
        ['b.mp4'],
      );
      expect(await File(loaded.thumbnailPath!).exists(), isFalse);
    },
  );

  test(
    'заменённый файл читается заново: позиция сбрасывается, система спрашивается снова',
    () async {
      final file = await harness.addFile(
        'a.mp4',
        modified: DateTime(2026, 9, 1),
      );

      harness.metadata.durations['a.mp4'] = const Duration(minutes: 5);

      final [a] = await harness.sync();

      await harness.repository.loadMetadata(a);
      await harness.repository.savePosition(
        a.copyWith(position: const Duration(minutes: 2)),
      );

      final [same] = await harness.sync();

      expect(same.isMetadataLoaded, isTrue);
      expect(same.position, const Duration(minutes: 2));

      await file.writeAsBytes(List.filled(300, 1));
      await file.setLastModified(DateTime(2026, 9, 5));

      final [replaced] = await harness.sync();

      expect(replaced.id, a.id);
      expect(replaced.sizeBytes, 300);
      expect(replaced.position, Duration.zero);
      expect(replaced.duration, isNull);
      expect(replaced.isMetadataLoaded, isFalse);
    },
  );

  test(
    'метаданные: система спрашивается только о недостающем, а сохранённая позиция не затирается',
    () async {
      await harness.addFile('a.mp4', modified: DateTime(2026, 9, 1));
      harness.metadata.durations['a.mp4'] = const Duration(seconds: 42);

      final [a] = await harness.sync();

      await harness.repository.savePosition(
        a.copyWith(position: const Duration(seconds: 20)),
      );

      /// Metadata loading started before the position was saved
      final loaded = (await harness.repository.loadMetadata(a)).requireData;

      expect(loaded.duration, const Duration(seconds: 42));
      expect(loaded.thumbnailPath, isNull);
      expect(loaded.isMetadataLoaded, isTrue);
      expect(harness.metadata.requests.single.$2, isNotNull);

      final [stored] = await harness.sync();

      expect(stored.position, const Duration(seconds: 20));
      expect(stored.duration, const Duration(seconds: 42));
      expect(stored.isMetadataLoaded, isTrue);

      /// A video with a thumbnail asks only for the duration
      await harness.repository.loadMetadata(
        a.copyWith(thumbnailPath: p.join(harness.thumbnailsFolder, 'a.jpg')),
      );

      expect(harness.metadata.requests.last.$2, isNull);
    },
  );

  test(
    'пропавшая папка — ошибка, а библиотека остаётся: диск мог быть отключён',
    () async {
      await harness.addFile('a.mp4', modified: DateTime(2026, 9, 1));
      await harness.sync();
      await Directory(
        harness.folder,
      ).rename(p.join(harness.root.path, 'Moved'));

      final response = await harness.repository.syncVideos(harness.folder);

      expect(response.failure?.code, const PlayerErrorCodes().folderNotFound);
      expect(response.failure?.message, contains(harness.folder));
      expect(await harness.libraryProvider.getVideos(), hasLength(1));
    },
  );

  test('в Linux пути с разным регистром — разные видео', () async {
    final linuxRepository = VideoLibraryRepository(
      libraryVideoTableProvider: harness.libraryProvider,
      downloadTaskTableProvider: harness.downloadsProvider,
      localVideoLibraryDataSource: _NamesDataSource([
        '/videos/Clip.mp4',
        '/videos/clip.mp4',
      ]),
      videoMetadataService: harness.metadata,
      caseSensitivePaths: true,
    );

    final videos = (await linuxRepository.syncVideos('/videos')).requireData;

    expect({for (final video in videos) video.id}, hasLength(2));
  });
}

/// A folder with the given files, without the disk
final class _NamesDataSource implements LocalVideoLibraryDataSource {
  final List<String> paths;

  _NamesDataSource(this.paths);

  @override
  Future<bool> folderExists(String folder) async => true;

  @override
  Future<List<LocalVideoFileModel>> getVideoFiles(String folder) async => [
    for (final path in paths)
      LocalVideoFileModel(path: path, sizeBytes: 1, modifiedAt: DateTime(2026)),
  ];

  @override
  Stream<void> watchFolder(String folder) => const Stream.empty();

  @override
  Future<bool> fileExists(String path) async => false;

  @override
  Future<void> copyFile(String from, String to) async {}

  @override
  Future<String> thumbnailPath(
    String videoId, {
    required String version,
    required String extension,
  }) async => '/thumbnails/$videoId-$version.$extension';

  @override
  Future<void> deleteThumbnailsExcept(Set<String> keepPaths) async {}
}
