part of 'media_muxer_service.dart';

/// Rewrites YouTube fragmented DASH streams (one track per file) into a regular MP4,
/// like `ffmpeg -c copy`: `ftyp`, `moov` with full sample tables, a single `mdat`.
/// Samples are copied byte for byte, nothing is re-encoded.
///
/// In a fragmented file sample sizes, durations and offsets live in every `moof`;
/// many players handle several such tracks in one file poorly, so they are
/// assembled back into `stts`/`stsz`/`stco`…
Future<void> _muxToMp4({required List<String> inputs, required String outputPath, bool audioOnly = false}) async {
  final opened = <_Input>[];

  try {
    final tracks = <_Track>[];

    for (final (index, path) in inputs.indexed) {
      final input = await _Input.open(path);
      opened.add(input);
      tracks.add(await input.readTrack(index + 1));
    }

    await _write(tracks, outputPath, audioOnly: audioOnly);
  } finally {
    for (final input in opened) {
      await input.close();
    }
  }
}

const _movieTimescale = 1000;

class _BoxRef {
  const _BoxRef(this.type, this.offset, this.size, this.headerSize);

  final String type;
  final int offset;
  final int size;
  final int headerSize;

  int get end => offset + size;
  int get bodyStart => offset + headerSize;
}

/// Consecutive samples of one `trun`: they lie together, so they become one chunk
class _Chunk {
  _Chunk(this.track, this.fileOffset, this.firstSample, this.sampleCount, this.byteSize, this.startTime);

  final _Track track;
  final int fileOffset;
  final int firstSample;
  final int sampleCount;
  final int byteSize;
  final double startTime;
  int outputOffset = 0;
}

class _Track {
  _Track(this.input, this.id);

  final _Input input;
  final int id;

  late int timescale;
  late String handler;
  late Uint8List tkhd;
  late Uint8List mdhd;
  late Uint8List hdlr;
  late Uint8List stsd;
  Uint8List? mediaHeader; // vmhd / smhd
  Uint8List? dinf;
  int editMediaTime = 0;

  /// Defaults from `trex`
  int defaultDuration = 0;
  int defaultSize = 0;
  int defaultFlags = 0;

  final sizes = <int>[];
  final durations = <int>[];
  final compositionOffsets = <int>[];
  final syncSamples = <int>[]; // starting from one
  final chunks = <_Chunk>[];

  int get mediaDuration => durations.fold(0, (sum, duration) => sum + duration);
  bool get isVideo => handler == 'vide';
}

class _Input {
  _Input(this.path, this.file, this.length);

  static Future<_Input> open(String path) async {
    final file = await File(path).open();
    return _Input(path, file, await file.length());
  }

  final String path;
  final RandomAccessFile file;
  final int length;

  Future<void> close() => file.close();

  Future<Uint8List> read(int offset, int size) async {
    await file.setPosition(offset);
    final bytes = await file.read(size);

    if (bytes.length != size) {
      throw FormatException('Unexpected end of $path');
    }
    return bytes;
  }

  Future<void> copyTo(RandomAccessFile output, int offset, int size) async {
    const block = 1 << 20;
    await file.setPosition(offset);

    for (var left = size; left > 0;) {
      final bytes = await file.read(math.min(left, block));
      if (bytes.isEmpty) {
        throw FormatException('Unexpected end of $path');
      }
      await output.writeFrom(bytes);
      left -= bytes.length;
    }
  }

  Future<List<_BoxRef>> _topLevelBoxes() async {
    final boxes = <_BoxRef>[];

    for (var offset = 0; offset + 8 <= length;) {
      final header = await read(offset, math.min(16, length - offset));
      final data = ByteData.sublistView(header);
      var size = data.getUint32(0);
      var headerSize = 8;

      if (size == 1) {
        size = data.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = length - offset;
      }

      if (size < headerSize || offset + size > length) {
        throw FormatException('Broken MP4 box at $offset in $path');
      }

      boxes.add(_BoxRef(String.fromCharCodes(header, 4, 8), offset, size, headerSize));
      offset += size;
    }

    return boxes;
  }

  Future<_Track> readTrack(int id) async {
    final track = _Track(this, id);
    var haveMoov = false;

    for (final box in await _topLevelBoxes()) {
      if (box.type == 'moov') {
        _readMoov(track, await read(box.offset, box.size));
        haveMoov = true;
      } else if (box.type == 'moof') {
        if (!haveMoov) {
          throw FormatException('moof before moov in $path');
        }
        _readMoof(track, await read(box.offset, box.size), box.offset);
      }
    }

    if (!haveMoov || track.sizes.isEmpty) {
      throw FormatException('$path is not a fragmented MP4 stream');
    }

    return track;
  }

  void _readMoov(_Track track, Uint8List moov) {
    final root = _BoxRef('moov', 0, moov.length, 8);
    final trak = _require(moov, root, 'trak');
    final mdia = _require(moov, trak, 'mdia');
    final minf = _require(moov, mdia, 'minf');
    final stbl = _require(moov, minf, 'stbl');

    track
      ..tkhd = _bytes(moov, _require(moov, trak, 'tkhd'))
      ..mdhd = _bytes(moov, _require(moov, mdia, 'mdhd'))
      ..hdlr = _bytes(moov, _require(moov, mdia, 'hdlr'))
      ..stsd = _bytes(moov, _require(moov, stbl, 'stsd'))
      ..dinf = _optional(moov, minf, 'dinf')
      ..mediaHeader = _optional(moov, minf, 'vmhd') ?? _optional(moov, minf, 'smhd');

    track.handler = String.fromCharCodes(track.hdlr, 16, 20);
    final mdhdVersion = track.mdhd[8];
    track.timescale = ByteData.sublistView(track.mdhd).getUint32(mdhdVersion == 1 ? 28 : 20);

    final edts = _find(moov, trak, 'edts');
    final elst = edts == null ? null : _find(moov, edts, 'elst');
    if (elst != null) {
      final data = ByteData.sublistView(moov);
      final version = moov[elst.offset + 8];
      final entries = data.getUint32(elst.offset + 12);
      if (entries > 0) {
        track.editMediaTime = version == 1 ? data.getInt64(elst.offset + 24) : data.getInt32(elst.offset + 20);
      }
    }

    final mvex = _find(moov, root, 'mvex');
    final trex = mvex == null ? null : _find(moov, mvex, 'trex');
    if (trex != null) {
      final data = ByteData.sublistView(moov);
      track
        ..defaultDuration = data.getUint32(trex.offset + 20)
        ..defaultSize = data.getUint32(trex.offset + 24)
        ..defaultFlags = data.getUint32(trex.offset + 28);
    }
  }

  void _readMoof(_Track track, Uint8List moof, int moofOffset) {
    final data = ByteData.sublistView(moof);
    final root = _BoxRef('moof', 0, moof.length, 8);

    for (final traf in _children(moof, root).where((box) => box.type == 'traf')) {
      final tfhd = _require(moof, traf, 'tfhd');
      final tfhdFlags = data.getUint32(tfhd.offset + 8) & 0xFFFFFF;
      var at = tfhd.offset + 16;

      if (tfhdFlags & 0x1 != 0) {
        throw const FormatException('tfhd with base_data_offset is not supported');
      }
      if (tfhdFlags & 0x2 != 0) at += 4; // sample_description_index
      var duration = track.defaultDuration;
      var size = track.defaultSize;
      var flags = track.defaultFlags;
      if (tfhdFlags & 0x8 != 0) {
        duration = data.getUint32(at);
        at += 4;
      }
      if (tfhdFlags & 0x10 != 0) {
        size = data.getUint32(at);
        at += 4;
      }
      if (tfhdFlags & 0x20 != 0) {
        flags = data.getUint32(at);
      }

      final tfdt = _find(moof, traf, 'tfdt');
      final baseTime = tfdt == null
          ? track.mediaDuration
          : (moof[tfdt.offset + 8] == 1 ? data.getUint64(tfdt.offset + 12) : data.getUint32(tfdt.offset + 12));

      /// Samples are addressed from the start of moof; a trun without an offset continues the previous one
      var dataPosition = moofOffset;
      var decodeTime = baseTime;

      for (final trun in _children(moof, traf).where((box) => box.type == 'trun')) {
        final trunFlags = data.getUint32(trun.offset + 8) & 0xFFFFFF;
        final version = moof[trun.offset + 8];
        final count = data.getUint32(trun.offset + 12);
        var p = trun.offset + 16;

        if (trunFlags & 0x1 != 0) {
          dataPosition = moofOffset + data.getInt32(p);
          p += 4;
        }
        int? firstFlags;
        if (trunFlags & 0x4 != 0) {
          firstFlags = data.getUint32(p);
          p += 4;
        }

        final chunkStart = dataPosition;
        final firstSample = track.sizes.length;
        var chunkBytes = 0;

        for (var i = 0; i < count; i++) {
          final sampleDuration = trunFlags & 0x100 != 0 ? data.getUint32((p += 4) - 4) : duration;
          final sampleSize = trunFlags & 0x200 != 0 ? data.getUint32((p += 4) - 4) : size;
          final sampleFlags = trunFlags & 0x400 != 0 ? data.getUint32((p += 4) - 4) : (i == 0 && firstFlags != null ? firstFlags : flags);
          final offset = trunFlags & 0x800 != 0
              ? (version == 1 ? data.getInt32((p += 4) - 4) : data.getUint32((p += 4) - 4))
              : 0;

          track.sizes.add(sampleSize);
          track.durations.add(sampleDuration);
          track.compositionOffsets.add(offset);
          if (sampleFlags & 0x10000 == 0) {
            track.syncSamples.add(track.sizes.length);
          }
          chunkBytes += sampleSize;
        }

        if (count > 0) {
          track.chunks.add(_Chunk(track, chunkStart, firstSample, count, chunkBytes, decodeTime / track.timescale));
        }
        dataPosition += chunkBytes;
        for (var i = firstSample; i < track.durations.length; i++) {
          decodeTime += track.durations[i];
        }
      }
    }
  }
}

Future<void> _write(List<_Track> tracks, String outputPath, {required bool audioOnly}) async {
  final chunks = [for (final track in tracks) ...track.chunks]..sort((left, right) => left.startTime.compareTo(right.startTime));
  final ftyp = _ftyp(audioOnly: audioOnly);
  final mdatPayload = chunks.fold<int>(0, (sum, chunk) => sum + chunk.byteSize);

  /// moov goes first, so its size is needed before the chunk offsets: build it
  /// with placeholders (of the same width), then with the real offsets
  final wide = ftyp.length + mdatPayload + 16 + 64 * 1024 * 1024 > 0xFFFFFFFF;
  var moov = _moov(tracks, wide64: wide);
  final mdatHeader = _mdatHeader(mdatPayload);
  var offset = ftyp.length + moov.length + mdatHeader.length;

  for (final chunk in chunks) {
    chunk.outputOffset = offset;
    offset += chunk.byteSize;
  }
  moov = _moov(tracks, wide64: wide);

  final output = await File(outputPath).open(mode: FileMode.write);

  try {
    await output.writeFrom(ftyp);
    await output.writeFrom(moov);
    await output.writeFrom(mdatHeader);

    for (final chunk in chunks) {
      await chunk.track.input.copyTo(output, chunk.fileOffset, chunk.byteSize);
    }
  } finally {
    await output.close();
  }
}

Uint8List _moov(List<_Track> tracks, {required bool wide64}) {
  final movieDuration = tracks.map((track) => _toMovieTime(track.mediaDuration, track.timescale)).reduce(math.max);

  return _box('moov', [
    _mvhd(movieDuration, nextTrackId: tracks.length + 1),
    for (final track in tracks) _trak(track, wide64: wide64),
  ]);
}

int _toMovieTime(int value, int timescale) => (value * _movieTimescale / timescale).round();

Uint8List _trak(_Track track, {required bool wide64}) {
  final duration = _toMovieTime(track.mediaDuration, track.timescale);

  return _box('trak', [
    _tkhd(track, duration),
    if (track.isVideo || track.editMediaTime != 0)
      _box('edts', [_elst(duration, track.editMediaTime)]),
    _box('mdia', [
      _mdhd(track),
      track.hdlr,
      _box('minf', [
        ?track.mediaHeader,
        ?track.dinf,
        _box('stbl', [
          track.stsd,
          _stts(track.durations),
          if (track.compositionOffsets.any((offset) => offset != 0)) _ctts(track.compositionOffsets),
          if (track.syncSamples.length != track.sizes.length) _uint32Table('stss', track.syncSamples),
          _stsc(track.chunks),
          _stsz(track.sizes),
          _chunkOffsets(track.chunks, wide64: wide64),
        ]),
      ]),
    ]),
  ]);
}

// region: boxes

Uint8List _box(String type, List<Uint8List> children) {
  final size = 8 + children.fold<int>(0, (sum, child) => sum + child.length);
  final bytes = Uint8List(size);
  ByteData.sublistView(bytes).setUint32(0, size);
  bytes.setAll(4, type.codeUnits);

  var offset = 8;
  for (final child in children) {
    bytes.setAll(offset, child);
    offset += child.length;
  }
  return bytes;
}

/// Full box: version, flags and a body of [size] bytes filled by [write]
Uint8List _fullBox(String type, int size, void Function(ByteData data) write, {int version = 0, int flags = 0}) {
  final bytes = Uint8List(12 + size);
  ByteData.sublistView(bytes)
    ..setUint32(0, bytes.length)
    ..setUint32(8, version << 24 | flags);
  bytes.setAll(4, type.codeUnits);
  write(ByteData.sublistView(bytes, 12));
  return bytes;
}

Uint8List _ftyp({required bool audioOnly}) {
  final brands = audioOnly ? ['M4A ', 'isom', 'iso2', 'mp41'] : ['isom', 'iso2', 'avc1', 'mp41'];
  final bytes = Uint8List(16 + 4 * brands.length);
  ByteData.sublistView(bytes)
    ..setUint32(0, bytes.length)
    ..setUint32(12, 0x200);
  bytes
    ..setAll(4, 'ftyp'.codeUnits)
    ..setAll(8, brands.first.codeUnits);
  for (final (index, brand) in brands.indexed) {
    bytes.setAll(16 + 4 * index, brand.codeUnits);
  }
  return bytes;
}

const _identityMatrix = [0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000];

Uint8List _mvhd(int duration, {required int nextTrackId}) => _fullBox('mvhd', 96, (data) {
  data
    ..setUint32(8, _movieTimescale)
    ..setUint32(12, duration)
    ..setUint32(16, 0x00010000) // rate 1.0
    ..setUint16(20, 0x0100); // volume 1.0
  for (final (index, value) in _identityMatrix.indexed) {
    data.setUint32(32 + 4 * index, value);
  }
  data.setUint32(92, nextTrackId);
});

Uint8List _tkhd(_Track track, int duration) {
  final source = ByteData.sublistView(track.tkhd);
  final width = source.getUint32(track.tkhd.length - 8);
  final height = source.getUint32(track.tkhd.length - 4);

  /// v0 body: creation, modification, track_ID, reserved, duration, reserved(8), layer,
  /// alternate_group, volume, reserved(2), matrix(36), width, height
  return _fullBox('tkhd', 80, (data) {
    data
      ..setUint32(8, track.id)
      ..setUint32(16, duration)
      ..setUint16(30, track.isVideo ? 0 : 1) // alternate_group: audio tracks are group 1, as in ffmpeg
      ..setUint16(32, track.isVideo ? 0 : 0x0100);
    for (final (index, value) in _identityMatrix.indexed) {
      data.setUint32(36 + 4 * index, value);
    }
    data
      ..setUint32(72, track.isVideo ? width : 0)
      ..setUint32(76, track.isVideo ? height : 0);
  }, flags: 0x3);
}

Uint8List _elst(int segmentDuration, int mediaTime) => _fullBox('elst', 16, (data) {
  data
    ..setUint32(0, 1)
    ..setUint32(4, segmentDuration)
    ..setInt32(8, mediaTime)
    ..setUint32(12, 0x00010000);
});

Uint8List _mdhd(_Track track) {
  final source = track.mdhd;
  final language = ByteData.sublistView(source).getUint16(source[8] == 1 ? 40 : 28);
  final duration = track.mediaDuration;

  if (duration > 0xFFFFFFFF) {
    return _fullBox('mdhd', 32, (data) {
      data
        ..setUint32(16, track.timescale)
        ..setUint64(20, duration)
        ..setUint16(28, language);
    }, version: 1);
  }

  return _fullBox('mdhd', 20, (data) {
    data
      ..setUint32(8, track.timescale)
      ..setUint32(12, duration)
      ..setUint16(16, language);
  });
}

/// (count, value) pairs of consecutive equal values
List<(int, int)> _runs(List<int> values) {
  final runs = <(int, int)>[];
  for (final value in values) {
    if (runs.isNotEmpty && runs.last.$2 == value) {
      runs.last = (runs.last.$1 + 1, value);
    } else {
      runs.add((1, value));
    }
  }
  return runs;
}

Uint8List _stts(List<int> durations) {
  final runs = _runs(durations);
  return _fullBox('stts', 4 + 8 * runs.length, (data) {
    data.setUint32(0, runs.length);
    for (final (index, (count, delta)) in runs.indexed) {
      data
        ..setUint32(4 + 8 * index, count)
        ..setUint32(8 + 8 * index, delta);
    }
  });
}

Uint8List _ctts(List<int> offsets) {
  final runs = _runs(offsets);
  final signed = offsets.any((offset) => offset < 0);
  return _fullBox('ctts', 4 + 8 * runs.length, (data) {
    data.setUint32(0, runs.length);
    for (final (index, (count, offset)) in runs.indexed) {
      data
        ..setUint32(4 + 8 * index, count)
        ..setInt32(8 + 8 * index, offset);
    }
  }, version: signed ? 1 : 0);
}

Uint8List _uint32Table(String type, List<int> values) => _fullBox(type, 4 + 4 * values.length, (data) {
  data.setUint32(0, values.length);
  for (final (index, value) in values.indexed) {
    data.setUint32(4 + 4 * index, value);
  }
});

Uint8List _stsc(List<_Chunk> chunks) {
  final entries = <(int firstChunk, int samplesPerChunk)>[];
  for (final (index, chunk) in chunks.indexed) {
    if (entries.isEmpty || entries.last.$2 != chunk.sampleCount) {
      entries.add((index + 1, chunk.sampleCount));
    }
  }

  return _fullBox('stsc', 4 + 12 * entries.length, (data) {
    data.setUint32(0, entries.length);
    for (final (index, (first, count)) in entries.indexed) {
      data
        ..setUint32(4 + 12 * index, first)
        ..setUint32(8 + 12 * index, count)
        ..setUint32(12 + 12 * index, 1);
    }
  });
}

Uint8List _stsz(List<int> sizes) => _fullBox('stsz', 8 + 4 * sizes.length, (data) {
  data.setUint32(4, sizes.length);
  for (final (index, size) in sizes.indexed) {
    data.setUint32(8 + 4 * index, size);
  }
});

Uint8List _chunkOffsets(List<_Chunk> chunks, {required bool wide64}) => wide64
    ? _fullBox('co64', 4 + 8 * chunks.length, (data) {
        data.setUint32(0, chunks.length);
        for (final (index, chunk) in chunks.indexed) {
          data.setUint64(4 + 8 * index, chunk.outputOffset);
        }
      })
    : _uint32Table('stco', [for (final chunk in chunks) chunk.outputOffset]);

Uint8List _mdatHeader(int payload) {
  if (payload + 8 <= 0xFFFFFFFF) {
    final bytes = Uint8List(8);
    ByteData.sublistView(bytes).setUint32(0, payload + 8);
    return bytes..setAll(4, 'mdat'.codeUnits);
  }

  final bytes = Uint8List(16);
  ByteData.sublistView(bytes)
    ..setUint32(0, 1)
    ..setUint64(8, payload + 16);
  return bytes..setAll(4, 'mdat'.codeUnits);
}

// region: parsing

Iterable<_BoxRef> _children(Uint8List bytes, _BoxRef parent) sync* {
  final data = ByteData.sublistView(bytes);
  final end = parent.end;

  for (var offset = parent.bodyStart; offset + 8 <= end;) {
    var size = data.getUint32(offset);
    var headerSize = 8;

    if (size == 1) {
      size = data.getUint64(offset + 8);
      headerSize = 16;
    } else if (size == 0) {
      size = end - offset;
    }

    if (size < headerSize || offset + size > end) {
      throw const FormatException('Broken MP4 box');
    }

    yield _BoxRef(String.fromCharCodes(bytes, offset + 4, offset + 8), offset, size, headerSize);
    offset += size;
  }
}

_BoxRef? _find(Uint8List bytes, _BoxRef parent, String type) =>
    _children(bytes, parent).where((box) => box.type == type).firstOrNull;

_BoxRef _require(Uint8List bytes, _BoxRef parent, String type) =>
    _find(bytes, parent, type) ?? (throw FormatException('${parent.type} without $type'));

Uint8List _bytes(Uint8List bytes, _BoxRef box) => Uint8List.fromList(Uint8List.sublistView(bytes, box.offset, box.end));

Uint8List? _optional(Uint8List bytes, _BoxRef parent, String type) {
  final box = _find(bytes, parent, type);
  return box == null ? null : _bytes(bytes, box);
}
