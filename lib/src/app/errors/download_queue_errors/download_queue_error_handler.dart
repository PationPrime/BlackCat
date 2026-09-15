part of 'download_queue_errors.dart';

class DownloadQueueErrorHandler extends ErrorHandler<DownloadQueueErrorCodes> {
  const DownloadQueueErrorHandler({
    super.errorCodes = const DownloadQueueErrorCodes(),
  });

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {};

  @override
  Failure? handleDomainException(Object error, StackTrace? stackTrace) =>
      switch (error) {
        DownloadQueueException(:final code, :final cause) =>
          DownloadQueueFailure(
            code: code,
            message: LocaleKeys.app_errors_download_queue_storage.tr(
              namedArgs: {'error': '${cause ?? code}'},
            ),
            stackTrace: stackTrace,
          ),
        _ => null,
      };
}
