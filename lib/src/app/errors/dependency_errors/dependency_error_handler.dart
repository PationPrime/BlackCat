part of 'dependency_errors.dart';

class DependencyErrorHandler extends ErrorHandler<DependencyErrorCodes> {
  const DependencyErrorHandler({
    super.errorCodes = const DependencyErrorCodes(),
  });

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {};

  @override
  Failure? handleDomainException(Object error, StackTrace? stackTrace) =>
      switch (error) {
        DependencyException(:final code, :final name, :final cause) =>
          DependencyFailure(
            code: code,
            message: _messageFor(
              code,
            ).tr(namedArgs: {'name': name ?? '', 'error': '${cause ?? code}'}),
            stackTrace: stackTrace,
          ),
        _ => null,
      };

  String _messageFor(String code) => switch (code) {
    'unsupported_platform' =>
      LocaleKeys.app_errors_dependencies_unsupported_platform,
    'download' => LocaleKeys.app_errors_dependencies_download,
    'checksum_missing' => LocaleKeys.app_errors_dependencies_checksum_missing,
    'checksum_mismatch' => LocaleKeys.app_errors_dependencies_checksum_mismatch,
    'extract' => LocaleKeys.app_errors_dependencies_extract,
    'save' => LocaleKeys.app_errors_dependencies_save,
    'not_working' => LocaleKeys.app_errors_dependencies_not_working,
    'canceled' => LocaleKeys.app_errors_dependencies_canceled,
    _ => LocaleKeys.app_errors_unknown,
  };
}
