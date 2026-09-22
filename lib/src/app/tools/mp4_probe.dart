import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// The picture and the length of an MP4 file, as its `moov` box tells them
class Mp4VideoInfo extends Equatable {
  /// Sample entry of the video: `avc1`, `hvc1`, `vp09`, `av01`…
  final String codec;
  final int width;
  final int height;

  /// Seconds
  final double? duration;

  const Mp4VideoInfo({
    required this.codec,
    required this.width,
    required this.height,
    this.duration,
  });

  @override
  List<Object?> get props => [codec, width, height, duration];
}

/// Where a reader of the file goes next to find `moov`
sealed class Mp4Seek {
  const Mp4Seek();
}

/// `moov` takes [size] bytes from [offset]
final class Mp4MoovAt extends Mp4Seek {
  final int offset;
  final int size;

  const Mp4MoovAt(this.offset, this.size);
}

/// The boxes before `moov` go past the read bytes: read on from [offset]
final class Mp4ReadFrom extends Mp4Seek {
  final int offset;

  const Mp4ReadFrom(this.offset);
}

/// The file has no `moov`, or its boxes are broken
final class Mp4NoMoov extends Mp4Seek {
  const Mp4NoMoov();
}

/// Reads the picture of an MP4 file from its boxes, without the media data.
/// A web file usually keeps `moov` at the start, so a few kilobytes are enough
abstract final class Mp4Probe {
  static const _containers = {'moov', 'trak', 'mdia', 'minf', 'stbl'};

  /// Walks the top-level boxes of [chunk], the bytes from [chunkOffset]
  /// of a file of [fileLength] bytes
  static Mp4Seek seek(Uint8List chunk, {int chunkOffset = 0, int? fileLength}) {
    final data = ByteData.sublistView(chunk);
    var position = 0;

    while (position + 8 <= chunk.length) {
      var size = data.getUint32(position);
      final type = String.fromCharCodes(chunk, position + 4, position + 8);
      var header = 8;

      if (size == 1) {
        if (position + 16 > chunk.length) break;

        size = data.getUint64(position + 8);
        header = 16;
      } else if (size == 0) {
        /// The last box goes to the end of the file
        if (fileLength == null) return const Mp4NoMoov();

        size = fileLength - chunkOffset - position;
      }

      if (size < header) return const Mp4NoMoov();

      if (type == 'moov') return Mp4MoovAt(chunkOffset + position, size);

      position += size;
    }

    final next = chunkOffset + position;

    return fileLength != null && next >= fileLength
        ? const Mp4NoMoov()
        : Mp4ReadFrom(next);
  }

  /// The first video track of a whole `moov` box. `null` without one
  static Mp4VideoInfo? videoOf(Uint8List moov) {
    final data = ByteData.sublistView(moov);
    double? duration;

    for (final (type, start, end) in _children(moov, 8, moov.length)) {
      if (type == 'mvhd' && start + 32 <= end) {
        duration = _durationOf(data, start);
      }

      if (type != 'trak') continue;

      final track = _videoTrackOf(moov, start, end);

      if (track != null) {
        return Mp4VideoInfo(
          codec: track.codec,
          width: track.width,
          height: track.height,
          duration: duration,
        );
      }
    }

    return null;
  }

  static ({String codec, int width, int height})? _videoTrackOf(
    Uint8List moov,
    int start,
    int end,
  ) {
    final data = ByteData.sublistView(moov);
    int? width;
    int? height;
    String? handler;
    ({String codec, int width, int height})? entry;

    void walk(int from, int to) {
      for (final (type, boxStart, boxEnd) in _children(moov, from, to)) {
        switch (type) {
          case 'tkhd':
            if (boxEnd - boxStart >= 92) {
              /// 16.16 numbers at the end of the box
              width = data.getUint32(boxEnd - 8) >> 16;
              height = data.getUint32(boxEnd - 4) >> 16;
            }
          case 'hdlr' when boxStart + 20 <= boxEnd:
            handler = String.fromCharCodes(moov, boxStart + 16, boxStart + 20);
          case 'stsd' when boxStart + 24 <= boxEnd:
            final entryStart = boxStart + 16;
            final codec = String.fromCharCodes(
              moov,
              entryStart + 4,
              entryStart + 8,
            );

            entry = (
              codec: codec,
              width: entryStart + 36 <= boxEnd
                  ? data.getUint16(entryStart + 32)
                  : 0,
              height: entryStart + 36 <= boxEnd
                  ? data.getUint16(entryStart + 34)
                  : 0,
            );
          case final container when _containers.contains(container):
            walk(boxStart + 8, boxEnd);
        }
      }
    }

    walk(start + 8, end);

    final sample = entry;

    if (handler != 'vide' || sample == null) return null;

    /// The track header gives the picture as shown; the sample entry is
    /// the fallback
    final trackWidth = width ?? 0;
    final trackHeight = height ?? 0;

    return trackWidth > 0 && trackHeight > 0
        ? (codec: sample.codec, width: trackWidth, height: trackHeight)
        : sample;
  }

  static double? _durationOf(ByteData data, int start) {
    final version = data.getUint8(start + 8);
    final int timescale;
    final int duration;

    if (version == 1) {
      if (data.lengthInBytes < start + 40) return null;

      timescale = data.getUint32(start + 28);
      duration = data.getUint64(start + 32);
    } else {
      timescale = data.getUint32(start + 20);
      duration = data.getUint32(start + 24);
    }

    return timescale == 0 ? null : duration / timescale;
  }

  /// Boxes between [start] and [end]: type, start and end of each
  static Iterable<(String, int, int)> _children(
    Uint8List bytes,
    int start,
    int end,
  ) sync* {
    final data = ByteData.sublistView(bytes);
    var position = start;

    while (position + 8 <= end) {
      var size = data.getUint32(position);
      var header = 8;

      if (size == 1) {
        if (position + 16 > end) return;

        size = data.getUint64(position + 8);
        header = 16;
      } else if (size == 0) {
        size = end - position;
      }

      if (size < header || position + size > end) return;

      yield (
        String.fromCharCodes(bytes, position + 4, position + 8),
        position,
        position + size,
      );

      position += size;
    }
  }
}
