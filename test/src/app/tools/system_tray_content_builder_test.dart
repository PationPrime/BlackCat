import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

import '../../support/test_localization.dart';

DownloadTaskModel _task({
  String title = 'Обзор',
  DownloadTaskStatus status = DownloadTaskStatus.downloading,
  int downloadedBytes = 420,
  int? totalBytes = 1000,
}) => DownloadTaskModel(
  id: 'a',
  video: VideoInfoModel(
    id: 'a',
    title: title,
    url: 'https://youtu.be/a',
    qualities: const [],
  ),
  quality: const QualityModel(
    id: '1080',
    kind: QualityKind.video,
    label: '1080p',
  ),
  status: status,
  section: DownloadTaskSection.active,
  downloadedBytes: downloadedBytes,
  totalBytes: totalBytes,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<String> _labels(SystemTrayContentModel content) => [
  for (final item in content.menu)
    if (item case SystemTrayMenuActionModel(:final label)) label,
];

void main() {
  setUpAll(loadTestTranslations);

  test('без активной загрузки: неактивная подпись и действия с окном', () {
    final content = SystemTrayContentBuilder.build(null);

    expect(_labels(content), [
      'Нет активной загрузки',
      'Открыть PeekyCat',
      'Свернуть в трей',
      'Выйти',
    ]);
    expect((content.menu.first as SystemTrayMenuActionModel).enabled, isFalse);
    expect(content.toolTip, 'PeekyCat');
  });

  test('активная загрузка: название и процент в меню и подсказке', () {
    final content = SystemTrayContentBuilder.build(_task());

    expect(_labels(content).take(2), ['Обзор', 'Скачивание 42%']);
    expect(content.toolTip, 'PeekyCat\nОбзор\nСкачивание 42%');
  });

  test('длинное название сворачивается в троеточие', () {
    final content = SystemTrayContentBuilder.build(
      _task(title: 'Название ' * 20),
    );

    expect(_labels(content).first, endsWith('…'));
    expect(
      _labels(content).first.runes.length,
      SystemTrayText.menuItemMaxLength,
    );
  });

  test('progressOf: пауза, склейка и подготовка', () {
    expect(
      SystemTrayContentBuilder.progressOf(
        _task(status: DownloadTaskStatus.paused),
      ),
      'На паузе · 42%',
    );
    expect(
      SystemTrayContentBuilder.progressOf(
        _task(status: DownloadTaskStatus.processing),
      ),
      'Склеиваем видео и звук…',
    );
    expect(
      SystemTrayContentBuilder.progressOf(
        _task(downloadedBytes: 0, totalBytes: null),
      ),
      'Готовим загрузку…',
    );
  });
}
