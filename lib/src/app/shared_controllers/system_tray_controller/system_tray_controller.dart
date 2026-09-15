import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logger/app_logger.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import '../app_window_controller/app_window_controller.dart';

part 'system_tray_state.dart';

/// App icon in the system tray: the title and progress of the active download
/// in the context menu and the tooltip, opening, hiding and quitting the app.
///
/// Native menus on Windows and macOS are not updated while open, so the menu
/// is rebuilt right before it opens and shows the progress at that moment
final class SystemTrayController extends Cubit<SystemTrayState> {
  static const _appLogger = AppLogger(where: 'SystemTrayController');

  static const windowsIconAsset = 'assets/tray/tray_icon.ico';
  static const iconAsset = 'assets/tray/tray_icon.png';

  final SystemTrayService _systemTrayService;
  final AppWindowController _appWindowController;

  StreamSubscription<SystemTrayEventModel>? _eventsSubscription;

  /// Translations are loaded: menu labels can be built
  var _isLanguageApplied = false;

  var _isMenuOpen = false;

  /// What the tray shows now: identical updates are skipped
  SystemTrayContentModel? _shownContent;

  SystemTrayController({
    required this._systemTrayService,
    required this._appWindowController,
  }) : super(const SystemTrayInitialState());

  void _safeEmit(SystemTrayState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    await _eventsSubscription?.cancel();

    await super.close();
  }

  /// Shows the tray icon. Once it is shown, closing the window hides the app
  /// in the tray. A failure leaves the app without the tray: closing the window
  /// ends it as usual
  Future<void> initialize() async {
    if (!_systemTrayService.isSupported) return;

    try {
      await _systemTrayService.initialize(
        windowsIconAsset: windowsIconAsset,
        iconAsset: iconAsset,
      );
    } catch (error, stackTrace) {
      _appLogger.logError(
        'Failed to show the tray icon: $error',
        stackTrace: stackTrace,
      );

      return;
    }

    _eventsSubscription = _systemTrayService.events.listen(_onTrayEvent);

    _safeEmit(state.copyWith(isAvailable: true));

    await _appWindowController.setClosesToTray(true);
  }

  /// Call when the app translations are loaded and after every language change
  Future<void> onLanguageApplied() async {
    _isLanguageApplied = true;

    await _render();
  }

  /// The download the tray shows; `null` when nothing is downloading
  Future<void> showActiveDownload(DownloadTaskModel? task) async {
    _safeEmit(
      state.copyWith(activeTask: task, clearActiveTask: task == null),
    );

    await _render();
  }

  /// Removes the tray icon and ends the app
  Future<void> quit() async {
    try {
      await _systemTrayService.destroy();
    } catch (error, stackTrace) {
      _appLogger.logError(
        'Failed to remove the tray icon: $error',
        stackTrace: stackTrace,
      );
    }

    await _appWindowController.quit();
  }

  Future<void> _render() async {
    if (!state.isAvailable || !_isLanguageApplied || _isMenuOpen) return;

    final content = SystemTrayContentBuilder.build(state.activeTask);

    if (content == _shownContent) return;

    _shownContent = content;

    try {
      await _systemTrayService.setMenu(content.menu);
      await _systemTrayService.setToolTip(content.toolTip);
    } catch (error, stackTrace) {
      _shownContent = null;

      _appLogger.logError(
        'Failed to update the tray: $error',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _openMenu() async {
    if (_isMenuOpen) return;

    await _render();

    _isMenuOpen = true;

    try {
      await _systemTrayService.popUpMenu();
    } catch (error, stackTrace) {
      _appLogger.logError(
        'Failed to open the tray menu: $error',
        stackTrace: stackTrace,
      );
    } finally {
      _isMenuOpen = false;
    }

    /// Progress that changed while the menu was open
    await _render();
  }

  void _onTrayEvent(SystemTrayEventModel event) {
    switch (event) {
      case SystemTrayIconClicked()
          when !_systemTrayService.opensMenuOnLeftClick:
        unawaited(_appWindowController.showWindow());
      case SystemTrayIconClicked() || SystemTrayIconRightClicked():
        unawaited(_openMenu());
      case SystemTrayMenuItemClicked(:final key):
        unawaited(_onMenuItemClicked(key));
    }
  }

  Future<void> _onMenuItemClicked(String key) async {
    switch (key) {
      case SystemTrayMenuKeys.activeDownload || SystemTrayMenuKeys.openWindow:
        await _appWindowController.showWindow();
      case SystemTrayMenuKeys.hideWindow:
        await _appWindowController.hideWindow();
      case SystemTrayMenuKeys.quit:
        await quit();
    }
  }
}
