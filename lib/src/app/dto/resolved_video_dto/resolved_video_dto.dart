import '../stream_format_dto/stream_format_dto.dart';

/// Видео с готовыми ссылками на потоки
class ResolvedVideoDto {
  final String id;
  final String title;
  final String? channel;
  final int? durationSeconds;
  final int? viewCount;
  final String? thumbnail;
  final List<StreamFormatDto> formats;

  /// По самому формату: у дублированного видео по потоку itag 140 на каждый язык
  final Map<StreamFormatDto, String> urls;

  /// Ссылки привязаны к сессии и устаревают
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
