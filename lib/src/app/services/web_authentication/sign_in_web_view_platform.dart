import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';

import '../../models/models.dart';
import '../../tools/tools.dart';

/// [FlutterWebAuth2.authenticate] implementation for desktop platforms.
///
/// Same approach as the package's WebView implementation (a desktop_webview_window
/// window whose navigations are checked against the callback address). On Windows,
/// it also works around WebView2's asynchronous navigation interception:
///
/// * desktop_webview_window cancels every navigation to ask Dart and immediately
///   starts it again. WebView2 silently drops the repeated navigation while the
///   cancelled one to the same address has not finished, so a fast redirect chain
///   (Google signs in to an already open session) leaves a blank page.
///   Here the navigation is restarted only after the cancelled one finishes.
/// * Profile cookies are read from the sign-in window itself before it closes
class SignInWebViewPlatform extends FlutterWebAuth2Platform {
  /// WebView2 data folder: keeps the Google session between launches
  final Future<String> Function() _profileFolder;

  /// Sign-in window title
  final String Function() _windowTitle;

  Webview? _webview;
  List<BrowserCookieModel> _cookies = const [];

  SignInWebViewPlatform({
    required this._profileFolder,
    required this._windowTitle,
  });

  /// Profile cookies at the moment the last sign-in finished
  List<BrowserCookieModel> takeCookies() {
    final cookies = _cookies;
    _cookies = const [];

    return cookies;
  }

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) async {
    if (!await WebviewWindow.isWebviewAvailable()) {
      throw StateError('Webview is not available');
    }

    final parsedOptions = FlutterWebAuth2Options.fromJson(options);
    final manuallyRestartsNavigation = Platform.isWindows;

    _webview?.close();
    _cookies = const [];

    final webview = _webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 520,
        windowHeight: 720,
        title: _windowTitle(),
        userDataFolderWindows: await _profileFolder(),
      ),
    );

    final result = Completer<String>();
    String? pendingUrl;
    var finishing = false;

    bool isCallback(Uri uri) =>
        uri.scheme == callbackUrlScheme &&
        (parsedOptions.httpsHost == null ||
            uri.host == parsedOptions.httpsHost) &&
        (parsedOptions.httpsPath == null ||
            uri.path == parsedOptions.httpsPath);

    Future<void> finish(String callbackUrl) async {
      finishing = true;

      try {
        _cookies = await readCookies(webview);
      } on PlatformException {
        _cookies = const [];
      }

      if (!result.isCompleted) {
        result.complete(callbackUrl);
      }

      webview.close();
    }

    if (manuallyRestartsNavigation) {
      webview.isNavigating.addListener(() {
        final url = pendingUrl;

        /// The cancelled navigation has finished: a repeated one will not be dropped now
        if (!webview.isNavigating.value && url != null && !finishing) {
          pendingUrl = null;
          webview.launch(url, triggerOnUrlRequestEvent: false);
        }
      });
    }

    webview.setOnUrlRequestCallback((url) {
      final uri = Uri.tryParse(url);

      if (uri != null && isCallback(uri)) {
        unawaited(finish(url));
      } else if (manuallyRestartsNavigation && !finishing) {
        pendingUrl = url;
      }

      /// WebView2 cancels a request while it waits for this callback. WKWebView does
      /// not, so returning false and launching again would reload every page forever.
      return !manuallyRestartsNavigation;
    });

    unawaited(
      webview.onClose.whenComplete(() {
        if (identical(_webview, webview)) {
          _webview = null;
        }

        if (!result.isCompleted) {
          result.completeError(
            PlatformException(code: 'CANCELED', message: 'User canceled'),
          );
        }
      }),
    );

    webview.launch(url, triggerOnUrlRequestEvent: false);

    return result.future;
  }

  @override
  Future<void> clearAllDanglingCalls() async {}

  /// All WebView profile cookies (the plugin does not expose its cookie type)
  static Future<List<BrowserCookieModel>> readCookies(Webview webview) async =>
      [
        for (final cookie in await webview.getAllCookies())
          BrowserCookieModel(
            name: NetscapeCookies.stripNul(cookie.name),
            value: NetscapeCookies.stripNul(cookie.value),
            domain: NetscapeCookies.stripNul(cookie.domain),
            path: NetscapeCookies.stripNul(cookie.path),
            expires: cookie.expires,
            secure: cookie.secure,
            httpOnly: cookie.httpOnly,
            sessionOnly: cookie.sessionOnly,
          ),
      ];
}
