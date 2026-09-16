import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';
import '../error_handler/error_handler.dart';

part 'dependency_error_handler.dart';

final class DependencyErrorCodes extends ErrorCodes {
  /// No official build for this operating system or processor
  final String unsupportedPlatform;
  final String download;
  final String checksumMissing;
  final String checksumMismatch;
  final String extract;
  final String save;

  /// Installed, but the program does not start
  final String notWorking;

  const DependencyErrorCodes({
    super.otherError,
    super.canceled,
    this.unsupportedPlatform = 'unsupported_platform',
    this.download = 'download',
    this.checksumMissing = 'checksum_missing',
    this.checksumMismatch = 'checksum_mismatch',
    this.extract = 'extract',
    this.save = 'save',
    this.notWorking = 'not_working',
  });
}

/// yt-dlp or Deno installation exception
final class DependencyException implements Exception {
  final String code;

  /// Program name for the message: `yt-dlp` or `Deno`
  final String? name;

  /// Original error for the message
  final Object? cause;

  const DependencyException(this.code, {this.name, this.cause});

  @override
  String toString() => 'DependencyException($code, $name, $cause)';
}

final class DependencyFailure extends Failure {
  const DependencyFailure({super.code, super.message, super.stackTrace});

  @override
  DependencyFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => DependencyFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  DependencyFailure fromOtherFailure(Failure other) => DependencyFailure(
    code: other.code,
    message: other.message,
    stackTrace: other.stackTrace,
  );
}
