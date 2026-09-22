import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Colors of the lava lamp
final class LavaLampPalette {
  /// Background without the lava
  final Color base;

  /// Glow around the lava
  final Color haze;

  /// The lava
  final Color body;

  /// Where the lava is thick
  final Color core;

  /// Where it is the thickest
  final Color deep;

  /// Lies over the lava as a card lies over the background: text on
  /// the background reads as well as in a card
  final Color veil;

  /// Color of the grain specks; its alpha is how dark the darkest one is
  final Color grain;

  const LavaLampPalette({
    required this.base,
    required this.haze,
    required this.body,
    required this.core,
    required this.deep,
    required this.veil,
    required this.grain,
  });

  /// In the order of the shader uniforms. The lava colors come already
  /// under the veil: the shader only mixes them, so the picture is the same
  /// as with the veil laid over it, and no extra layer is drawn
  List<Color> get shaderColors => [
    base,
    for (final lava in [haze, body, core, deep]) Color.alphaBlend(veil, lava),
  ];

  @override
  bool operator ==(Object other) =>
      other is LavaLampPalette &&
      other.base == base &&
      other.haze == haze &&
      other.body == body &&
      other.core == core &&
      other.deep == deep &&
      other.veil == veil &&
      other.grain == grain;

  @override
  int get hashCode => Object.hash(base, haze, body, core, deep, veil, grain);
}

/// The grain of the lava lamp: a still tile of specks, one per logical
/// pixel, repeated over the background. Made once for a grain color
abstract final class LavaLampGrain {
  static const tileSize = 256;

  /// The same specks on every launch
  static const _seed = 20260917;

  static final _tiles = <Color, ui.Image>{};
  static final _making = <Color, Future<ui.Image>>{};

  /// The tile if it is made already
  static ui.Image? made(Color grain) => _tiles[grain];

  static Future<ui.Image> tile(Color grain) =>
      _making[grain] ??= _make(grain).then((image) => _tiles[grain] = image);

  /// Specks of the given color: most pixels stay clear, a few get dark
  static Uint8List pixels(Color grain) {
    final random = math.Random(_seed);
    final pixels = Uint8List(tileSize * tileSize * 4);
    final red = (grain.r * 255).round();
    final green = (grain.g * 255).round();
    final blue = (grain.b * 255).round();

    for (var offset = 0; offset < pixels.length; offset += 4) {
      final t = ((random.nextDouble() - 0.55) / 0.45).clamp(0.0, 1.0);

      /// Smoothstep: soft specks, not a flat grey veil
      final alpha = (t * t * (3 - 2 * t) * grain.a * 255).round();

      pixels
        ..[offset] = red
        ..[offset + 1] = green
        ..[offset + 2] = blue
        ..[offset + 3] = alpha;
    }

    return pixels;
  }

  static Future<ui.Image> _make(Color grain) {
    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(
      pixels(grain),
      tileSize,
      tileSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    return completer.future;
  }
}
