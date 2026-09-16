import 'package:url_launcher/url_launcher.dart';

/// Opens links in the default browser
abstract interface class UrlLauncherService {
  /// `false` if no app could open the link
  Future<bool> openUrl(String url);
}

class UrlLauncherServiceImpl implements UrlLauncherService {
  const UrlLauncherServiceImpl();

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      return false;
    }
  }
}
