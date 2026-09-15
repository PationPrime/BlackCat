import '../stream_format_dto/stream_format_dto.dart';

/// Ответ `/youtubei/v1/player`
class PlayerResponseDto {
  /// `OK`, `LOGIN_REQUIRED`, `UNPLAYABLE`…
  final String? status;

  /// Причина отказа, уже переведённая YouTube
  final String? reason;

  /// Скачиваемые MP4-потоки: WebM приложение не склеивает
  final List<StreamFormatDto> formats;
  final String? title;
  final String? author;
  final int? lengthSeconds;
  final int? viewCount;
  final String? thumbnail;

  const PlayerResponseDto({
    required this.status,
    required this.formats,
    this.reason,
    this.title,
    this.author,
    this.lengthSeconds,
    this.viewCount,
    this.thumbnail,
  });

  factory PlayerResponseDto.fromJson(Map<String, dynamic> json) {
    final playability =
        json['playabilityStatus'] as Map<String, dynamic>? ?? const {};
    final streaming = json['streamingData'] as Map<String, dynamic>? ?? const {};
    final details = json['videoDetails'] as Map<String, dynamic>? ?? const {};
    final thumbnails =
        (details['thumbnail'] as Map?)?['thumbnails'] as List? ?? const [];

    return PlayerResponseDto(
      status: playability['status'] as String?,
      reason: (playability['reason'] as String?)?.trim(),
      formats: [
        for (final format
            in (streaming['adaptiveFormats'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          if (StreamFormatDto.fromJson(format) case final dto?
              when dto.isMp4 && dto.contentLength != null)
            dto,
      ],
      title: details['title'] as String?,
      author: details['author'] as String?,
      lengthSeconds: int.tryParse('${details['lengthSeconds'] ?? ''}'),
      viewCount: int.tryParse('${details['viewCount'] ?? ''}'),
      thumbnail: thumbnails.isEmpty
          ? null
          : (thumbnails.last as Map)['url'] as String?,
    );
  }

  bool get isPlayable => status == 'OK';

  /// Смотреть видео мешает отсутствие входа в аккаунт
  bool get requiresSignIn =>
      status == 'LOGIN_REQUIRED' ||
      status == 'AGE_CHECK_REQUIRED' ||
      status == 'CONTENT_CHECK_REQUIRED';
}
