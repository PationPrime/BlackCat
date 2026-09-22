import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/services/services.dart';

void main() {
  test('версия и номер сборки из pubspec: 0.2.0+1', () async {
    PackageInfo.setMockInitialValues(
      appName: 'PeekyCat',
      packageName: 'peeky_cat',
      version: '0.2.0',
      buildNumber: '1',
      buildSignature: '',
    );

    expect(
      await const AppInfoServiceImpl().getVersion(),
      const AppVersionModel(version: '0.2.0', buildNumber: '1'),
    );
  });
}
