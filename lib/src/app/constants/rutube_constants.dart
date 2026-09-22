abstract final class RuTubeConstants {
  static const origin = 'https://rutube.ru';

  /// Player settings of a video: title, author, preview and the HLS link.
  /// `no_404` makes a blocked video answer with the reason instead of 404
  static String playOptionsUrl(
    String videoId, {
    String? privateKey,
    String apiOrigin = origin,
  }) => Uri.parse('$apiOrigin/api/play/options/$videoId/')
      .replace(
        queryParameters: {
          'no_404': 'true',
          'referer': origin,
          'pver': 'v2',
          'p': ?privateKey,
        },
      )
      .toString();

  /// Segments downloaded at the same time: they are small, and each costs
  /// a round trip to the CDN
  static const segmentConnections = 8;

  /// Segments of the variant finished before a pause keep this name
  /// in the download work folder: `rutube-<bandwidth>-<index>.ts`
  static const segmentPrefix = 'rutube-';
}
