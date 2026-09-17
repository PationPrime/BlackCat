part of 'video_player_dialog.dart';

/// Player buttons: white icons without a frame, as on YouTube
class _VideoPlayerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  const _VideoPlayerButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    iconColor: context.color.onPlayer,
    hoverColor: context.color.playerHover,
    size: 44,
    iconSize: iconSize,
  );
}

/// Video title and closing over the top of the video
class _VideoPlayerTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onClosePressed;

  const _VideoPlayerTopBar({required this.title, required this.onClosePressed});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [context.color.playerShade, context.color.transparent],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.header5Semibold.copyWith(
                color: context.color.onPlayer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ExcludeFocus(
            child: _VideoPlayerButton(
              icon: Icons.close_rounded,
              tooltip: LocaleKeys.app_player_controls_close.tr(),
              onPressed: onClosePressed,
              iconSize: 26,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Progress bar and buttons under the video. Play and pause are on the left
class _VideoPlayerControls extends StatelessWidget {
  final VideoPlaybackModel playback;
  final bool isFullScreen;
  final VoidCallback onTogglePlayPressed;
  final VoidCallback onRewindPressed;
  final VoidCallback onForwardPressed;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggled;
  final VoidCallback onToggleFullScreenPressed;

  /// The progress bar is dragged or the speed menu is open: the controls
  /// must not hide meanwhile
  final ValueChanged<bool> onBusyChanged;

  const _VideoPlayerControls({
    required this.playback,
    required this.isFullScreen,
    required this.onTogglePlayPressed,
    required this.onRewindPressed,
    required this.onForwardPressed,
    required this.onSeek,
    required this.onRateChanged,
    required this.onVolumeChanged,
    required this.onMuteToggled,
    required this.onToggleFullScreenPressed,
    required this.onBusyChanged,
  });

  static String _time(Duration duration) =>
      AppFormatters.duration(duration.inSeconds) ?? '0:00';

  (IconData, String) get _playButton => playback.isCompleted
      ? (Icons.replay_rounded, LocaleKeys.app_player_controls_replay.tr())
      : playback.isPlaying
      ? (Icons.pause_rounded, LocaleKeys.app_player_controls_pause.tr())
      : (Icons.play_arrow_rounded, LocaleKeys.app_player_controls_play.tr());

  @override
  Widget build(BuildContext context) {
    final (playIcon, playTooltip) = _playButton;

    /// The controls take no keyboard focus: the space bar and the letters
    /// always reach the player
    return ExcludeFocus(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.color.transparent, context.color.playerShade],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 40, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VideoProgressBar(
                position: playback.position,
                duration: playback.duration,
                buffered: playback.buffered,
                onSeek: onSeek,
                onScrubbingChanged: onBusyChanged,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _VideoPlayerButton(
                    icon: playIcon,
                    tooltip: playTooltip,
                    onPressed: onTogglePlayPressed,
                    iconSize: 32,
                  ),
                  _VideoPlayerButton(
                    icon: Icons.replay_10_rounded,
                    tooltip: LocaleKeys.app_player_controls_rewind.tr(),
                    onPressed: onRewindPressed,
                  ),
                  _VideoPlayerButton(
                    icon: Icons.forward_10_rounded,
                    tooltip: LocaleKeys.app_player_controls_forward.tr(),
                    onPressed: onForwardPressed,
                  ),
                  _VideoVolumeControl(
                    volume: playback.volume,
                    isMuted: playback.isMuted,
                    onVolumeChanged: onVolumeChanged,
                    onMuteToggled: onMuteToggled,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${_time(playback.position)} / ${_time(playback.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: context.text.captionMedium.copyWith(
                        color: context.color.onPlayer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _VideoSpeedButton(
                    rate: playback.rate,
                    onRateChanged: onRateChanged,
                    onMenuChanged: onBusyChanged,
                  ),
                  _VideoPlayerButton(
                    icon: isFullScreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: isFullScreen
                        ? LocaleKeys.app_player_controls_exit_full_screen.tr()
                        : LocaleKeys.app_player_controls_full_screen.tr(),
                    onPressed: onToggleFullScreenPressed,
                    iconSize: 30,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
