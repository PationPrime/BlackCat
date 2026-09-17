import 'dart:math' as math;

/// Inclusive byte range of a file, as HTTP ranges are
final class ByteRange {
  final int start;
  final int end;

  const ByteRange(this.start, this.end) : assert(start >= 0 && end >= start);

  int get length => end - start + 1;

  @override
  bool operator ==(Object other) =>
      other is ByteRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start-$end';
}

/// How a file of a known size splits into slices: every slice but the last
/// one is [sliceSize] long
final class SliceLayout {
  final int fileLength;
  final int sliceSize;

  const SliceLayout({required this.fileLength, required this.sliceSize});

  int get sliceCount => fileLength == 0 ? 0 : (fileLength / sliceSize).ceil();

  ByteRange slice(int index) {
    final start = index * sliceSize;

    return ByteRange(start, math.min(start + sliceSize, fileLength) - 1);
  }

  /// Slice counters of a file whose first [bytes] are downloaded in order
  List<int> prefixCounters(int bytes) {
    final downloaded = bytes.clamp(0, fileLength);

    return [
      for (var index = 0; index < sliceCount; index++)
        (downloaded - slice(index).start).clamp(0, slice(index).length),
    ];
  }
}

/// `Content-Range: bytes <start>-<end>/<total>` of a partial response
final class ContentRange {
  static final _pattern = RegExp(
    r'^\s*bytes\s+(\d+)\s*-\s*(\d+)\s*/\s*(\d+|\*)\s*$',
    caseSensitive: false,
  );

  final int start;
  final int end;

  /// `null` for `*`: the server does not tell the size
  final int? total;

  const ContentRange(this.start, this.end, this.total);

  /// `null` for a missing or malformed header, and for an end before
  /// the start
  static ContentRange? parse(String? header) {
    final match = header == null ? null : _pattern.firstMatch(header);

    if (match == null) return null;

    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final total = match.group(3) == '*' ? null : int.tryParse(match.group(3)!);

    if (start == null || end == null || end < start) return null;

    return ContentRange(start, end, total);
  }

  /// The size from `bytes */<total>` of a 416 response
  static int? unsatisfiedTotal(String? header) {
    final match = header == null
        ? null
        : RegExp(r'^\s*bytes\s+\*\s*/\s*(\d+)\s*$').firstMatch(header);

    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  String toString() => 'bytes $start-$end/${total ?? '*'}';
}
