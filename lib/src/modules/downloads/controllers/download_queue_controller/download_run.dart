part of 'download_queue_controller.dart';

/// Result of a stopped download. [interrupted]: the stop interrupted
/// the download rather than arriving after it had finished on its own
typedef _StoppedRun = ({OperationResult<DownloadedFileModel> result, bool interrupted});

/// A running download: its stopping and result
final class _DownloadRun {
  final String taskId;
  final cancellation = DownloadCancellation();
  final _completer = Completer<OperationResult<DownloadedFileModel>>();

  _DownloadRun(this.taskId);

  bool get isCompleted => _completer.isCompleted;

  Future<OperationResult<DownloadedFileModel>> get result => _completer.future;

  void complete(OperationResult<DownloadedFileModel> result) =>
      _completer.complete(result);
}
