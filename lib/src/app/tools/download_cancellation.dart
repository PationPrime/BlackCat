import 'package:dio/dio.dart';

/// Stopping a download: pause or cancel. Downloaded bytes stay in the download
/// work folder, so the next run continues from the same place
final class DownloadCancellation {
  final _cancelToken = CancelToken();

  bool get isCancelled => _cancelToken.isCancelled;

  /// Token for the dio requests of this download
  CancelToken get cancelToken => _cancelToken;

  /// Completes when the download is stopped
  Future<void> get whenCancelled => _cancelToken.whenCancel;

  void cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
  }
}
