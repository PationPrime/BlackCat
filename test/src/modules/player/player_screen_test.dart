import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';
import 'package:peeky_cat/src/modules/player/module.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_services.dart';
import '../../support/test_app.dart';
import '../../support/test_localization.dart';

const _downloads = r'C:\Users\user\Downloads';
const _window = Size(1200, 800);

final _video = find.byKey(FakeVideoPlayerService.viewKey);

/// The dialog box around the video
Finder get _playerBox =>
    find.ancestor(of: _video, matching: find.byType(AnimatedContainer)).last;

Future<TestApp> _pumpPlayer(
  WidgetTester tester, {
  List<LibraryVideoModel>? videos,
  Size size = _window,
}) async {
  final app = TestApp();

  if (videos != null) {
    app.videoLibraryRepository.folders[_downloads] = videos;
  }

  await app.pumpPage(tester, const PlayerScreen(), size: size);

  return app;
}

/// Opens the player from the first card and lets it start
Future<void> _openFirst(WidgetTester tester, TestApp app) async {
  await tester.tap(find.byTooltip('Смотреть').first);
  await app.settle(tester);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> _closePlayer(WidgetTester tester, TestApp app) async {
  if (app.appWindowController.state.isFullScreen) {
    await _press(tester, LogicalKeyboardKey.escape);
  }

  await _press(tester, LogicalKeyboardKey.escape);
  await app.settle(tester);
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets(
    'карточки: чёрная плашка без превью, кнопка просмотра, название, длительность и место остановки',
    (tester) async {
      final app = await _pumpPlayer(
        tester,
        videos: [
          testLibraryVideo('a', thumbnailPath: r'C:\missing\a.jpg'),
          testLibraryVideo(
            'b',
            position: const Duration(minutes: 3, seconds: 25),
            duration: const Duration(hours: 1, minutes: 2),
          ),
          testLibraryVideo('c', position: const Duration(minutes: 10)),
          testLibraryVideo('d', duration: null),
        ],
      );

      expect(find.text('Плеер'), findsOneWidget);
      expect(find.text(r'Папка: C:\Users\user\Downloads'), findsOneWidget);
      expect(find.byType(LibraryVideoCard), findsNWidgets(4));
      expect(find.byTooltip('Смотреть'), findsNWidgets(4));

      for (final title in ['Ролик a', 'Ролик b', 'Ролик c', 'Ролик d']) {
        expect(find.text(title), findsOneWidget);
      }

      expect(find.text('10:00'), findsNWidgets(2));
      expect(find.text('1:02:00'), findsOneWidget);
      expect(find.textContaining('Остановились на 3:25'), findsOneWidget);
      expect(find.textContaining('Просмотрено'), findsOneWidget);

      /// The missing thumbnail leaves the black plate, the play button stays on it
      final plate = find
          .ancestor(
            of: find.byTooltip('Смотреть').first,
            matching: find.byType(ColoredBox),
          )
          .first;

      expect(tester.widget<ColoredBox>(plate).color, Colors.black);
      expect(tester.takeException(), isNull);

      await app.close();
    },
  );

  testWidgets('карточки идут колонками по ширине окна без переполнений', (
    tester,
  ) async {
    final videos = [
      for (var index = 0; index < 5; index++) testLibraryVideo('$index'),
    ];
    final app = await _pumpPlayer(
      tester,
      videos: videos,
      size: const Size(1300, 1400),
    );
    final cards = find.byType(LibraryVideoCard);

    expect(
      tester.getTopLeft(cards.at(0)).dy,
      tester.getTopLeft(cards.at(3)).dy,
    );
    expect(
      tester.getTopLeft(cards.at(4)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
    expect(tester.takeException(), isNull);

    await app.close();

    final narrow = await _pumpPlayer(
      tester,
      videos: videos,
      size: const Size(420, 2600),
    );
    final narrowCards = find.byType(LibraryVideoCard);

    expect(
      tester.getTopLeft(narrowCards.at(1)).dy,
      greaterThan(tester.getTopLeft(narrowCards.at(0)).dy),
    );
    expect(
      tester.getTopLeft(narrowCards.at(1)).dx,
      tester.getTopLeft(narrowCards.at(0)).dx,
    );
    expect(tester.takeException(), isNull);

    await narrow.close();
  });

  testWidgets('пустая папка: подсказка и переход к скачиванию', (tester) async {
    final app = await _pumpPlayer(tester, videos: []);

    expect(
      find.textContaining('В папке загрузок пока нет видео'),
      findsOneWidget,
    );

    await tester.tap(find.text('Скачать видео'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.home);

    await app.close();
  });

  testWidgets(
    'пропавшая папка: сообщение с путём, «Повторить» перечитывает её',
    (tester) async {
      final app = TestApp();

      app.videoLibraryRepository.missingFolders.add(_downloads);

      await app.pumpPage(tester, const PlayerScreen(), size: _window);

      expect(find.byType(AppFailureBanner), findsOneWidget);
      expect(
        find.textContaining(
          r'Папка загрузок не найдена: C:\Users\user\Downloads',
        ),
        findsOneWidget,
      );
      expect(find.byType(LibraryVideoCard), findsNothing);

      app.videoLibraryRepository.missingFolders.clear();

      await tester.tap(find.text('Повторить'));
      await app.settle(tester);

      expect(find.byType(AppFailureBanner), findsNothing);
      expect(find.byType(LibraryVideoCard), findsNWidgets(2));

      await app.close();
    },
  );

  testWidgets(
    'карточка открывает плеер на 80% окна; закрытие сохраняет позицию, и карточка её показывает',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);

      expect(_video, findsOneWidget);
      expect(tester.getSize(_playerBox), const Size(960, 640));
      expect(tester.getCenter(_playerBox), const Offset(600, 400));
      expect(
        app.videoPlayerService.openedPath,
        r'C:\Users\user\Downloads\a.mp4',
      );
      expect(
        find.descendant(of: _playerBox, matching: find.text('Ролик a')),
        findsOneWidget,
      );
      expect(find.text('0:00 / 10:00'), findsOneWidget);

      app.videoPlayerService.emit(
        (playback) => playback.copyWith(
          position: const Duration(minutes: 3, seconds: 25),
        ),
      );
      await app.settle(tester);

      expect(find.text('3:25 / 10:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть (Esc)'));
      await app.settle(tester);

      expect(_video, findsNothing);
      expect(app.videoPlayerService.calls.last, 'stop');
      expect(
        app.videoLibraryRepository.savedPositions.last.position,
        const Duration(minutes: 3, seconds: 25),
      );
      expect(find.textContaining('Остановились на 3:25'), findsOneWidget);

      /// The next opening continues from there
      await _openFirst(tester, app);

      expect(
        app.videoPlayerService.openedStart,
        const Duration(minutes: 3, seconds: 25),
      );

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets(
    'пробел ставит на паузу и возобновляет с анимацией в центре; кнопка паузы — слева внизу',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);

      final pauseButton = find.byTooltip('Пауза (k)');

      expect(pauseButton, findsOneWidget);

      /// Play and pause is the first control at the bottom left
      final buttonRect = tester.getRect(pauseButton);
      final boxRect = tester.getRect(_playerBox);

      expect(buttonRect.left - boxRect.left, lessThan(40));
      expect(boxRect.bottom - buttonRect.bottom, lessThan(40));
      expect(
        tester.getRect(find.byTooltip('Назад на 10 секунд (j)')).left,
        greaterThan(buttonRect.left),
      );

      /// No big button in the middle until the space bar is pressed
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      await _press(tester, LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 50));

      expect(app.videoPlayerService.calls, contains('pause'));
      expect(find.byTooltip('Смотреть (k)'), findsOneWidget);

      /// The flash shows the pause icon and fades out
      final flash = find.byIcon(Icons.pause_rounded);

      expect(flash, findsOneWidget);
      expect(tester.getCenter(flash), tester.getCenter(_playerBox));

      await tester.pump(const Duration(milliseconds: 600));

      final opacity = tester.widget<Opacity>(
        find.ancestor(of: flash, matching: find.byType(Opacity)).first,
      );

      expect(opacity.opacity, 0);

      await _press(tester, LogicalKeyboardKey.keyK);
      await app.settle(tester);

      expect(app.videoPlayerService.calls.last, 'play');
      expect(find.byTooltip('Пауза (k)'), findsOneWidget);

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets(
    'J, L и стрелки перематывают на 10 секунд, нажатия подряд складываются в подсказке',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);

      app.videoPlayerService.emit(
        (playback) => playback.copyWith(position: const Duration(minutes: 1)),
      );
      await app.settle(tester);

      await _press(tester, LogicalKeyboardKey.keyJ);

      expect(app.videoPlayerService.calls.last, 'seek 50');
      expect(find.text('10 секунд'), findsOneWidget);

      /// The hint sits over the left side
      expect(
        tester.getCenter(find.text('10 секунд')).dx,
        lessThan(tester.getCenter(_playerBox).dx),
      );

      await _press(tester, LogicalKeyboardKey.arrowLeft);

      expect(app.videoPlayerService.calls.last, 'seek 40');
      expect(find.text('20 секунд'), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.keyL);

      expect(app.videoPlayerService.calls.last, 'seek 50');
      expect(find.text('10 секунд'), findsOneWidget);
      expect(
        tester.getCenter(find.text('10 секунд')).dx,
        greaterThan(tester.getCenter(_playerBox).dx),
      );

      await _press(tester, LogicalKeyboardKey.arrowRight);

      expect(app.videoPlayerService.calls.last, 'seek 60');
      expect(find.text('20 секунд'), findsOneWidget);

      await app.settle(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('20 секунд'), findsNothing);

      /// The buttons at the bottom seek too
      await tester.tap(find.byTooltip('Вперёд на 10 секунд (l)'));
      await tester.pump();

      expect(app.videoPlayerService.calls.last, 'seek 70');

      await tester.tap(find.byTooltip('Назад на 10 секунд (j)'));
      await tester.pump();

      expect(app.videoPlayerService.calls.last, 'seek 60');

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets(
    'двойной клик у краёв перематывает, частые клики после него продолжают; одиночный клик — пауза',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);

      app.videoPlayerService.emit(
        (playback) => playback.copyWith(position: const Duration(minutes: 1)),
      );
      await app.settle(tester);

      final box = tester.getRect(_playerBox);

      /// 35% from the edges seek, the rest is the middle
      final left = Offset(box.left + box.width * 0.3, box.center.dy);
      final right = Offset(box.right - box.width * 0.3, box.center.dy);
      final middle = box.center;

      await tester.tapAt(right);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(right);
      await tester.pump();

      expect(app.videoPlayerService.calls.last, 'seek 70');
      expect(find.text('10 секунд'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.tapAt(right);
      await tester.pump();

      expect(app.videoPlayerService.calls.last, 'seek 80');
      expect(find.text('20 секунд'), findsOneWidget);

      await app.settle(tester);

      await tester.tapAt(left);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(left);
      await tester.pump();

      expect(app.videoPlayerService.calls.last, 'seek 70');
      expect(app.videoPlayerService.calls, isNot(contains('pause')));

      await app.settle(tester);

      /// A single click waits for a second one, then pauses
      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 100));

      expect(app.videoPlayerService.calls, isNot(contains('pause')));

      await tester.pump(const Duration(milliseconds: 300));

      expect(app.videoPlayerService.calls.last, 'pause');

      /// A double click in the middle switches full screen
      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(middle);
      await app.settle(tester);

      expect(app.appWindowService.fullScreen, isTrue);
      expect(app.videoPlayerService.calls.last, 'pause');

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets(
    'F, кнопка и двойной клик разворачивают во весь экран; Esc выходит из него, затем закрывает плеер',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);
      await _press(tester, LogicalKeyboardKey.keyF);
      await app.settle(tester);

      expect(app.appWindowService.fullScreen, isTrue);
      expect(app.appWindowController.state.isFullScreen, isTrue);
      expect(tester.getSize(_playerBox), _window);
      expect(
        find.byTooltip('Выйти из полноэкранного режима (f)'),
        findsOneWidget,
      );

      await _press(tester, LogicalKeyboardKey.escape);
      await app.settle(tester);

      expect(app.appWindowService.fullScreen, isFalse);
      expect(tester.getSize(_playerBox), const Size(960, 640));

      await tester.tap(find.byTooltip('Во весь экран (f)'));
      await app.settle(tester);

      expect(app.appWindowService.fullScreen, isTrue);

      /// Closing the player leaves full screen too
      await tester.tap(find.byTooltip('Закрыть (Esc)'));
      await app.settle(tester);

      expect(_video, findsNothing);
      expect(app.appWindowService.fullScreen, isFalse);

      await _openFirst(tester, app);
      await _press(tester, LogicalKeyboardKey.escape);
      await app.settle(tester);

      expect(_video, findsNothing);

      await app.close();
    },
  );

  testWidgets(
    'скорость 1.25, 1.5 и 2 выбирается в меню, Shift+. и Shift+, переключают её',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);
      await tester.tap(find.text('1×'));
      await app.settle(tester);

      expect(find.text('Скорость воспроизведения'), findsWidgets);

      for (final option in ['Обычная', '1.25', '1.5', '2']) {
        expect(find.text(option), findsOneWidget);
      }

      await tester.tap(find.text('1.5'));
      await app.settle(tester);

      expect(app.videoPlayerService.calls.last, 'rate 1.5');
      expect(find.text('1.5×'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await app.settle(tester);

      expect(app.videoPlayerService.calls.last, 'rate 2.0');
      expect(find.text('2×'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await app.settle(tester);

      expect(find.text('1×'), findsOneWidget);

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets(
    'полоса прогресса перематывает кликом и перетаскиванием, цифры — на долю видео',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);

      final box = tester.getRect(_playerBox);
      final timeline = tester.getRect(find.byTooltip('Пауза (k)'));

      /// The bar lies just above the buttons across the whole player
      final barY = timeline.top - 14;

      await tester.tapAt(Offset(box.left + 12 + (box.width - 24) / 2, barY));
      await tester.pump();

      expect(app.videoPlayerService.calls.last, 'seek 300');

      await tester.dragFrom(
        Offset(box.left + 12 + (box.width - 24) / 4, barY),
        Offset((box.width - 24) / 2, 0),
      );
      await app.settle(tester);

      expect(app.videoPlayerService.calls.last, 'seek 450');

      await _press(tester, LogicalKeyboardKey.digit3);

      expect(app.videoPlayerService.calls.last, 'seek 180');

      await _press(tester, LogicalKeyboardKey.home);

      expect(app.videoPlayerService.calls.last, 'seek 0');

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets('M и стрелки вверх и вниз меняют звук и показывают уровень', (
    tester,
  ) async {
    final app = await _pumpPlayer(tester);

    await _openFirst(tester, app);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(app.videoPlayerService.calls.last, 'volume 0.95');
    expect(find.text('95%'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.keyM);
    await tester.pump();

    expect(app.videoPlayerService.calls.last, 'muted true');
    expect(find.text('0%'), findsOneWidget);
    expect(find.byTooltip('Включить звук (m)'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(app.videoPlayerService.calls.last, 'volume 1.00');
    expect(find.byTooltip('Выключить звук (m)'), findsOneWidget);

    await _closePlayer(tester, app);
    await app.close();
  });

  testWidgets(
    'управление прячется через 3 секунды просмотра и появляется от движения мыши',
    (tester) async {
      final app = await _pumpPlayer(tester);

      await _openFirst(tester, app);

      double controlsOpacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find.byTooltip('Пауза (k)'),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;

      expect(controlsOpacity(), 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));

      expect(controlsOpacity(), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);

      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(_playerBox));
      await mouse.moveTo(tester.getCenter(_playerBox) + const Offset(10, 10));
      await tester.pump();

      expect(controlsOpacity(), 1);

      /// A paused video keeps the controls
      await _press(tester, LogicalKeyboardKey.space);
      await tester.pump(const Duration(seconds: 4));

      expect(
        find.ancestor(
          of: find.byTooltip('Смотреть (k)'),
          matching: find.byType(AnimatedOpacity),
        ),
        findsWidgets,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find
                  .ancestor(
                    of: find.byTooltip('Смотреть (k)'),
                    matching: find.byType(AnimatedOpacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );

      await _closePlayer(tester, app);
      await app.close();
    },
  );

  testWidgets('ошибка воспроизведения: причина, «Повторить» и «Закрыть»', (
    tester,
  ) async {
    final app = await _pumpPlayer(tester);

    app.videoPlayerService.openError = 'no decoder';

    await _openFirst(tester, app);

    expect(
      find.textContaining('Не удалось воспроизвести видео'),
      findsOneWidget,
    );

    app.videoPlayerService.openError = null;

    await tester.tap(
      find.descendant(of: _playerBox, matching: find.text('Повторить')),
    );
    await app.settle(tester);

    expect(find.textContaining('Не удалось воспроизвести видео'), findsNothing);
    expect(find.byTooltip('Пауза (k)'), findsOneWidget);

    app.videoPlayerService.emit(
      (playback) => playback.copyWith(error: 'broken', isPlaying: false),
    );
    await app.settle(tester);

    await tester.tap(
      find.descendant(of: _playerBox, matching: find.text('Закрыть')),
    );
    await app.settle(tester);

    expect(_video, findsNothing);

    await app.close();
  });

  group('удаление видео', () {
    /// The finished download of video a in the download list
    Future<TestApp> pumpWithDownload(WidgetTester tester) async {
      final app = TestApp();

      app.queueRepository.restoreResult = (
        failure: null,
        data: [
          DownloadTaskModel(
            id: 'task-a',
            video: testVideo('a'),
            quality: testQuality,
            status: DownloadTaskStatus.done,
            section: DownloadTaskSection.finished,
            filePath: '$_downloads\\a.mp4',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        ],
      );
      app.videoLibraryRepository.downloadsOfVideo['a'] = ['task-a'];

      await app.queueController.restoreQueue();
      await app.pumpPage(tester, const PlayerScreen(), size: _window);

      return app;
    }

    Finder deleteButtonOf(String title) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(LibraryVideoCard),
      ),
      matching: find.byTooltip('Удалить'),
    );

    testWidgets('после подтверждения видео пропадает из плеера и из загрузок', (
      tester,
    ) async {
      final app = await pumpWithDownload(tester);

      expect(app.queueController.state.finished, hasLength(1));

      await tester.tap(deleteButtonOf('Ролик a'));
      await app.settle(tester);

      expect(find.text('Удалить видео?'), findsOneWidget);
      expect(
        find.textContaining('«Ролик a» будет удалено с устройства'),
        findsOneWidget,
      );

      await tester.tap(find.text('Удалить'));
      await app.settle(tester);

      expect(app.videoLibraryRepository.deletedVideos, ['a']);
      expect(find.text('Ролик a'), findsNothing);
      expect(find.byType(LibraryVideoCard), findsOneWidget);
      expect(app.queueController.state.finished, isEmpty);
      expect(app.queueRepository.removedTaskIds, ['task-a']);

      await app.close();
    });

    testWidgets('отмена ничего не удаляет', (tester) async {
      final app = await pumpWithDownload(tester);

      await tester.tap(deleteButtonOf('Ролик a'));
      await app.settle(tester);
      await tester.tap(find.text('Отмена'));
      await app.settle(tester);

      expect(app.videoLibraryRepository.deletedVideos, isEmpty);
      expect(find.byType(LibraryVideoCard), findsNWidgets(2));
      expect(app.queueController.state.finished, hasLength(1));

      await app.close();
    });

    testWidgets(
      'занятый файл: видео остаётся, в загрузках тоже, ошибка на странице',
      (tester) async {
        final app = await pumpWithDownload(tester);

        app.videoLibraryRepository.lockedVideos.add('a');

        await tester.tap(deleteButtonOf('Ролик a'));
        await app.settle(tester);
        await tester.tap(find.text('Удалить'));
        await app.settle(tester);

        expect(find.text('Ролик a'), findsOneWidget);
        expect(app.queueController.state.finished, hasLength(1));
        expect(find.textContaining('Не удалось удалить видео'), findsOneWidget);

        await app.close();
      },
    );
  });
}
