import 'dart:ffi' show Abi;

import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

const _ytDlpChecksums =
    '1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6  yt-dlp\n'
    '66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a  yt-dlp.exe\n'
    '05b438997bafc3affdfda9d041353c9d73e04dc842207254b655b0887c4445b0  yt-dlp_arm64.exe\n';

/// Deno publishes the Windows checksum as `Get-FileHash` output
const _denoWindowsChecksum =
    '\r\nAlgorithm : SHA256\r\n'
    'Hash      : 15E5300B0BA3C3695A7621D90160A746EC9E710228CEE639AFA9D580F6E3CD11\r\n'
    r'Path      : C:\a\deno\deno\target\release\deno-x86_64-pc-windows-msvc.zip'
    '\r\n\r\n';

void main() {
  test('сборки yt-dlp и Deno выбираются по системе и процессору', () {
    expect(DependencyAssets.ytDlpAsset(Abi.windowsX64), 'yt-dlp.exe');
    expect(DependencyAssets.ytDlpAsset(Abi.windowsArm64), 'yt-dlp_arm64.exe');
    expect(DependencyAssets.ytDlpAsset(Abi.macosArm64), 'yt-dlp_macos');
    expect(DependencyAssets.ytDlpAsset(Abi.linuxArm64), 'yt-dlp_linux_aarch64');
    expect(DependencyAssets.ytDlpAsset(Abi.androidArm64), isNull);

    expect(
      DependencyAssets.denoAsset(Abi.windowsX64),
      'deno-x86_64-pc-windows-msvc.zip',
    );
    expect(
      DependencyAssets.denoAsset(Abi.macosX64),
      'deno-x86_64-apple-darwin.zip',
    );
    expect(
      DependencyAssets.denoAsset(Abi.linuxX64),
      'deno-x86_64-unknown-linux-gnu.zip',
    );
    expect(DependencyAssets.denoAsset(Abi.windowsIA32), isNull);

    expect(
      DependencyAssets.executableName('deno', abi: Abi.windowsX64),
      'deno.exe',
    );
    expect(DependencyAssets.executableName('deno', abi: Abi.linuxX64), 'deno');
  });

  test('ссылки ведут на последний релиз GitHub', () {
    expect(
      DependencyAssets.ytDlpUrl('yt-dlp.exe'),
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
    );
    expect(
      DependencyAssets.ytDlpChecksumsUrl,
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS',
    );
    expect(
      DependencyAssets.denoChecksumUrl('deno-x86_64-pc-windows-msvc.zip'),
      'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip.sha256sum',
    );
  });

  test('sha256Of: строка нужного файла из списка sha256sum', () {
    expect(
      DependencyAssets.sha256Of(_ytDlpChecksums, 'yt-dlp.exe'),
      '66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a',
    );
    expect(
      DependencyAssets.sha256Of(_ytDlpChecksums, 'yt-dlp'),
      '1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6',
    );
    expect(DependencyAssets.sha256Of(_ytDlpChecksums, 'yt-dlp_macos'), isNull);
  });

  test('sha256Of: вывод Get-FileHash сверяется по имени файла', () {
    expect(
      DependencyAssets.sha256Of(
        _denoWindowsChecksum,
        'deno-x86_64-pc-windows-msvc.zip',
      ),
      '15e5300b0ba3c3695a7621d90160a746ec9e710228cee639afa9d580f6e3cd11',
    );
    expect(
      DependencyAssets.sha256Of(
        _denoWindowsChecksum,
        'deno-aarch64-pc-windows-msvc.zip',
      ),
      isNull,
    );
    expect(
      DependencyAssets.sha256Of(
        '394f07f4da2bebe6ce6f1e7ce0fa16429b29b08c35e3fac3fe25972676dff4b2  deno-x86_64-unknown-linux-gnu.zip\n',
        'deno-x86_64-unknown-linux-gnu.zip',
      ),
      '394f07f4da2bebe6ce6f1e7ce0fa16429b29b08c35e3fac3fe25972676dff4b2',
    );
  });

  test('версии JavaScript-сред сравниваются с минимальными', () {
    expect(
      DependencyAssets.parseVersion(
        'deno 2.9.6 (stable, release, x86_64-pc-windows-msvc)',
      ),
      [2, 9, 6],
    );
    expect(DependencyAssets.parseVersion('v24.12.0'), [24, 12, 0]);
    expect(DependencyAssets.parseVersion('2026.08.19'), [2026, 8, 19]);
    expect(DependencyAssets.parseVersion('1.2'), [1, 2, 0]);
    expect(DependencyAssets.parseVersion('unknown'), isNull);

    expect(DependencyAssets.isAtLeast([24, 12, 0], [22, 0, 0]), isTrue);
    expect(DependencyAssets.isAtLeast([22, 0, 0], [22, 0, 0]), isTrue);
    expect(DependencyAssets.isAtLeast([20, 18, 1], [22, 0, 0]), isFalse);
    expect(DependencyAssets.isAtLeast([2, 2, 9], [2, 3, 0]), isFalse);
  });
}
