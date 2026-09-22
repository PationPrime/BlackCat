import 'dart:io' as io;
import 'dart:async';
import 'dart:convert';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';

import '../../constants/constants.dart';
import '../../errors/errors.dart';
import '../file_system/file_system_service.dart';

/// Runs JavaScript and returns the value of the last expression as a string
abstract interface class JsEngineService {
  Future<String> evaluate(String script);
}

/// A hidden WebView2 window: the same Chromium as the sign-in window,
/// so no separate engine needs to be installed
class WebViewJsEngineServiceImpl implements JsEngineService {
  final FileSystemService _fileSystemService;

  Future<Webview>? _webview;

  WebViewJsEngineServiceImpl({required this._fileSystemService});

  @override
  Future<String> evaluate(String script) async {
    final webview = await (_webview ??= _create());

    try {
      final result = await webview.evaluateJavaScript(script);

      return decodeEvaluationResult(result);
    } on PlatformException catch (error) {
      throw VideoException(
        const VideoErrorCodes().jsEngine,
        args: {'error': '${error.message}'},
      );
    }
  }

  /// WebView2 serializes a JavaScript result as JSON, while WKWebView returns
  /// strings directly. Keep the engine contract identical on both platforms.
  static String decodeEvaluationResult(String? result) {
    final value = result?.replaceAll('\u0000', '') ?? '';

    if (value.isEmpty) return 'null';

    try {
      final decoded = jsonDecode(value);

      return decoded is String ? decoded : jsonEncode(decoded);
    } on FormatException {
      return value;
    }
  }

  Future<Webview> _create() async {
    if (!await WebviewWindow.isWebviewAvailable()) {
      _webview = null;

      throw VideoException(const VideoErrorCodes().webViewRuntime);
    }

    /// Own profile: the engine does not touch the sign-in window profile
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 1,
        windowHeight: 1,
        windowPosX: -32000,
        windowPosY: -32000,
        useWindowPositionAndSize: true,
        titleBarHeight: 0,
        title: 'PeekyCat JS',
        userDataFolderWindows: await _fileSystemService.localAppFolder(
          StorageConstants.jsEngineProfileFolder,
        ),
      ),
    );

    if (io.Platform.isWindows) {
      await webview.setWebviewWindowVisibility(false);
    }

    /// If the window disappears, the next call creates a new one (scripts are loaded again)
    unawaited(webview.onClose.whenComplete(() => _webview = null));

    return webview;
  }
}
