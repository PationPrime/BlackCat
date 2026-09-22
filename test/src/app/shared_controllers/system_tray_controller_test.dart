import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

import '../../support/fake_services.dart';
import '../../support/test_localization.dart';

DownloadTaskModel _task({
  int downloadedBytes = 420,
  DownloadTaskStatus status = DownloadTaskStatus.downloading,
}) => DownloadTaskModel(
  id: 'a',
  video: const VideoInfoModel(
    id: 'a',
    title: 'Обзор',
    url: 'https://youtu.be/a',
    qualities: [],
  ),
  quality: const QualityModel(
    id: '1080',
    kind: QualityKind.video,
    label: '1080p',
  ),
  status: status,
  section: DownloadTaskSection.active,
  downloadedBytes: downloadedBytes,
  totalBytes: 1000,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Harness {
  final windowService = FakeAppWindowService();
  final trayService = FakeSystemTrayService();

  late final windowController = AppWindowController(
    appWindowService: windowService,
  );
  late final controller = SystemTrayController(
    systemTrayService: trayService,
    appWindowController: windowController,
  );

  Future<void> start() async {
    await controller.initialize();
    await controller.onLanguageApplied();
  }
}

void main() {
  setUpAll(loadTestTranslations);

  test(
    'initialize: иконка в трее — закрытие окна прячет приложение туда',
    () async {
      final harness = _Harness();

      await harness.controller.initialize();

      expect(harness.controller.state.isAvailable, isTrue);
      expect(harness.windowController.state.closesToTray, isTrue);
      expect(harness.windowService.preventClose, isTrue);

      /// Menu labels wait for the translations
      expect(harness.trayService.menus, isEmpty);

      await harness.controller.onLanguageApplied();

      expect(harness.trayService.lastMenuLabels, [
        'Нет активной загрузки',
        'Открыть PeekyCat',
        'Свернуть в трей',
        'Выйти',
      ]);
      expect(harness.trayService.toolTips.last, 'PeekyCat');
    },
  );

  test('initialize: трей недоступен — окно закрывается как обычно', () async {
    final harness = _Harness();

    harness.trayService.initializeError = StateError('no tray');

    await harness.controller.initialize();

    expect(harness.controller.state.isAvailable, isFalse);
    expect(harness.windowController.state.closesToTray, isFalse);
  });

  test(
    'активная загрузка: название и процент, одинаковые обновления пропускаются',
    () async {
      final harness = _Harness();

      await harness.start();
      await harness.controller.showActiveDownload(_task());

      expect(harness.trayService.lastMenuLabels.take(2), [
        'Обзор',
        'Скачивание 42%',
      ]);
      expect(
        harness.trayService.toolTips.last,
        'PeekyCat\nОбзор\nСкачивание 42%',
      );

      final menusCount = harness.trayService.menus.length;

      /// A few bytes more, the same whole percent
      await harness.controller.showActiveDownload(_task(downloadedBytes: 421));

      expect(harness.trayService.menus, hasLength(menusCount));

      await harness.controller.showActiveDownload(null);

      expect(harness.trayService.lastMenuLabels.first, 'Нет активной загрузки');
    },
  );

  test(
    'правый клик: меню со свежим прогрессом, пока открыто — не перестраивается',
    () async {
      final harness = _Harness();
      final menuGate = Completer<void>();

      await harness.start();
      await harness.controller.showActiveDownload(_task());

      harness.trayService.menuGate = menuGate;
      harness.trayService.emit(const SystemTrayIconRightClicked());
      await _settle();

      expect(harness.trayService.popUpCalls, 1);

      final menusWhileOpen = harness.trayService.menus.length;

      await harness.controller.showActiveDownload(_task(downloadedBytes: 870));

      expect(harness.trayService.menus, hasLength(menusWhileOpen));

      menuGate.complete();
      await _settle();

      expect(harness.trayService.lastMenuLabels[1], 'Скачивание 87%');
    },
  );

  test('левый клик на Windows открывает окно, на macOS — меню', () async {
    final harness = _Harness();

    await harness.start();

    harness.trayService.emit(const SystemTrayIconClicked());
    await _settle();

    expect(harness.windowService.calls, contains('show'));
    expect(harness.trayService.popUpCalls, 0);

    harness.trayService.opensMenuOnLeftClick = true;
    harness.trayService.emit(const SystemTrayIconClicked());
    await _settle();

    expect(harness.trayService.popUpCalls, 1);
  });

  test(
    'пункты меню: открыть, свернуть в трей, выйти с удалением иконки',
    () async {
      final harness = _Harness();

      await harness.start();

      harness.trayService
        ..emit(const SystemTrayMenuItemClicked(SystemTrayMenuKeys.hideWindow))
        ..emit(
          const SystemTrayMenuItemClicked(SystemTrayMenuKeys.activeDownload),
        );
      await _settle();

      expect(harness.windowService.calls, containsAllInOrder(['hide', 'show']));

      harness.trayService.emit(
        const SystemTrayMenuItemClicked(SystemTrayMenuKeys.quit),
      );
      await _settle();

      expect(harness.trayService.isDestroyed, isTrue);
      expect(harness.windowService.calls.last, 'quit');
    },
  );
}
