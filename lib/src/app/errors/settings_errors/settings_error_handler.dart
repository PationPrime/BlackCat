part of 'settings_errors.dart';

class SettingsErrorHandler extends ErrorHandler<SettingsErrorCodes> {
  const SettingsErrorHandler({super.errorCodes = const SettingsErrorCodes()});

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {};

  @override
  Failure? handleDomainException(Object error, StackTrace? stackTrace) =>
      switch (error) {
        SettingsException(:final code, :final cause)
            when code == errorCodes.picker =>
          SettingsFailure(
            code: code,
            message: LocaleKeys.app_errors_settings_picker.tr(
              namedArgs: {'error': '$cause'},
            ),
            stackTrace: stackTrace,
          ),
        SettingsException(:final code, :final cause) => SettingsFailure(
          code: errorCodes.storage,
          message: LocaleKeys.app_errors_settings_storage.tr(
            namedArgs: {'error': '${cause ?? code}'},
          ),
          stackTrace: stackTrace,
        ),
        _ => null,
      };
}
