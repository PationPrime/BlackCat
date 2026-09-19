import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/services/services.dart';

void main() {
  test(
    'buildFilename сохраняет кириллицу и убирает запрещённые в Windows символы',
    () {
      expect(
        FileSystemServiceImpl.buildFilename(
          'Обзор Akko Monsgeek M1. Сделай сам за 8.5к: "тест"?',
          r'C:\tmp\kgA8JPY2lIA.mp4',
        ),
        'Обзор Akko Monsgeek M1. Сделай сам за 8.5к тест.mp4',
      );
      expect(
        FileSystemServiceImpl.buildFilename(null, r'C:\tmp\kgA8JPY2lIA.m4a'),
        'kgA8JPY2lIA.m4a',
      );
    },
  );

  test('uniquePath нумерует уже существующие файлы', () {
    final taken = {r'C:\Downloads\clip.mp4', r'C:\Downloads\clip (2).mp4'};

    expect(
      FileSystemServiceImpl.uniquePath(
        r'C:\Downloads',
        'clip.mp4',
        exists: taken.contains,
      ),
      r'C:\Downloads\clip (3).mp4',
    );
    expect(
      FileSystemServiceImpl.uniquePath(
        r'C:\Downloads',
        'other.mp4',
        exists: taken.contains,
      ),
      r'C:\Downloads\other.mp4',
    );
  });

  test(
    'sha256OfFile и extractFromZip: программа достаётся из архива по имени',
    () async {
      final root = await Directory.systemTemp.createTemp('file-system-service');
      addTearDown(() => root.delete(recursive: true));

      final service = FileSystemServiceImpl();
      final zip = File(p.join(root.path, 'deno.zip'));

      await zip.writeAsBytes(
        ZipEncoder().encodeBytes(
          Archive()
            ..addFile(ArchiveFile.string('README.md', 'readme'))
            ..addFile(
              ArchiveFile.bytes('bin/deno.exe', utf8.encode('deno program')),
            ),
        ),
      );

      final destination = p.join(root.path, 'Tools', 'deno.exe');

      expect(
        await service.extractFromZip(
          zip.path,
          entryName: 'deno.exe',
          destination: destination,
        ),
        isTrue,
      );
      expect(await File(destination).readAsString(), 'deno program');
      expect(
        await service.sha256OfFile(destination),
        '83510ac22e56fc487cf36ad5f600d7aa003a6dae11c8d7b7caf1eaef4c83a1ce',
      );
      expect(
        await service.extractFromZip(
          zip.path,
          entryName: 'yt-dlp.exe',
          destination: p.join(root.path, 'x'),
        ),
        isFalse,
      );
    },
  );
}
