import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../tools/tools.dart';
import '../base_repository_interface.dart';

/// yt-dlp and the JavaScript runtime it needs for YouTube
abstract interface class DependenciesRepositoryInterface
    implements BaseRepositoryInterface {
  /// yt-dlp can run on this platform
  bool get isSupported;

  /// What is installed. [refresh]: look again instead of the kept result
  Future<OperationResult<YtDlpSetupModel>> getSetup({bool refresh = false});

  /// Downloads the missing programs from their GitHub releases into the app
  /// folder and checks their SHA-256. Fails if anything is still missing
  Future<OperationResult<YtDlpSetupModel>> installMissing({
    required void Function(DependencyInstallProgressModel progress) onProgress,
    DownloadCancellation? cancellation,
  });
}
