abstract final class YouTubeConstants {
  static const origin = 'https://www.youtube.com';

  static const browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// Встроенный плеер считается размещённым на сторонней странице:
  /// подходит любой адрес не на YouTube
  static const embedUrl = 'https://www.reddit.com/';

  /// Большие ответы YouTube отдаёт медленно; куски по 10 МиБ
  /// (как у веб-плеера и yt-dlp) качаются быстро
  static const streamChunkSize = 10 << 20;

  /// Без `passive=true`: с ним Google пропускает форму входа
  static final signInUrl = Uri.https('accounts.google.com', '/ServiceLogin', {
    'service': 'youtube',
    'hl': 'ru',
    'continue':
        'https://www.youtube.com/signin?action_handle_signin=true&app=desktop&hl=ru&next=%2F',
  }).toString();

  /// Последний редирект входа — возврат на главную YouTube
  static const signInCallbackHost = 'www.youtube.com';
  static const signInCallbackPath = '/';
}
