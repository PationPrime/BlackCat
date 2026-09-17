part of 'video_player_dialog.dart';

/// Seek hint over a side of the video: a light arc, running arrows
/// and the seconds seeked in a row
class _VideoSeekIndicator extends StatefulWidget {
  final bool forward;
  final int seconds;

  const _VideoSeekIndicator({required this.forward, required this.seconds});

  @override
  State<_VideoSeekIndicator> createState() => _VideoSeekIndicatorState();
}

class _VideoSeekIndicatorState extends State<_VideoSeekIndicator>
    with SingleTickerProviderStateMixin {
  static const _arrowCount = 3;

  late final _arrows = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _arrows.dispose();

    super.dispose();
  }

  /// Arrows light up one after another toward the seek direction
  double _arrowOpacity(int index) {
    final phase =
        (_arrows.value * (_arrowCount + 1) - index) % (_arrowCount + 1);

    return phase < 1 ? 1 - (phase - 0.5).abs() : 0.25;
  }

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _SeekZoneClipper(forward: widget.forward),
    child: ColoredBox(
      color: context.color.playerHover,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _arrows,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < _arrowCount; index++)
                    Opacity(
                      opacity: _arrowOpacity(
                        widget.forward ? index : _arrowCount - 1 - index,
                      ).clamp(0.0, 1.0),
                      child: Transform.flip(
                        flipX: !widget.forward,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: context.color.onPlayer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.app_player_seek_seconds.tr(
                namedArgs: {'seconds': '${widget.seconds}'},
              ),
              style: context.text.captionMedium.copyWith(
                color: context.color.onPlayer,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The zone bulges toward the middle of the video with its inner edge
class _SeekZoneClipper extends CustomClipper<Path> {
  final bool forward;

  const _SeekZoneClipper({required this.forward});

  @override
  Path getClip(Size size) {
    final left = forward ? 0.0 : -size.width;

    return Path()..addOval(
      Rect.fromLTWH(
        left,
        -size.height * 0.25,
        size.width * 2,
        size.height * 1.5,
      ),
    );
  }

  @override
  bool shouldReclip(_SeekZoneClipper oldClipper) =>
      oldClipper.forward != forward;
}
