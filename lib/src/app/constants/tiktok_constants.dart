abstract final class TikTokConstants {
  static const origin = 'https://www.tiktok.com';

  /// The page of a video opens by its id alone: `@_` stands for any author
  static String videoPageUrl(String id, {String? author}) =>
      '$origin/@${author ?? '_'}/video/$id';

  /// Connections of one video: its file is a few megabytes
  static const connections = 4;

  /// The video file in the download work folder: `tiktok-<bitrate>.mp4`
  static const filePrefix = 'tiktok-';
}
