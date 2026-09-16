import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:path/path.dart' as p;

import '../constants/constants.dart';

/// Release files of yt-dlp and Deno for the current system and their checksums
abstract final class DependencyAssets {
  static final _checksumLinePattern = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');
  static final _powerShellHashPattern = RegExp(
    r'^\s*Hash\s*:\s*([0-9a-fA-F]{64})\s*$',
    multiLine: true,
  );
  static final _powerShellPathPattern = RegExp(
    r'^\s*Path\s*:\s*(.+?)\s*$',
    multiLine: true,
  );
  static final _versionPattern = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?');

  /// Program file name: `yt-dlp.exe` on Windows, `yt-dlp` elsewhere
  static String executableName(String name, {required Abi abi}) =>
      _isWindows(abi) ? '$name.exe' : name;

  /// Standalone yt-dlp build: Python is not needed. `null` for a system
  /// without an official build
  static String? ytDlpAsset(Abi abi) => switch (abi) {
    Abi.windowsX64 => 'yt-dlp.exe',
    Abi.windowsArm64 => 'yt-dlp_arm64.exe',
    Abi.windowsIA32 => 'yt-dlp_x86.exe',
    Abi.macosX64 || Abi.macosArm64 => 'yt-dlp_macos',
    Abi.linuxX64 => 'yt-dlp_linux',
    Abi.linuxArm64 => 'yt-dlp_linux_aarch64',
    _ => null,
  };

  /// Deno archive with a single `deno` program inside
  static String? denoAsset(Abi abi) => switch (abi) {
    Abi.windowsX64 => 'deno-x86_64-pc-windows-msvc.zip',
    Abi.windowsArm64 => 'deno-aarch64-pc-windows-msvc.zip',
    Abi.macosX64 => 'deno-x86_64-apple-darwin.zip',
    Abi.macosArm64 => 'deno-aarch64-apple-darwin.zip',
    Abi.linuxX64 => 'deno-x86_64-unknown-linux-gnu.zip',
    Abi.linuxArm64 => 'deno-aarch64-unknown-linux-gnu.zip',
    _ => null,
  };

  static String ytDlpUrl(String asset) =>
      '${DependencyConstants.ytDlpReleaseUrl}/$asset';

  static String get ytDlpChecksumsUrl =>
      ytDlpUrl(DependencyConstants.ytDlpChecksumsFile);

  static String denoUrl(String asset) =>
      '${DependencyConstants.denoReleaseUrl}/$asset';

  static String denoChecksumUrl(String asset) =>
      denoUrl('$asset${DependencyConstants.denoChecksumSuffix}');

  /// Lowercase SHA-256 of [fileName]. Understands `sha256sum` lines
  /// (`<hash>  <file>`) and the `Get-FileHash` listing Deno publishes
  /// for Windows. `null` if the file is not listed
  static String? sha256Of(String checksums, String fileName) {
    for (final line in const LineSplitter().convert(checksums)) {
      final match = _checksumLinePattern.firstMatch(line.trim());

      if (match != null && _basename(match.group(2)!.trim()) == fileName) {
        return match.group(1)!.toLowerCase();
      }
    }

    final hash = _powerShellHashPattern.firstMatch(checksums)?.group(1);
    final path = _powerShellPathPattern.firstMatch(checksums)?.group(1);

    if (hash == null || (path != null && _basename(path) != fileName)) {
      return null;
    }

    return hash.toLowerCase();
  }

  /// `[2, 9, 6]` from `deno 2.9.6 (stable…)`, `v24.12.0` or `2026.08.19`
  static List<int>? parseVersion(String output) {
    final match = _versionPattern.firstMatch(output);

    if (match == null) return null;

    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.tryParse(match.group(3) ?? '') ?? 0,
    ];
  }

  static bool isAtLeast(List<int> version, List<int> minimum) {
    for (var index = 0; index < minimum.length; index++) {
      final part = index < version.length ? version[index] : 0;

      if (part != minimum[index]) {
        return part > minimum[index];
      }
    }

    return true;
  }

  /// Checksum files list paths of the build machine: Windows or POSIX ones
  static String _basename(String path) => p.windows.basename(path);

  static bool _isWindows(Abi abi) =>
      abi == Abi.windowsX64 ||
      abi == Abi.windowsArm64 ||
      abi == Abi.windowsIA32;
}
