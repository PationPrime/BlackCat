abstract class ErrorCodes {
  final String otherError;
  final String connectionTimeout;
  final String noConnection;
  final String canceled;
  final String typeError;

  const ErrorCodes({
    this.otherError = 'other_error',
    this.connectionTimeout = 'connection_timeout',
    this.noConnection = 'no_connection',
    this.canceled = 'canceled',
    this.typeError = 'type_error',
  });
}
