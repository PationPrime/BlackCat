import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/models.dart';

/// Video player of local files
abstract interface class VideoPlayerService {
  /// Every change of [current]
  Stream<VideoPlaybackModel> get playback;

  VideoPlaybackModel get current;

  /// Opens the file and plays it from [start]. Speed and volume stay
  /// as they were
  Future<void> open(String path, {Duration start = Duration.zero});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// 1 is the normal speed
  Future<void> setRate(double rate);

  /// [volume] from 0 to 1
  Future<void> setVolume(double volume);

  /// Muting keeps the volume for unmuting
  Future<void> setMuted(bool muted);

  /// Stops playback and closes the file
  Future<void> stop();

  /// Picture of the open video, fitted into the available space on black
  Widget buildView();
}

final class MediaKitVideoPlayerServiceImpl implements VideoPlayerService {
  final _playback = StreamController<VideoPlaybackModel>.broadcast();

  /// One player for the whole app, never disposed: on Windows every disposed
  /// media_kit player unbalances COM, and after a few the system file dialogs
  /// and drag-and-drop stop working (media-kit/media-kit#1449)
  Player? _player;
  VideoController? _videoController;

  var _current = const VideoPlaybackModel();

  @override
  Stream<VideoPlaybackModel> get playback => _playback.stream;

  @override
  VideoPlaybackModel get current => _current;

  void _update(VideoPlaybackModel Function(VideoPlaybackModel) change) {
    final next = change(_current);

    if (next == _current) return;

    _current = next;
    _playback.add(next);
  }

  Player _ensurePlayer() {
    if (_player case final player?) return player;

    final player = Player();

    _player = player;
    _videoController = VideoController(player);

    final stream = player.stream;

    stream.position.listen(
      (position) => _update((value) => value.copyWith(position: position)),
    );
    stream.duration.listen(
      (duration) => _update((value) => value.copyWith(duration: duration)),
    );
    stream.buffer.listen(
      (buffered) => _update((value) => value.copyWith(buffered: buffered)),
    );
    stream.playing.listen(
      (isPlaying) => _update((value) => value.copyWith(isPlaying: isPlaying)),
    );
    stream.buffering.listen(
      (isBuffering) =>
          _update((value) => value.copyWith(isBuffering: isBuffering)),
    );
    stream.completed.listen(
      (isCompleted) =>
          _update((value) => value.copyWith(isCompleted: isCompleted)),
    );
    stream.rate.listen(
      (rate) => _update((value) => value.copyWith(rate: rate)),
    );
    stream.error.listen(
      (error) => _update((value) => value.copyWith(error: error)),
    );

    return player;
  }

  @override
  Future<void> open(String path, {Duration start = Duration.zero}) async {
    final player = _ensurePlayer();

    _update(
      (value) => VideoPlaybackModel(
        position: start,
        rate: value.rate,
        volume: value.volume,
        isMuted: value.isMuted,
      ),
    );

    await player.open(Media(path, start: start > Duration.zero ? start : null));
    await _applyVolume();
  }

  @override
  Future<void> play() async {
    final player = _ensurePlayer();

    /// A finished video starts over
    if (_current.isCompleted) {
      await player.seek(Duration.zero);
    }

    await player.play();
  }

  @override
  Future<void> pause() => _ensurePlayer().pause();

  @override
  Future<void> seek(Duration position) {
    _update((value) => value.copyWith(position: position, isCompleted: false));

    return _ensurePlayer().seek(position);
  }

  @override
  Future<void> setRate(double rate) => _ensurePlayer().setRate(rate);

  @override
  Future<void> setVolume(double volume) {
    _update(
      (value) => value.copyWith(volume: volume.clamp(0.0, 1.0), isMuted: false),
    );

    return _applyVolume();
  }

  @override
  Future<void> setMuted(bool muted) {
    _update((value) => value.copyWith(isMuted: muted));

    return _applyVolume();
  }

  /// media_kit has no mute of its own: a muted player plays at zero volume
  Future<void> _applyVolume() =>
      _ensurePlayer().setVolume(_current.isMuted ? 0 : _current.volume * 100);

  @override
  Future<void> stop() async => await _player?.stop();

  @override
  Widget buildView() {
    _ensurePlayer();

    return Video(
      controller: _videoController!,
      controls: NoVideoControls,

      /// A desktop player goes on while the window is minimized
      pauseUponEnteringBackgroundMode: false,
    );
  }
}
