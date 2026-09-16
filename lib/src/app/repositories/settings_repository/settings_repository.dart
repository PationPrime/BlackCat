import 'package:easy_localization/easy_localization.dart';

import '../../data_sources/data_sources.dart';
import '../../errors/errors.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import 'settings_repository_interface.dart';

final class SettingsRepository implements SettingsRepositoryInterface {
  final LocalSettingsDataSource _localSettingsDataSource;
  final FileSelectorService _fileSelectorService;
  final FileSystemService _fileSystemService;

  const SettingsRepository({
    required this._localSettingsDataSource,
    required this._fileSelectorService,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<SettingsErrorCodes> get errorHandler =>
      const SettingsErrorHandler();

  @override
  Future<OperationResult<DownloadDirectoryModel>> getDownloadDirectory() async {
    try {
      final savedPath = await _localSettingsDataSource.getDownloadDirectory();

      if (savedPath != null && savedPath.isNotEmpty) {
        return ok(DownloadDirectoryModel(path: savedPath, isDefault: false));
      }

      return ok(await _defaultDirectory());
    } catch (error, stackTrace) {
      return fail(
        errorHandler.handleError(
          SettingsException(const SettingsErrorCodes().storage, cause: error),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<OperationResult<DownloadDirectoryModel?>> pickDownloadDirectory({
    String? initialDirectory,
  }) async {
    final String? pickedPath;

    try {
      pickedPath = await _fileSelectorService.pickDirectory(
        initialDirectory: initialDirectory,
        confirmButtonText: LocaleKeys.app_settings_download_directory_picker_confirm
            .tr(),
      );
    } catch (error, stackTrace) {
      return fail(
        errorHandler.handleError(
          SettingsException(const SettingsErrorCodes().picker, cause: error),
          stackTrace: stackTrace,
        ),
      );
    }

    if (pickedPath == null) {
      return ok(null);
    }

    try {
      final defaultDirectory = await _defaultDirectory();

      /// Downloads was picked: that is the default value
      if (pickedPath == defaultDirectory.path) {
        await _localSettingsDataSource.clearDownloadDirectory();

        return ok(defaultDirectory);
      }

      await _localSettingsDataSource.setDownloadDirectory(pickedPath);

      return ok(DownloadDirectoryModel(path: pickedPath, isDefault: false));
    } catch (error, stackTrace) {
      return fail(
        errorHandler.handleError(
          SettingsException(const SettingsErrorCodes().storage, cause: error),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<OperationResult<DownloadDirectoryModel>>
  resetDownloadDirectory() async {
    try {
      await _localSettingsDataSource.clearDownloadDirectory();

      return ok(await _defaultDirectory());
    } catch (error, stackTrace) {
      return fail(
        errorHandler.handleError(
          SettingsException(const SettingsErrorCodes().storage, cause: error),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<OperationResult<AppLanguageModel>> getLanguage() async {
    try {
      return ok(
        AppLanguageModel.fromCode(
          await _localSettingsDataSource.getLanguageCode(),
        ),
      );
    } catch (error, stackTrace) {
      return fail(
        errorHandler.handleError(
          SettingsException(const SettingsErrorCodes().storage, cause: error),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<OperationResult<AppLanguageModel>> setLanguage(
    AppLanguageModel language,
  ) async {
    try {
      await _localSettingsDataSource.setLanguageCode(language.code);

      return ok(language);
    } catch (error, stackTrace) {
      return fail(
        errorHandler.handleError(
          SettingsException(const SettingsErrorCodes().storage, cause: error),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<DownloadDirectoryModel> _defaultDirectory() async =>
      DownloadDirectoryModel(
        path: await _fileSystemService.defaultDownloadsFolder(),
        isDefault: true,
      );
}
