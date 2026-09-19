import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/services/services.dart';

const windowsFrame = AppWindowFrameModel(
  isCustom: true,
  showsWindowButtons: true,
  resizeEdges: {
    AppWindowResizeEdge.top,
    AppWindowResizeEdge.topLeft,
    AppWindowResizeEdge.topRight,
  },
);

/// Window stand-in: remembers calls and emits events on request
class FakeAppWindowService implements AppWindowService {
  final _events = StreamController<AppWindowEvent>.broadcast();

  @override
  bool isSupported;

  @override
  AppWindowFrameModel frame;

  bool maximized;
  bool fullScreen = false;
  bool? preventClose;
  Size? minimumSize;
  Object? initializeError;

  final calls = <String>[];
  final resizedEdges = <AppWindowResizeEdge>[];

  FakeAppWindowService({
    this.isSupported = true,
    this.frame = windowsFrame,
    this.maximized = false,
  });

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
  Future<void> setPreventClose(bool preventClose) async =>
      this.preventClose = preventClose;

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
  Future<void> setFullScreen(bool fullScreen) async {
    this.fullScreen = fullScreen;
    calls.add('setFullScreen($fullScreen)');
  }

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> startDragging() async => calls.add('startDragging');

  @override
  Future<void> startResizing(AppWindowResizeEdge edge) async =>
      resizedEdges.add(edge);

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
  Future<void> initialize({
    required String windowsIconAsset,
    required String iconAsset,
  }) async {
    if (initializeError case final error?) throw error;
  }

  @override
  Future<void> setMenu(List<SystemTrayMenuItemModel> items) async =>
      menus.add(items);

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

/// Player stand-in: remembers calls and plays along like the real player.
/// The test moves the position with [emit]
class FakeVideoPlayerService implements VideoPlayerService {
  static const viewKey = ValueKey('fake-video-view');

  final _playback = StreamController<VideoPlaybackModel>.broadcast();
  var _current = const VideoPlaybackModel();

  final calls = <String>[];
  String? openedPath;
  Duration? openedStart;

  /// Duration the opened video reports
  Duration videoDuration;
  Object? openError;

  /// `false`: a seek is not reported, the test reports positions itself
  bool reportsSeeks = true;

  FakeVideoPlayerService({this.videoDuration = const Duration(minutes: 10)});

  void emit(VideoPlaybackModel Function(VideoPlaybackModel playback) change) {
    _current = change(_current);
    _playback.add(_current);
  }

  @override
  Stream<VideoPlaybackModel> get playback => _playback.stream;

  @override
  VideoPlaybackModel get current => _current;

  @override
  Future<void> open(String path, {Duration start = Duration.zero}) async {
    calls.add('open');

    if (openError case final error?) {
      throw PlayerException(const PlayerErrorCodes().playback, cause: error);
    }

    openedPath = path;
    openedStart = start;
    emit(
      (playback) => VideoPlaybackModel(
        position: start,
        duration: videoDuration,
        isPlaying: true,
        rate: playback.rate,
        volume: playback.volume,
        isMuted: playback.isMuted,
      ),
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit((playback) => playback.copyWith(isPlaying: true, isCompleted: false));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit((playback) => playback.copyWith(isPlaying: false));
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek ${position.inSeconds}');

    if (reportsSeeks) {
      emit(
        (playback) => playback.copyWith(position: position, isCompleted: false),
      );
    }
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('rate $rate');
    emit((playback) => playback.copyWith(rate: rate));
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume ${volume.toStringAsFixed(2)}');
    emit((playback) => playback.copyWith(volume: volume, isMuted: false));
  }

  @override
  Future<void> setMuted(bool muted) async {
    calls.add('muted $muted');
    emit((playback) => playback.copyWith(isMuted: muted));
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit((playback) => playback.copyWith(isPlaying: false));
  }

  /// Picture of the video; black by default
  Widget? view;

  @override
  Widget buildView() => KeyedSubtree(
    key: viewKey,
    child: view ?? const ColoredBox(color: Color(0xFF000000)),
  );
}
