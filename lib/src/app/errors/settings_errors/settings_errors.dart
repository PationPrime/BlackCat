import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';
import '../error_handler/error_handler.dart';

part 'settings_error_handler.dart';

final class SettingsErrorCodes extends ErrorCodes {
  final String picker;
  final String storage;

  const SettingsErrorCodes({
    super.otherError,
    this.picker = 'picker',
    this.storage = 'storage',
  });
}

/// Settings exception: thrown by the settings repository
final class SettingsException implements Exception {
  final String code;
  final Object? cause;

  const SettingsException(this.code, {this.cause});

  @override
  String toString() => 'SettingsException($code, $cause)';
}

final class SettingsFailure extends Failure {
  const SettingsFailure({super.code, super.message, super.stackTrace});

  @override
  SettingsFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => SettingsFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  SettingsFailure fromOtherFailure(Failure other) => SettingsFailure(
    code: other.code,
    message: other.message,
    stackTrace: other.stackTrace,
  );
}
