part of 'video_player_dialog.dart';

/// YouTube-like progress bar: thickens under the cursor, shows the time
/// at the cursor, seeks on a click and while dragged
class _VideoProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<bool> onScrubbingChanged;

  const _VideoProgressBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    required this.onScrubbingChanged,
  });

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  static const _height = 20.0;
  static const _barHeight = 3.0;
  static const _activeBarHeight = 5.0;
  static const _knobSize = 13.0;
  static const _animationDuration = Duration(milliseconds: 100);

  /// A dragged bar seeks no more often: every seek decodes a frame
  static const _dragSeekInterval = Duration(milliseconds: 150);

  double? _hoverFraction;
  double? _dragFraction;
  var _lastDragSeek = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _active => _hoverFraction != null || _dragFraction != null;

  double _fraction(Duration value) => widget.duration <= Duration.zero
      ? 0
      : (value.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0);

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  Duration _durationAt(double fraction) => widget.duration * fraction;

  void _seek(double fraction) => widget.onSeek(_durationAt(fraction));

  void _onDragStart(double fraction) {
    setState(() => _dragFraction = fraction);
    widget.onScrubbingChanged(true);
    _lastDragSeek = DateTime.now();
    _seek(fraction);
  }

  void _onDragUpdate(double fraction) {
    setState(() => _dragFraction = fraction);

    final now = DateTime.now();

    if (now.difference(_lastDragSeek) >= _dragSeekInterval) {
      _lastDragSeek = now;
      _seek(fraction);
    }
  }

  void _onDragEnd() {
    final fraction = _dragFraction;

    setState(() => _dragFraction = null);
    widget.onScrubbingChanged(false);

    if (fraction != null) _seek(fraction);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final played = _dragFraction ?? _fraction(widget.position);
      final pointer = _dragFraction ?? _hoverFraction;
      final barHeight = _active ? _activeBarHeight : _barHeight;
      final enabled = widget.duration > Duration.zero;

      Widget segment(double fraction, Color color) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        heightFactor: 1,
        child: ColoredBox(color: color),
      );

      return MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onHover: (event) => setState(
          () => _hoverFraction = _fractionAt(event.localPosition.dx, width),
        ),
        onExit: (_) => setState(() => _hoverFraction = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (details) => _seek(_fractionAt(details.localPosition.dx, width))
              : null,
          onHorizontalDragStart: enabled
              ? (details) =>
                    _onDragStart(_fractionAt(details.localPosition.dx, width))
              : null,
          onHorizontalDragUpdate: enabled
              ? (details) =>
                    _onDragUpdate(_fractionAt(details.localPosition.dx, width))
              : null,
          onHorizontalDragEnd: enabled ? (_) => _onDragEnd() : null,
          onHorizontalDragCancel: enabled ? _onDragEnd : null,
          child: SizedBox(
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: _animationDuration,
                  height: barHeight,
                  color: context.color.playerTrack,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      segment(
                        _fraction(widget.buffered),
                        context.color.playerBuffered,
                      ),
                      if (_hoverFraction case final hover? when hover > played)
                        segment(hover, context.color.playerBuffered),
                      segment(played, context.color.playerProgress),
                    ],
                  ),
                ),
                Positioned(
                  left: played * width - _knobSize / 2,
                  child: AnimatedScale(
                    scale: _active ? 1 : 0,
                    duration: _animationDuration,
                    child: Container(
                      width: _knobSize,
                      height: _knobSize,
                      decoration: BoxDecoration(
                        color: context.color.playerProgress,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                if (pointer != null && enabled)
                  Positioned(
                    bottom: _height + 4,
                    left: (pointer * width - 32).clamp(0.0, width - 64),
                    width: 64,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.color.playerMenu,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            AppFormatters.duration(
                                  _durationAt(pointer).inSeconds,
                                ) ??
                                '',
                            style: context.text.captionMedium.copyWith(
                              color: context.color.onPlayer,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
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
