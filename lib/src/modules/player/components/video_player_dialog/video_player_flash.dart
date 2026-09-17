part of 'video_player_dialog.dart';

/// Pause or resume after the space bar: the icon grows and fades
/// in the middle of the video
class _VideoPlayerFlash extends StatefulWidget {
  /// The video resumed: the play icon. Paused: the pause icon
  final bool showsPlay;

  const _VideoPlayerFlash({super.key, required this.showsPlay});

  @override
  State<_VideoPlayerFlash> createState() => _VideoPlayerFlashState();
}

class _VideoPlayerFlashState extends State<_VideoPlayerFlash>
    with SingleTickerProviderStateMixin {
  static const _size = 76.0;

  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();

  @override
  void dispose() {
    _animation.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) {
      final progress = Curves.easeOut.transform(_animation.value);

      return Opacity(
        opacity: 1 - progress,
        child: Transform.scale(scale: 0.9 + 0.5 * progress, child: child),
      );
    },
    child: Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: context.color.playerOverlay,
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.showsPlay ? Icons.play_arrow_rounded : Icons.pause_rounded,
        size: 44,
        color: context.color.onPlayer,
      ),
    ),
  );
}
