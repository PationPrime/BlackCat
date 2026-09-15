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
        AuthenticationException(:final code)
            when code == errorCodes.webViewRuntime =>
          AuthenticationFailure(
            code: code,
            message: LocaleKeys.app_errors_authentication_web_view_runtime.tr(),
            stackTrace: stackTrace,
          ),
        AuthenticationException(:final code)
            when code == errorCodes.sessionNotIssued =>
          AuthenticationFailure(
            code: code,
            message: LocaleKeys.app_errors_authentication_session_not_issued
                .tr(),
            stackTrace: stackTrace,
          ),

        /// flutter_web_auth_2 сообщает об отсутствии WebView2 через [StateError]
        StateError _ => AuthenticationFailure(
          code: errorCodes.webViewRuntime,
          message: LocaleKeys.app_errors_authentication_web_view_runtime.tr(),
          stackTrace: stackTrace,
        ),
        _ => null,
      };
}
