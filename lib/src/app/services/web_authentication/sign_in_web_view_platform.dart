import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';

import '../../models/models.dart';
import '../../tools/tools.dart';

/// Реализация [FlutterWebAuth2.authenticate] для Windows.
///
/// Подход тот же, что у WebView-реализации пакета (окно desktop_webview_window,
/// переходы которого сверяются с адресом возврата), с двумя отличиями:
///
/// * desktop_webview_window отменяет каждый переход, чтобы спросить Dart,
///   и сразу запускает его заново. WebView2 молча выбрасывает повторный переход,
///   пока отменённый на тот же адрес не завершился, и быстрая цепочка редиректов
///   (Google входит в уже открытую сессию) оставляет пустую страницу.
///   Здесь переход перезапускается только после завершения отменённого.
/// * cookies профиля читаются из самого окна входа перед его закрытием
class SignInWebViewPlatform extends FlutterWebAuth2Platform {
  /// Папка данных WebView2: хранит сессию Google между запусками
  final Future<String> Function() _profileFolder;

  /// Заголовок окна входа
  final String Function() _windowTitle;

  Webview? _webview;
  List<BrowserCookieModel> _cookies = const [];

  SignInWebViewPlatform({
    required this._profileFolder,
    required this._windowTitle,
  });

  /// cookies профиля в момент завершения последнего входа
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

    webview.isNavigating.addListener(() {
      final url = pendingUrl;

      /// Отменённый переход завершился: теперь повторный не выбросится
      if (!webview.isNavigating.value && url != null && !finishing) {
        pendingUrl = null;
        webview.launch(url, triggerOnUrlRequestEvent: false);
      }
    });

    webview.setOnUrlRequestCallback((url) {
      final uri = Uri.tryParse(url);

      if (uri != null && isCallback(uri)) {
        unawaited(finish(url));
      } else if (!finishing) {
        pendingUrl = url;
      }

      /// Не даём плагину перезапускать переход самому (см. описание класса)
      return false;
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

  /// Все cookies профиля WebView (тип cookie плагин наружу не отдаёт)
  static Future<List<BrowserCookieModel>> readCookies(Webview webview) async => [
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
