import 'package:equatable/equatable.dart';

/// A quality TikTok serves: one MP4 file with video and audio together
class TikTokFormatDto extends Equatable {
  /// Mirrors of the same file
  final List<String> urls;

  /// Bits per second
  final int bitrate;
  final int? width;
  final int? height;

  /// `h264`, `h265_hvc1`…
  final String codec;

  /// Exact size of the file in bytes, when TikTok tells it
  final int? size;

  const TikTokFormatDto({
    required this.urls,
    required this.bitrate,
    required this.codec,
    this.width,
    this.height,
    this.size,
  });

  /// H.265 plays in fewer players than H.264
  bool get isHevc {
    final name = codec.toLowerCase();

    return name.startsWith('h265') ||
        name.contains('hevc') ||
        name.contains('bytevc1');
  }

  @override
  List<Object?> get props => [urls, bitrate, width, height, codec, size];
}

/// A TikTok video from its page: what the page shows, the qualities and what
/// their links need
class TikTokVideoDto {
  final String id;
  final String title;

  /// Author name in links, without `@`
  final String? author;

  /// Author name as the page shows it
  final String? authorName;

  /// Duration in seconds
  final num? durationSeconds;
  final String? thumbnail;
  final int? viewCount;
  final List<TikTokFormatDto> formats;

  /// Page of the video: its links want it as the referrer
  final String pageUrl;

  /// `Cookie` header of the page: the video links are refused without it
  final String cookies;

  const TikTokVideoDto({
    required this.id,
    required this.title,
    required this.formats,
    required this.pageUrl,
    required this.cookies,
    this.author,
    this.authorName,
    this.durationSeconds,
    this.thumbnail,
    this.viewCount,
  });

  /// Page link of the video with its author
  String get url => 'https://www.tiktok.com/@${author ?? '_'}/video/$id';
}
