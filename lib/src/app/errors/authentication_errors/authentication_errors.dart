import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';
import '../error_handler/error_handler.dart';

part 'authentication_error_handler.dart';

final class AuthenticationErrorCodes extends ErrorCodes {
  final String webViewRuntime;
  final String sessionNotIssued;

  const AuthenticationErrorCodes({
    super.otherError,
    this.webViewRuntime = 'web_view_runtime',
    this.sessionNotIssued = 'session_not_issued',
  });
}

/// YouTube account sign-in exception
final class AuthenticationException implements Exception {
  final String code;

  const AuthenticationException(this.code);

  @override
  String toString() => 'AuthenticationException($code)';
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    super.code,
    super.message,
    super.details,
    super.stackTrace,
  });

  @override
  AuthenticationFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => AuthenticationFailure(
    message: message ?? error.toString(),
    stackTrace: stackTrace,
  );

  @override
  AuthenticationFailure fromOtherFailure(Failure other) =>
      AuthenticationFailure(
        code: other.code,
        message: other.message,
        details: other.details,
        stackTrace: other.stackTrace,
      );
}
