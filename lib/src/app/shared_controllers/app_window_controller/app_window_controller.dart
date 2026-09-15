import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logger/app_logger.dart';
import '../../models/models.dart';
import '../../services/services.dart';

part 'app_window_state.dart';

/// Main app window: custom title bar buttons, dragging, resizing and closing
final class AppWindowController extends Cubit<AppWindowState> {
  static const _appLogger = AppLogger(where: 'AppWindowController');

  /// The downloader layout still fits at this size
  static const minimumSize = Size(560, 600);

  final AppWindowService _appWindowService;

  StreamSubscription<AppWindowEvent>? _eventsSubscription;

  AppWindowController({required this._appWindowService})
    : super(const AppWindowInitialState());

  void _safeEmit(AppWindowState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    await _eventsSubscription?.cancel();

    await super.close();
  }

  /// Replaces the system title bar with the app one where the platform
  /// allows it. A failure leaves the system frame: the app stays usable
  Future<void> initialize() async {
    if (!_appWindowService.isSupported) return;

    try {
      await _appWindowService.initialize(minimumSize: minimumSize);
    } catch (error, stackTrace) {
      _appLogger.logError(
        'Failed to set up the app window: $error',
        stackTrace: stackTrace,
      );

      return;
    }

    _eventsSubscription = _appWindowService.events.listen(_onWindowEvent);

    _safeEmit(
      state.copyWith(
        frame: _appWindowService.frame,
        isMaximized: await _appWindowService.isMaximized(),
      ),
    );
  }

  /// Closing hides the window in the tray once [enabled]. The platform close
  /// (Alt+F4, the taskbar menu, the macOS close button) then only asks the app
  Future<void> setClosesToTray(bool enabled) async {
    await _appWindowService.setPreventClose(enabled);

    _safeEmit(state.copyWith(closesToTray: enabled));
  }

  Future<void> minimize() => _appWindowService.minimize();

  Future<void> toggleMaximize() async {
    if (await _appWindowService.isMaximized()) {
      await _appWindowService.unmaximize();
    } else {
      await _appWindowService.maximize();
    }
  }

  Future<void> startDragging() => _appWindowService.startDragging();

  Future<void> startResizing(AppWindowResizeEdge edge) =>
      _appWindowService.startResizing(edge);

  /// The close button: hides the window in the tray, where downloads go on.
  /// Without a tray icon the app ends
  Future<void> closeWindow() async {
    if (state.closesToTray) {
      await _appWindowService.hide();
    } else {
      await quit();
    }
  }

  Future<void> showWindow() => _appWindowService.show();

  Future<void> hideWindow() => _appWindowService.hide();

  Future<void> quit() => _appWindowService.quit();

  void _onWindowEvent(AppWindowEvent event) {
    switch (event) {
      case AppWindowEvent.closeRequested:
        unawaited(closeWindow());
      case AppWindowEvent.maximized:
        _safeEmit(state.copyWith(isMaximized: true));
      case AppWindowEvent.unmaximized:
        _safeEmit(state.copyWith(isMaximized: false));
      case AppWindowEvent.minimized ||
          AppWindowEvent.restored ||
          AppWindowEvent.shown ||
          AppWindowEvent.hidden:
        break;
    }
  }
}
