import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// The app cat sitting face on, its tail wrapped around the front paws:
/// the logo next to the app name.
///
/// The cat is black in both themes, so in the dark one a thin outline
/// keeps it apart from the background
class AppCatLogo extends StatelessWidget {
  /// Height of the logo; its width follows the drawing
  final double size;

  const AppCatLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * _CatPainter.aspectRatio, size),
    painter: _CatPainter(
      fur: context.color.logo,
      outline: context.color.logoOutline,
      detail: context.color.logoDetail,
      eyes: context.color.accent,
    ),
  );
}

/// Draws the cat of [_ink] scaled to the widget. The lines keep their width
/// on the screen, so the logo stays neat at any size
class _CatPainter extends CustomPainter {
  /// What the drawing takes of its own coordinates
  static const _ink = Rect.fromLTRB(12, 1, 84, 111);

  /// Room left around the drawing for the outline, in pixels
  static const _outlineSpace = 2.4;

  static double get aspectRatio => _ink.width / _ink.height;

  final Color fur;
  final Color outline;
  final Color detail;
  final Color eyes;

  const _CatPainter({
    required this.fur,
    required this.outline,
    required this.detail,
    required this.eyes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      (size.width - _outlineSpace) / _ink.width,
      (size.height - _outlineSpace) / _ink.height,
    );

    if (scale <= 0) return;

    canvas.save();
    canvas.translate(
      (size.width - _ink.width * scale) / 2 - _ink.left * scale,
      (size.height - _ink.height * scale) / 2 - _ink.top * scale,
    );
    canvas.scale(scale);

    final line = math.max(1.0, math.min(size.height / 24, 2.4)) / scale;
    final head = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(50, 33), width: 52, height: 44),
      );
    final paws = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(42, 97), width: 14, height: 10),
      )
      ..addOval(
        Rect.fromCenter(center: const Offset(58, 97), width: 14, height: 10),
      );
    final tail = _tail();

    /// One outline around the whole cat, not around every part of it
    final silhouette = [head, _ear(left: true), _ear(left: false), paws, tail]
        .fold(
          _body(),
          (whole, part) => Path.combine(PathOperation.union, whole, part),
        );

    canvas.drawPath(silhouette, Paint()..color = fur);

    if (outline.a > 0) {
      canvas.drawPath(
        silhouette,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = line,
      );
    }

    /// The tail lies in front of the paws: their lines stay inside the cat
    canvas.save();
    canvas.clipPath(silhouette);

    /// Softer than the outline: the tail and the paws only need to be told
    /// apart from the fur
    final inside = Paint()
      ..color = detail
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(paws, inside)
      ..drawPath(tail, Paint()..color = fur)
      ..drawPath(tail, inside)
      ..restore();

    final details = Paint()..color = detail;

    canvas
      ..drawPath(_innerEar(left: true), details)
      ..drawPath(_innerEar(left: false), details)
      ..drawPath(_nose(), details);

    for (final x in const [38.0, 62.0]) {
      canvas
        ..drawOval(
          Rect.fromCenter(center: Offset(x, 33), width: 11, height: 12.5),
          Paint()..color = eyes,
        )
        ..drawOval(
          Rect.fromCenter(center: Offset(x, 33), width: 3.8, height: 7.6),
          Paint()..color = fur,
        );
    }

    canvas.restore();
  }

  /// Sitting body: shoulders under the head widening to the haunches
  static Path _body() => Path()
    ..moveTo(33, 50)
    ..cubicTo(27, 64, 20, 84, 18, 100)
    ..quadraticBezierTo(17, 110, 28, 110)
    ..lineTo(72, 110)
    ..quadraticBezierTo(83, 110, 82, 100)
    ..cubicTo(80, 84, 73, 64, 67, 50)
    ..close();

  static Path _ear({required bool left}) => _mirrored(
    left,
    (x) => Path()
      ..moveTo(x(29), 30)
      ..lineTo(x(23), 6)
      ..quadraticBezierTo(x(22), 1, x(28), 4)
      ..lineTo(x(47), 16)
      ..close(),
  );

  static Path _innerEar({required bool left}) => _mirrored(
    left,
    (x) => Path()
      ..moveTo(x(31), 26)
      ..lineTo(x(27), 12)
      ..lineTo(x(41), 20)
      ..close(),
  );

  /// The tail comes from behind the right haunch and ends in front
  /// of the left paw
  static Path _tail() => Path()
    ..moveTo(81, 99)
    ..cubicTo(84, 106, 70, 111, 50, 111)
    ..cubicTo(34, 111, 20, 106, 14, 92)
    ..cubicTo(12.5, 88, 17, 86.5, 18.5, 90)
    ..cubicTo(21, 97, 28, 100, 42, 101)
    ..cubicTo(58, 102, 72, 100, 78, 86)
    ..close();

  static Path _nose() => Path()
    ..moveTo(46.5, 43)
    ..lineTo(53.5, 43)
    ..lineTo(50, 47.5)
    ..close();

  /// The cat is symmetric: the right side is the left one mirrored
  static Path _mirrored(
    bool left,
    Path Function(double Function(double x)) draw,
  ) => draw(left ? (x) => x : (x) => 100 - x);

  @override
  bool shouldRepaint(_CatPainter oldDelegate) =>
      oldDelegate.fur != fur ||
      oldDelegate.outline != outline ||
      oldDelegate.detail != detail ||
      oldDelegate.eyes != eyes;
}
