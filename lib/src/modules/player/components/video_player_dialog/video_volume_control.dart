part of 'video_player_dialog.dart';

String _volumeIcon({required double volume, required bool isMuted}) =>
    isMuted || volume <= 0
    ? Assets.icons.iconVolumeMute.path
    : volume < 0.5
    ? Assets.icons.iconVolumeMin.path
    : Assets.icons.iconVolumeMax.path;

/// Mute button with a volume slider that slides out under the cursor
class _VideoVolumeControl extends StatefulWidget {
  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggled;
  final double iconSize;

  const _VideoVolumeControl({
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onMuteToggled,
    this.iconSize = 24,
  });

  @override
  State<_VideoVolumeControl> createState() => _VideoVolumeControlState();
}

class _VideoVolumeControlState extends State<_VideoVolumeControl> {
  static const _sliderWidth = 72.0;
  static const _knobSize = 12.0;

  var _hovered = false;
  var _dragging = false;

  void _setVolumeAt(double dx) =>
      widget.onVolumeChanged((dx / _sliderWidth).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final shown = widget.isMuted ? 0.0 : widget.volume;
    final expanded = _hovered || _dragging;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VideoPlayerButton(
            icon: _volumeIcon(volume: widget.volume, isMuted: widget.isMuted),
            tooltip: widget.isMuted || widget.volume <= 0
                ? LocaleKeys.app_player_controls_unmute.tr()
                : LocaleKeys.app_player_controls_mute.tr(),
            onPressed: widget.onMuteToggled,
            iconSize: widget.iconSize,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: expanded ? _sliderWidth + _knobSize : 0,
            height: 44,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: _sliderWidth + _knobSize,
              maxWidth: _sliderWidth + _knobSize,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _knobSize / 2),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _setVolumeAt(details.localPosition.dx),
                    onHorizontalDragStart: (details) {
                      setState(() => _dragging = true);
                      _setVolumeAt(details.localPosition.dx);
                    },
                    onHorizontalDragUpdate: (details) =>
                        _setVolumeAt(details.localPosition.dx),
                    onHorizontalDragEnd: (_) =>
                        setState(() => _dragging = false),
                    onHorizontalDragCancel: () =>
                        setState(() => _dragging = false),
                    child: SizedBox(
                      width: _sliderWidth,
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 3,
                            color: context.color.playerTrack,
                          ),
                          Container(
                            width: _sliderWidth * shown,
                            height: 3,
                            color: context.color.onPlayer,
                          ),
                          Positioned(
                            left: _sliderWidth * shown - _knobSize / 2,
                            child: Container(
                              width: _knobSize,
                              height: _knobSize,
                              decoration: BoxDecoration(
                                color: context.color.onPlayer,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Volume after the arrows or M: a pill at the top of the video
class _VideoVolumeHint extends StatelessWidget {
  final double volume;
  final bool isMuted;
  final double iconSize;

  const _VideoVolumeHint({
    required this.volume,
    required this.isMuted,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.color.playerOverlay,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            _volumeIcon(volume: volume, isMuted: isMuted),
            height: iconSize,
            width: iconSize,
            color: context.color.onPlayer,
          ),
          const SizedBox(width: 8),
          Text(
            '${isMuted ? 0 : (volume * 100).round()}%',
            style: context.text.captionMedium.copyWith(
              color: context.color.onPlayer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}
