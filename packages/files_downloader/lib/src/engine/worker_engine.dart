import '../models/download_result.dart';

/// What the download isolate runs: a download of sliced files
/// or of segments
abstract interface class WorkerEngine {
  Future<FilesDownloadResult> run();

  /// Pauses the download; [discard] deletes what it downloaded
  void stop({bool discard = false});

  void setSpeedLimit(int? bytesPerSecond);
}
