import 'package:flutter/foundation.dart';

import '../failure/failure.dart';

@immutable
class AppLogger {
  final String where;

  const AppLogger({required this.where});

  void logError(
    String message, {
    String? code,
    bool showWhere = true,
    String? lexicalScope,
    StackTrace? stackTrace,
    String? sign,
  }) {
    if (kReleaseMode) {
      return;
    }

    final text =
        '${sign ?? ''}${showWhere ? ' ($where)' : ''}${lexicalScope is String ? "\n[lexical scope]: $lexicalScope" : ""}${code is String ? "\n[code]: [$code]" : ""}\n[message]: $message${stackTrace is StackTrace ? "\n[stackTrace]: $stackTrace" : ""}';

    debugPrintSynchronously('\x1B[31m[ERROR]:$text\x1B[0m');
  }

  void logFailure(
    Failure failure,
    String errorDescription, {
    StackTrace? stackTrace,
  }) => logError(
    '$errorDescription: ${failure.message}',
    code: failure.code,
    stackTrace: stackTrace ?? failure.stackTrace,
  );

  void logMessage(
    String message, {
    String? lexicalScope,
    bool showWhere = true,
    String? sign = '📝',
  }) {
    if (kReleaseMode) {
      return;
    }

    final text =
        "${sign ?? ''}${showWhere ? ' ($where)' : ''}${lexicalScope is String ? " (lexical scope: $lexicalScope)" : ""}: $message";

    debugPrintSynchronously('\x1B[32m[MESSAGE]: $text\x1B[0m');
  }
}
