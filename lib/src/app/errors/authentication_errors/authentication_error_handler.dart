part of 'authentication_errors.dart';

class AuthenticationErrorHandler
    extends ErrorHandler<AuthenticationErrorCodes> {
  const AuthenticationErrorHandler({
    super.errorCodes = const AuthenticationErrorCodes(),
  });

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {};

  @override
  Failure? handleDomainException(Object error, StackTrace? stackTrace) =>
      switch (error) {
        AuthenticationException(:final code, :final cause) =>
          AuthenticationFailure(
            code: code,
            message: _messageFor(code, cause),
            stackTrace: stackTrace,
          ),

        /// flutter_web_auth_2 reports missing WebView2 via [StateError]
        StateError _ => AuthenticationFailure(
          code: errorCodes.webViewRuntime,
          message: LocaleKeys.app_errors_authentication_web_view_runtime.tr(),
          stackTrace: stackTrace,
        ),
        _ => null,
      };

  String _messageFor(String code, Object? cause) {
    final key = switch (code) {
      'web_view_runtime' =>
        LocaleKeys.app_errors_authentication_web_view_runtime,
      'session_not_issued' =>
        LocaleKeys.app_errors_authentication_session_not_issued,
      'cookies_picker' => LocaleKeys.app_errors_authentication_cookies_picker,
      'cookies_read' => LocaleKeys.app_errors_authentication_cookies_read,
      'cookies_not_text' =>
        LocaleKeys.app_errors_authentication_cookies_not_text,
      'cookies_too_large' =>
        LocaleKeys.app_errors_authentication_cookies_too_large,
      'cookies_json' => LocaleKeys.app_errors_authentication_cookies_json,
      'cookies_format' => LocaleKeys.app_errors_authentication_cookies_format,
      'cookies_no_youtube' =>
        LocaleKeys.app_errors_authentication_cookies_no_youtube,
      'cookies_no_session' =>
        LocaleKeys.app_errors_authentication_cookies_no_session,
      'cookies_expired' => LocaleKeys.app_errors_authentication_cookies_expired,
      'cookies_save' => LocaleKeys.app_errors_authentication_cookies_save,
      _ => LocaleKeys.app_errors_unknown,
    };

    return key.tr(namedArgs: {'error': '${cause ?? code}'});
  }
}
