/// Скорость загрузки за последние секунды: для строки со скоростью и остатком времени
class SpeedMeter {
  final Duration window;
  final _samples = <(DateTime, int)>[];

  SpeedMeter({this.window = const Duration(seconds: 3)});

  void add(int bytes, {DateTime? now}) {
    now ??= DateTime.now();
    _samples
      ..add((now, bytes))
      ..removeWhere((sample) => now!.difference(sample.$1) > window);
  }

  /// Байт в секунду. `null`, пока данных мало
  double? bytesPerSecond({DateTime? now}) {
    now ??= DateTime.now();
    _samples.removeWhere((sample) => now!.difference(sample.$1) > window);

    if (_samples.length < 2) {
      return null;
    }

    final seconds = now.difference(_samples.first.$1).inMilliseconds / 1000;
    final bytes = _samples
        .skip(1)
        .fold<int>(0, (sum, sample) => sum + sample.$2);

    return seconds <= 0 ? null : bytes / seconds;
  }
}
