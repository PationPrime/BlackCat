import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

void main() {
  for (final (name, platform) in [
    /// Files of the v0.1.0 release
    ('PeekyCat_0.1.0.1_Apple_Silicon_aarch64.dmg', ReleasePlatformModel.macos),
    ('PeekyCat_Windows_x86_0.1.0.1.zip', ReleasePlatformModel.windows),
    ('PeekyCat_0.2.0_Intel_x64.pkg', ReleasePlatformModel.macos),
    ('PeekyCat-macOS-universal.zip', ReleasePlatformModel.macos),
    ('PeekyCat-Setup-0.2.0.exe', ReleasePlatformModel.windows),
    ('PeekyCat_0.2.0_x64.msi', ReleasePlatformModel.windows),
    ('peekycat-win64.tar.gz', ReleasePlatformModel.windows),
    ('PeekyCat-0.2.0-x86_64.AppImage', ReleasePlatformModel.linux),
    ('peekycat_0.2.0_amd64.deb', ReleasePlatformModel.linux),
    ('PeekyCat-linux-x64.tar.gz', ReleasePlatformModel.linux),
  ]) {
    test('$name — ${platform.name}', () {
      expect(ReleaseAssetPlatform.of(name), platform);
    });
  }

  for (final name in [
    'PeekyCat_Windows_x86_0.1.0.1.zip.sha256',
    'checksums.txt',
    'PeekyCat-0.2.0.dmg.sig',
    'source.zip',
    'darwinia-notes.zip',
  ]) {
    test('$name — не файл приложения для системы', () {
      expect(ReleaseAssetPlatform.of(name), isNull);
    });
  }
}
