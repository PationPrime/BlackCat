import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/tools/tools.dart';

void main() {
  for (final (name, platform) in [
    /// Files of the v0.1.0 release
    ('BlackCat_0.1.0.1_Apple_Silicon_aarch64.dmg', ReleasePlatformModel.macos),
    ('BlackCat_Windows_x86_0.1.0.1.zip', ReleasePlatformModel.windows),
    ('BlackCat_0.2.0_Intel_x64.pkg', ReleasePlatformModel.macos),
    ('BlackCat-macOS-universal.zip', ReleasePlatformModel.macos),
    ('BlackCat-Setup-0.2.0.exe', ReleasePlatformModel.windows),
    ('BlackCat_0.2.0_x64.msi', ReleasePlatformModel.windows),
    ('blackcat-win64.tar.gz', ReleasePlatformModel.windows),
    ('BlackCat-0.2.0-x86_64.AppImage', ReleasePlatformModel.linux),
    ('blackcat_0.2.0_amd64.deb', ReleasePlatformModel.linux),
    ('BlackCat-linux-x64.tar.gz', ReleasePlatformModel.linux),
  ]) {
    test('$name — ${platform.name}', () {
      expect(ReleaseAssetPlatform.of(name), platform);
    });
  }

  for (final name in [
    'BlackCat_Windows_x86_0.1.0.1.zip.sha256',
    'checksums.txt',
    'BlackCat-0.2.0.dmg.sig',
    'source.zip',
    'darwinia-notes.zip',
  ]) {
    test('$name — не файл приложения для системы', () {
      expect(ReleaseAssetPlatform.of(name), isNull);
    });
  }
}
