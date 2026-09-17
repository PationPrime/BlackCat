part of 'player_errors.dart';

class PlayerErrorHandler extends ErrorHandler<PlayerErrorCodes> {
  const PlayerErrorHandler({super.errorCodes = const PlayerErrorCodes()});

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {};

  @override
  Failure? handleDomainException(Object error, StackTrace? stackTrace) =>
      switch (error) {
        PlayerException(:final code, :final path)
            when code == errorCodes.folderNotFound =>
          PlayerFailure(
            code: code,
            message: LocaleKeys.app_errors_player_folder_not_found.tr(
              namedArgs: {'path': path ?? ''},
            ),
            stackTrace: stackTrace,
          ),
        PlayerException(:final code, :final cause)
            when code == errorCodes.playback =>
          PlayerFailure(
            code: code,
            message: LocaleKeys.app_errors_player_playback.tr(
              namedArgs: {'error': '${cause ?? ''}'},
            ),
            stackTrace: stackTrace,
          ),
        PlayerException(:final code, :final cause) => PlayerFailure(
          code: errorCodes.storage,
          message: LocaleKeys.app_errors_player_storage.tr(
            namedArgs: {'error': '${cause ?? code}'},
          ),
          stackTrace: stackTrace,
        ),
        _ => null,
      };
}
