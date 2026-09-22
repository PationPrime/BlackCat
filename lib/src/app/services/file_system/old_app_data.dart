import 'dart:io';

import 'package:path/path.dart' as p;

import '../../logger/app_logger.dart';

/// The app was called BlackCat before, and everyone who used it keeps
/// its data in the folders of that name: the installed yt-dlp and Deno,
/// unfinished downloads, thumbnails, the queue database and the account
/// cookies. On the first launch under the new name they move over
abstract final class OldAppData {
  static const _appLogger = AppLogger(where: 'OldAppData');

  /// The app folder of the old name in `%LOCALAPPDATA%`
  static const localAppFolder = 'BlackCat';

  /// The company of the old name: `%APPDATA%` keeps the support folder
  /// under it on Windows
  static const _windowsCompany = 'com.blackcat';

  /// The bundle of the old name on macOS
  static const _bundleId = 'com.BlackCat';

  /// The support folder of the old name, next to [supportFolder] of the new
  /// one: `%APPDATA%\com.blackcat\BlackCat` on Windows, `com.BlackCat`
  /// in `~/Library/Application Support` on macOS and `BlackCat`
  /// in `~/.local/share` on Linux
  static String? supportFolderNextTo(
    String supportFolder, {
    String? platform,
  }) => switch (platform ?? Platform.operatingSystem) {
    'windows' => p.join(
      p.dirname(p.dirname(supportFolder)),
      _windowsCompany,
      localAppFolder,
    ),
    'macos' => p.join(p.dirname(supportFolder), _bundleId),
    'linux' => p.join(p.dirname(supportFolder), localAppFolder),
    _ => null,
  };

  /// Moves the folder of the old name to [to]. Keeps [to] when something
  /// is in it already: that data is newer.
  ///
  /// Returns whether anything moved. A move that did not work out is not
  /// a reason to stop the launch: the app opens as on a first launch
  static Future<bool> move({required String from, required String to}) async {
    final source = Directory(from);
    final target = Directory(to);

    if (p.equals(from, to) || !await source.exists()) return false;

    if (await target.exists()) {
      if (!await target.list().isEmpty) return false;

      await target.delete();
    }

    try {
      await target.parent.create(recursive: true);
      await source.rename(to);

      return true;
    } on FileSystemException catch (error, stackTrace) {
      _appLogger.logError(
        'The data of the old app name stays in $from: $error',
        stackTrace: stackTrace,
      );

      return false;
    }
  }
}
