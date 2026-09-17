import 'dart:math' as math;

/// Shared speed limit of all connections of a download.
///
/// Every chunk reserves its time slot: at the limit, bytes are spread evenly
/// over time. Unused time of up to a second is given back as a burst
final class SpeedLimiter {
  static const _burst = Duration(seconds: 1);

  final Stopwatch _clock;

  int? _bytesPerSecond;

  /// When the next byte may pass, in microseconds of [_clock]
  double _nextSlot = 0;

  SpeedLimiter({this._bytesPerSecond, Stopwatch? clock})
    : _clock = clock ?? (Stopwatch()..start());

  int? get bytesPerSecond => _bytesPerSecond;

  set bytesPerSecond(int? value) {
    _bytesPerSecond = value == null || value <= 0 ? null : value;
    _nextSlot = _clock.elapsedMicroseconds.toDouble();
  }

  /// How long [bytes] have to wait; zero without a limit
  Duration reserve(int bytes) {
    final limit = _bytesPerSecond;

    if (limit == null || bytes <= 0) return Duration.zero;

    final now = _clock.elapsedMicroseconds.toDouble();
    final start = math.max(_nextSlot, now - _burst.inMicroseconds);

    _nextSlot = start + bytes * Duration.microsecondsPerSecond / limit;

    final wait = _nextSlot - now;

    return wait <= 0 ? Duration.zero : Duration(microseconds: wait.round());
  }
}

/// Download speed over the last seconds
final class SpeedMeter {
  final Duration window;
  final Stopwatch _clock;
  final _samples = <(int, int)>[];

  SpeedMeter({this.window = const Duration(seconds: 3), Stopwatch? clock})
    : _clock = clock ?? (Stopwatch()..start());

  void add(int bytes) {
    final now = _clock.elapsedMicroseconds;

    _samples.add((now, bytes));
    _dropOld(now);
  }

  void _dropOld(int now) =>
      _samples.removeWhere((sample) => now - sample.$1 > window.inMicroseconds);

  /// Bytes per second; `null` while too little is known
  double? get bytesPerSecond {
    final now = _clock.elapsedMicroseconds;

    _dropOld(now);

    if (_samples.length < 2) return null;

    final seconds = (now - _samples.first.$1) / Duration.microsecondsPerSecond;
    final bytes = _samples.skip(1).fold<int>(0, (sum, s) => sum + s.$2);

    return seconds <= 0 ? null : bytes / seconds;
  }
}
