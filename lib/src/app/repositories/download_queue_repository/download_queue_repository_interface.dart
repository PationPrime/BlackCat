import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

/// Download queue that survives an app restart
abstract interface class DownloadQueueRepositoryInterface
    implements BaseRepositoryInterface {
  /// Downloads from previous launches by section and position within it.
  ///
  /// Downloaded bytes are taken from the unfinished files on disk and their
  /// slice state: progress is saved to the database less often than the files
  /// are written. Work folders of downloads that are not in the queue are wiped
  Future<OperationResult<List<DownloadTaskModel>>> restoreTasks();

  /// Saves downloads: section, position, status, selected streams
  Future<OperationResult<void>> saveTasks(List<DownloadTaskModel> tasks);

  /// Saves the progress of the active download
  Future<OperationResult<void>> updateProgress({
    required String taskId,
    required int downloadedBytes,
    int? totalBytes,
  });

  /// Saves a local copy of the download thumbnail into the app folder and returns
  /// its path. `null` if the video has no thumbnail
  Future<OperationResult<String?>> saveThumbnail(DownloadTaskModel task);

  /// Removes downloads from the queue and deletes their unfinished files
  /// and thumbnail copies
  Future<OperationResult<void>> removeTasks(List<String> taskIds);
}
