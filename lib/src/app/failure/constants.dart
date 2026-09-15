part of 'failure.dart';

/// Глобальная неизвестная ошибка
class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Unknown error', super.stackTrace});

  @override
  UnknownFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => UnknownFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  UnknownFailure fromOtherFailure(Failure other) =>
      UnknownFailure(message: other.message, stackTrace: other.stackTrace);
}

/// Сервер не ответил за отведённое время
class ConnectionTimeOutFailure extends Failure {
  final String? errorCode;

  const ConnectionTimeOutFailure({
    this.errorCode = 'connection_timeout',
    super.message = 'Connection timeout',
    super.stackTrace,
    super.dioException,
  }) : super(code: errorCode);

  @override
  ConnectionTimeOutFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => ConnectionTimeOutFailure(
    message: message ?? '$error',
    stackTrace: stackTrace,
  );

  @override
  ConnectionTimeOutFailure fromOtherFailure(Failure other) =>
      ConnectionTimeOutFailure(
        message: other.message,
        stackTrace: other.stackTrace,
        dioException: other.dioException,
      );
}

/// Нет соединения с сервером
class NoConnectionFailure extends Failure {
  final String? errorCode;

  const NoConnectionFailure({
    this.errorCode = 'no_connection',
    super.message = 'No connection',
    super.stackTrace,
    super.dioException,
  }) : super(code: errorCode);

  @override
  NoConnectionFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => NoConnectionFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  NoConnectionFailure fromOtherFailure(Failure other) => NoConnectionFailure(
    message: other.message,
    stackTrace: other.stackTrace,
    dioException: other.dioException,
  );
}

class OtherFailure extends Failure {
  final String errorCode;

  const OtherFailure({
    this.errorCode = 'other_error',
    super.message = 'Something went wrong',
    super.stackTrace,
    super.dioException,
    super.details,
  }) : super(code: errorCode);

  @override
  OtherFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => OtherFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  OtherFailure fromOtherFailure(Failure other) => OtherFailure(
    message: other.message,
    stackTrace: other.stackTrace,
    dioException: other.dioException,
    details: other.details,
  );
}
