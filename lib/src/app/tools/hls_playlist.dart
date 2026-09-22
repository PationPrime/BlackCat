import 'package:equatable/equatable.dart';

/// A quality of an HLS master playlist
class HlsVariant extends Equatable {
  final Uri uri;

  /// Peak bits per second of the variant
  final int bandwidth;
  final int? width;
  final int? height;
  final String? codecs;
  final double? frameRate;

  const HlsVariant({
    required this.uri,
    required this.bandwidth,
    this.width,
    this.height,
    this.codecs,
    this.frameRate,
  });

  @override
  List<Object?> get props => [uri, bandwidth, width, height, codecs, frameRate];
}

class HlsSegment extends Equatable {
  final Uri uri;

  /// Seconds of playback
  final double duration;

  const HlsSegment({required this.uri, required this.duration});

  @override
  List<Object?> get props => [uri, duration];
}

/// Segments of one quality, in playback order
class HlsMediaPlaylist extends Equatable {
  final List<HlsSegment> segments;

  const HlsMediaPlaylist(this.segments);

  /// Seconds of playback of all segments
  double get duration =>
      segments.fold<double>(0, (sum, segment) => sum + segment.duration);

  @override
  List<Object?> get props => [segments];
}

/// What the app cannot download from an HLS playlist
enum HlsUnsupportedReason {
  /// Segments are encrypted
  encrypted,

  /// Segments are fragmented MP4 or byte ranges of one file,
  /// not MPEG-TS files
  segmentFormat,

  /// A live stream: the playlist has no end
  live,
}

final class HlsUnsupportedException implements Exception {
  final HlsUnsupportedReason reason;

  const HlsUnsupportedException(this.reason);

  @override
  String toString() => 'HlsUnsupportedException(${reason.name})';
}

/// Master and media playlists of HLS (RFC 8216), as far as a download of
/// MPEG-TS segments needs them. Relative links resolve against [base]:
/// the link of the playlist itself
abstract final class HlsPlaylistParser {
  static final _attributePattern = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)');

  /// Variants of a master playlist, in its order. Throws [FormatException]
  /// if the text is not a master playlist
  static List<HlsVariant> parseMaster(String text, Uri base) {
    final lines = _lines(text);
    final variants = <HlsVariant>[];

    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('#EXT-X-STREAM-INF:')) continue;

      final attributes = _attributes(
        lines[i].substring('#EXT-X-STREAM-INF:'.length),
      );
      final uri = lines
          .skip(i + 1)
          .where((line) => !line.startsWith('#'))
          .firstOrNull;
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '');

      if (uri == null || bandwidth == null) continue;

      final resolution = attributes['RESOLUTION']?.split('x');

      variants.add(
        HlsVariant(
          uri: base.resolve(uri),
          bandwidth: bandwidth,
          width: resolution?.length == 2 ? int.tryParse(resolution![0]) : null,
          height: resolution?.length == 2 ? int.tryParse(resolution![1]) : null,
          codecs: attributes['CODECS'],
          frameRate: double.tryParse(attributes['FRAME-RATE'] ?? ''),
        ),
      );
    }

    if (variants.isEmpty) {
      throw const FormatException('The master playlist has no variants');
    }

    return variants;
  }

  /// Segments of a media playlist. Throws [HlsUnsupportedException] for
  /// encrypted, fragmented MP4 and live playlists, [FormatException]
  /// if the text is not a media playlist
  static HlsMediaPlaylist parseMedia(String text, Uri base) {
    final lines = _lines(text);
    final segments = <HlsSegment>[];
    var ended = false;
    double? duration;

    for (final line in lines) {
      if (line.startsWith('#EXT-X-KEY:')) {
        final method = _attributes(
          line.substring('#EXT-X-KEY:'.length),
        )['METHOD'];

        if (method != null && method != 'NONE') {
          throw const HlsUnsupportedException(HlsUnsupportedReason.encrypted);
        }
      } else if (line.startsWith('#EXT-X-MAP') ||
          line.startsWith('#EXT-X-BYTERANGE')) {
        throw const HlsUnsupportedException(HlsUnsupportedReason.segmentFormat);
      } else if (line == '#EXT-X-ENDLIST' ||
          line == '#EXT-X-PLAYLIST-TYPE:VOD') {
        ended = true;
      } else if (line.startsWith('#EXTINF:')) {
        duration = double.tryParse(
          line.substring('#EXTINF:'.length).split(',').first.trim(),
        );
      } else if (!line.startsWith('#')) {
        if (duration == null) continue;

        segments.add(HlsSegment(uri: base.resolve(line), duration: duration));
        duration = null;
      }
    }

    if (segments.isEmpty) {
      throw const FormatException('The media playlist has no segments');
    }

    if (!ended) {
      throw const HlsUnsupportedException(HlsUnsupportedReason.live);
    }

    return HlsMediaPlaylist(segments);
  }

  static List<String> _lines(String text) {
    final lines = [
      for (final line in text.split(RegExp(r'\r?\n')))
        if (line.trim().isNotEmpty) line.trim(),
    ];

    if (lines.firstOrNull != '#EXTM3U') {
      throw const FormatException('Not an HLS playlist');
    }

    return lines;
  }

  static Map<String, String> _attributes(String list) => {
    for (final match in _attributePattern.allMatches(list))
      match.group(1)!: match.group(2)!.replaceAll('"', '').trim(),
  };
}
