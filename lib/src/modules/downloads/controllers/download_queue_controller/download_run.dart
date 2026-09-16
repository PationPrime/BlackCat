part of 'download_queue_controller.dart';

/// Result of a stopped download. [interrupted]: the stop interrupted
/// the download rather than arriving after it had finished on its own
typedef _StoppedRun = ({
  OperationResult<DownloadedFileModel> result,
  bool interrupted,
});

/// A running download: its stopping and result
final class _DownloadRun {
  final String taskId;
  final cancellation = DownloadCancellation();
  final _completer = Completer<OperationResult<DownloadedFileModel>>();

  /// When the download last reported its speed
  DateTime? speedReportedAt;

  /// When its progress was last shown
  DateTime? progressShownAt;

  DownloadProgressModel? _deferredProgress;
  Timer? _deferredTimer;

  _DownloadRun(this.taskId);

  bool get isCompleted => _completer.isCompleted;

  Future<OperationResult<DownloadedFileModel>> get result => _completer.future;

  void complete(OperationResult<DownloadedFileModel> result) =>
      _completer.complete(result);

  /// Stops the download together with the progress waiting to be shown
  void stop() {
    cancelDeferredProgress();
    cancellation.cancel();
  }

  /// Keeps [progress] to show it [after] the given time. A report without
  /// a speed keeps the speed of the report it replaces
  void deferProgress(
    DownloadProgressModel progress, {
    required Duration after,
    required void Function(DownloadProgressModel progress) onDue,
  }) {
    final previous = _deferredProgress;

    _deferredProgress = progress.speed == null && previous?.speed != null
        ? DownloadProgressModel(
            progress.stage,
            progress.percent,
            speed: previous!.speed,
            downloadedBytes: progress.downloadedBytes,
            totalBytes: progress.totalBytes,
          )
        : progress;

    _deferredTimer ??= Timer(after, () {
      final due = _deferredProgress;

      _deferredTimer = null;
      _deferredProgress = null;

      if (due != null) onDue(due);
    });
  }

  void cancelDeferredProgress() {
    _deferredTimer?.cancel();
    _deferredTimer = null;
    _deferredProgress = null;
  }
}
