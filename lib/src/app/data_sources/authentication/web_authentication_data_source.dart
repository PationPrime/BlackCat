import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../constants/constants.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'local_authentication_data_source.dart';

/// YouTube sign-in via flutter_web_auth_2 and WebView2 profile cookies
abstract interface class WebAuthenticationDataSource {
  /// Profile cookies after sign-in. `null` if the user closed the window
  Future<List<BrowserCookieModel>?> signIn();

  /// Opens the sign-in window profile in a hidden window just to read cookies
  Future<List<BrowserCookieModel>> readProfileCookies();
}

final class WebAuthenticationDataSourceImpl
    implements WebAuthenticationDataSource {
  final SignInWebViewPlatform _signInWebViewPlatform;
  final LocalAuthenticationDataSource _localAuthenticationDataSource;

  const WebAuthenticationDataSourceImpl({
    required this._signInWebViewPlatform,
    required this._localAuthenticationDataSource,
  });

  @override
  Future<List<BrowserCookieModel>?> signIn() async {
    try {
      await FlutterWebAuth2.authenticate(
        url: YouTubeConstants.signInUrl,
        callbackUrlScheme: 'https',
        options: const FlutterWebAuth2Options(
          httpsHost: YouTubeConstants.signInCallbackHost,
          httpsPath: YouTubeConstants.signInCallbackPath,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') {
        return null;
      }

      rethrow;
    }

    return _signInWebViewPlatform.takeCookies();
  }

  @override
  Future<List<BrowserCookieModel>> readProfileCookies() async {
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 1,
        windowHeight: 1,
        windowPosX: -32000,
        windowPosY: -32000,
        useWindowPositionAndSize: true,
        titleBarHeight: 0,
        title: 'YT Download',
        userDataFolderWindows: await _localAuthenticationDataSource
            .signInProfileFolder(),
      ),
    );

    try {
      await webview.setWebviewWindowVisibility(false);

      return await SignInWebViewPlatform.readCookies(webview);
    } finally {
      webview.close();
    }
  }
}
