part of 'video_player_dialog.dart';

/// Part of the player a tap lands on: a double tap seeks near the edges
/// and switches full screen in the middle
enum _PlayerZone { rewind, middle, forward }

/// The video with its gestures, keyboard shortcuts, hints and controls
class _VideoPlayerSurface extends StatefulWidget {
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onClose;

  const _VideoPlayerSurface({
    required this.isFullScreen,
    required this.onToggleFullScreen,
    required this.onClose,
  });

  @override
  State<_VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<_VideoPlayerSurface> {
  /// Hints stay on the screen this long after the last change
  static const _hintDuration = Duration(milliseconds: 700);

  static const _digitKeys = [
    PhysicalKeyboardKey.digit0,
    PhysicalKeyboardKey.digit1,
    PhysicalKeyboardKey.digit2,
    PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4,
    PhysicalKeyboardKey.digit5,
    PhysicalKeyboardKey.digit6,
    PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8,
    PhysicalKeyboardKey.digit9,
  ];

  final _focusNode = FocusNode(debugLabel: 'VideoPlayer');

  late final Widget _video;

  var _controlsVisible = true;
  var _controlsHovered = false;

  /// The progress bar is dragged or the speed menu is open
  var _controlsBusy = false;
  Timer? _hideTimer;

  /// Pause and resume hint of the space bar: every press restarts it
  var _flashCount = 0;
  var _flashShowsPlay = false;

  _PlayerZone? _seekHintZone;
  var _seekHintSeconds = 0;
  Timer? _seekHintTimer;

  var _volumeHintVisible = false;
  Timer? _volumeHintTimer;

  /// A single tap waits for a possible second one
  _PlayerZone? _pendingTapZone;
  Timer? _pendingTapTimer;

  /// Side of the last double tap and when it was: taps right after it
  /// seek once more
  _PlayerZone? _tapSeekZone;
  DateTime? _tapSeekAt;

  VideoPlaybackController get _controller =>
      context.read<VideoPlaybackController>();

  @override
  void initState() {
    super.initState();

    _video = context.read<VideoPlayerService>().buildView();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekHintTimer?.cancel();
    _volumeHintTimer?.cancel();
    _pendingTapTimer?.cancel();
    _focusNode.dispose();

    super.dispose();
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }

    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(PlayerConstants.controlsHideDelay, _hideControls);
  }

  void _hideControls() {
    _hideTimer?.cancel();

    if (mounted && _controlsVisible) {
      setState(() => _controlsVisible = false);
    }
  }

  /// A paused video, an error or a busy control keep the controls on
  bool _controlsShown(VideoPlaybackState playbackState) =>
      _controlsVisible ||
      _controlsHovered ||
      _controlsBusy ||
      !playbackState.playback.isPlaying ||
      playbackState.failure != null;

  void _setControlsBusy(bool busy) {
    setState(() => _controlsBusy = busy);

    if (!busy) _scheduleHide();
  }

  _PlayerZone _zoneOf(double dx, double width) {
    final edge = width * PlayerConstants.seekZoneFraction;

    return dx < edge
        ? _PlayerZone.rewind
        : dx > width - edge
        ? _PlayerZone.forward
        : _PlayerZone.middle;
  }

  void _onTapUp(TapUpDetails details, double width) {
    _focusNode.requestFocus();
    _showControls();

    final zone = _zoneOf(details.localPosition.dx, width);
    final now = DateTime.now();

    if (zone != _PlayerZone.middle &&
        zone == _tapSeekZone &&
        now.difference(_tapSeekAt ?? DateTime(0)) <
            PlayerConstants.seekStreakTimeout) {
      _cancelPendingTap();
      _tapSeekAt = now;
      _seek(zone);

      return;
    }

    if (_pendingTapTimer != null && _pendingTapZone == zone) {
      _cancelPendingTap();
      _onDoubleTap(zone, now);

      return;
    }

    /// A tap in another part right after is not a double tap
    if (_pendingTapTimer != null) {
      _cancelPendingTap();
      unawaited(_controller.togglePlay());
    }

    _pendingTapZone = zone;
    _pendingTapTimer = Timer(PlayerConstants.doubleTapTimeout, () {
      _pendingTapTimer = null;
      _pendingTapZone = null;

      unawaited(_controller.togglePlay());
    });
  }

  void _onDoubleTap(_PlayerZone zone, DateTime now) {
    if (zone == _PlayerZone.middle) {
      widget.onToggleFullScreen();

      return;
    }

    _tapSeekZone = zone;
    _tapSeekAt = now;
    _seek(zone);
  }

  void _cancelPendingTap() {
    _pendingTapTimer?.cancel();
    _pendingTapTimer = null;
    _pendingTapZone = null;
  }

  /// Seeks by 10 seconds and shows it on the side; seeks in a row add up
  void _seek(_PlayerZone zone) {
    const step = PlayerConstants.seekStep;

    unawaited(_controller.seekBy(zone == _PlayerZone.forward ? step : -step));

    _seekHintTimer?.cancel();
    _seekHintTimer = Timer(_hintDuration, () {
      if (mounted) setState(() => _seekHintZone = null);
    });

    setState(() {
      _seekHintSeconds =
          (_seekHintZone == zone ? _seekHintSeconds : 0) + step.inSeconds;
      _seekHintZone = zone;
    });
  }

  void _togglePlayWithFlash() {
    setState(() {
      _flashShowsPlay = !_controller.state.playback.isPlaying;
      _flashCount++;
    });

    unawaited(_controller.togglePlay());
  }

  void _showVolumeHint() {
    _volumeHintTimer?.cancel();
    _volumeHintTimer = Timer(_hintDuration, () {
      if (mounted) setState(() => _volumeHintVisible = false);
    });

    setState(() => _volumeHintVisible = true);
  }

  void _changeRate(int step) {
    const rates = PlayerConstants.playbackRates;
    final index = rates.indexOf(_controller.state.playback.rate);
    final next = (index < 0 ? 0 : index + step).clamp(0, rates.length - 1);

    unawaited(_controller.setRate(rates[next]));
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final repeated = event is KeyRepeatEvent;
    final key = event.physicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final playback = _controller.state.playback;

    /// Letters are matched by their place: the shortcuts work in any layout
    switch (key) {
      case PhysicalKeyboardKey.space || PhysicalKeyboardKey.keyK:
        if (!repeated) _togglePlayWithFlash();

        return KeyEventResult.handled;
      case PhysicalKeyboardKey.keyJ || PhysicalKeyboardKey.arrowLeft:
        _seek(_PlayerZone.rewind);
      case PhysicalKeyboardKey.keyL || PhysicalKeyboardKey.arrowRight:
        _seek(_PlayerZone.forward);
      case PhysicalKeyboardKey.keyF:
        if (!repeated) widget.onToggleFullScreen();
      case PhysicalKeyboardKey.keyM:
        if (!repeated) {
          unawaited(_controller.toggleMute());
          _showVolumeHint();
        }
      case PhysicalKeyboardKey.arrowUp:
        unawaited(_controller.changeVolumeBy(PlayerConstants.volumeStep));
        _showVolumeHint();
      case PhysicalKeyboardKey.arrowDown:
        unawaited(_controller.changeVolumeBy(-PlayerConstants.volumeStep));
        _showVolumeHint();
      case PhysicalKeyboardKey.home:
        unawaited(_controller.seekTo(Duration.zero));
      case PhysicalKeyboardKey.end:
        unawaited(_controller.seekTo(playback.duration));
      case PhysicalKeyboardKey.period when shift:
        if (!repeated) _changeRate(1);
      case PhysicalKeyboardKey.comma when shift:
        if (!repeated) _changeRate(-1);
      case PhysicalKeyboardKey.escape:
        if (repeated) return KeyEventResult.handled;

        if (widget.isFullScreen) {
          widget.onToggleFullScreen();
        } else {
          widget.onClose();
        }

        return KeyEventResult.handled;
      case _ when _digitKeys.contains(key):

        /// 0 is the start, 1…9 are 10%…90% of the video, as on YouTube
        unawaited(
          _controller.seekTo(
            playback.duration * (_digitKeys.indexOf(key) / 10),
          ),
        );
      default:
        return KeyEventResult.ignored;
    }

    _showControls();

    return KeyEventResult.handled;
  }

  Widget _center(VideoPlaybackState playbackState) {
    if (playbackState.failure case final failure?) {
      return _VideoPlayerFailure(
        message: failure.message,
        onRetryPressed: _controller.open,
        onClosePressed: widget.onClose,
      );
    }

    if (playbackState.isOpening || playbackState.playback.isBuffering) {
      return SizedBox.square(
        dimension: 48,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: context.color.onPlayer,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<VideoPlaybackController, VideoPlaybackState>(
    builder: (context, playbackState) {
      final controlsShown = _controlsShown(playbackState);
      final playback = playbackState.playback;

      return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          /// The cursor hides together with the controls, as on YouTube
          cursor: controlsShown ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _showControls(),
          onExit: (_) {
            if (playback.isPlaying) _hideControls();
          },
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: context.color.player, child: _video),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _onTapUp(details, constraints.maxWidth),
                ),
                if (_seekHintZone case final zone?)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    width:
                        constraints.maxWidth * PlayerConstants.seekZoneFraction,
                    left: zone == _PlayerZone.rewind ? 0 : null,
                    right: zone == _PlayerZone.forward ? 0 : null,
                    child: IgnorePointer(
                      child: _VideoSeekIndicator(
                        forward: zone == _PlayerZone.forward,
                        seconds: _seekHintSeconds,
                      ),
                    ),
                  ),
                Center(child: _center(playbackState)),
                if (_flashCount > 0)
                  Center(
                    child: IgnorePointer(
                      child: _VideoPlayerFlash(
                        key: ValueKey(_flashCount),
                        showsPlay: _flashShowsPlay,
                      ),
                    ),
                  ),
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _volumeHintVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Center(
                        child: _VideoVolumeHint(
                          volume: playback.volume,
                          isMuted: playback.isMuted,
                          iconSize: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _VideoPlayerFade(
                    visible: controlsShown,
                    child: _VideoPlayerTopBar(
                      title: playbackState.video.title,
                      onClosePressed: widget.onClose,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _controlsHovered = true),
                    onExit: (_) => setState(() => _controlsHovered = false),
                    child: _VideoPlayerFade(
                      visible: controlsShown,
                      child: _VideoPlayerControls(
                        playback: playback,
                        isFullScreen: widget.isFullScreen,
                        onTogglePlayPressed: _controller.togglePlay,
                        onRewindPressed: () => _seek(_PlayerZone.rewind),
                        onForwardPressed: () => _seek(_PlayerZone.forward),
                        onSeek: _controller.seekTo,
                        onRateChanged: _controller.setRate,
                        onVolumeChanged: _controller.setVolume,
                        onMuteToggled: _controller.toggleMute,
                        onToggleFullScreenPressed: widget.onToggleFullScreen,
                        onBusyChanged: _setControlsBusy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Controls fade out together; hidden ones take no taps
class _VideoPlayerFade extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _VideoPlayerFade({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: child,
    ),
  );
}

/// The video could not be played: the reason, a retry and closing
class _VideoPlayerFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetryPressed;
  final VoidCallback onClosePressed;

  const _VideoPlayerFailure({
    required this.message,
    required this.onRetryPressed,
    required this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: context.color.onPlayerSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyRegular.copyWith(
              color: context.color.onPlayer,
            ),
          ),
          const SizedBox(height: 20),
          ExcludeFocus(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                AppPrimaryButton(
                  title: LocaleKeys.app_player_retry.tr(),
                  onPressed: onRetryPressed,
                ),
                AppSecondaryButton(
                  title: LocaleKeys.app_player_close.tr(),
                  onPressed: onClosePressed,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
