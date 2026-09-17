import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';
import '../error_handler/error_handler.dart';

part 'player_error_handler.dart';

final class PlayerErrorCodes extends ErrorCodes {
  /// The download folder is missing: the drive is unplugged or the folder
  /// was deleted
  final String folderNotFound;
  final String storage;

  /// The player could not open or play the video
  final String playback;

  const PlayerErrorCodes({
    super.otherError,
    this.folderNotFound = 'folder_not_found',
    this.storage = 'storage',
    this.playback = 'playback',
  });
}

/// Player library and playback exception
final class PlayerException implements Exception {
  final String code;

  /// Folder or file the error is about
  final String? path;
  final Object? cause;

  const PlayerException(this.code, {this.path, this.cause});

  @override
  String toString() => 'PlayerException($code, $path, $cause)';
}

final class PlayerFailure extends Failure {
  const PlayerFailure({super.code, super.message, super.stackTrace});

  @override
  PlayerFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => PlayerFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  PlayerFailure fromOtherFailure(Failure other) => PlayerFailure(
    code: other.code,
    message: other.message,
    stackTrace: other.stackTrace,
  );
}
