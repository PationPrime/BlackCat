import 'package:equatable/equatable.dart';

/// A quality X serves: one MP4 file with video and audio together
class XFormatDto extends Equatable {
  final String url;

  /// Bits per second; 0 for a GIF, which has one file
  final int bitrate;
  final int? width;
  final int? height;

  /// `avc1`, `hevc`… from the file link. `null` when the link does not tell
  final String? codec;

  /// Exact or estimated size in bytes
  final int? size;

  const XFormatDto({
    required this.url,
    required this.bitrate,
    this.width,
    this.height,
    this.codec,
    this.size,
  });

  XFormatDto withSize(int? size) => XFormatDto(
    url: url,
    bitrate: bitrate,
    width: width,
    height: height,
    codec: codec,
    size: size,
  );

  @override
  List<Object?> get props => [url, bitrate, width, height, codec, size];
}

/// A video of an X post
class XVideoDto {
  /// Post id
  final String id;
  final String title;

  /// Author name in links, without `@`
  final String? author;

  /// Author name as the post shows it
  final String? authorName;

  /// Duration in seconds
  final num? durationSeconds;
  final String? thumbnail;
  final int? viewCount;
  final List<XFormatDto> formats;

  /// Page of the post
  final String url;

  const XVideoDto({
    required this.id,
    required this.title,
    required this.formats,
    required this.url,
    this.author,
    this.authorName,
    this.durationSeconds,
    this.thumbnail,
    this.viewCount,
  });
}
