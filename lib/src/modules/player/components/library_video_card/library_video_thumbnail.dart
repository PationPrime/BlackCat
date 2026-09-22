part of 'library_video_card.dart';

/// 16:9 thumbnail on black: a video without one is a black plate.
/// The play button is always in the middle
class _LibraryVideoThumbnail extends StatelessWidget {
  static const _playButtonSize = 56.0;
  static const _watchedBarHeight = 4.0;
  static const _animationDuration = Duration(milliseconds: 150);

  final LibraryVideoModel video;
  final bool hovered;
  final VoidCallback? onPlayPressed;

  const _LibraryVideoThumbnail({
    required this.video,
    required this.hovered,
    this.onPlayPressed,
  });

  Widget _image(BuildContext context) => switch (video.thumbnailPath) {
    final path? => Image.file(
      File(path),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          AnimatedOpacity(
            opacity: frame == null && !wasSynchronouslyLoaded ? 0 : 1,
            duration: _animationDuration,
            child: child,
          ),
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    ),
    null => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    final duration = AppFormatters.duration(
      video.duration == null ? null : video.duration!.inMilliseconds / 1000,
    );
    final watched = video.watchedFraction;

    return AppPressable(
      onPressed: onPlayPressed,
      builder: (context, highlighted) => AnimatedContainer(
        duration: _animationDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hovered || highlighted
                ? context.color.borderHover
                : context.color.border,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: context.color.player,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: hovered ? 1.04 : 1,
                    duration: _animationDuration,
                    child: _image(context),
                  ),
                  Center(
                    child: Tooltip(
                      message: LocaleKeys.app_player_play.tr(),
                      waitDuration: const Duration(milliseconds: 400),
                      child: AnimatedScale(
                        scale: hovered || highlighted ? 1.1 : 1,
                        duration: _animationDuration,
                        child: AnimatedContainer(
                          duration: _animationDuration,
                          width: _playButtonSize,
                          height: _playButtonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hovered || highlighted
                                ? context.color.playerProgress
                                : context.color.playerOverlay,
                            border: Border.all(
                              color: context.color.onPlayer.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Assets.icons.iconPlay.svg(
                              color: context.color.onPlayer,
                              width: 24,
                              height: 24,
                              semanticsLabel: LocaleKeys.app_player_play.tr(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (duration != null)
                    Positioned(
                      right: 8,
                      bottom: 8 + (watched == null ? 0 : _watchedBarHeight),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.color.playerShade,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Text(
                            duration,
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

                  /// Where the user stopped, as on YouTube
                  if (watched != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _watchedBarHeight,
                      child: ColoredBox(
                        color: context.color.playerTrack,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: watched,
                          child: ColoredBox(
                            color: context.color.playerProgress,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
