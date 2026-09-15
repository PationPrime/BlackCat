import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';

import '../../support/test_localization.dart';

DioException _dioException({int? status, DioExceptionType type = DioExceptionType.badResponse}) {
  final request = RequestOptions(path: 'https://rr1.googlevideo.com/videoplayback');

  return DioException(
    requestOptions: request,
    type: type,
    response: status == null ? null : Response(requestOptions: request, statusCode: status),
  );
}

void main() {
  const handler = VideoErrorHandler();
  const codes = VideoErrorCodes();

  setUpAll(loadTestTranslations);

  test('VideoException → VideoFailure с текстом и признаком входа', () {
    final failure = handler.handleError(const VideoException('not_youtube_url')) as VideoFailure;

    expect(failure.code, codes.notYouTubeUrl);
    expect(failure.message, 'Это не ссылка на YouTube-видео.');
    expect(failure.needsSignIn, isFalse);
  });

  test('отказ YouTube: причина из ответа и нужен вход', () {
    final failure =
        handler.handleError(const VideoException('unplayable', reason: 'Войдите в аккаунт', needsSignIn: true))
            as VideoFailure;

    expect(failure.message, 'Войдите в аккаунт');
    expect(failure.needsSignIn, isTrue);
  });

  test('подстановки попадают в текст', () {
    final failure = handler.handleError(const VideoException('mux', args: {'error': 'moof before moov'}));

    expect(failure.message, 'Не удалось собрать файл: moof before moov');
  });

  test('HTTP 403 и 429 от googlevideo — свои ошибки', () {
    expect(handler.handleError(_dioException(status: 403)).code, codes.streamForbidden);
    expect(handler.handleError(_dioException(status: 429)).code, codes.rateLimited);
    expect(handler.handleError(_dioException(status: 500)).message, 'YouTube ответил ошибкой 500.');
  });

  test('таймаут и нет соединения', () {
    expect(handler.handleError(_dioException(type: DioExceptionType.receiveTimeout)), isA<ConnectionTimeOutFailure>());
    expect(handler.handleError(_dioException(type: DioExceptionType.connectionError)), isA<NoConnectionFailure>());
  });

  test('Failure возвращается как есть, прочее — неизвестная ошибка', () {
    const failure = VideoFailure(code: 'x', message: 'готовая');

    expect(handler.handleError(failure), same(failure));
    expect(handler.handleError(Exception('boom')), isA<UnknownFailure>());
  });

  test('AuthenticationErrorHandler: нет WebView2 и сессия не выдана', () {
    const authenticationHandler = AuthenticationErrorHandler();

    expect(authenticationHandler.handleError(StateError('Webview is not available')).code, 'web_view_runtime');
    expect(
      authenticationHandler.handleError(const AuthenticationException('session_not_issued')).message,
      'Вход не завершён: YouTube не выдал cookies аккаунта. Попробуйте ещё раз.',
    );
    expect(authenticationHandler.handleError(PlatformException(code: 'x')), isA<UnknownFailure>());
  });
}
