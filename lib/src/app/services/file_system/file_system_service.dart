import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../constants/constants.dart';

abstract interface class FileSystemService {
  /// `%LOCALAPPDATA%\YT Download\<name>`: WebView2 profiles, cache
  Future<String> localAppFolder(String name);

  /// Folder for settings and cookies in `%APPDATA%`
  Future<String> supportFolder();

  /// The system Downloads folder
  Future<String> defaultDownloadsFolder();

  Future<bool> directoryExists(String path);

  /// Download work folder: unfinished streams stay in it until the download
  /// finishes and survive an app restart
  Future<Directory> downloadWorkDirectory(String taskId);

  Future<void> deleteDownloadWorkDirectory(String taskId);

  /// Wipes work folders of downloads that are no longer in the queue
  Future<void> deleteDownloadWorkDirectoriesExcept(Set<String> taskIds);

  /// File size in bytes; `0` if the file does not exist
  Future<int> fileLength(String path);

  Future<void> deleteFile(String path);

  /// Copies [from] to [to], replacing an existing file
  Future<void> copyFile(String from, String to);

  /// Renames [from] to [to], replacing an existing file
  Future<void> renameFile(String from, String to);

  /// Writes [bytes] into [path], creating missing folders
  Future<void> writeFile(String path, List<int> bytes);

  /// Lowercase hex SHA-256 of the file
  Future<String> sha256OfFile(String path);

  /// Writes the [entryName] file of the zip archive into [destination].
  /// Returns `false` if the archive has no such file
  Future<bool> extractFromZip(
    String zipPath, {
    required String entryName,
    required String destination,
  });

  /// Allows running the file on macOS and Linux; removes macOS quarantine
  /// after the installer has verified the file checksum
  Future<void> makeExecutable(String path);

  /// Path of the local thumbnail copy of a download, e.g. `<taskId>.jpg`
  Future<String> thumbnailPath(String taskId, {required String extension});

  /// Deletes local thumbnail copies of the downloads
  Future<void> deleteThumbnails(Set<String> taskIds);

  /// Wipes local thumbnail copies of downloads that are no longer in the queue
  Future<void> deleteThumbnailsExcept(Set<String> taskIds);

  /// Moves the finished file into [folder] under a readable name
  /// and returns the resulting path
  Future<String> moveToFolder(String filePath, String folder, {String? title});

  /// Opens the file manager with the file selected: Explorer, Finder;
  /// on Linux the folder of the file
  Future<void> revealInExplorer(String filePath);

  /// Opens the folder in the system file manager
  Future<void> openFolder(String folderPath);
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
  Future<String> defaultDownloadsFolder() async {
    final folder = await getDownloadsDirectory();

    if (folder != null) return folder.path;

    return p.join(
      Platform.isWindows
          ? Platform.environment['USERPROFILE'] ?? '.'
          : Platform.environment['HOME'] ?? '.',
      'Downloads',
    );
  }

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  Future<Directory> _downloadWorkRoot() async =>
      Directory(await localAppFolder(StorageConstants.downloadWorkFolder));

  @override
  Future<Directory> downloadWorkDirectory(String taskId) async => Directory(
    p.join((await _downloadWorkRoot()).path, taskId),
  ).create(recursive: true);

  @override
  Future<void> deleteDownloadWorkDirectory(String taskId) async =>
      _deleteIfExists(
        Directory(p.join((await _downloadWorkRoot()).path, taskId)),
      );

  @override
  Future<void> deleteDownloadWorkDirectoriesExcept(Set<String> taskIds) async {
    final root = await _downloadWorkRoot();

    if (!await root.exists()) return;

    await for (final entity in root.list()) {
      if (!taskIds.contains(p.basename(entity.path))) {
        await _deleteIfExists(entity);
      }
    }
  }

  @override
  Future<int> fileLength(String path) async {
    final file = File(path);

    return await file.exists() ? await file.length() : 0;
  }

  @override
  Future<void> deleteFile(String path) => _deleteIfExists(File(path));

  @override
  Future<void> copyFile(String from, String to) async {
    await Directory(p.dirname(to)).create(recursive: true);
    await File(from).copy(to);
  }

  @override
  Future<void> renameFile(String from, String to) async {
    await _deleteIfExists(File(to));
    await File(from).rename(to);
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<String> sha256OfFile(String path) async =>
      '${await sha256.bind(File(path).openRead()).first}';

  @override
  Future<bool> extractFromZip(
    String zipPath, {
    required String entryName,
    required String destination,
  }) async {
    await Directory(p.dirname(destination)).create(recursive: true);

    /// Unpacking is synchronous and takes seconds for Deno: it runs
    /// off the UI isolate
    return Isolate.run(() => _extractZipEntry(zipPath, entryName, destination));
  }

  static bool _extractZipEntry(
    String zipPath,
    String entryName,
    String destination,
  ) {
    final input = InputFileStream(zipPath);

    try {
      final entry = ZipDecoder()
          .decodeStream(input)
          .files
          .where(
            (file) => file.isFile && p.posix.basename(file.name) == entryName,
          )
          .firstOrNull;

      if (entry == null) return false;

      final output = OutputFileStream(destination);

      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }

      return true;
    } finally {
      input.closeSync();
    }
  }

  @override
  Future<void> makeExecutable(String path) async {
    if (Platform.isWindows) return;

    final result = await Process.run('chmod', ['+x', path]);

    if (result.exitCode != 0) {
      throw FileSystemException('chmod failed: ${result.stderr}', path);
    }

    if (Platform.isMacOS) {
      // Files received over HTTP can inherit the quarantine extended
      // attribute. At this point the repository has already compared the
      // file's SHA-256 with the checksum from the same official release.
      // Absence of the attribute is normal, so a non-zero exit code is ignored.
      await Process.run('xattr', ['-d', 'com.apple.quarantine', path]);
    }
  }

  Future<Directory> _thumbnailsRoot() async =>
      Directory(await localAppFolder(StorageConstants.thumbnailsFolder));

  @override
  Future<String> thumbnailPath(
    String taskId, {
    required String extension,
  }) async => p.join((await _thumbnailsRoot()).path, '$taskId.$extension');

  @override
  Future<void> deleteThumbnails(Set<String> taskIds) =>
      _deleteThumbnailsWhere(taskIds.contains);

  @override
  Future<void> deleteThumbnailsExcept(Set<String> taskIds) =>
      _deleteThumbnailsWhere((taskId) => !taskIds.contains(taskId));

  Future<void> _deleteThumbnailsWhere(bool Function(String taskId) test) async {
    final root = await _thumbnailsRoot();

    if (!await root.exists()) return;

    await for (final entity in root.list()) {
      if (test(p.basenameWithoutExtension(entity.path))) {
        await _deleteIfExists(entity);
      }
    }
  }

  Future<void> _deleteIfExists(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException {
      /// The file is still busy: the folder stays until the next launch
    }
  }

  @override
  Future<String> moveToFolder(
    String filePath,
    String folder, {
    String? title,
  }) async {
    await Directory(folder).create(recursive: true);

    final target = uniquePath(folder, buildFilename(title, filePath));

    try {
      await File(filePath).rename(target);
    } on FileSystemException {
      /// The work folder and the download folder may be on different drives.
      /// Copy under a temporary name: an interrupted copy does not leave
      /// a broken file with the video name in the download folder
      final copyPath = '$target.copying';

      try {
        await File(filePath).copy(copyPath);
        await File(copyPath).rename(target);
      } catch (_) {
        await _deleteIfExists(File(copyPath));

        rethrow;
      }

      await File(filePath).delete();
    }

    return target;
  }

  @override
  Future<void> revealInExplorer(String filePath) =>
      switch (Platform.operatingSystem) {
        'windows' => Process.run('explorer.exe', ['/select,', filePath]),
        'macos' => Process.run('open', ['-R', filePath]),
        'linux' => Process.run('xdg-open', [p.dirname(filePath)]),
        _ => Future.error(UnsupportedError('File manager is not supported')),
      };

  @override
  Future<void> openFolder(String folderPath) =>
      switch (Platform.operatingSystem) {
        'windows' => Process.run('explorer.exe', [folderPath]),
        'macos' => Process.run('open', [folderPath]),
        'linux' => Process.run('xdg-open', [folderPath]),
        _ => Future.error(UnsupportedError('File manager is not supported')),
      };

  /// Readable file name from the video title, valid on Windows
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

  /// `name.mp4`, then `name (2).mp4`, `name (3).mp4`…: the first free one
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
