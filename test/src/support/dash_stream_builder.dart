import 'dart:typed_data';

/// Tiny fragmented MP4 files with the same box structure as YouTube DASH streams

Uint8List box(String type, [List<Uint8List> children = const []]) {
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

Uint8List full(String type, List<int> uint32s, {int version = 0, int flags = 0}) {
  final payload = ByteData(4 + 4 * uint32s.length)..setUint32(0, version << 24 | flags);
  for (final (index, value) in uint32s.indexed) {
    payload.setUint32(4 + 4 * index, value);
  }
  return box(type, [payload.buffer.asUint8List()]);
}

Uint8List raw(List<int> bytes) => Uint8List.fromList(bytes);

/// Sample: data (text), duration, keyframe, composition offset
typedef Sample = (String data, int duration, bool sync, int cto);

Uint8List dashStream({
  required String handler,
  required int timescale,
  required List<(int time, List<Sample>)> fragments,
  int elstMediaTime = 0,
}) {
  final mvhd = full('mvhd', [0, 0, timescale, 0, 0x00010000, 0x01000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]);
  final tkhd = full('tkhd', [0, 0, 1, 0, 0, 0, 0, 0, 0, 0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000, 1920 << 16, 1080 << 16], flags: 3);
  final mdhd = full('mdhd', [0, 0, timescale, 0, 0x55c40000]);
  final hdlr = box('hdlr', [raw([0, 0, 0, 0, 0, 0, 0, 0, ...handler.codeUnits, ...List.filled(13, 0)])]);
  final moov = box('moov', [
    mvhd,
    box('mvex', [full('trex', [1, 1, 0, 0, 0])]),
    box('trak', [
      tkhd,
      if (elstMediaTime != 0) box('edts', [full('elst', [1, 0, elstMediaTime, 0x00010000])]),
      box('mdia', [
        mdhd,
        hdlr,
        box('minf', [
          box('dinf'),
          box('stbl', [full('stsd', [1]), full('stts', [0]), full('stsc', [0]), full('stco', [0]), full('stsz', [0, 0])]),
        ]),
      ]),
    ]),
  ]);

  final out = BytesBuilder()
    ..add(box('ftyp', [raw('dash'.codeUnits), raw([0, 0, 0, 0])]))
    ..add(moov)
    ..add(full('sidx', [1, timescale, 0, 0, 0]));

  for (final (index, (time, samples)) in fragments.indexed) {
    Uint8List trun(int dataOffset) => full('trun', [
      samples.length,
      dataOffset,
      for (final (data, duration, sync, cto) in samples) ...[duration, data.length, sync ? 0 : 0x10000, cto],
    ], flags: 0x001 | 0x100 | 0x200 | 0x400 | 0x800);

    Uint8List moofWith(int dataOffset) => box('moof', [
      full('mfhd', [index + 1]),
      box('traf', [full('tfhd', [1], flags: 0x20000), full('tfdt', [time]), trun(dataOffset)]),
    ]);

    final moofSize = moofWith(0).length;
    out
      ..add(moofWith(moofSize + 8))
      ..add(box('mdat', [raw(samples.expand((sample) => sample.$1.codeUnits).toList())]));
  }

  return out.toBytes();
}

class Box {
  final String type;
  final Uint8List bytes;

  Box(this.type, this.bytes);

  ByteData get data => ByteData.sublistView(bytes);

  List<Box> get children {
    final result = <Box>[];
    for (var offset = 8; offset + 8 <= bytes.length;) {
      final size = ByteData.sublistView(bytes).getUint32(offset);
      result.add(Box(String.fromCharCodes(bytes, offset + 4, offset + 8), Uint8List.sublistView(bytes, offset, offset + size)));
      offset += size;
    }
    return result;
  }

  Box child(String type) => children.firstWhere((box) => box.type == type);
  List<Box> all(String type) => children.where((box) => box.type == type).toList();
  Box? maybe(String type) => children.where((box) => box.type == type).firstOrNull;

  int u32(int offset) => data.getUint32(offset);

  List<List<int>> table(int entryWords) => [
    for (var i = 0; i < u32(12); i++) [for (var w = 0; w < entryWords; w++) data.getInt32(16 + 4 * (i * entryWords + w))],
  ];
}

List<Box> topLevel(Uint8List file) => Box('file', Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, ...file])).children;
