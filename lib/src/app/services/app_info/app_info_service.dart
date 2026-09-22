import 'package:package_info_plus/package_info_plus.dart';

import '../../models/models.dart';

/// What the running app build says about itself
abstract interface class AppInfoService {
  /// Version of the build: from the executable on Windows, `Info.plist` on
  /// macOS and `version.json` of the bundle on Linux
  Future<AppVersionModel> getVersion();
}

class AppInfoServiceImpl implements AppInfoService {
  const AppInfoServiceImpl();

  @override
  Future<AppVersionModel> getVersion() async {
    final info = await PackageInfo.fromPlatform();

    return AppVersionModel(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }
}
