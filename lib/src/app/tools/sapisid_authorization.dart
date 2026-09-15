import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../constants/constants.dart';

/// Заголовок `Authorization` веб-клиента YouTube для запросов с cookies
abstract final class SapisidAuthorization {
  /// `SAPISIDHASH <ts>_<sha1("[u ]ts sapisid origin")>[_u]`
  /// и варианты 1P/3P через пробел. `null`, если cookies SAPISID нет
  static String? build({
    String? sapisid,
    String? sapisid1p,
    String? sapisid3p,
    String? userSessionId,
    DateTime? now,
    String origin = YouTubeConstants.origin,
  }) {
    final timestamp =
        '${((now ?? DateTime.now()).millisecondsSinceEpoch / 1000).round()}';

    String make(String scheme, String sid) {
      final hash = sha1.convert(
        utf8.encode([?userSessionId, timestamp, sid, origin].join(' ')),
      );

      return '$scheme ${[timestamp, '$hash', if (userSessionId != null) 'u'].join('_')}';
    }

    final parts = [
      if (sapisid != null) make('SAPISIDHASH', sapisid),
      if (sapisid1p != null) make('SAPISID1PHASH', sapisid1p),
      if (sapisid3p != null) make('SAPISID3PHASH', sapisid3p),
    ];

    return parts.isEmpty ? null : parts.join(' ');
  }
}
