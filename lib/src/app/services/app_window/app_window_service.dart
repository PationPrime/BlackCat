import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/models.dart';

/// Main app window on desktop platforms: frame, state and closing
abstract interface class AppWindowService {
  /// The service controls a window on this platform: Windows, macOS or Linux
  bool get isSupported;

  /// How the app draws the window frame on this platform
  AppWindowFrameModel get frame;

  Stream<AppWindowEvent> get events;

  /// Hides the system title bar, sets the minimum size and starts
  /// reporting window [events]
  Future<void> initialize({required Size minimumSize});

  /// While set, closing the window only reports
  /// [AppWindowEvent.closeRequested] instead of ending the app
  Future<void> setPreventClose(bool preventClose);

  Future<bool> isMaximized();

  Future<bool> isVisible();

  /// Shows the window, restores it if minimized and brings it to the front
  Future<void> show();

  Future<void> hide();

  Future<void> minimize();

  Future<void> maximize();

  Future<void> unmaximize();

  /// The window covers the whole screen without the taskbar and frame
  Future<void> setFullScreen(bool fullScreen);

  Future<bool> isFullScreen();

  /// Moves the window after the pointer, like dragging the system title bar
  Future<void> startDragging();

  Future<void> startResizing(AppWindowResizeEdge edge);

  /// Ends the app without a close request
  Future<void> quit();
}

final class AppWindowServiceImpl
    with WindowListener
    implements AppWindowService {
  final _events = StreamController<AppWindowEvent>.broadcast();

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  AppWindowFrameModel get frame {
    if (!isSupported) {
      return const AppWindowFrameModel.system();
    }

    if (Platform.isMacOS) {
      /// The native traffic light buttons and resize borders stay:
      /// the title bar only leaves room for the buttons
      return const AppWindowFrameModel(isCustom: true, leadingInset: 76);
    }

    if (Platform.isWindows) {
      /// Without the system title bar Windows keeps resize borders on the left,
      /// right and bottom; only the top edge is resized by the app
      return const AppWindowFrameModel(
        isCustom: true,
        showsWindowButtons: true,
        resizeEdges: {
          AppWindowResizeEdge.top,
          AppWindowResizeEdge.topLeft,
          AppWindowResizeEdge.topRight,
        },
      );
    }

    /// Linux: GTK removes all window decorations, resize borders included
    return AppWindowFrameModel(
      isCustom: true,
      showsWindowButtons: true,
      resizeEdges: AppWindowResizeEdge.values.toSet(),
    );
  }

  @override
  Stream<AppWindowEvent> get events => _events.stream;

  @override
  Future<void> initialize({required Size minimumSize}) async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();

    windowManager.addListener(this);

    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
    );
    await windowManager.setMinimumSize(minimumSize);
  }

  @override
  Future<void> setPreventClose(bool preventClose) async {
    if (!isSupported) return;

    await windowManager.setPreventClose(preventClose);
  }

  @override
  Future<bool> isMaximized() async =>
      isSupported && await windowManager.isMaximized();

  @override
  Future<bool> isVisible() async =>
      !isSupported || await windowManager.isVisible();

  @override
  Future<void> show() async {
    if (!isSupported) return;

    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }

    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hide() async {
    if (!isSupported) return;

    await windowManager.hide();
  }

  @override
  Future<void> minimize() async {
    if (!isSupported) return;

    await windowManager.minimize();
  }

  @override
  Future<void> maximize() async {
    if (!isSupported) return;

    await windowManager.maximize();
  }

  @override
  Future<void> unmaximize() async {
    if (!isSupported) return;

    await windowManager.unmaximize();
  }

  @override
  Future<void> setFullScreen(bool fullScreen) async {
    if (!isSupported) return;

    await windowManager.setFullScreen(fullScreen);
  }

  @override
  Future<bool> isFullScreen() async =>
      isSupported && await windowManager.isFullScreen();

  @override
  Future<void> startDragging() async {
    if (!isSupported) return;

    await windowManager.startDragging();
  }

  @override
  Future<void> startResizing(AppWindowResizeEdge edge) async {
    if (!isSupported || Platform.isMacOS) return;

    await windowManager.startResizing(switch (edge) {
      AppWindowResizeEdge.top => ResizeEdge.top,
      AppWindowResizeEdge.topLeft => ResizeEdge.topLeft,
      AppWindowResizeEdge.topRight => ResizeEdge.topRight,
      AppWindowResizeEdge.left => ResizeEdge.left,
      AppWindowResizeEdge.right => ResizeEdge.right,
      AppWindowResizeEdge.bottom => ResizeEdge.bottom,
      AppWindowResizeEdge.bottomLeft => ResizeEdge.bottomLeft,
      AppWindowResizeEdge.bottomRight => ResizeEdge.bottomRight,
    });
  }

  @override
  Future<void> quit() async {
    if (!isSupported) {
      exit(0);
    }

    windowManager.removeListener(this);

    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() => _events.add(AppWindowEvent.closeRequested);

  @override
  void onWindowMaximize() => _events.add(AppWindowEvent.maximized);

  @override
  void onWindowUnmaximize() => _events.add(AppWindowEvent.unmaximized);

  @override
  void onWindowMinimize() => _events.add(AppWindowEvent.minimized);

  @override
  void onWindowRestore() => _events.add(AppWindowEvent.restored);

  @override
  void onWindowEnterFullScreen() =>
      _events.add(AppWindowEvent.enteredFullScreen);

  @override
  void onWindowLeaveFullScreen() => _events.add(AppWindowEvent.leftFullScreen);

  @override
  void onWindowEvent(String eventName) {
    switch (eventName) {
      case 'show':
        _events.add(AppWindowEvent.shown);
      case 'hide':
        _events.add(AppWindowEvent.hidden);
    }
  }
}
