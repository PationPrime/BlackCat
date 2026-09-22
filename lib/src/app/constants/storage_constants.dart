abstract final class StorageConstants {
  /// App folder in `%LOCALAPPDATA%`
  static const localAppFolder = 'PeekyCat';

  /// WebView2 profile of the sign-in window: keeps the Google session between launches
  static const signInProfileFolder = 'WebView';

  /// WebView2 profile for running the player JavaScript
  static const jsEngineProfileFolder = 'JsEngine';

  /// YouTube player JavaScript cache
  static const playerCacheFolder = 'Cache/players';

  /// Account cookies.txt in `%APPDATA%`
  static const cookiesFileName = 'youtube_cookies.txt';

  /// Where the account cookies.txt was imported from, next to it.
  /// Missing when the cookies come from the sign-in window
  static const cookiesSourceFileName = 'youtube_cookies_source.json';

  /// yt-dlp and Deno installed by the app in `%LOCALAPPDATA%\PeekyCat`
  static const toolsFolder = 'Tools';

  /// Unfinished download streams in `%LOCALAPPDATA%\PeekyCat`:
  /// each download has its own subfolder so it can continue after a pause
  /// and after an app restart
  static const downloadWorkFolder = 'Unfinished downloads';

  /// Local copies of downloaded video thumbnails in `%LOCALAPPDATA%\PeekyCat`:
  /// the downloaded list shows them without network access
  static const thumbnailsFolder = 'Thumbnails';

  /// Thumbnails of the player library videos in `%LOCALAPPDATA%\PeekyCat`:
  /// frames the system file manager shows or copies of the download thumbnails
  static const libraryThumbnailsFolder = 'Library thumbnails';

  /// Download queue database in `%APPDATA%`
  static const databaseFileName = 'youtube-downloader-database.sqlite';

  /// Download folder chosen by the user
  static const downloadDirectoryKey = 'settings.download_directory';

  /// App interface language chosen by the user
  static const languageKey = 'settings.language';
}
