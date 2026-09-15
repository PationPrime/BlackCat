import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';

import '../localization/lang/locale_keys.g.dart';

abstract final class AppFormatters {
  /// `5` → `0:05`, `3723` → `1:02:03`
  static String? duration(num? seconds) {
    if (seconds == null || seconds.isNaN) {
      return null;
    }

    final total = math.max(0, seconds.round());
    final parts = [total ~/ 3600, (total % 3600) ~/ 60, total % 60];
    final shown = parts[0] > 0 ? parts : parts.sublist(1);

    return [
      for (var index = 0; index < shown.length; index++)
        index == 0 ? '${shown[index]}' : '${shown[index]}'.padLeft(2, '0'),
    ].join(':');
  }

  /// Разряды через неразрывный пробел, как в ru-RU: `1 234 567`
  static String? count(int? count) {
    if (count == null) {
      return null;
    }

    final digits = count.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+$)'),
      (_) => ' ',
    );

    return count < 0 ? '-$grouped' : grouped;
  }
}

/// Размер файла в самой крупной единице, где он больше единицы
abstract final class AppFileSize {
  static const _step = 1024;

  static const _unitKeys = [
    LocaleKeys.app_common_file_size_bytes,
    LocaleKeys.app_common_file_size_kilobytes,
    LocaleKeys.app_common_file_size_megabytes,
    LocaleKeys.app_common_file_size_gigabytes,
  ];

  /// `512` → `512 Б`, `1536` → `1.5 КБ`, `70000000` → `67 МБ`.
  /// `null` для пустого размера
  static String? format(num? bytes) {
    if (bytes == null || bytes <= 0) {
      return null;
    }

    final index = math.min(
      (math.log(bytes) / math.log(_step)).floor(),
      _unitKeys.length - 1,
    );
    final value = bytes / math.pow(_step, index);
    final formatted = value >= 10 || index == 0
        ? '${value.round()}'
        : value.toStringAsFixed(1);

    return _unitKeys[index].tr(namedArgs: {'value': formatted});
  }
}
