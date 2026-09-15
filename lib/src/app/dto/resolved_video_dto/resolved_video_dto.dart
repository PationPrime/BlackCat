import '../stream_format_dto/stream_format_dto.dart';

/// Video with ready stream links
class ResolvedVideoDto {
  final String id;
  final String title;
  final String? channel;
  final int? durationSeconds;
  final int? viewCount;
  final String? thumbnail;
  final List<StreamFormatDto> formats;

  /// Keyed by the format itself: a dubbed video has an itag 140 stream per language
  final Map<StreamFormatDto, String> urls;

  /// Links are bound to the session and expire
  final DateTime expiresAt;

  const ResolvedVideoDto({
    required this.id,
    required this.title,
    required this.formats,
    required this.urls,
    required this.expiresAt,
    this.channel,
    this.durationSeconds,
    this.viewCount,
    this.thumbnail,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);
}
