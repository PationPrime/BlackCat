import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../models/models.dart';
import '../../tools/tools.dart';

/// App icon in the system tray (the menu bar on macOS) with a context menu.
///
/// Platforms differ:
/// * Windows and macOS report icon clicks, the app opens the menu itself
///   and the icon has a tooltip.
/// * Linux shows the icon through AppIndicator: the desktop shell opens
///   the menu on click, reports no clicks and shows no tooltip, but applies
///   menu changes right away, even while the menu is open.
///   GNOME needs the AppIndicator extension for the icon to appear
abstract interface class SystemTrayService {
  /// The platform has a system tray: Windows, macOS or Linux
  bool get isSupported;

  /// The icon reports clicks and the app opens the menu itself.
  /// `false` on Linux: the shell opens the menu
  bool get opensMenuOnClick;

  /// A left click opens the menu, as status items do on macOS.
  /// On Windows a left click is for opening the app window
  bool get opensMenuOnLeftClick;

  /// The icon shows a tooltip on hover: Windows and macOS
  bool get supportsToolTip;

  Stream<SystemTrayEventModel> get events;

  /// Shows the icon. [windowsIconAsset] is an `.ico` asset, Windows loads
  /// no other format; [iconAsset] is a PNG for macOS and Linux
  Future<void> initialize({
    required String windowsIconAsset,
    required String iconAsset,
  });

  /// Replaces the context menu. An open native menu on Windows and macOS
  /// is not updated: the new items appear the next time it opens
  Future<void> setMenu(List<SystemTrayMenuItemModel> items);

  /// Does nothing where [supportsToolTip] is `false`
  Future<void> setToolTip(String toolTip);

  /// Opens the context menu at the pointer. On Windows the call completes
  /// only when the menu closes. Does nothing where [opensMenuOnClick] is `false`
  Future<void> popUpMenu();

  /// Removes the icon: otherwise Windows keeps a dead icon in the tray
  /// until the pointer passes over it
  Future<void> destroy();
}

final class SystemTrayServiceImpl
    with TrayListener
    implements SystemTrayService {
  final _events = StreamController<SystemTrayEventModel>.broadcast();

  var _isInitialized = false;

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  bool get opensMenuOnClick =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  @override
  bool get opensMenuOnLeftClick => !kIsWeb && Platform.isMacOS;

  @override
  bool get supportsToolTip => opensMenuOnClick;

  @override
  Stream<SystemTrayEventModel> get events => _events.stream;

  @override
  Future<void> initialize({
    required String windowsIconAsset,
    required String iconAsset,
  }) async {
    if (!isSupported || _isInitialized) return;

    trayManager.addListener(this);

    await trayManager.setIcon(Platform.isWindows ? windowsIconAsset : iconAsset);

    _isInitialized = true;
  }

  @override
  Future<void> setMenu(List<SystemTrayMenuItemModel> items) async {
    if (!_isInitialized) return;

    await trayManager.setContextMenu(
      Menu(
        items: [
          for (final item in items)
            switch (item) {
              SystemTrayMenuActionModel(:final key, :final label, :final enabled) =>
                MenuItem(
                  key: key,
                  label: _platformLabel(label),
                  disabled: !enabled,
                ),
              SystemTrayMenuSeparatorModel() => MenuItem.separator(),
            },
        ],
      ),
    );
  }

  /// Windows turns `&` into a keyboard shortcut underline
  String _platformLabel(String label) => Platform.isWindows
      ? SystemTrayText.escapeWindowsMenuMnemonics(label)
      : label;

  @override
  Future<void> setToolTip(String toolTip) async {
    if (!_isInitialized || !supportsToolTip) return;

    await trayManager.setToolTip(
      Platform.isWindows
          ? SystemTrayText.limitUtf16(
              toolTip,
              SystemTrayText.windowsToolTipMaxUtf16Length,
            )
          : toolTip,
    );
  }

  @override
  Future<void> popUpMenu() async {
    if (!_isInitialized || !opensMenuOnClick) return;

    await trayManager.popUpContextMenu();
  }

  @override
  Future<void> destroy() async {
    if (!_isInitialized) return;

    trayManager.removeListener(this);
    _isInitialized = false;

    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => _events.add(const SystemTrayIconClicked());

  @override
  void onTrayIconRightMouseDown() =>
      _events.add(const SystemTrayIconRightClicked());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key case final key?) {
      _events.add(SystemTrayMenuItemClicked(key));
    }
  }
}
