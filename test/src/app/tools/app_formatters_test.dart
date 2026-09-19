import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:black_cat/src/app/tools/tools.dart';

import '../../support/test_localization.dart';

void main() {
  setUpAll(() async {
    loadTestTranslations();
    await initializeDateFormatting();
  });

  test('duration', () {
    expect(AppFormatters.duration(5), '0:05');
    expect(AppFormatters.duration(754), '12:34');
    expect(AppFormatters.duration(3723), '1:02:03');
    expect(AppFormatters.duration(null), isNull);
  });

  test('count: разряды по языку', () {
    expect(AppFormatters.count(1234567, locale: 'ru'), '1\u00A0234\u00A0567');
    expect(AppFormatters.count(1234567, locale: 'en'), '1,234,567');
    expect(AppFormatters.count(999, locale: 'ru'), '999');
    expect(AppFormatters.count(null), isNull);
  });

  test('dateTime: дата и время по языку', () {
    final dateTime = DateTime(2026, 9, 16, 14, 5);

    expect(
      AppFormatters.dateTime(dateTime, locale: 'en'),
      'Sep 16, 2026 14:05',
    );
    expect(AppFormatters.dateTime(dateTime, locale: 'ru'), contains('2026'));
    expect(AppFormatters.dateTime(dateTime, locale: 'ru'), contains('14:05'));
    expect(AppFormatters.dateTime(null), isNull);
  });

  test('AppFileSize.format', () {
    expect(AppFileSize.format(512), '512 Б');
    expect(AppFileSize.format(1536), '1.5 КБ');
    expect(AppFileSize.format(70000000), '67 МБ');
    expect(AppFileSize.format(0), isNull);
  });

  test('SpeedMeter: байт в секунду за окно', () {
    final start = DateTime(2026);
    final meter = SpeedMeter()
      ..add(0, now: start)
      ..add(1000, now: start.add(const Duration(milliseconds: 500)))
      ..add(1000, now: start.add(const Duration(seconds: 1)));

    expect(
      meter.bytesPerSecond(now: start.add(const Duration(seconds: 1))),
      2000,
    );
    expect(SpeedMeter().bytesPerSecond(), isNull);
  });
}
