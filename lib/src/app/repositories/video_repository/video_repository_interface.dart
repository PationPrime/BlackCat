import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../tools/tools.dart';
import '../base_repository_interface.dart';

abstract interface class VideoRepositoryInterface
    implements BaseRepositoryInterface {
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url);

  /// Downloads the video in the selected quality into [destinationDirectory]
  /// (Downloads by default). Returns the finished file and its size.
  ///
  /// Unfinished data is kept in the [taskId] download work folder. Calling again
  /// with the same [taskId] and the [streams] of the previous run continues from
  /// the same place, both after a pause via [cancellation] and after an app
  /// restart. [onStreamsSelected] reports the streams to remember
  /// for the next resume
  Future<OperationResult<DownloadedFileModel>> downloadVideo({
    required String taskId,
    required String url,
    required String quality,
    List<DownloadStreamModel> streams = const [],
    String? destinationDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  });
}
