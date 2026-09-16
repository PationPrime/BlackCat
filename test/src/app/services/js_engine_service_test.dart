import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/services/js_engine/js_engine_service.dart';

void main() {
  test('приводит результаты WebView2 и WKWebView к одному виду', () {
    expect(
      WebViewJsEngineServiceImpl.decodeEvaluationResult('"function"'),
      'function',
    );
    expect(
      WebViewJsEngineServiceImpl.decodeEvaluationResult('function'),
      'function',
    );
    expect(
      WebViewJsEngineServiceImpl.decodeEvaluationResult('{"type":"result"}'),
      '{"type":"result"}',
    );
  });
}
