import 'dart:math' as math;

/// A blob of the lava lamp at a moment: center and radius in heights
/// of the area, and the strength of its field
typedef LavaLampBlob = ({double x, double y, double radius, double weight});

/// Two sines of incommensurable speeds: the motion never repeats
double _wave(double time, double speed, double phase) =>
    0.65 * math.sin(speed * time + phase) +
    0.35 * math.sin(speed * 1.618 * time + phase * 2.3);

/// A point that wanders around its home along slow waves on each axis
final class _Drift {
  /// Home in shares of the width and the height
  final double homeX;
  final double homeY;

  /// How far the point strays, in shares of the width and the height
  final double driftX;
  final double driftY;

  /// Radians a second
  final double speedX;
  final double speedY;
  final double phase;

  const _Drift({
    required this.homeX,
    required this.homeY,
    required this.driftX,
    required this.driftY,
    required this.speedX,
    required this.speedY,
    required this.phase,
  });

  /// In heights of the area
  (double, double) at(double seconds, double aspect) => (
    aspect * (homeX + driftX * _wave(seconds, speedX, phase)),
    homeY + driftY * _wave(seconds, speedY, phase + 1.3),
  );
}

/// A blob that circles around a wandering point while the circle
/// widens and narrows and the blob itself breathes
final class _BlobPath {
  final _Drift center;

  /// Radius of the circle in heights of the area
  final double distance;

  /// Radians a second, the sign is the direction
  final double spin;
  final double phase;

  /// In heights of the area
  final double radius;
  final double weight;

  const _BlobPath({
    required this.center,
    required this.distance,
    required this.spin,
    required this.phase,
    required this.radius,
    required this.weight,
  });

  LavaLampBlob at(double seconds, double aspect) {
    final (centerX, centerY) = center.at(seconds, aspect);
    final angle = spin * seconds + phase;
    final reach = distance * (1 + 0.35 * _wave(seconds, 0.09, phase));

    return (
      x: centerX + reach * math.cos(angle),
      y: centerY + reach * math.sin(angle),
      radius: radius * (1 + 0.1 * math.sin(0.05 * seconds + phase)),
      weight: weight,
    );
  }
}

/// How the blobs of the lava lamp move: most of them hold together
/// in one big mass that wanders, turns and changes its shape, one more
/// drifts on its own and now and then joins it, and a faint one trails
/// around the mass as a glowing wisp
abstract final class LavaLampMotion {
  static const _mass = _Drift(
    homeX: 0.52,
    homeY: 0.5,
    driftX: 0.3,
    driftY: 0.34,
    speedX: 0.052,
    speedY: 0.037,
    phase: 0.7,
  );

  static const _stray = _Drift(
    homeX: 0.3,
    homeY: 0.72,
    driftX: 0.4,
    driftY: 0.42,
    speedX: 0.071,
    speedY: 0.058,
    phase: 4.1,
  );

  static const _paths = [
    _BlobPath(
      center: _mass,
      distance: 0.06,
      spin: 0.11,
      phase: 0,
      radius: 0.34,
      weight: 1,
    ),
    _BlobPath(
      center: _mass,
      distance: 0.32,
      spin: 0.085,
      phase: 1.2,
      radius: 0.28,
      weight: 0.95,
    ),
    _BlobPath(
      center: _mass,
      distance: 0.36,
      spin: -0.065,
      phase: 3.6,
      radius: 0.25,
      weight: 0.9,
    ),

    /// Dense and small: turns the middle of the mass blue
    _BlobPath(
      center: _mass,
      distance: 0.16,
      spin: 0.14,
      phase: 5,
      radius: 0.19,
      weight: 1.3,
    ),
    _BlobPath(
      center: _stray,
      distance: 0,
      spin: 0,
      phase: 2.9,
      radius: 0.24,
      weight: 1,
    ),

    /// Too faint to become lava: only the glow
    _BlobPath(
      center: _mass,
      distance: 0.62,
      spin: -0.05,
      phase: 2.2,
      radius: 0.3,
      weight: 0.36,
    ),
  ];

  /// As many as the shader takes
  static int get count => _paths.length;

  /// The blobs after [seconds] of motion in an area of the [aspect] ratio
  static List<LavaLampBlob> at(double seconds, {required double aspect}) => [
    for (final path in _paths) path.at(seconds, aspect),
  ];
}
