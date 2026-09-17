import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/modules/player/controllers/controllers.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_services.dart';
import '../../support/test_localization.dart';

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Harness {
  final repository = FakeVideoLibraryRepository();
  final player = FakeVideoPlayerService();
  final settings = SettingsController(settingsRepository: FakeSettingsRepository());
  late final library = VideoLibraryController(videoLibraryRepository: repository, settingsController: settings);
  late VideoPlaybackController controller;

  VideoPlaybackState get state => controller.state;

  List<Duration> get saved => [for (final video in repository.savedPositions) video.position];

  Future<void> open(
    LibraryVideoModel video, {
    Duration positionUpdateInterval = Duration.zero,
    Duration positionSaveInterval = const Duration(hours: 1),
  }) async {
    repository.folders[r'C:\Users\user\Downloads'] = [video];
    await settings.loadSettings();
    await library.load();
    await _settle();

    controller = VideoPlaybackController(
      videoPlayerService: player,
      videoLibraryController: library,
      video: video,
      positionUpdateInterval: positionUpdateInterval,
      positionSaveInterval: positionSaveInterval,
    );

    await controller.open();
    await _settle();
  }

  void moveTo(Duration position, {bool? isPlaying, bool? isCompleted}) => player.emit(
    (playback) => playback.copyWith(position: position, isPlaying: isPlaying, isCompleted: isCompleted),
  );

  Future<void> close() async {
    await library.close();
    await settings.close();
  }
}

void main() {
  setUpAll(loadTestTranslations);

  test('видео открывается с места остановки, недосмотренное совсем чуть-чуть и досмотренное — с начала', () async {
    for (final (position, start) in [
      (const Duration(minutes: 3), const Duration(minutes: 3)),
      (const Duration(seconds: 4), Duration.zero),
      (const Duration(minutes: 9, seconds: 58), Duration.zero),
    ]) {
      final harness = _Harness();

      await harness.open(testLibraryVideo('a', position: position));

      expect(harness.player.openedPath, r'C:\Users\user\Downloads\a.mp4');
      expect(harness.player.openedStart, start);
      expect(harness.state.isOpening, isFalse);
      expect(harness.state.playback.isPlaying, isTrue);
      expect(harness.state.playback.position, start);

      await harness.controller.close();
      await harness.close();
    }
  });

  test('позиция сохраняется при паузе, раз в интервал, в конце и при закрытии', () async {
    final harness = _Harness();

    await harness.open(testLibraryVideo('a'), positionSaveInterval: const Duration(milliseconds: 200));

    /// Nothing is saved right after opening
    harness.moveTo(const Duration(seconds: 30));
    await _settle();

    expect(harness.saved, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    harness.moveTo(const Duration(seconds: 40));
    await _settle();

    expect(harness.saved, [const Duration(seconds: 40)]);

    harness.moveTo(const Duration(seconds: 41));
    await _settle();

    expect(harness.saved, hasLength(1));

    harness.moveTo(const Duration(seconds: 45));
    await harness.controller.pause();
    await _settle();

    expect(harness.saved, [const Duration(seconds: 40), const Duration(seconds: 45)]);

    harness.moveTo(const Duration(minutes: 9, seconds: 59), isCompleted: true, isPlaying: false);
    await _settle();

    /// A finished video is saved as watched to its end and shows the whole bar
    expect(harness.saved.last, const Duration(minutes: 10));
    expect(harness.state.playback.position, const Duration(minutes: 10));
    expect(harness.library.state.videos.single.isWatched, isTrue);

    await harness.controller.play();
    harness.moveTo(const Duration(seconds: 12));
    await _settle();
    await harness.controller.close();

    expect(harness.saved.last, const Duration(seconds: 12));
    expect(harness.player.calls.last, 'stop');

    await harness.close();
  });

  test('закрытие до ответа плеера не затирает сохранённую позицию', () async {
    final harness = _Harness();

    harness.player.openError = 'no decoder';

    await harness.open(testLibraryVideo('a', position: const Duration(minutes: 3)));
    await harness.controller.close();

    expect(harness.saved, isEmpty);

    await harness.close();
  });

  test('ошибка открытия показывается, «Повторить» открывает видео заново', () async {
    final harness = _Harness();

    harness.player.openError = 'no decoder';

    await harness.open(testLibraryVideo('a'));

    expect(harness.state.failure?.code, const PlayerErrorCodes().playback);
    expect(harness.state.failure?.message, contains('Не удалось воспроизвести видео'));
    expect(harness.state.isOpening, isFalse);

    harness.player.openError = null;
    await harness.controller.open();

    expect(harness.state.failure, isNull);
    expect(harness.player.calls.where((call) => call == 'open'), hasLength(2));

    /// A player error during playback is shown too
    harness.player.emit((playback) => playback.copyWith(error: 'broken frame'));
    await _settle();

    expect(harness.state.failure?.message, contains('broken frame'));

    await harness.controller.close();
    await harness.close();
  });

  test('перемотка на 10 секунд: нажатия подряд складываются, границы видео не переходятся', () async {
    final harness = _Harness();

    await harness.open(testLibraryVideo('a', position: const Duration(minutes: 1)));

    harness.player.reportsSeeks = false;

    await harness.controller.seekBy(const Duration(seconds: 10));

    /// The player still reports the old position: the next press counts from the target
    harness.moveTo(const Duration(minutes: 1));
    await _settle();

    expect(harness.state.playback.position, const Duration(seconds: 70));

    await harness.controller.seekBy(const Duration(seconds: 10));

    expect(harness.player.calls, containsAllInOrder(['seek 70', 'seek 80']));
    expect(harness.state.playback.position, const Duration(seconds: 80));

    harness.moveTo(const Duration(seconds: 80));
    await _settle();
    await harness.controller.seekBy(const Duration(minutes: -5));

    expect(harness.player.calls.last, 'seek 0');

    await harness.controller.seekTo(const Duration(hours: 1));

    expect(harness.player.calls.last, 'seek 600');

    await harness.controller.close();
    await harness.close();
  });

  test('позиция на экране обновляется не чаще интервала, остальное — сразу', () async {
    final harness = _Harness();

    await harness.open(testLibraryVideo('a'), positionUpdateInterval: const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 250));

    harness.moveTo(const Duration(seconds: 1));
    await _settle();

    expect(harness.state.playback.position, const Duration(seconds: 1));

    harness.moveTo(const Duration(seconds: 2));
    harness.moveTo(const Duration(seconds: 3));
    await _settle();

    expect(harness.state.playback.position, const Duration(seconds: 1));

    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(harness.state.playback.position, const Duration(seconds: 3));

    await harness.controller.setRate(1.5);
    await _settle();

    expect(harness.state.playback.rate, 1.5);

    await harness.controller.close();
    await harness.close();
  });

  test('громкость: стрелки меняют её в пределах 0–100%, M выключает и возвращает звук', () async {
    final harness = _Harness();

    await harness.open(testLibraryVideo('a'));
    await harness.controller.changeVolumeBy(0.05);
    await _settle();

    expect(harness.state.playback.volume, 1);

    await harness.controller.changeVolumeBy(-0.25);
    await _settle();

    expect(harness.state.playback.volume, closeTo(0.75, 0.001));

    await harness.controller.toggleMute();
    await _settle();

    expect(harness.state.playback.isMuted, isTrue);

    await harness.controller.toggleMute();
    await _settle();

    expect(harness.state.playback.isMuted, isFalse);
    expect(harness.state.playback.volume, closeTo(0.75, 0.001));

    await harness.controller.close();
    await harness.close();
  });
}
