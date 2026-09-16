/// Way the app gets and downloads videos
enum DownloadEngineModel {
  /// The app's own downloader: requests of the embedded YouTube player
  /// and the WebView2 JavaScript engine
  builtIn,

  /// yt-dlp on the computer: the preferred engine once it and a JavaScript
  /// runtime are installed
  ytDlp;

  /// Works without yt-dlp
  static const fallback = builtIn;

  /// Engine by the stored name; [fallback] for an unknown or missing name
  static DownloadEngineModel fromName(String? name) =>
      values.where((engine) => engine.name == name).firstOrNull ?? fallback;
}
