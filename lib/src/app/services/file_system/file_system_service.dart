import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../constants/constants.dart';

abstract interface class FileSystemService {
  /// `%LOCALAPPDATA%\YT Download\<name>`: профили WebView2, кэш
  Future<String> localAppFolder(String name);

  /// Папка для настроек и cookies в `%APPDATA%`
  Future<String> supportFolder();

  Future<Directory> createTempDirectory(String prefix);

  /// Переносит готовый файл в «Загрузки» под читаемым именем
  /// и возвращает итоговый путь
  Future<String> moveToDownloads(String filePath, {String? title});

  /// Открывает Проводник с выделенным файлом
  Future<void> revealInExplorer(String filePath);
}

class FileSystemServiceImpl implements FileSystemService {
  static final _forbiddenCharactersPattern = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  @override
  Future<String> localAppFolder(String name) async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final base = localAppData == null
        ? (await getApplicationSupportDirectory()).path
        : p.join(localAppData, StorageConstants.localAppFolder);

    return p.join(base, name);
  }

  @override
  Future<String> supportFolder() async =>
      (await getApplicationSupportDirectory()).path;

  @override
  Future<Directory> createTempDirectory(String prefix) =>
      Directory.systemTemp.createTemp(prefix);

  @override
  Future<String> moveToDownloads(String filePath, {String? title}) async {
    final target = uniquePath(
      await _downloadsFolder(),
      buildFilename(title, filePath),
    );

    try {
      await File(filePath).rename(target);
    } on FileSystemException {
      /// Временная папка и «Загрузки» могут быть на разных дисках
      await File(filePath).copy(target);
      await File(filePath).delete();
    }

    return target;
  }

  @override
  Future<void> revealInExplorer(String filePath) =>
      Process.run('explorer.exe', ['/select,', filePath]);

  Future<String> _downloadsFolder() async {
    final folder =
        await getDownloadsDirectory() ??
        Directory(
          p.join(Platform.environment['USERPROFILE'] ?? '.', 'Downloads'),
        );

    await folder.create(recursive: true);

    return folder.path;
  }

  /// Читаемое имя файла из названия видео, допустимое в Windows
  static String buildFilename(String? title, String filePath) {
    final extension = p.extension(filePath);
    var base = (title ?? '')
        .replaceAll(_forbiddenCharactersPattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    base = base
        .substring(0, math.min(base.length, 150))
        .replaceFirst(RegExp(r'[. ]+$'), '');

    return '${base.isEmpty ? p.basenameWithoutExtension(filePath) : base}$extension';
  }

  /// `name.mp4`, затем `name (2).mp4`, `name (3).mp4`… — первое свободное
  static String uniquePath(
    String folder,
    String filename, {
    bool Function(String path)? exists,
  }) {
    exists ??= (path) => File(path).existsSync();

    final base = p.basenameWithoutExtension(filename);
    final extension = p.extension(filename);
    var candidate = p.join(folder, filename);

    for (var index = 2; exists(candidate); index++) {
      candidate = p.join(folder, '$base ($index)$extension');
    }

    return candidate;
  }
}
