import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';
import '../error_handler/error_handler.dart';

part 'download_queue_error_handler.dart';

final class DownloadQueueErrorCodes extends ErrorCodes {
  final String storage;

  const DownloadQueueErrorCodes({super.otherError, this.storage = 'storage'});
}

/// Download queue exception: failed to read or write
/// the queue database or unfinished files
final class DownloadQueueException implements Exception {
  final String code;
  final Object? cause;

  const DownloadQueueException(this.code, {this.cause});

  @override
  String toString() => 'DownloadQueueException($code, $cause)';
}

final class DownloadQueueFailure extends Failure {
  const DownloadQueueFailure({super.code, super.message, super.stackTrace});

  @override
  DownloadQueueFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => DownloadQueueFailure(
    message: message ?? '$error',
    stackTrace: stackTrace,
  );

  @override
  DownloadQueueFailure fromOtherFailure(Failure other) => DownloadQueueFailure(
    code: other.code,
    message: other.message,
    stackTrace: other.stackTrace,
  );
}
