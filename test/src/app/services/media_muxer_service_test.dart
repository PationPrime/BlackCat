import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/services/services.dart';

import '../../support/dash_stream_builder.dart';

void main() {
  const muxer = Mp4MediaMuxerServiceImpl();
  late Directory directory;

  setUp(
    () async => directory = await Directory.systemTemp.createTemp('mux-test'),
  );
  tearDown(() => directory.delete(recursive: true));

  Future<Uint8List> mux(
    List<Uint8List> streams, {
    bool audioOnly = false,
  }) async {
    final inputs = [
      for (final (index, bytes) in streams.indexed)
        (await File(
          p.join(directory.path, 'in$index.mp4'),
        ).writeAsBytes(bytes)).path,
    ];
    final output = p.join(directory.path, 'out.mp4');

    await muxer.muxToMp4(
      inputs: inputs,
      outputPath: output,
      audioOnly: audioOnly,
    );

    return File(output).readAsBytes();
  }

  test(
    'видео и звук: обычный MP4 с таблицами сэмплов, указывающими на нужные байты',
    () async {
      final video = dashStream(
        handler: 'vide',
        timescale: 1000,
        elstMediaTime: 40,
        fragments: [
          (0, [('KEY0', 500, true, 40), ('v1', 500, false, 0)]),
          (1000, [('KEY2', 500, true, 40), ('v3', 500, false, 0)]),
        ],
      );
      final audio = dashStream(
        handler: 'soun',
        timescale: 44100,
        fragments: [
          (0, [('a0', 22050, true, 0), ('a1', 22050, true, 0)]),
          (44100, [('a2', 22050, true, 0), ('a3', 22050, true, 0)]),
          (88200, [('a4', 22050, true, 0), ('a5', 22050, true, 0)]),
        ],
      );

      final file = await mux([video, audio]);
      final boxes = topLevel(file);

      expect(boxes.map((box) => box.type), [
        'ftyp',
        'moov',
        'mdat',
      ], reason: 'без moof/sidx: не фрагментирован');
      expect(String.fromCharCodes(boxes.first.bytes, 8, 12), 'isom');

      final moov = boxes[1];
      expect(moov.maybe('mvex'), isNull);

      final mvhd = moov.child('mvhd');
      expect(
        [mvhd.u32(20), mvhd.u32(24)],
        [1000, 3000],
        reason: 'миллисекунды, самая длинная дорожка 3 с',
      );
      expect(mvhd.u32(mvhd.bytes.length - 4), 3, reason: 'next_track_ID');

      Map<String, Object> describe(Box trak) {
        final tkhd = trak.child('tkhd');
        final mdia = trak.child('mdia');
        final stbl = mdia.child('minf').child('stbl');
        final stco = stbl
            .child('stco')
            .table(1)
            .map((entry) => entry.first)
            .toList();
        final stsz = stbl.child('stsz');
        final sizes = [
          for (var i = 0; i < stsz.u32(16); i++) stsz.u32(20 + 4 * i),
        ];
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
        'stts': [
          [4, 500],
        ],
        'ctts': [
          [1, 40],
          [1, 0],
          [1, 40],
          [1, 0],
        ],
        'stss': [
          [1],
          [3],
        ],
        'elst': [
          [2000, 40, 0x00010000],
        ],
        'samples': ['KEY0', 'v1', 'KEY2', 'v3'],
      });

      expect(describe(traks[1]), {
        'id': 2,
        'tkhdDuration': 3000,
        'group+volume': [1, 0x0100],
        'mdhd': [44100, 132300],
        'stts': [
          [6, 22050],
        ],
        'ctts': 'none',
        'stss': 'none',
        'elst': 'none',
        'samples': ['a0', 'a1', 'a2', 'a3', 'a4', 'a5'],
      });

      expect(
        String.fromCharCodes(boxes[2].bytes, 8),
        'KEY0v1a0a1KEY2v3a2a3a4a5',
        reason: 'чанки чередуются по времени',
      );
    },
  );

  test('только звук: M4A с одной дорожкой', () async {
    final audio = dashStream(
      handler: 'soun',
      timescale: 44100,
      fragments: [
        (0, [('a0', 1024, true, 0)]),
        (1024, [('a1', 1024, true, 0)]),
      ],
    );

    final boxes = topLevel(await mux([audio], audioOnly: true));

    expect(boxes.map((box) => box.type), ['ftyp', 'moov', 'mdat']);
    expect(String.fromCharCodes(boxes.first.bytes, 8, 12), 'M4A ');
    expect(boxes[1].all('trak'), hasLength(1));
    expect(String.fromCharCodes(boxes[2].bytes, 8), 'a0a1');
  });

  test('фрагменты с абсолютными смещениями данных отклоняются', () async {
    final bytes = dashStream(
      handler: 'vide',
      timescale: 1000,
      fragments: [
        (0, [('V0', 1000, true, 0)]),
      ],
    );
    final tfhd = String.fromCharCodes(bytes).indexOf('tfhd');
    ByteData.sublistView(bytes).setUint32(tfhd + 4, 0x000001);

    expect(
      () => mux([bytes]),
      throwsA(
        isA<VideoException>().having(
          (error) => error.code,
          'code',
          const VideoErrorCodes().mux,
        ),
      ),
    );
  });
}
