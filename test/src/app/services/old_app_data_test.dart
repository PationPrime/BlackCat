import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/services/file_system/old_app_data.dart';

/// A folder with one file in it
Directory _folder(Directory root, String name, {String? file}) {
  final folder = Directory(p.join(root.path, name))
    ..createSync(recursive: true);

  if (file != null) {
    File(p.join(folder.path, file)).writeAsStringSync('cookies');
  }

  return folder;
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('old_app_data'));

  tearDown(() => root.deleteSync(recursive: true));

  test('папка старого имени лежит рядом с новой на каждой системе', () {
    expect(
      OldAppData.supportFolderNextTo(
        p.join('C:', 'AppData', 'Roaming', 'com.peekycat', 'PeekyCat'),
        platform: 'windows',
      ),
      p.join('C:', 'AppData', 'Roaming', 'com.blackcat', 'BlackCat'),
    );
    expect(
      OldAppData.supportFolderNextTo(
        p.join('Library', 'Application Support', 'com.PeekyCat'),
        platform: 'macos',
      ),
      p.join('Library', 'Application Support', 'com.BlackCat'),
    );
    expect(
      OldAppData.supportFolderNextTo(
        p.join('.local', 'share', 'PeekyCat'),
        platform: 'linux',
      ),
      p.join('.local', 'share', 'BlackCat'),
    );
    expect(
      OldAppData.supportFolderNextTo('anywhere', platform: 'fuchsia'),
      isNull,
    );
  });

  test('данные старого имени переезжают в папку нового', () async {
    final from = _folder(root, 'BlackCat', file: 'youtube_cookies.txt');
    final to = p.join(root.path, 'PeekyCat');

    expect(await OldAppData.move(from: from.path, to: to), isTrue);
    expect(File(p.join(to, 'youtube_cookies.txt')).existsSync(), isTrue);
    expect(from.existsSync(), isFalse);
  });

  test('пустую папку нового имени занимают данные старого', () async {
    final from = _folder(root, 'BlackCat', file: 'database.sqlite');
    final to = _folder(root, 'PeekyCat');

    expect(await OldAppData.move(from: from.path, to: to.path), isTrue);
    expect(File(p.join(to.path, 'database.sqlite')).existsSync(), isTrue);
  });

  test(
    'когда под новым именем уже работали, старые данные не трогают',
    () async {
      final from = _folder(root, 'BlackCat', file: 'database.sqlite');
      final to = _folder(root, 'PeekyCat', file: 'database.sqlite');

      expect(await OldAppData.move(from: from.path, to: to.path), isFalse);
      expect(from.listSync(), hasLength(1));
      expect(to.listSync(), hasLength(1));
    },
  );

  test('без папки старого имени ничего не происходит', () async {
    final to = p.join(root.path, 'PeekyCat');

    expect(
      await OldAppData.move(from: p.join(root.path, 'BlackCat'), to: to),
      isFalse,
    );
    expect(Directory(to).existsSync(), isFalse);
  });
}
