import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../tools/tools.dart';
import 'video_repository_interface.dart';
import 'yt_dlp_video_repository_interface.dart';

/// Sends every call to the repository of the site of the video link,
/// so the search and the download queue work alike for every site
class SourceVideoRepository implements VideoRepositoryInterface {
  final Map<VideoSourceModel, VideoRepositoryInterface> _repositories;

  const SourceVideoRepository(this._repositories);

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  VideoRepositoryInterface? _repositoryOf(String url) =>
      switch (VideoLinks.sourceOf(url)) {
        final source? => _repositories[source],
        null => null,
      };

  OperationResult<T> _unsupported<T>() => fail(
    errorHandler.handleError(
      VideoException(const VideoErrorCodes().unsupportedUrl),
    ),
  );

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async =>
      await _repositoryOf(url)?.getVideoInfo(url) ?? _unsupported();

  @override
  Future<OperationResult<DownloadedFileModel>> downloadVideo({
    required String taskId,
    required String url,
    required String quality,
    List<DownloadStreamModel> streams = const [],
    String? destinationDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async =>
      await _repositoryOf(url)?.downloadVideo(
        taskId: taskId,
        url: url,
        quality: quality,
        streams: streams,
        destinationDirectory: destinationDirectory,
        cancellation: cancellation,
        onStreamsSelected: onStreamsSelected,
        onProgress: onProgress,
      ) ??
      _unsupported();
}

/// yt-dlp repositories of every site
final class SourceYtDlpVideoRepository extends SourceVideoRepository
    implements YtDlpVideoRepositoryInterface {
  const SourceYtDlpVideoRepository(super._repositories);
}
