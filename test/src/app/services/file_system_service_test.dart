import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/services/services.dart';

void main() {
  test('buildFilename сохраняет кириллицу и убирает запрещённые в Windows символы', () {
    expect(
      FileSystemServiceImpl.buildFilename('Обзор Akko Monsgeek M1. Сделай сам за 8.5к: "тест"?', r'C:\tmp\kgA8JPY2lIA.mp4'),
      'Обзор Akko Monsgeek M1. Сделай сам за 8.5к тест.mp4',
    );
    expect(FileSystemServiceImpl.buildFilename(null, r'C:\tmp\kgA8JPY2lIA.m4a'), 'kgA8JPY2lIA.m4a');
  });

  test('uniquePath нумерует уже существующие файлы', () {
    final taken = {r'C:\Downloads\clip.mp4', r'C:\Downloads\clip (2).mp4'};

    expect(
      FileSystemServiceImpl.uniquePath(r'C:\Downloads', 'clip.mp4', exists: taken.contains),
      r'C:\Downloads\clip (3).mp4',
    );
    expect(
      FileSystemServiceImpl.uniquePath(r'C:\Downloads', 'other.mp4', exists: taken.contains),
      r'C:\Downloads\other.mp4',
    );
  });
}
