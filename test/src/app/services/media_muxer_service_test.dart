import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/services/services.dart';

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

void main() {
  const muxer = Mp4MediaMuxerServiceImpl();
  late Directory directory;

  setUp(() async => directory = await Directory.systemTemp.createTemp('mux-test'));
  tearDown(() => directory.delete(recursive: true));

  Future<Uint8List> mux(List<Uint8List> streams, {bool audioOnly = false}) async {
    final inputs = [
      for (final (index, bytes) in streams.indexed)
        (await File(p.join(directory.path, 'in$index.mp4')).writeAsBytes(bytes)).path,
    ];
    final output = p.join(directory.path, 'out.mp4');

    await muxer.muxToMp4(inputs: inputs, outputPath: output, audioOnly: audioOnly);

    return File(output).readAsBytes();
  }

  test('видео и звук: обычный MP4 с таблицами сэмплов, указывающими на нужные байты', () async {
    final video = dashStream(handler: 'vide', timescale: 1000, elstMediaTime: 40, fragments: [
      (0, [('KEY0', 500, true, 40), ('v1', 500, false, 0)]),
      (1000, [('KEY2', 500, true, 40), ('v3', 500, false, 0)]),
    ]);
    final audio = dashStream(handler: 'soun', timescale: 44100, fragments: [
      (0, [('a0', 22050, true, 0), ('a1', 22050, true, 0)]),
      (44100, [('a2', 22050, true, 0), ('a3', 22050, true, 0)]),
      (88200, [('a4', 22050, true, 0), ('a5', 22050, true, 0)]),
    ]);

    final file = await mux([video, audio]);
    final boxes = topLevel(file);

    expect(boxes.map((box) => box.type), ['ftyp', 'moov', 'mdat'], reason: 'без moof/sidx: не фрагментирован');
    expect(String.fromCharCodes(boxes.first.bytes, 8, 12), 'isom');

    final moov = boxes[1];
    expect(moov.maybe('mvex'), isNull);

    final mvhd = moov.child('mvhd');
    expect([mvhd.u32(20), mvhd.u32(24)], [1000, 3000], reason: 'миллисекунды, самая длинная дорожка 3 с');
    expect(mvhd.u32(mvhd.bytes.length - 4), 3, reason: 'next_track_ID');

    Map<String, Object> describe(Box trak) {
      final tkhd = trak.child('tkhd');
      final mdia = trak.child('mdia');
      final stbl = mdia.child('minf').child('stbl');
      final stco = stbl.child('stco').table(1).map((entry) => entry.first).toList();
      final stsz = stbl.child('stsz');
      final sizes = [for (var i = 0; i < stsz.u32(16); i++) stsz.u32(20 + 4 * i)];
      final stsc = stbl.child('stsc').table(3);

      /// Read every sample back via stsc/stco/stsz
      final samples = <String>[];
      var sample = 0;
      for (var chunk = 0; chunk < stco.length; chunk++) {
        final perChunk = stsc.lastWhere((entry) => entry[0] <= chunk + 1)[1];
        var at = stco[chunk];
        for (var i = 0; i < perChunk; i++, sample++) {
          samples.add(String.fromCharCodes(file, at, at + sizes[sample]));
          at += sizes[sample];
        }
      }

      return {
        'id': tkhd.u32(20),
        'tkhdDuration': tkhd.u32(28),
        'group+volume': [tkhd.data.getUint16(42), tkhd.data.getUint16(44)],
        'mdhd': [mdia.child('mdhd').u32(20), mdia.child('mdhd').u32(24)],
        'stts': stbl.child('stts').table(2),
        'ctts': stbl.maybe('ctts')?.table(2) ?? 'none',
        'stss': stbl.maybe('stss')?.table(1) ?? 'none',
        'elst': trak.maybe('edts')?.child('elst').table(3) ?? 'none',
        'samples': samples,
      };
    }

    final traks = moov.all('trak');

    expect(describe(traks[0]), {
      'id': 1,
      'tkhdDuration': 2000,
      'group+volume': [0, 0],
      'mdhd': [1000, 2000],
      'stts': [[4, 500]],
      'ctts': [[1, 40], [1, 0], [1, 40], [1, 0]],
      'stss': [[1], [3]],
      'elst': [[2000, 40, 0x00010000]],
      'samples': ['KEY0', 'v1', 'KEY2', 'v3'],
    });

    expect(describe(traks[1]), {
      'id': 2,
      'tkhdDuration': 3000,
      'group+volume': [1, 0x0100],
      'mdhd': [44100, 132300],
      'stts': [[6, 22050]],
      'ctts': 'none',
      'stss': 'none',
      'elst': 'none',
      'samples': ['a0', 'a1', 'a2', 'a3', 'a4', 'a5'],
    });

    expect(String.fromCharCodes(boxes[2].bytes, 8), 'KEY0v1a0a1KEY2v3a2a3a4a5', reason: 'чанки чередуются по времени');
  });

  test('только звук: M4A с одной дорожкой', () async {
    final audio = dashStream(handler: 'soun', timescale: 44100, fragments: [
      (0, [('a0', 1024, true, 0)]),
      (1024, [('a1', 1024, true, 0)]),
    ]);

    final boxes = topLevel(await mux([audio], audioOnly: true));

    expect(boxes.map((box) => box.type), ['ftyp', 'moov', 'mdat']);
    expect(String.fromCharCodes(boxes.first.bytes, 8, 12), 'M4A ');
    expect(boxes[1].all('trak'), hasLength(1));
    expect(String.fromCharCodes(boxes[2].bytes, 8), 'a0a1');
  });

  test('фрагменты с абсолютными смещениями данных отклоняются', () async {
    final bytes = dashStream(handler: 'vide', timescale: 1000, fragments: [(0, [('V0', 1000, true, 0)])]);
    final tfhd = String.fromCharCodes(bytes).indexOf('tfhd');
    ByteData.sublistView(bytes).setUint32(tfhd + 4, 0x000001);

    expect(
      () => mux([bytes]),
      throwsA(isA<VideoException>().having((error) => error.code, 'code', const VideoErrorCodes().mux)),
    );
  });
}
