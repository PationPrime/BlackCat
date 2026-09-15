import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/services/services.dart';

const windowsFrame = AppWindowFrameModel(
  isCustom: true,
  showsWindowButtons: true,
  resizeEdges: {AppWindowResizeEdge.top, AppWindowResizeEdge.topLeft, AppWindowResizeEdge.topRight},
);

/// Window stand-in: remembers calls and emits events on request
class FakeAppWindowService implements AppWindowService {
  final _events = StreamController<AppWindowEvent>.broadcast();

  @override
  bool isSupported;

  @override
  AppWindowFrameModel frame;

  bool maximized;
  bool? preventClose;
  Size? minimumSize;
  Object? initializeError;

  final calls = <String>[];
  final resizedEdges = <AppWindowResizeEdge>[];

  FakeAppWindowService({this.isSupported = true, this.frame = windowsFrame, this.maximized = false});

  void emit(AppWindowEvent event) => _events.add(event);

  @override
  Stream<AppWindowEvent> get events => _events.stream;

  @override
  Future<void> initialize({required Size minimumSize}) async {
    if (initializeError case final error?) throw error;

    this.minimumSize = minimumSize;
    calls.add('initialize');
  }

  @override
  Future<void> setPreventClose(bool preventClose) async => this.preventClose = preventClose;

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<bool> isVisible() async => !calls.contains('hide');

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> maximize() async {
    maximized = true;
    calls.add('maximize');
  }

  @override
  Future<void> unmaximize() async {
    maximized = false;
    calls.add('unmaximize');
  }

  @override
  Future<void> startDragging() async => calls.add('startDragging');

  @override
  Future<void> startResizing(AppWindowResizeEdge edge) async => resizedEdges.add(edge);

  @override
  Future<void> quit() async => calls.add('quit');
}

/// Tray stand-in: remembers menus and tooltips, keeps the menu open
/// until [menuGate] completes
class FakeSystemTrayService implements SystemTrayService {
  final _events = StreamController<SystemTrayEventModel>.broadcast();

  @override
  bool isSupported;

  @override
  bool opensMenuOnClick;

  @override
  bool opensMenuOnLeftClick;

  @override
  bool supportsToolTip;

  Object? initializeError;
  Completer<void>? menuGate;

  final menus = <List<SystemTrayMenuItemModel>>[];
  final toolTips = <String>[];
  var popUpCalls = 0;
  var isDestroyed = false;

  FakeSystemTrayService({
    this.isSupported = true,
    this.opensMenuOnClick = true,
    this.opensMenuOnLeftClick = false,
    this.supportsToolTip = true,
  });

  void emit(SystemTrayEventModel event) => _events.add(event);

  List<String> get lastMenuLabels => [
    for (final item in menus.last)
      if (item case SystemTrayMenuActionModel(:final label)) label,
  ];

  @override
  Stream<SystemTrayEventModel> get events => _events.stream;

  @override
  Future<void> initialize({required String windowsIconAsset, required String iconAsset}) async {
    if (initializeError case final error?) throw error;
  }

  @override
  Future<void> setMenu(List<SystemTrayMenuItemModel> items) async => menus.add(items);

  @override
  Future<void> setToolTip(String toolTip) async => toolTips.add(toolTip);

  @override
  Future<void> popUpMenu() async {
    popUpCalls++;
    await menuGate?.future;
  }

  @override
  Future<void> destroy() async => isDestroyed = true;
}
