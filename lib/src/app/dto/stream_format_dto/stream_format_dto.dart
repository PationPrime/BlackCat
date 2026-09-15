/// A stream from `streamingData.adaptiveFormats` of the player API response
class StreamFormatDto {
  static final _codecsPattern = RegExp(r'codecs="([^"]*)"');

  final int itag;
  final String mimeType;

  /// Link before solving the `n` challenge (and the signature, if any)
  final String url;

  /// Encrypted signature from `signatureCipher`; the solution goes into [signatureParam]
  final String? signature;
  final String signatureParam;

  final String? videoCodec;
  final String? audioCodec;
  final int? width;
  final int? height;
  final num? fps;
  final num? bitrate;
  final int? contentLength;
  final int? approxDurationMs;
  final bool audioIsDefault;

  const StreamFormatDto({
    required this.itag,
    required this.mimeType,
    required this.url,
    this.signature,
    this.signatureParam = 'signature',
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.fps,
    this.bitrate,
    this.contentLength,
    this.approxDurationMs,
    this.audioIsDefault = false,
  });

  /// `null` for streams that cannot be downloaded over plain HTTPS (e.g. SABR only)
  static StreamFormatDto? fromJson(Map<String, dynamic> json) {
    var url = json['url'] as String?;
    String? signature;
    var signatureParam = 'signature';

    if (url == null && json['signatureCipher'] is String) {
      final cipher = Uri.splitQueryString(json['signatureCipher'] as String);
      url = cipher['url'];
      signature = cipher['s'];
      signatureParam = cipher['sp'] ?? 'signature';
    }

    final mimeType = json['mimeType'] as String? ?? '';
    final itag = json['itag'];

    if (url == null || itag is! int || mimeType.isEmpty) {
      return null;
    }

    final codecs = (_codecsPattern.firstMatch(mimeType)?.group(1) ?? '')
        .split(',')
        .map((codec) => codec.trim());
    final isVideo = mimeType.startsWith('video/');
    final isAudio =
        json['audioQuality'] != null || mimeType.startsWith('audio/');

    return StreamFormatDto(
      itag: itag,
      mimeType: mimeType,
      url: url,
      signature: signature,
      signatureParam: signatureParam,
      videoCodec: isVideo ? codecs.first : null,
      audioCodec: isAudio ? codecs.last : null,
      width: json['width'] as int?,
      height: json['height'] as int?,
      fps: json['fps'] as num?,
      bitrate: (json['averageBitrate'] ?? json['bitrate']) as num?,
      contentLength: int.tryParse('${json['contentLength'] ?? ''}'),
      approxDurationMs: int.tryParse('${json['approxDurationMs'] ?? ''}'),
      audioIsDefault: (json['audioTrack'] as Map?)?['audioIsDefault'] == true,
    );
  }

  bool get isMp4 =>
      mimeType.startsWith('video/mp4') || mimeType.startsWith('audio/mp4');

  bool get hasVideo => videoCodec != null;

  bool get hasAudio => audioCodec != null;

  String? get nChallenge => Uri.parse(url).queryParameters['n'];

  /// Link with the `n` and signature solutions substituted
  String resolvedUrl({
    required Map<String, String> n,
    required Map<String, String> sig,
  }) {
    final uri = Uri.parse(url);
    final query = Map<String, String>.of(uri.queryParameters);
    final challenge = query['n'];

    if (challenge != null) {
      final solved = n[challenge];

      if (solved == null) {
        throw StateError('n challenge of itag $itag is unsolved');
      }

      query['n'] = solved;
    }

    if (signature != null) {
      final solved = sig[signature!];

      if (solved == null) {
        throw StateError('signature of itag $itag is unsolved');
      }

      query[signatureParam] = solved;
    }

    return uri.replace(queryParameters: query).toString();
  }

  /// The format as a yt-dlp dictionary: the quality list is built by the same code
  Map<String, dynamic> toRawFormat() => {
    'format_id': '$itag',
    'vcodec': videoCodec ?? 'none',
    'acodec': audioCodec ?? 'none',
    'width': width,
    'height': height,
    'fps': fps,
    'tbr': bitrate == null ? null : bitrate! / 1000,
    'abr': hasAudio && !hasVideo && bitrate != null ? bitrate! / 1000 : null,
    'filesize': contentLength,
  };
}
