abstract final class StorageConstants {
  /// Папка приложения в `%LOCALAPPDATA%`
  static const localAppFolder = 'YT Download';

  /// Профиль WebView2 окна входа: хранит сессию Google между запусками
  static const signInProfileFolder = 'WebView';

  /// Профиль WebView2 для исполнения JavaScript плеера
  static const jsEngineProfileFolder = 'JsEngine';

  /// Кэш JavaScript плеера YouTube
  static const playerCacheFolder = 'Cache/players';

  /// cookies.txt аккаунта в `%APPDATA%`
  static const cookiesFileName = 'youtube_cookies.txt';
}
