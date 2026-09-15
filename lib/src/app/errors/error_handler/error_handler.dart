import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../../logger/app_logger.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';

/// Базовый класс для преобразования ошибок в [Failure]
abstract class ErrorHandler<T extends ErrorCodes> {
  static const _appLogger = AppLogger(where: 'ErrorHandler');

  final T errorCodes;

  const ErrorHandler({required this.errorCodes});

  /// Ответы с этими HTTP-статусами превращаются в свои [Failure]
  Map<String, Failure Function(ApiError)> get errorCodeToFailure;

  /// Исключения своей предметной области (не сетевые).
  /// `null` — исключение не относится к домену обработчика
  Failure? handleDomainException(Object error, StackTrace? stackTrace) => null;

  Failure handleError(Object error, {StackTrace? stackTrace}) {
    if (error is Failure) {
      return error;
    }

    final domainFailure = handleDomainException(error, stackTrace);

    if (domainFailure != null) {
      return domainFailure;
    }

    if (error is DioException) {
      final apiError = _extractError(error, stackTrace);
      final failureBuilder = errorCodeToFailure[apiError.code];

      return failureBuilder != null
          ? failureBuilder.call(apiError)
          : handleUnhandledError(error, stackTrace);
    }

    final failure = switch (error) {
      TypeError exception => OtherFailure(
        errorCode: errorCodes.typeError,
        message: LocaleKeys.app_errors_unknown.tr(
          namedArgs: {'error': '$exception'},
        ),
        stackTrace: stackTrace,
      ),
      _ => UnknownFailure(
        message: LocaleKeys.app_errors_unknown.tr(
          namedArgs: {'error': '$error'},
        ),
        stackTrace: stackTrace,
      ),
    };

    _appLogger.logFailure(failure, 'Unhandled error');

    return failure;
  }

  Failure handleUnhandledError(DioException error, [StackTrace? stackTrace]) {
    final status = error.response?.statusCode;

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => ConnectionTimeOutFailure(
        errorCode: errorCodes.connectionTimeout,
        message: LocaleKeys.app_errors_network_timeout.tr(),
        stackTrace: stackTrace,
        dioException: error,
      ),
      DioExceptionType.connectionError => NoConnectionFailure(
        errorCode: errorCodes.noConnection,
        message: LocaleKeys.app_errors_network_no_connection.tr(),
        stackTrace: stackTrace,
        dioException: error,
      ),
      DioExceptionType.cancel => OtherFailure(
        errorCode: errorCodes.canceled,
        message: LocaleKeys.app_errors_network_canceled.tr(),
        stackTrace: stackTrace,
        dioException: error,
      ),
      _ when status != null => OtherFailure(
        errorCode: '$status',
        message: LocaleKeys.app_errors_network_http_status.tr(
          namedArgs: {'status': '$status'},
        ),
        stackTrace: stackTrace,
        dioException: error,
      ),
      _ => OtherFailure(
        errorCode: errorCodes.otherError,
        message: LocaleKeys.app_errors_network_unexpected.tr(
          namedArgs: {'error': error.message ?? error.type.name},
        ),
        stackTrace: stackTrace,
        dioException: error,
      ),
    };
  }

  /// Код ошибки [DioException] — HTTP-статус ответа
  ApiError _extractError(DioException error, [StackTrace? stackTrace]) =>
      ApiError(
        code: '${error.response?.statusCode}',
        message: error.message ?? '',
        stackTrace: stackTrace,
        dioException: error,
      );
}
