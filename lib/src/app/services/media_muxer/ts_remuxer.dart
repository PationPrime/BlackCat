part of 'media_muxer_service.dart';

/// Rewrites MPEG-TS (HLS segments, one after another) into a regular MP4,
/// like `ffmpeg -c copy`: H.264 video and AAC audio are copied, not
/// re-encoded.
///
/// Two passes over the input: the first one finds the samples, their sizes
/// and times, so `moov` goes before `mdat`; the second one writes the
/// samples straight into the output. H.264 access units become
/// length-prefixed NAL units, ADTS frames lose their headers. Video and
/// audio are interleaved by the second of playback
void _remuxTsToMp4Sync({
  required List<String> inputs,
  required String outputPath,
}) {
  final scan = _TsScan();

  _TsDemuxer(scan.onPes).readAll(inputs);

  final layout = scan.layout();
  final output = File(outputPath).openSync(mode: FileMode.write);

  try {
    final writer = _TsChunkWriter(layout, output);

    _TsDemuxer(writer.onPes).readAll(inputs);
    writer.finish();
  } finally {
    output.closeSync();
  }
}

const _tsPacketSize = 188;
const _tsClock = 90000;
const _tsWrap = 1 << 33;

/// Stream types of the PMT the remuxer understands
const _tsStreamH264 = 0x1B;
const _tsStreamAdtsAac = 0x0F;

/// Other video and audio types: known, but not supported
const _tsVideoTypes = {0x01, 0x02, 0x10, 0x24, 0x42};
const _tsAudioTypes = {0x03, 0x04, 0x11, 0x81, 0x87};

const _aacSampleRates = [
  96000,
  88200,
  64000,
  48000,
  44100,
  32000,
  24000,
  22050,
  16000,
  12000,
  11025,
  8000,
  7350,
];

/// Samples of AAC per frame
const _aacFrameSamples = 1024;

enum _TsKind { video, audio }

/// A PES packet of a stream: one access unit of video or some ADTS frames
class _TsPes {
  _TsPes(this.kind, this.pts, this.dts, this.payload);

  final _TsKind kind;
  final int? pts;
  final int? dts;
  final Uint8List payload;
}

// region: demuxing

/// Reads TS packets of the inputs in order and puts together the PES
/// packets of the first H.264 and the first AAC stream
class _TsDemuxer {
  _TsDemuxer(this.onPes);

  final void Function(_TsPes pes) onPes;

  int? _pmtPid;
  int? _videoPid;
  int? _audioPid;
  final _pending = <int, BytesBuilder>{};

  void readAll(List<String> inputs) {
    for (final path in inputs) {
      _read(path);
    }

    for (final pid in [..._pending.keys]) {
      _emit(pid);
    }
  }

  void _read(String path) {
    final file = File(path).openSync();

    try {
      const blockSize = _tsPacketSize * 4096;
      final block = Uint8List(blockSize);
      var carry = 0;
      var synced = false;

      while (true) {
        final read = file.readIntoSync(block, carry);
        final length = carry + read;

        if (length < _tsPacketSize) {
          break;
        }

        var offset = 0;

        if (!synced) {
          offset = _syncOffset(block, length);
          synced = true;
        }

        while (offset + _tsPacketSize <= length) {
          if (block[offset] != 0x47) {
            final next = _syncOffset(block, length, from: offset + 1);

            if (next >= length) {
              offset = length;
              break;
            }
            offset = next;
            continue;
          }

          _packet(Uint8List.sublistView(block, offset, offset + _tsPacketSize));
          offset += _tsPacketSize;
        }

        carry = length - offset;
        block.setRange(0, carry, block, offset);

        if (read == 0) break;
      }
    } finally {
      file.closeSync();
    }
  }

  /// First position where two packets in a row start with the sync byte
  static int _syncOffset(Uint8List bytes, int length, {int from = 0}) {
    for (var i = from; i + _tsPacketSize < length; i++) {
      if (bytes[i] == 0x47 && bytes[i + _tsPacketSize] == 0x47) return i;
    }
    for (var i = from; i < length; i++) {
      if (bytes[i] == 0x47) return i;
    }
    return length;
  }

  void _packet(Uint8List packet) {
    final unitStart = packet[1] & 0x40 != 0;
    final pid = (packet[1] & 0x1F) << 8 | packet[2];
    final adaptation = packet[3] >> 4 & 0x3;
    var offset = 4;

    if (adaptation & 0x2 != 0) {
      offset += 1 + packet[4];
    }
    if (adaptation & 0x1 == 0 || offset >= _tsPacketSize) {
      return;
    }

    final payload = Uint8List.sublistView(packet, offset);

    if (pid == 0) {
      if (unitStart) _pat(payload);
    } else if (pid == _pmtPid) {
      if (unitStart) _pmt(payload);
    } else if (pid == _videoPid || pid == _audioPid) {
      if (unitStart) {
        _emit(pid);
        _pending[pid] = BytesBuilder(copy: true);
      }
      _pending[pid]?.add(payload);
    }
  }

  /// Section of a PSI table, skipping the pointer field
  static Uint8List? _section(Uint8List payload) {
    final start = 1 + payload[0];

    if (start + 3 > payload.length) return null;

    final length = (payload[start + 1] & 0x0F) << 8 | payload[start + 2];
    final end = math.min(start + 3 + length, payload.length);

    return Uint8List.sublistView(payload, start, end);
  }

  void _pat(Uint8List payload) {
    final section = _section(payload);

    if (section == null || section[0] != 0x00) return;

    /// Programs follow the 8-byte header and precede the CRC
    for (var i = 8; i + 4 <= section.length - 4; i += 4) {
      final program = section[i] << 8 | section[i + 1];

      if (program != 0) {
        _pmtPid = (section[i + 2] & 0x1F) << 8 | section[i + 3];
        return;
      }
    }
  }

  void _pmt(Uint8List payload) {
    final section = _section(payload);

    if (section == null || section[0] != 0x02) return;

    final programInfoLength = (section[10] & 0x0F) << 8 | section[11];

    for (var i = 12 + programInfoLength; i + 5 <= section.length - 4;) {
      final type = section[i];
      final pid = (section[i + 1] & 0x1F) << 8 | section[i + 2];
      final infoLength = (section[i + 3] & 0x0F) << 8 | section[i + 4];

      if (type == _tsStreamH264) {
        _videoPid ??= pid;
      } else if (type == _tsStreamAdtsAac) {
        _audioPid ??= pid;
      } else if (_tsVideoTypes.contains(type) && _videoPid == null) {
        throw FormatException(
          'Video of stream type 0x${type.toRadixString(16)} is not supported: only H.264 is',
        );
      } else if (_tsAudioTypes.contains(type) && _audioPid == null) {
        throw FormatException(
          'Audio of stream type 0x${type.toRadixString(16)} is not supported: only AAC is',
        );
      }

      i += 5 + infoLength;
    }
  }

  void _emit(int pid) {
    final bytes = _pending.remove(pid)?.takeBytes();

    if (bytes == null || bytes.length < 9) return;

    /// PES: start code, stream id, length, flags, header length, PTS/DTS
    if (bytes[0] != 0 || bytes[1] != 0 || bytes[2] != 1) return;

    final flags = bytes[7] >> 6;
    final headerEnd = 9 + bytes[8];

    if (headerEnd > bytes.length) return;

    final pts = flags & 0x2 != 0 ? _timestamp(bytes, 9) : null;
    final dts = flags == 0x3 ? _timestamp(bytes, 14) : null;

    onPes(
      _TsPes(
        pid == _videoPid ? _TsKind.video : _TsKind.audio,
        pts,
        dts,
        Uint8List.sublistView(bytes, headerEnd),
      ),
    );
  }

  static int _timestamp(Uint8List bytes, int at) =>
      (bytes[at] >> 1 & 0x07) << 30 |
      bytes[at + 1] << 22 |
      (bytes[at + 2] >> 1) << 15 |
      bytes[at + 3] << 7 |
      bytes[at + 4] >> 1;
}

/// 33-bit TS time that keeps growing past its wrap
class _TsClock {
  int? _last;
  var _base = 0;

  int unwrap(int value) {
    final last = _last;

    if (last != null && value + _base < last - _tsWrap ~/ 2) {
      _base += _tsWrap;
    }

    return _last = value + _base;
  }
}

// region: samples

/// One H.264 access unit as an MP4 sample: length-prefixed NAL units
/// without access unit delimiters and without the parameter sets the
/// sample entry already has
class _AvcSample {
  _AvcSample(this.bytes, {required this.isKey});

  final Uint8List bytes;
  final bool isKey;
}

class _AvcConverter {
  Uint8List? sps;
  Uint8List? pps;

  _AvcSample? convert(Uint8List annexB) {
    final units = _nalUnits(annexB);
    final kept = <Uint8List>[];
    var isKey = false;
    var hasPicture = false;

    for (final unit in units) {
      final type = unit[0] & 0x1F;

      switch (type) {
        case 9:
          continue;
        case 7:
          sps ??= Uint8List.fromList(unit);
          if (_same(unit, sps!)) continue;
        case 8:
          pps ??= Uint8List.fromList(unit);
          if (_same(unit, pps!)) continue;
        case 5:
          isKey = true;
          hasPicture = true;
        case >= 1 && <= 4:
          hasPicture = true;
      }

      kept.add(unit);
    }

    if (!hasPicture) return null;

    final size = kept.fold<int>(0, (sum, unit) => sum + 4 + unit.length);
    final bytes = Uint8List(size);
    final data = ByteData.sublistView(bytes);
    var offset = 0;

    for (final unit in kept) {
      data.setUint32(offset, unit.length);
      bytes.setAll(offset + 4, unit);
      offset += 4 + unit.length;
    }

    return _AvcSample(bytes, isKey: isKey);
  }

  static bool _same(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// NAL units of an Annex B stream: the bytes between start codes,
  /// without the zeros that pad them
  static List<Uint8List> _nalUnits(Uint8List data) {
    final units = <Uint8List>[];
    final length = data.length;
    int? start;

    void close(int end) {
      final from = start;

      if (from == null) return;

      var to = end;
      while (to > from && data[to - 1] == 0) {
        to--;
      }
      if (to > from) units.add(Uint8List.sublistView(data, from, to));
    }

    for (var i = 0; i + 2 < length;) {
      if (data[i + 2] > 1) {
        i += 3;
      } else if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1) {
        close(i);
        i += 3;
        start = i;
      } else {
        i++;
      }
    }

    close(length);

    return units;
  }
}

/// AAC frame of an ADTS stream without its header
class _AacFrame {
  _AacFrame(this.bytes, this.pts);

  final Uint8List bytes;
  final int pts;
}

/// AAC settings from an ADTS header: the MP4 sample entry needs them
class _AacConfig {
  const _AacConfig({
    required this.objectType,
    required this.rateIndex,
    required this.channels,
  });

  final int objectType;
  final int rateIndex;
  final int channels;

  int get sampleRate => _aacSampleRates[rateIndex];

  /// AudioSpecificConfig: object type, sampling frequency index, channels
  Uint8List get audioSpecificConfig => Uint8List.fromList([
    objectType << 3 | rateIndex >> 1,
    (rateIndex & 1) << 7 | channels << 3,
  ]);
}

class _AdtsParser {
  _AacConfig? config;
  Uint8List _carry = Uint8List(0);
  int? _nextPts;

  List<_AacFrame> frames(Uint8List payload, int? pts) {
    final bytes = _carry.isEmpty
        ? payload
        : (BytesBuilder(copy: false)
                ..add(_carry)
                ..add(payload))
              .takeBytes();
    final frames = <_AacFrame>[];
    var offset = 0;

    /// The PES time belongs to the first frame that starts in this PES
    var framePts = _carry.isEmpty ? (pts ?? _nextPts) : _nextPts;
    var ptsForNextStart = _carry.isEmpty ? null : pts;

    while (offset + 7 <= bytes.length) {
      if (bytes[offset] != 0xFF || bytes[offset + 1] & 0xF6 != 0xF0) {
        offset++;
        continue;
      }

      final headerSize = bytes[offset + 1] & 0x01 != 0 ? 7 : 9;
      final frameLength =
          (bytes[offset + 3] & 0x03) << 11 |
          bytes[offset + 4] << 3 |
          bytes[offset + 5] >> 5;

      if (frameLength < headerSize) {
        offset++;
        continue;
      }
      if (offset + frameLength > bytes.length) {
        break;
      }

      final current = config ??= _AacConfig(
        objectType: (bytes[offset + 2] >> 6) + 1,
        rateIndex: bytes[offset + 2] >> 2 & 0x0F,
        channels: (bytes[offset + 2] & 0x01) << 2 | bytes[offset + 3] >> 6,
      );

      if (current.rateIndex >= _aacSampleRates.length) {
        throw const FormatException('Unknown AAC sampling frequency');
      }

      final time = framePts ?? 0;

      frames.add(
        _AacFrame(
          Uint8List.sublistView(
            bytes,
            offset + headerSize,
            offset + frameLength,
          ),
          time,
        ),
      );
      offset += frameLength;

      final next = time + _aacFrameSamples * _tsClock ~/ current.sampleRate;

      framePts = ptsForNextStart ?? next;
      ptsForNextStart = null;
      _nextPts = framePts;
    }

    _carry = Uint8List.fromList(Uint8List.sublistView(bytes, offset));

    return frames;
  }
}

// region: first pass

/// What the first pass finds: sample sizes and times of each stream
class _TsScan {
  final _avc = _AvcConverter();
  final _adts = _AdtsParser();
  final _videoClock = _TsClock();
  final _audioClock = _TsClock();

  final videoSizes = <int>[];
  final videoDts = <int>[];
  final videoPts = <int>[];
  final videoKeys = <int>[];
  final audioSizes = <int>[];
  final audioPts = <int>[];

  void onPes(_TsPes pes) {
    switch (pes.kind) {
      case _TsKind.video:
        final sample = _avc.convert(pes.payload);

        if (sample == null) return;

        final pts = pes.pts == null
            ? _nextVideoTime()
            : _videoClock.unwrap(pes.pts!);
        final dts = pes.dts == null ? pts : _videoClock.unwrap(pes.dts!);

        videoSizes.add(sample.bytes.length);
        videoDts.add(dts);
        videoPts.add(pts);
        if (sample.isKey) videoKeys.add(videoSizes.length);
      case _TsKind.audio:
        final pts = pes.pts == null ? null : _audioClock.unwrap(pes.pts!);

        for (final frame in _adts.frames(pes.payload, pts)) {
          audioSizes.add(frame.bytes.length);
          audioPts.add(frame.pts);
        }
    }
  }

  /// A video PES without a time: one frame after the previous one
  int _nextVideoTime() {
    if (videoDts.length < 2) return videoDts.isEmpty ? 0 : videoDts.last + 3600;
    return videoDts.last + (videoDts.last - videoDts[videoDts.length - 2]);
  }

  _TsLayout layout() {
    if (videoSizes.isEmpty && audioSizes.isEmpty) {
      throw const FormatException(
        'The stream has neither H.264 video nor AAC audio',
      );
    }

    final sps = _avc.sps;
    final pps = _avc.pps;

    if (videoSizes.isNotEmpty && (sps == null || pps == null)) {
      throw const FormatException('The H.264 stream has no SPS or PPS');
    }

    return _TsLayout.build(this, sps: sps, pps: pps, audio: _adts.config);
  }
}

/// Tracks for `moov` and the order of chunks in `mdat`
class _TsLayout {
  _TsLayout(
    this.tracks,
    this.order, {
    required this.video,
    required this.audio,
  });

  final List<_Track> tracks;
  final _Track? video;
  final _Track? audio;

  /// Chunks in the order they lie in `mdat`
  final List<_Chunk> order;

  bool get audioOnly => video == null;

  static _TsLayout build(
    _TsScan scan, {
    required Uint8List? sps,
    required Uint8List? pps,
    required _AacConfig? audio,
  }) {
    final hasVideo = scan.videoSizes.isNotEmpty;
    final hasAudio = scan.audioSizes.isNotEmpty && audio != null;

    /// Playback starts with the first shown video frame, or with the audio
    final presentationStart = hasVideo
        ? scan.videoPts.take(64).reduce(math.min)
        : scan.audioPts.first;
    final origin = [
      if (hasVideo) scan.videoDts.first,
      if (hasAudio) scan.audioPts.first,
    ].reduce(math.min);

    var nextId = 1;
    final videoTrack = hasVideo
        ? _videoTrack(scan, nextId++, sps!, pps!, presentationStart)
        : null;
    final audioTrack = hasAudio
        ? _audioTrack(scan, nextId++, audio, presentationStart)
        : null;

    /// Chunks of one second each, video before audio within a second
    int window(int time) => (time - origin) ~/ _tsClock;

    final videoChunks = hasVideo
        ? _chunks(videoTrack!, [for (final dts in scan.videoDts) window(dts)])
        : const <_Chunk>[];
    final audioChunks = hasAudio
        ? _chunks(audioTrack!, [for (final pts in scan.audioPts) window(pts)])
        : const <_Chunk>[];

    final order = <_Chunk>[];
    var v = 0;
    var a = 0;

    while (v < videoChunks.length || a < audioChunks.length) {
      final videoWindow = v < videoChunks.length
          ? videoChunks[v].startTime
          : double.infinity;
      final audioWindow = a < audioChunks.length
          ? audioChunks[a].startTime
          : double.infinity;

      if (videoWindow <= audioWindow) {
        order.add(videoChunks[v++]);
      } else {
        order.add(audioChunks[a++]);
      }
    }

    return _TsLayout(
      [?videoTrack, ?audioTrack],
      order,
      video: videoTrack,
      audio: audioTrack,
    );
  }

  /// Consecutive samples of the same second form a chunk; the chunk start
  /// time is its second
  static List<_Chunk> _chunks(_Track track, List<int> windows) {
    final chunks = <_Chunk>[];
    var first = 0;

    for (var i = 1; i <= windows.length; i++) {
      if (i == windows.length || windows[i] != windows[first]) {
        var bytes = 0;
        for (var s = first; s < i; s++) {
          bytes += track.sizes[s];
        }
        chunks.add(
          _Chunk(track, 0, first, i - first, bytes, windows[first].toDouble()),
        );
        first = i;
      }
    }

    track.chunks.addAll(chunks);

    return chunks;
  }

  static _Track _videoTrack(
    _TsScan scan,
    int id,
    Uint8List sps,
    Uint8List pps,
    int presentationStart,
  ) {
    final count = scan.videoSizes.length;
    final durations = <int>[];
    var previous = 3600;

    for (var i = 0; i < count; i++) {
      final delta = i + 1 < count
          ? scan.videoDts[i + 1] - scan.videoDts[i]
          : previous;
      final duration = delta > 0 ? delta : previous;

      durations.add(duration);
      previous = duration;
    }

    final size = _SpsInfo.parse(sps);
    final track = _Track(id)
      ..timescale = _tsClock
      ..handler = 'vide'
      ..tkhd = _sourceTkhd(width: size.width, height: size.height)
      ..mdhd = _sourceMdhd()
      ..hdlr = _hdlr('vide', 'VideoHandler')
      ..stsd = _fullBox(
        'stsd',
        4,
        (data) => data.setUint32(0, 1),
      ).withChild(_avc1(sps, pps, size))
      ..mediaHeader = _fullBox('vmhd', 8, (_) {}, flags: 1)
      ..dinf = _dinf()
      ..editMediaTime = math.max(0, presentationStart - scan.videoDts.first);

    track.sizes.addAll(scan.videoSizes);
    track.durations.addAll(durations);
    track.compositionOffsets.addAll([
      for (var i = 0; i < count; i++) scan.videoPts[i] - scan.videoDts[i],
    ]);
    track.syncSamples.addAll(scan.videoKeys);

    return track;
  }

  static _Track _audioTrack(
    _TsScan scan,
    int id,
    _AacConfig config,
    int presentationStart,
  ) {
    final rate = config.sampleRate;

    /// Audio before the first video frame is cut; audio that starts later
    /// waits with an empty edit
    final lead = scan.audioPts.first - presentationStart;
    final track = _Track(id)
      ..timescale = rate
      ..handler = 'soun'
      ..tkhd = _sourceTkhd(width: 0, height: 0)
      ..mdhd = _sourceMdhd()
      ..hdlr = _hdlr('soun', 'SoundHandler')
      ..stsd = _fullBox(
        'stsd',
        4,
        (data) => data.setUint32(0, 1),
      ).withChild(_mp4a(config))
      ..mediaHeader = _fullBox('smhd', 4, (_) {})
      ..dinf = _dinf()
      ..editMediaTime = lead < 0 ? (-lead * rate / _tsClock).round() : 0
      ..emptyEditDuration = lead > 0
          ? (lead * _movieTimescale / _tsClock).round()
          : 0;

    track.sizes.addAll(scan.audioSizes);
    track.durations.addAll(
      List.filled(scan.audioSizes.length, _aacFrameSamples),
    );
    track.compositionOffsets.addAll(List.filled(scan.audioSizes.length, 0));
    track.syncSamples.addAll([
      for (var i = 1; i <= scan.audioSizes.length; i++) i,
    ]);

    return track;
  }
}

// region: second pass

/// Converts the samples again and writes each chunk once all of its
/// samples are there
class _TsChunkWriter {
  _TsChunkWriter(this.layout, this.output) {
    final ftyp = _ftyp(audioOnly: layout.audioOnly);
    final payload = layout.order.fold<int>(
      0,
      (sum, chunk) => sum + chunk.byteSize,
    );
    final wide = ftyp.length + payload + 16 + 64 * 1024 * 1024 > 0xFFFFFFFF;
    var moov = _moov(layout.tracks, wide64: wide);
    final mdatHeader = _mdatHeader(payload);
    var offset = ftyp.length + moov.length + mdatHeader.length;

    for (final chunk in layout.order) {
      chunk.outputOffset = offset;
      offset += chunk.byteSize;
    }
    moov = _moov(layout.tracks, wide64: wide);

    output
      ..writeFromSync(ftyp)
      ..writeFromSync(moov)
      ..writeFromSync(mdatHeader);
  }

  final _TsLayout layout;
  final RandomAccessFile output;

  final _avc = _AvcConverter();
  final _adts = _AdtsParser();
  final _videoSamples = Queue<Uint8List>();
  final _audioSamples = Queue<Uint8List>();

  /// Samples of each track already taken from the stream
  var _videoTaken = 0;
  var _audioTaken = 0;
  var _next = 0;

  void onPes(_TsPes pes) {
    switch (pes.kind) {
      case _TsKind.video:
        if (layout.video == null) return;

        final sample = _avc.convert(pes.payload);

        if (sample == null) return;

        _videoSamples.add(sample.bytes);
        _videoTaken++;
      case _TsKind.audio:
        if (layout.audio == null) return;

        for (final frame in _adts.frames(pes.payload, pes.pts)) {
          _audioSamples.add(frame.bytes);
          _audioTaken++;
        }
    }

    _flush();
  }

  void _flush() {
    while (_next < layout.order.length) {
      final chunk = layout.order[_next];
      final isVideo = identical(chunk.track, layout.video);
      final taken = isVideo ? _videoTaken : _audioTaken;

      if (taken < chunk.firstSample + chunk.sampleCount) return;

      final samples = isVideo ? _videoSamples : _audioSamples;
      final bytes = BytesBuilder(copy: false);

      for (var i = 0; i < chunk.sampleCount; i++) {
        bytes.add(samples.removeFirst());
      }

      final data = bytes.takeBytes();

      if (data.length != chunk.byteSize) {
        throw const FormatException('The stream changed between the passes');
      }

      output.writeFromSync(data);
      _next++;
    }
  }

  void finish() {
    _flush();

    if (_next != layout.order.length) {
      throw const FormatException(
        'The stream ended earlier on the second pass',
      );
    }
  }
}

// region: sample entries

/// Picture size from an H.264 sequence parameter set
class _SpsInfo {
  const _SpsInfo(this.width, this.height);

  final int width;
  final int height;

  static const _highProfiles = {
    100,
    110,
    122,
    244,
    44,
    83,
    86,
    118,
    128,
    138,
    139,
    134,
    135,
  };

  static _SpsInfo parse(Uint8List sps) {
    final bits = _BitReader(
      _withoutEmulationPrevention(Uint8List.sublistView(sps, 1)),
    );
    final profile = bits.bits(8);

    bits
      ..bits(16) // constraint flags, level
      ..ue(); // seq_parameter_set_id

    var chroma = 1;

    if (_highProfiles.contains(profile)) {
      chroma = bits.ue();
      if (chroma == 3) bits.bits(1);
      bits
        ..ue() // bit_depth_luma_minus8
        ..ue() // bit_depth_chroma_minus8
        ..bits(1); // qpprime_y_zero_transform_bypass_flag

      if (bits.bits(1) == 1) {
        for (var i = 0; i < (chroma == 3 ? 12 : 8); i++) {
          if (bits.bits(1) == 1) _skipScalingList(bits, i < 6 ? 16 : 64);
        }
      }
    }

    bits.ue(); // log2_max_frame_num_minus4

    final pocType = bits.ue();

    if (pocType == 0) {
      bits.ue();
    } else if (pocType == 1) {
      bits
        ..bits(1)
        ..se()
        ..se();
      final cycle = bits.ue();
      for (var i = 0; i < cycle; i++) {
        bits.se();
      }
    }

    bits
      ..ue() // max_num_ref_frames
      ..bits(1); // gaps_in_frame_num_value_allowed_flag

    final widthInMbs = bits.ue() + 1;
    final heightInMapUnits = bits.ue() + 1;
    final frameMbsOnly = bits.bits(1);

    if (frameMbsOnly == 0) bits.bits(1);
    bits.bits(1); // direct_8x8_inference_flag

    var cropLeft = 0;
    var cropRight = 0;
    var cropTop = 0;
    var cropBottom = 0;

    if (bits.bits(1) == 1) {
      cropLeft = bits.ue();
      cropRight = bits.ue();
      cropTop = bits.ue();
      cropBottom = bits.ue();
    }

    final cropUnitX = chroma == 1 || chroma == 2 ? 2 : 1;
    final cropUnitY = (chroma == 1 ? 2 : 1) * (2 - frameMbsOnly);

    return _SpsInfo(
      widthInMbs * 16 - cropUnitX * (cropLeft + cropRight),
      (2 - frameMbsOnly) * heightInMapUnits * 16 -
          cropUnitY * (cropTop + cropBottom),
    );
  }

  static void _skipScalingList(_BitReader bits, int size) {
    var last = 8;
    var next = 8;

    for (var j = 0; j < size; j++) {
      if (next != 0) {
        next = (last + bits.se() + 256) % 256;
      }
      last = next == 0 ? last : next;
    }
  }

  static Uint8List _withoutEmulationPrevention(Uint8List bytes) {
    final out = BytesBuilder(copy: false);
    var zeros = 0;

    for (final byte in bytes) {
      if (zeros >= 2 && byte == 3) {
        zeros = 0;
        continue;
      }
      out.addByte(byte);
      zeros = byte == 0 ? zeros + 1 : 0;
    }

    return out.takeBytes();
  }
}

class _BitReader {
  _BitReader(this._bytes);

  final Uint8List _bytes;
  var _position = 0;

  int bits(int count) {
    var value = 0;

    for (var i = 0; i < count; i++) {
      final index = _position >> 3;

      if (index >= _bytes.length) {
        throw const FormatException('The H.264 SPS ended too early');
      }

      value = value << 1 | (_bytes[index] >> (7 - (_position & 7)) & 1);
      _position++;
    }

    return value;
  }

  /// Unsigned Exp-Golomb
  int ue() {
    var zeros = 0;

    while (bits(1) == 0) {
      if (++zeros > 31) {
        throw const FormatException('Broken Exp-Golomb code in the H.264 SPS');
      }
    }

    return (1 << zeros) - 1 + (zeros == 0 ? 0 : bits(zeros));
  }

  /// Signed Exp-Golomb
  int se() {
    final value = ue();

    return value.isOdd ? (value + 1) ~/ 2 : -(value ~/ 2);
  }
}

/// `tkhd` in the shape the writer reads: the size in 16.16 at the end
Uint8List _sourceTkhd({required int width, required int height}) =>
    _fullBox('tkhd', 80, (data) {
      data
        ..setUint32(72, width << 16)
        ..setUint32(76, height << 16);
    });

/// `mdhd` in the shape the writer reads: the language `und`
Uint8List _sourceMdhd() =>
    _fullBox('mdhd', 20, (data) => data.setUint16(16, 0x55C4));

Uint8List _hdlr(String type, String name) =>
    _fullBox('hdlr', 20 + name.length + 1, (data) {
      final bytes = Uint8List.sublistView(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      bytes
        ..setAll(4, type.codeUnits)
        ..setAll(20, name.codeUnits);
    });

Uint8List _dinf() => _box('dinf', [
  _fullBox(
    'dref',
    4,
    (data) => data.setUint32(0, 1),
  ).withChild(_fullBox('url ', 0, (_) {}, flags: 1)),
]);

Uint8List _avc1(Uint8List sps, Uint8List pps, _SpsInfo size) {
  final avcC = _box('avcC', [
    Uint8List.fromList([
      1,
      sps[1],
      sps[2],
      sps[3],
      0xFF, // version, profile, compatibility, level, 4-byte lengths
      0xE1, sps.length >> 8, sps.length & 0xFF, ...sps,
      1, pps.length >> 8, pps.length & 0xFF, ...pps,
    ]),
  ]);
  final entry = Uint8List(78);

  ByteData.sublistView(entry)
    ..setUint16(6, 1) // data_reference_index
    ..setUint16(24, size.width)
    ..setUint16(26, size.height)
    ..setUint32(28, 0x00480000) // 72 dpi
    ..setUint32(32, 0x00480000)
    ..setUint16(40, 1) // frame_count
    ..setUint16(74, 0x0018) // depth
    ..setInt16(76, -1);

  return _box('avc1', [entry, avcC]);
}

Uint8List _mp4a(_AacConfig config) {
  final asc = config.audioSpecificConfig;

  /// ES_Descriptor with the decoder config and the SL config inside
  final decoderSpecific = [0x05, asc.length, ...asc];
  final decoderConfig = [
    0x04,
    13 + decoderSpecific.length,
    0x40,
    0x15,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...decoderSpecific,
  ];
  final esDescriptor = [
    0x03,
    3 + decoderConfig.length + 3,
    0,
    0,
    0,
    ...decoderConfig,
    0x06,
    1,
    0x02,
  ];
  final esds = _fullBox('esds', esDescriptor.length, (data) {
    for (final (index, value) in esDescriptor.indexed) {
      data.setUint8(index, value);
    }
  });
  final entry = Uint8List(28);

  ByteData.sublistView(entry)
    ..setUint16(6, 1) // data_reference_index
    ..setUint16(16, config.channels)
    ..setUint16(18, 16) // sample size
    ..setUint32(24, config.sampleRate < 0x10000 ? config.sampleRate << 16 : 0);

  return _box('mp4a', [entry, esds]);
}

extension on Uint8List {
  /// A box with [child] appended to its body, e.g. `stsd` and its entry
  Uint8List withChild(Uint8List child) {
    final bytes = Uint8List(length + child.length)
      ..setAll(0, this)
      ..setAll(length, child);

    ByteData.sublistView(bytes).setUint32(0, bytes.length);

    return bytes;
  }
}
