import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../failure/failure.dart';
import '../../logger/app_logger.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../repositories/repositories.dart';

part 'settings_state.dart';

/// App settings: download folder and interface language
final class SettingsController extends Cubit<SettingsState> {
  static const _appLogger = AppLogger(where: 'SettingsController');

  final SettingsRepositoryInterface _settingsRepository;

  /// [initialLanguage]: the language read before the app started,
  /// so the first frame is already in it
  SettingsController({
    required this._settingsRepository,
    AppLanguageModel initialLanguage = AppLanguageModel.fallback,
  }) : super(SettingsInitialState(language: initialLanguage));

  void _safeEmit(SettingsState state) {
    if (isClosed) return;

    emit(state);
  }

  Future<void> loadSettings() async {
    _safeEmit(state.copyWith(isLoading: true, clearFailure: true));

    final directoryResponse = await _settingsRepository.getDownloadDirectory();

    if (directoryResponse.isFailed) {
      _logAndEmitFailure(directoryResponse.failure, 'Failed to load settings');

      return;
    }

    final languageResponse = await _settingsRepository.getLanguage();

    if (languageResponse.isFailed) {
      _logAndEmitFailure(languageResponse.failure, 'Failed to load language');

      return;
    }

    _safeEmit(
      state.copyWith(
        isLoading: false,
        downloadDirectory: directoryResponse.requireData,
        language: languageResponse.requireData,
      ),
    );
  }

  Future<void> pickDownloadDirectory() async {
    _safeEmit(state.copyWith(clearFailure: true));

    final directoryResponse = await _settingsRepository.pickDownloadDirectory(
      initialDirectory: state.downloadDirectory?.path,
    );

    if (directoryResponse.isFailed) {
      _logAndEmitFailure(
        directoryResponse.failure,
        'Failed to pick download directory',
      );

      return;
    }

    final directory = directoryResponse.data;

    /// The dialog was closed: the folder stays the same
    if (directory == null) return;

    _safeEmit(state.copyWith(downloadDirectory: directory));
  }

  Future<void> resetDownloadDirectory() async {
    _safeEmit(state.copyWith(clearFailure: true));

    final directoryResponse = await _settingsRepository
        .resetDownloadDirectory();

    if (directoryResponse.isFailed) {
      _logAndEmitFailure(
        directoryResponse.failure,
        'Failed to reset download directory',
      );

      return;
    }

    _safeEmit(state.copyWith(downloadDirectory: directoryResponse.requireData));
  }

  /// Switches the interface language right away and saves it
  /// for the next launches
  Future<void> changeLanguage(AppLanguageModel language) async {
    if (language == state.language) return;

    final previousLanguage = state.language;

    _safeEmit(state.copyWith(language: language, clearFailure: true));

    final languageResponse = await _settingsRepository.setLanguage(language);

    if (languageResponse.isFailed) {
      /// Not saved: the next launch would open in the previous language,
      /// so the switch is rolled back
      _safeEmit(state.copyWith(language: previousLanguage));
      _logAndEmitFailure(languageResponse.failure, 'Failed to save language');
    }
  }

  void _logAndEmitFailure(Failure? failure, String description) {
    final effectiveFailure = failure ?? const OtherFailure();

    _appLogger.logFailure(effectiveFailure, description);

    _safeEmit(state.copyWith(isLoading: false, failure: effectiveFailure));
  }
}
