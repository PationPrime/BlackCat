import 'package:path/path.dart' as p;

import '../models/models.dart';

/// The system a release file is for, by its name:
/// `PeekyCat_0.1.0.1_Apple_Silicon_aarch64.dmg` is for macOS,
/// `PeekyCat_Windows_x86_0.1.0.1.zip` is for Windows
abstract final class ReleaseAssetPlatform {
  static const _extensions = {
    '.dmg': ReleasePlatformModel.macos,
    '.pkg': ReleasePlatformModel.macos,
    '.exe': ReleasePlatformModel.windows,
    '.msi': ReleasePlatformModel.windows,
    '.msix': ReleasePlatformModel.windows,
    '.appx': ReleasePlatformModel.windows,
    '.appimage': ReleasePlatformModel.linux,
    '.deb': ReleasePlatformModel.linux,
    '.rpm': ReleasePlatformModel.linux,
    '.flatpak': ReleasePlatformModel.linux,
    '.snap': ReleasePlatformModel.linux,
  };

  /// Words of an archive name: `.zip` and `.tar.gz` are made for any system
  static const _words = {
    'macos': ReleasePlatformModel.macos,
    'mac': ReleasePlatformModel.macos,
    'osx': ReleasePlatformModel.macos,
    'darwin': ReleasePlatformModel.macos,
    'apple': ReleasePlatformModel.macos,
    'windows': ReleasePlatformModel.windows,
    'win': ReleasePlatformModel.windows,
    'win32': ReleasePlatformModel.windows,
    'win64': ReleasePlatformModel.windows,
    'linux': ReleasePlatformModel.linux,
  };

  /// Checksums and signatures are not downloads of the app
  static const _skippedExtensions = {
    '.sha256',
    '.sha512',
    '.md5',
    '.sig',
    '.asc',
    '.txt',
    '.json',
    '.blockmap',
  };

  /// `null` for a file of no system: checksums, sources
  static ReleasePlatformModel? of(String name) {
    final lower = name.toLowerCase();
    final extension = p.extension(lower);

    if (_skippedExtensions.contains(extension)) return null;

    if (_extensions[extension] case final platform?) return platform;

    for (final word in lower.split(RegExp('[^a-z0-9]+'))) {
      if (_words[word] case final platform?) return platform;
    }

    return null;
  }
}
