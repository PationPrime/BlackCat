import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/modules/player/controllers/controllers.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_localization.dart';

const _downloads = r'C:\Users\user\Downloads';
const _videos = r'D:\Videos';

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Harness {
  final repository = FakeVideoLibraryRepository();
  final settingsRepository = FakeSettingsRepository();
  late final settings = SettingsController(
    settingsRepository: settingsRepository,
  );
  late final controller = VideoLibraryController(
    videoLibraryRepository: repository,
    settingsController: settings,
    folderChangesDebounce: const Duration(milliseconds: 50),
  );

  VideoLibraryState get state => controller.state;

  List<String> get ids => [for (final video in state.videos) video.id];

  Future<void> start() async {
    await settings.loadSettings();
    await controller.load();
    await _settle();
  }

  Future<void> close() async {
    await controller.close();
    await settings.close();
  }
}

void main() {
  setUpAll(loadTestTranslations);

  test(
    'до загрузки настроек список ждёт, потом читается папка загрузок и за ней следят',
    () async {
      final harness = _Harness();

      await harness.controller.load();

      expect(harness.state.isLoading, isTrue);
      expect(harness.repository.syncedFolders, isEmpty);

      await harness.start();

      expect(harness.state.isLoading, isFalse);
      expect(harness.state.folder, _downloads);
      expect(harness.ids, ['a', 'b']);
      expect(harness.repository.watchedFolders, [_downloads]);

      await harness.close();
    },
  );

  test(
    'смена папки в настройках показывает её видео и следит уже за ней',
    () async {
      final harness = _Harness();

      harness.repository.folders[_videos] = [
        testLibraryVideo('c', folder: _videos),
      ];

      await harness.start();

      harness.settingsRepository.pickResult = (
        failure: null,
        data: const DownloadDirectoryModel(path: _videos, isDefault: false),
      );

      await harness.settings.pickDownloadDirectory();
      await _settle();

      expect(harness.state.folder, _videos);
      expect(harness.ids, ['c']);
      expect(harness.repository.watchedFolders, [_downloads, _videos]);

      await harness.close();
    },
  );

  test('изменения в папке собираются и перечитывают список один раз', () async {
    final harness = _Harness();

    await harness.start();

    harness.repository.folders[_downloads]!.insert(0, testLibraryVideo('new'));
    harness.repository
      ..changeFolder()
      ..changeFolder()
      ..changeFolder();
    await _settle();

    expect(harness.ids, ['a', 'b']);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _settle();

    expect(harness.ids, ['new', 'a', 'b']);
    expect(harness.repository.syncedFolders, [_downloads, _downloads]);

    await harness.close();
  });

  test(
    'превью и длительность догружаются по одному сверху вниз; сбой не повторяется',
    () async {
      final harness = _Harness();

      harness.repository.folders[_downloads] = [
        testLibraryVideo('a', isMetadataLoaded: false, duration: null),
        testLibraryVideo('b'),
        testLibraryVideo('c', isMetadataLoaded: false),
      ];
      harness.repository.metadata['a'] = const VideoFileMetadataModel(
        duration: Duration(seconds: 90),
        hasThumbnail: true,
      );
      harness.repository.failedMetadata.add('c');
      harness.repository.metadataGate = Completer<void>();

      await harness.start();

      expect(harness.repository.metadataRequests, ['a']);
      expect(harness.state.videos.first.thumbnailPath, isNull);

      harness.repository.metadataGate!.complete();
      await _settle();

      expect(harness.repository.metadataRequests, ['a', 'c']);

      final a = harness.state.videos.first;

      expect(a.thumbnailPath, 'thumbnails/a.jpg');
      expect(a.duration, const Duration(seconds: 90));
      expect(a.isMetadataLoaded, isTrue);

      await harness.controller.refresh();
      await _settle();

      expect(harness.repository.metadataRequests, ['a', 'c']);

      await harness.close();
    },
  );

  test(
    'позиция просмотра сохраняется и видна сразу; длительность плеера точнее',
    () async {
      final harness = _Harness();

      await harness.start();
      await harness.controller.savePosition(
        'b',
        position: const Duration(minutes: 2),
        duration: const Duration(minutes: 9, seconds: 59),
      );

      final b = harness.state.videos.last;

      expect(b.position, const Duration(minutes: 2));
      expect(b.duration, const Duration(minutes: 9, seconds: 59));
      expect(b.watchedAt, isNotNull);
      expect(
        harness.repository.savedPositions.single.position,
        const Duration(minutes: 2),
      );

      /// A video no longer in the folder is not saved
      await harness.controller.savePosition(
        'gone',
        position: const Duration(seconds: 5),
      );

      expect(harness.repository.savedPositions, hasLength(1));

      await harness.close();
    },
  );

  test(
    'чтение папки, начатое до сохранения позиции, не откатывает её на экране',
    () async {
      final harness = _Harness();

      await harness.start();

      await harness.controller.savePosition(
        'a',
        position: const Duration(minutes: 4),
      );

      /// The reading got the database before the position was written
      harness.repository.folders[_downloads] = [
        testLibraryVideo('a'),
        testLibraryVideo('b'),
      ];

      await harness.controller.refresh();

      expect(harness.state.videos.first.position, const Duration(minutes: 4));

      await harness.close();
    },
  );

  test(
    'пропавшая папка: ошибка с путём и пустой список; повтор после появления папки',
    () async {
      final harness = _Harness();

      harness.repository.missingFolders.add(_downloads);

      await harness.start();

      expect(harness.state.videos, isEmpty);
      expect(
        harness.state.failure?.code,
        const PlayerErrorCodes().folderNotFound,
      );
      expect(harness.state.failure?.message, contains(_downloads));

      harness.repository.missingFolders.clear();

      await harness.controller.refresh();

      expect(harness.state.failure, isNull);
      expect(harness.ids, ['a', 'b']);

      await harness.close();
    },
  );
}
