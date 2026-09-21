import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:black_cat/src/app/constants/constants.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/failure/failure.dart';
import 'package:black_cat/src/app/logger/app_logger.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/services/services.dart';

import '../video_library_controller/video_library_controller.dart';

part 'video_playback_state.dart';

/// Playback of one library video in the player.
///
/// Where the user stopped is saved while the video plays, on pause,
/// at the end and when the player closes. The next opening continues
/// from there
final class VideoPlaybackController extends Cubit<VideoPlaybackState> {
  static const _appLogger = AppLogger(where: 'VideoPlaybackController');

  /// The player reports the old position for a moment after a seek
  static const _seekSettleTime = Duration(seconds: 2);
  static const _seekArrivalTolerance = Duration(seconds: 1);

  final VideoPlayerService _videoPlayerService;
  final VideoLibraryController _videoLibraryController;

  /// The position on the screen changes no more often
  final Duration _positionUpdateInterval;

  /// The watch position is saved no more often while playing
  final Duration _positionSaveInterval;

  StreamSubscription<VideoPlaybackModel>? _playbackSubscription;

  /// The player has reported the opened video: before that the position
  /// is not known and is not saved
  var _hasPlayback = false;

  DateTime? _shownAt;
  VideoPlaybackModel? _deferredPlayback;
  Timer? _deferredTimer;

  var _savedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Duration? _seekTarget;
  var _seekStartedAt = DateTime.fromMillisecondsSinceEpoch(0);

  VideoPlaybackController({
    required this._videoPlayerService,
    required this._videoLibraryController,
    required LibraryVideoModel video,
    this._positionUpdateInterval = PlayerConstants.positionUpdateInterval,
    this._positionSaveInterval = PlayerConstants.positionSaveInterval,
  }) : super(VideoPlaybackInitialState(video: video));

  void _safeEmit(VideoPlaybackState state) {
    if (isClosed) return;

    emit(state);
  }

  /// Opens the video where the user stopped last time
  Future<void> open() async {
    /// Cancelling may wait for the platform: the new subscription starts anyway
    unawaited(_playbackSubscription?.cancel());

    _hasPlayback = false;

    /// The start position is already saved: the first save is due later
    _savedAt = DateTime.now();
    _playbackSubscription = _videoPlayerService.playback.listen(_onPlayback);

    _safeEmit(
      state.copyWith(
        isOpening: true,
        playback: _videoPlayerService.current.copyWith(
          position: state.video.resumePosition,
          duration: state.video.duration ?? Duration.zero,
          isPlaying: false,
          isCompleted: false,
          clearError: true,
        ),
        clearFailure: true,
      ),
    );

    try {
      await _videoPlayerService.open(
        state.video.path,
        start: state.video.resumePosition,
      );
    } catch (error, stackTrace) {
      _showFailure(error, stackTrace);
    }

    _safeEmit(state.copyWith(isOpening: false));
  }

  void _showFailure(Object error, StackTrace? stackTrace) {
    final failure = const PlayerErrorHandler().handleError(
      PlayerException(const PlayerErrorCodes().playback, cause: error),
      stackTrace: stackTrace,
    );

    _appLogger.logFailure(failure, 'Failed to play the video');

    _safeEmit(state.copyWith(isOpening: false, failure: failure));
  }

  void _onPlayback(VideoPlaybackModel playback) {
    if (isClosed) return;

    if (playback.duration > Duration.zero) {
      _hasPlayback = true;
    }

    /// At the end the player reports the time of the last frame:
    /// a finished video shows the whole bar
    final settled = playback.copyWith(
      position: playback.isCompleted && playback.duration > Duration.zero
          ? playback.duration
          : _settledPosition(playback),
    );

    if (settled.error case final error? when error != state.playback.error) {
      _showFailure(error, null);
    }

    /// Only the position moved: shown at a steady pace
    final positionOnly =
        settled.copyWith(
          position: state.playback.position,
          buffered: state.playback.buffered,
        ) ==
        state.playback;
    final sinceShown = DateTime.now().difference(
      _shownAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );

    if (positionOnly && sinceShown < _positionUpdateInterval) {
      _deferredPlayback = settled;
      _deferredTimer ??= Timer(_positionUpdateInterval - sinceShown, () {
        _deferredTimer = null;

        if (_deferredPlayback case final deferred?) {
          _deferredPlayback = null;
          _show(deferred);
        }
      });

      return;
    }

    _cancelDeferred();
    _show(settled);
  }

  /// Right after a seek the screen keeps the target position until
  /// the player gets there
  Duration _settledPosition(VideoPlaybackModel playback) {
    final target = _seekTarget;

    if (target == null) return playback.position;

    final arrived = (playback.position - target).abs() <= _seekArrivalTolerance;
    final expired = DateTime.now().difference(_seekStartedAt) > _seekSettleTime;

    if (arrived || expired) {
      _seekTarget = null;

      return playback.position;
    }

    return target;
  }

  void _cancelDeferred() {
    _deferredTimer?.cancel();
    _deferredTimer = null;
    _deferredPlayback = null;
  }

  void _show(VideoPlaybackModel playback) {
    final previous = state.playback;
    final now = DateTime.now();

    _shownAt = now;
    _safeEmit(state.copyWith(playback: playback));

    final finished = playback.isCompleted && !previous.isCompleted;
    final paused = previous.isPlaying && !playback.isPlaying;
    final saveDue =
        playback.isPlaying && now.difference(_savedAt) >= _positionSaveInterval;

    if (finished || paused || saveDue) {
      unawaited(_savePosition());
    }
  }

  /// The latest known playback, even if not shown yet
  VideoPlaybackModel get _latest => _deferredPlayback ?? state.playback;

  Future<void> _savePosition() async {
    if (!_hasPlayback) return;

    final playback = _latest;

    _savedAt = DateTime.now();

    await _videoLibraryController.savePosition(
      state.video.id,
      position: playback.isCompleted ? playback.duration : playback.position,
      duration: playback.duration,
    );
  }

  Future<void> togglePlay() => _latest.isPlaying ? pause() : play();

  Future<void> play() => _run(_videoPlayerService.play);

  Future<void> pause() => _run(_videoPlayerService.pause);

  /// Seeks by [offset] from the current position: back if negative
  Future<void> seekBy(Duration offset) =>
      seekTo((_seekTarget ?? _latest.position) + offset);

  Future<void> seekTo(Duration position) {
    final duration = _latest.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : duration > Duration.zero && position > duration
        ? duration
        : position;

    _seekTarget = target;
    _seekStartedAt = DateTime.now();
    _cancelDeferred();
    _show(_latest.copyWith(position: target, isCompleted: false));

    return _run(() => _videoPlayerService.seek(target));
  }

  Future<void> setRate(double rate) =>
      _run(() => _videoPlayerService.setRate(rate));

  /// [volume] from 0 to 1; changing it unmutes
  Future<void> setVolume(double volume) =>
      _run(() => _videoPlayerService.setVolume(volume.clamp(0.0, 1.0)));

  Future<void> changeVolumeBy(double delta) =>
      setVolume(_latest.volume + delta);

  Future<void> toggleMute() =>
      _run(() => _videoPlayerService.setMuted(!_latest.isMuted));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _showFailure(error, stackTrace);
    }
  }

  void dismissFailure() => _safeEmit(state.copyWith(clearFailure: true));

  /// Saves where the user stopped and closes the video
  @override
  Future<void> close() async {
    _cancelDeferred();

    /// Cancelling may wait for the platform: the player closes anyway
    unawaited(_playbackSubscription?.cancel());

    await _savePosition();

    try {
      await _videoPlayerService.stop();
    } catch (error, stackTrace) {
      _appLogger.logError(
        'Failed to stop the player: $error',
        stackTrace: stackTrace,
      );
    }

    await super.close();
  }
}
