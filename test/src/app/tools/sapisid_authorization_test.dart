import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

void main() {
  test('SapisidAuthorization повторяет алгоритм веб-клиента', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1757930000 * 1000);

    String sha(String text) => sha1.convert(utf8.encode(text)).toString();

    expect(
      SapisidAuthorization.build(sapisid: 'SID1', sapisid3p: 'SID3', now: now),
      'SAPISIDHASH 1757930000_${sha('1757930000 SID1 https://www.youtube.com')} '
      'SAPISID3PHASH 1757930000_${sha('1757930000 SID3 https://www.youtube.com')}',
    );
    expect(
      SapisidAuthorization.build(
        sapisid: 'SID1',
        userSessionId: 'USER',
        now: now,
      ),
      'SAPISIDHASH 1757930000_${sha('USER 1757930000 SID1 https://www.youtube.com')}_u',
    );
    expect(SapisidAuthorization.build(now: now), isNull);
  });
}
