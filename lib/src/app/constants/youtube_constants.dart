abstract final class YouTubeConstants {
  static const origin = 'https://www.youtube.com';

  static const browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// The embedded player is treated as hosted on a third-party page:
  /// any address outside YouTube works
  static const embedUrl = 'https://www.reddit.com/';

  /// YouTube serves large responses slowly; 10 MiB chunks
  /// (as the web player and yt-dlp use) download fast
  static const streamChunkSize = 10 << 20;

  /// Chunks of a download requested at the same time
  static const streamConnections = 4;

  /// Without `passive=true`: with it Google skips the sign-in form
  static final signInUrl = Uri.https('accounts.google.com', '/ServiceLogin', {
    'service': 'youtube',
    'hl': 'ru',
    'continue':
        'https://www.youtube.com/signin?action_handle_signin=true&app=desktop&hl=ru&next=%2F',
  }).toString();

  /// The last sign-in redirect: back to the YouTube home page
  static const signInCallbackHost = 'www.youtube.com';
  static const signInCallbackPath = '/';
}
