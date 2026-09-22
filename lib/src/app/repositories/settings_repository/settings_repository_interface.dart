import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

abstract interface class SettingsRepositoryInterface
    implements BaseRepositoryInterface {
  /// Folder chosen by the user or Downloads by default
  Future<OperationResult<DownloadDirectoryModel>> getDownloadDirectory();

  /// System folder picker dialog. `null` if the user closed it
  Future<OperationResult<DownloadDirectoryModel?>> pickDownloadDirectory({
    String? initialDirectory,
  });

  /// Switches saving back to Downloads
  Future<OperationResult<DownloadDirectoryModel>> resetDownloadDirectory();

  /// Interface language chosen by the user or [AppLanguageModel.fallback]
  Future<OperationResult<AppLanguageModel>> getLanguage();

  /// Saves the interface language for the next launches
  Future<OperationResult<AppLanguageModel>> setLanguage(
    AppLanguageModel language,
  );

  /// Version of the running app build
  Future<OperationResult<AppVersionModel>> getAppVersion();
}
