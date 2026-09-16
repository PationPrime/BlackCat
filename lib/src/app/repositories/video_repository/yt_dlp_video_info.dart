part of 'yt_dlp_video_repository.dart';

/// Video info from `yt-dlp --dump-single-json` with ready stream links
final class _YtDlpVideoInfo {
  /// The JSON as yt-dlp printed it: yt-dlp downloads from it later
  final String raw;
  final String? title;
  final String? channel;
  final num? duration;
  final String? thumbnail;
  final int? viewCount;
  final List<RawFormat> formats;

  /// Links are bound to the session and expire
  final DateTime expiresAt;

  const _YtDlpVideoInfo({
    required this.raw,
    required this.formats,
    required this.expiresAt,
    this.title,
    this.channel,
    this.duration,
    this.thumbnail,
    this.viewCount,
  });

  /// Throws [FormatException] for output that is not a video JSON
  factory _YtDlpVideoInfo.fromJson(String raw) {
    final json = jsonDecode(raw);

    if (json is! Map<String, dynamic>) {
      throw const FormatException('yt-dlp printed no video info');
    }

    final formats = [
      for (final format in json['formats'] as List? ?? const [])
        if (format is Map<String, dynamic>) format,
    ];

    return _YtDlpVideoInfo(
      raw: raw,
      title: json['title'] as String?,
      channel: (json['channel'] ?? json['uploader']) as String?,
      duration: json['duration'] as num?,
      thumbnail: json['thumbnail'] as String?,
      viewCount: (json['view_count'] as num?)?.toInt(),
      formats: formats,
      expiresAt: _expiry(formats),
    );
  }

  bool get expired => DateTime.now().isAfter(expiresAt);

  /// With a margin: a long download must not start on almost expired links
  static DateTime _expiry(List<RawFormat> formats) {
    final expires = [
      for (final format in formats)
        ?int.tryParse(
          Uri.tryParse('${format['url']}')?.queryParameters['expire'] ?? '',
        ),
    ];

    return expires.isEmpty
        ? DateTime.now().add(const Duration(hours: 1))
        : DateTime.fromMillisecondsSinceEpoch(
            expires.reduce(math.min) * 1000,
          ).subtract(const Duration(minutes: 30));
  }
}
