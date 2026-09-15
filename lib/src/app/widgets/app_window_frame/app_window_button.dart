part of 'app_window_frame.dart';

enum _AppWindowGlyph { minimize, maximize, restore, close }

/// Title bar button of Windows proportions with a thin line glyph
class _AppWindowButton extends StatelessWidget {
  static const _width = 46.0;
  static const _glyphSize = 10.0;

  final _AppWindowGlyph glyph;

  /// Label for the screen reader. The title bar lies above the navigator:
  /// there is no overlay for a tooltip
  final String semanticLabel;
  final VoidCallback? onPressed;

  const _AppWindowButton({
    required this.glyph,
    required this.semanticLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isClose = glyph == _AppWindowGlyph.close;

    return Semantics(
      label: semanticLabel,
      child: AppPressable(
        onPressed: onPressed,
        builder: (context, highlighted) => AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: _width,
          height: AppWindowFrame.titleBarHeight,
          alignment: Alignment.center,
          color: highlighted
              ? isClose
                    ? context.color.windowCloseHover
                    : context.color.hoverOverlay
              : context.color.transparent,
          child: CustomPaint(
            size: const Size.square(_glyphSize),
            painter: _AppWindowGlyphPainter(
              glyph: glyph,
              color: highlighted && isClose
                  ? context.color.onWindowCloseHover
                  : context.color.iconPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppWindowGlyphPainter extends CustomPainter {
  final _AppWindowGlyph glyph;
  final Color color;

  const _AppWindowGlyphPainter({required this.glyph, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    /// Half-pixel offset keeps one-pixel lines sharp
    final bounds = (Offset.zero & size).deflate(0.5);

    switch (glyph) {
      case _AppWindowGlyph.minimize:
        canvas.drawLine(
          Offset(bounds.left, bounds.center.dy),
          Offset(bounds.right, bounds.center.dy),
          paint,
        );
      case _AppWindowGlyph.maximize:
        canvas.drawRect(bounds, paint);
      case _AppWindowGlyph.restore:
        const shift = 2.0;
        final front = Rect.fromLTRB(
          bounds.left,
          bounds.top + shift,
          bounds.right - shift,
          bounds.bottom,
        );

        canvas
          ..drawRect(front, paint)
          ..drawPath(
            Path()
              ..moveTo(bounds.left + shift, front.top)
              ..lineTo(bounds.left + shift, bounds.top)
              ..lineTo(bounds.right, bounds.top)
              ..lineTo(bounds.right, front.bottom - shift)
              ..lineTo(front.right, front.bottom - shift),
            paint,
          );
      case _AppWindowGlyph.close:
        canvas
          ..drawLine(bounds.topLeft, bounds.bottomRight, paint)
          ..drawLine(bounds.topRight, bounds.bottomLeft, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppWindowGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
