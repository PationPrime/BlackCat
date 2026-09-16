abstract final class DownloadConstants {
  /// The download progress, speed and remaining time change on the screen
  /// no more often: frequent changes look jerky. The progress bar animates
  /// over the same time, so it moves smoothly
  static const progressUpdateInterval = Duration(seconds: 1);
}
