import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';

import '../../support/fake_services.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('initialize: своя рамка платформы и минимальный размер окна', () async {
    final service = FakeAppWindowService(maximized: true);
    final controller = AppWindowController(appWindowService: service);

    await controller.initialize();

    expect(service.minimumSize, AppWindowController.minimumSize);
    expect(controller.state.frame, windowsFrame);
    expect(controller.state.isMaximized, isTrue);
  });

  test('initialize: без поддержки окна остаётся системная рамка', () async {
    final service = FakeAppWindowService(isSupported: false);
    final controller = AppWindowController(appWindowService: service);

    await controller.initialize();

    expect(service.calls, isEmpty);
    expect(controller.state.frame.isCustom, isFalse);
  });

  test('initialize: ошибка платформы оставляет системную рамку', () async {
    final service = FakeAppWindowService()..initializeError = StateError('no window');
    final controller = AppWindowController(appWindowService: service);

    await controller.initialize();

    expect(controller.state.frame.isCustom, isFalse);
  });

  test('closeWindow: без трея приложение закрывается, с треем окно прячется', () async {
    final service = FakeAppWindowService();
    final controller = AppWindowController(appWindowService: service);

    await controller.closeWindow();

    expect(service.calls, ['quit']);

    await controller.setClosesToTray(true);
    await controller.closeWindow();

    expect(service.preventClose, isTrue);
    expect(service.calls, ['quit', 'hide']);
  });

  test('системное закрытие окна при трее прячет окно', () async {
    final service = FakeAppWindowService();
    final controller = AppWindowController(appWindowService: service);

    await controller.initialize();
    await controller.setClosesToTray(true);

    service.emit(AppWindowEvent.closeRequested);
    await _settle();

    expect(service.calls, contains('hide'));
    expect(service.calls, isNot(contains('quit')));
  });

  test('развёртывание окна отражается в состоянии и переключается', () async {
    final service = FakeAppWindowService();
    final controller = AppWindowController(appWindowService: service);

    await controller.initialize();

    service.emit(AppWindowEvent.maximized);
    await _settle();

    expect(controller.state.isMaximized, isTrue);

    service.emit(AppWindowEvent.unmaximized);
    await _settle();

    expect(controller.state.isMaximized, isFalse);

    await controller.toggleMaximize();
    await controller.toggleMaximize();

    expect(service.calls, containsAllInOrder(['maximize', 'unmaximize']));
  });

  test('полный экран: переключается сразу и следит за событиями окна', () async {
    final service = FakeAppWindowService();
    final controller = AppWindowController(appWindowService: service);

    await controller.initialize();
    await controller.toggleFullScreen();

    expect(controller.state.isFullScreen, isTrue);
    expect(service.fullScreen, isTrue);

    /// A repeated request changes nothing
    await controller.setFullScreen(true);

    expect(service.calls.where((call) => call.startsWith('setFullScreen')), hasLength(1));

    service.emit(AppWindowEvent.leftFullScreen);
    await _settle();

    expect(controller.state.isFullScreen, isFalse);

    service.emit(AppWindowEvent.enteredFullScreen);
    await _settle();

    expect(controller.state.isFullScreen, isTrue);

    await controller.toggleFullScreen();

    expect(service.calls.last, 'setFullScreen(false)');
  });
}
