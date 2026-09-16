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

  /// The file picker failed to open
  final String cookiesPicker;

  /// The chosen cookies.txt could not be read
  final String cookiesRead;

  /// Not a `.txt` file or binary content
  final String cookiesNotText;
  final String cookiesTooLarge;

  /// Cookies exported as JSON instead of the Netscape format
  final String cookiesJson;

  /// Text without a single Netscape cookie line
  final String cookiesFormat;
  final String cookiesNoYouTube;

  /// youtube.com cookies without a signed-in account
  final String cookiesNoSession;
  final String cookiesExpired;

  /// The imported cookies could not be saved
  final String cookiesSave;

  const AuthenticationErrorCodes({
    super.otherError,
    this.webViewRuntime = 'web_view_runtime',
    this.sessionNotIssued = 'session_not_issued',
    this.cookiesPicker = 'cookies_picker',
    this.cookiesRead = 'cookies_read',
    this.cookiesNotText = 'cookies_not_text',
    this.cookiesTooLarge = 'cookies_too_large',
    this.cookiesJson = 'cookies_json',
    this.cookiesFormat = 'cookies_format',
    this.cookiesNoYouTube = 'cookies_no_youtube',
    this.cookiesNoSession = 'cookies_no_session',
    this.cookiesExpired = 'cookies_expired',
    this.cookiesSave = 'cookies_save',
  });
}

/// YouTube account sign-in exception
final class AuthenticationException implements Exception {
  final String code;

  /// Original error for the message, e.g. of reading the file
  final Object? cause;

  const AuthenticationException(this.code, {this.cause});

  @override
  String toString() => 'AuthenticationException($code, $cause)';
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
