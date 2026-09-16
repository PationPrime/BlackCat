/// Official builds the app installs when yt-dlp or a JavaScript runtime
/// is missing. `latest/download` always points to the newest release
abstract final class DependencyConstants {
  static const ytDlpReleaseUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download';

  /// SHA-256 of every yt-dlp release file: `<hash>  <file>` per line
  static const ytDlpChecksumsFile = 'SHA2-256SUMS';

  static const denoReleaseUrl =
      'https://github.com/denoland/deno/releases/latest/download';

  /// Deno publishes a checksum next to each archive: `<archive>.sha256sum`
  static const denoChecksumSuffix = '.sha256sum';

  /// Guide on exporting cookies.txt from a browser
  static const cookiesGuideUrl =
      'https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp';

  /// Oldest JavaScript runtimes yt-dlp accepts for YouTube checks
  static const minDenoVersion = [2, 3, 0];
  static const minNodeVersion = [22, 0, 0];
  static const minBunVersion = [1, 2, 11];
}
