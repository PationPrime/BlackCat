import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'lava_lamp_motion.dart';
import 'lava_lamp_palette.dart';

/// Paints the lava lamp: the blob field from the shader, then the grain.
///
/// Cheap on purpose:
/// - its own layer: the pages do not repaint with it, it does not repaint
///   with them;
/// - a timer asks for a frame [framesPerSecond] times a second instead of
///   every screen refresh: the blobs move slowly, and a 120 Hz screen does
///   not paint the whole window 120 times a second for them;
/// - the field is drawn at [fieldScale] of the size and stretched: it is
///   soft anyway, and the shader runs for a fraction of the pixels;
/// - the grain is a small still tile repeated over the area
final class RenderLavaLamp extends RenderBox {
  static const framesPerSecond = 30;
  static const fieldScale = 0.5;

  /// The motion starts where the blobs already met
  static const _startSeconds = 40.0;

  final _clock = Stopwatch();
  final _fieldPaint = Paint()
    ..filterQuality = FilterQuality.low
    ..isAntiAlias = false;
  final _shaderPaint = Paint();

  final ui.FragmentShader _shader;
  LavaLampPalette _palette;
  bool _animating;
  ui.Image? _grain;
  Paint? _grainPaint;
  Timer? _timer;
  var _paintCount = 0;

  RenderLavaLamp({
    required this._shader,
    required this._palette,
    required this._animating,
    ui.Image? grain,
  }) {
    this.grain = grain;
  }

  /// Frames painted: tests see the animation go and stop by it
  int get debugPaintCount => _paintCount;

  set palette(LavaLampPalette value) {
    if (value == _palette) return;

    _palette = value;
    markNeedsPaint();
  }

  bool get animating => _animating;

  set animating(bool value) {
    if (value == _animating) return;

    _animating = value;
    _syncTimer();
  }

  /// The grain tile; none until it is made
  set grain(ui.Image? value) {
    if (identical(value, _grain)) return;

    _grain = value;
    _grainPaint = value == null
        ? null
        : (Paint()
            ..filterQuality = FilterQuality.none
            ..shader = ui.ImageShader(
              value,
              TileMode.repeated,
              TileMode.repeated,
              Matrix4.identity().storage,
              filterQuality: FilterQuality.none,
            ));
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// Pointers go to the pages over it
  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncTimer();
  }

  @override
  void detach() {
    _stop();
    super.detach();
  }

  @override
  void dispose() {
    _stop();
    _shader.dispose();
    super.dispose();
  }

  void _syncTimer() {
    if (!_animating || !attached) {
      _stop();

      return;
    }

    _clock.start();
    _timer ??= Timer.periodic(
      Duration(microseconds: Duration.microsecondsPerSecond ~/ framesPerSecond),
      (_) => markNeedsPaint(),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  double get _seconds =>
      _startSeconds +
      _clock.elapsedMicroseconds / Duration.microsecondsPerSecond;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;

    _paintCount++;

    final canvas = context.canvas;
    final area = offset & size;
    final field = _drawField(_seconds);

    canvas.drawImageRect(
      field,
      Rect.fromLTWH(0, 0, field.width.toDouble(), field.height.toDouble()),
      area,
      _fieldPaint,
    );

    /// The recorded frame keeps the image as long as it needs it
    field.dispose();

    if (_grainPaint case final grainPaint?) {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawRect(Offset.zero & size, grainPaint)
        ..restore();
    }
  }

  /// The blob field drawn into its own small image. There the fragment
  /// coordinates are the image pixels on every graphics backend
  ui.Image _drawField(double seconds) {
    final width = math.max(1, (size.width * fieldScale).ceil());
    final height = math.max(1, (size.height * fieldScale).ceil());
    final shader = _shader;
    var index = 0;

    void put(double value) => shader.setFloat(index++, value);

    put(width.toDouble());
    put(height.toDouble());
    put(seconds);

    for (final blob in LavaLampMotion.at(seconds, aspect: width / height)) {
      put(blob.x);
      put(blob.y);
      put(blob.radius);
      put(blob.weight);
    }

    for (final color in _palette.shaderColors) {
      put(color.r);
      put(color.g);
      put(color.b);
    }

    final recorder = ui.PictureRecorder();

    ui.Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      _shaderPaint..shader = shader,
    );

    final picture = recorder.endRecording();

    try {
      return picture.toImageSync(width, height);
    } finally {
      picture.dispose();
    }
  }
}
