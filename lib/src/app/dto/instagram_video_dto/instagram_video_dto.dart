import 'package:equatable/equatable.dart';

enum InstagramStreamKind {
  /// A ready MP4 file with video and audio
  file,

  /// DASH video without audio
  video,

  /// DASH audio
  audio,
}

/// A file Instagram serves for a post
class InstagramStreamDto extends Equatable {
  final InstagramStreamKind kind;
  final String url;

  /// Stays the same when the links change: the DASH representation id,
  /// or the size of a ready file. Picks the same stream after a pause
  final int key;

  /// `avc1.64001f`, `vp09.00.40.08`, `mp4a.40.5`… `null` when unknown
  final String? codec;
  final int? width;
  final int? height;

  /// Exact or estimated size in bytes
  final int? size;

  /// Bits per second
  final int? bandwidth;

  /// Seconds of a ready file, as its header tells
  final double? duration;

  const InstagramStreamDto({
    required this.kind,
    required this.url,
    required this.key,
    this.codec,
    this.width,
    this.height,
    this.size,
    this.bandwidth,
    this.duration,
  });

  bool get hasVideo => kind != InstagramStreamKind.audio;

  /// H.264 plays everywhere; VP9 and AV1 not in every player. Instagram
  /// makes its ready files in H.264, so one of an unknown codec counts too
  bool get isH264 {
    final name = codec?.toLowerCase() ?? '';

    if (name.isEmpty) return kind == InstagramStreamKind.file;

    return name.startsWith('avc') || name.startsWith('h264');
  }

  @override
  List<Object?> get props => [
    kind,
    url,
    key,
    codec,
    width,
    height,
    size,
    bandwidth,
    duration,
  ];
}

/// A post video from its page: what the page shows and the files
class InstagramVideoDto {
  /// Shortcode of the post
  final String code;
  final String title;

  /// Author name in links
  final String? author;

  /// Author name as the page shows it
  final String? authorName;

  /// Duration in seconds
  final num? durationSeconds;
  final String? thumbnail;
  final int? viewCount;
  final List<InstagramStreamDto> streams;

  /// Page of the post
  final String url;

  const InstagramVideoDto({
    required this.code,
    required this.title,
    required this.streams,
    required this.url,
    this.author,
    this.authorName,
    this.durationSeconds,
    this.thumbnail,
    this.viewCount,
  });
}
