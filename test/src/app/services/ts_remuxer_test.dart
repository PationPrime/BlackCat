import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/services/services.dart';

import '../../support/dash_stream_builder.dart';

/// HLS of 6 seconds made by ffmpeg: H.264 High 160x90 at 25 fps with
/// B-frames and mono AAC-LC at 44.1 kHz, three segments of 2 seconds.
/// The audio starts 23 ms (one AAC frame) before the first video frame
const _fixture = 'test/src/support/fixtures/hls';

const _segments = [
  '$_fixture/segment-0.ts',
  '$_fixture/segment-1.ts',
  '$_fixture/segment-2.ts',
];

void main() {
  const muxer = Mp4MediaMuxerServiceImpl();
  late Directory directory;

  setUp(
    () async => directory = await Directory.systemTemp.createTemp('ts-remux'),
  );
  tearDown(() => directory.delete(recursive: true));

  Future<List<Box>> remux(List<String> inputs) async {
    final output = p.join(directory.path, 'out.mp4');

    await muxer.remuxTsToMp4(inputs: inputs, outputPath: output);

    return topLevel(await File(output).readAsBytes());
  }

  List<int> sampleSizes(Box stbl) {
    final stsz = stbl.child('stsz');

    return [for (var i = 0; i < stsz.u32(16); i++) stsz.u32(20 + 4 * i)];
  }

  test(
    'сегменты HLS становятся обычным MP4: H.264 и AAC без перекодирования',
    () async {
      final boxes = await remux(_segments);

      expect(boxes.map((box) => box.type), ['ftyp', 'moov', 'mdat']);

      final traks = boxes[1].all('trak');

      expect(traks, hasLength(2));

      final video = traks[0].child('mdia');
      final audio = traks[1].child('mdia');
      final videoStbl = video.child('minf').child('stbl');
      final audioStbl = audio.child('minf').child('stbl');

      expect(String.fromCharCodes(video.child('hdlr').bytes, 16, 20), 'vide');
      expect(String.fromCharCodes(audio.child('hdlr').bytes, 16, 20), 'soun');

      /// Timescale and duration: 90 kHz for 6 s, and the audio rate
      expect(
        [video.child('mdhd').u32(20), video.child('mdhd').u32(24)],
        [90000, 6 * 90000],
      );
      expect(audio.child('mdhd').u32(20), 44100);

      /// 25 fps × 6 s and every AAC frame of the stream
      final videoSizes = sampleSizes(videoStbl);
      final audioSizes = sampleSizes(audioStbl);

      expect(videoSizes, hasLength(150));
      expect(audioSizes, hasLength(260));

      /// Width and height come from the SPS, with its cropping:
      /// the stsd entry count is followed by the avc1 entry
      final stsd = videoStbl.child('stsd');

      expect(String.fromCharCodes(stsd.bytes, 20, 24), 'avc1');
      expect([stsd.data.getUint16(48), stsd.data.getUint16(50)], [160, 90]);
      expect(String.fromCharCodes(stsd.bytes).contains('avcC'), isTrue);
      expect(
        String.fromCharCodes(audioStbl.child('stsd').bytes).contains('esds'),
        isTrue,
      );

      /// B-frames: pictures are shown later than decoded
      expect(videoStbl.maybe('ctts'), isNotNull);
      expect(videoStbl.child('stss').table(1).first, [1]);

      /// Every sample lies in mdat, nothing else does
      expect(
        [...videoSizes, ...audioSizes].fold<int>(0, (a, b) => a + b),
        boxes[2].bytes.length - 8,
      );
    },
  );

  test(
    'звук, начатый раньше видео, обрезается списком правок: синхронность как в TS',
    () async {
      final boxes = await remux(_segments);
      final traks = boxes[1].all('trak');

      /// Video shows its first picture at once: the edit skips the delay
      /// of the B-frames. Audio skips its first frame, the 23 ms before
      /// the video
      expect(traks[0].child('edts').child('elst').table(3), [
        [6000, 7200, 0x00010000],
      ]);
      expect(traks[1].child('edts').child('elst').table(3).single[1], 1024);
    },
  );

  test('сегменты можно передать и одним файлом, как пишет yt-dlp', () async {
    final joined = File(p.join(directory.path, 'joined.ts'));

    await joined.writeAsBytes([
      for (final segment in _segments) ...await File(segment).readAsBytes(),
    ]);

    final boxes = await remux([joined.path]);
    final stbl = boxes[1].all('trak').first.child('mdia').child('minf');

    expect(sampleSizes(stbl.child('stbl')), hasLength(150));
  });

  test('не MPEG-TS — ошибка сборки файла, а не падение', () async {
    final broken = File(p.join(directory.path, 'broken.ts'));

    await broken.writeAsString('not a transport stream' * 100);

    await expectLater(
      muxer.remuxTsToMp4(
        inputs: [broken.path],
        outputPath: p.join(directory.path, 'out.mp4'),
      ),
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
