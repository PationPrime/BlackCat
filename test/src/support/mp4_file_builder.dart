import 'dart:typed_data';

import 'dash_stream_builder.dart';

/// A regular MP4 of an H.264 video: `ftyp`, `moov` with the picture and the
/// duration, and [mdat] boxes; `moov` goes after them when not [moovFirst]
Uint8List progressiveMp4({
  int width = 720,
  int height = 1280,
  int timescale = 1000,
  int duration = 10000,
  List<Uint8List> mdat = const [],
  bool moovFirst = true,
}) {
  final visualEntry = Uint8List(78);

  ByteData.sublistView(visualEntry)
    ..setUint16(24, width)
    ..setUint16(26, height);

  // dart format off
  final mvhd = full('mvhd', [0, 0, timescale, duration, 0x00010000, 0x01000000, ...List.filled(17, 0), 2]);
  final tkhd = full('tkhd', [0, 0, 1, 0, 0, 0, 0, 0, 0, 0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000, width << 16, height << 16], flags: 3);
  final hdlr = box('hdlr', [raw([0, 0, 0, 0, 0, 0, 0, 0, ...'vide'.codeUnits, ...List.filled(13, 0)])]);
  // dart format on

  final moov = box('moov', [
    mvhd,
    box('trak', [
      tkhd,
      box('mdia', [
        full('mdhd', [0, 0, timescale, duration, 0x55c40000]),
        hdlr,
        box('minf', [
          box('dinf'),
          box('stbl', [
            box('stsd', [
              raw([0, 0, 0, 0, 0, 0, 0, 1]),
              box('avc1', [visualEntry]),
            ]),
          ]),
        ]),
      ]),
    ]),
  ]);

  return Uint8List.fromList([
    ...box('ftyp', [
      raw('isom'.codeUnits),
      raw([0, 0, 2, 0]),
    ]),
    if (moovFirst) ...moov,
    for (final data in mdat) ...box('mdat', [data]),
    if (!moovFirst) ...moov,
  ]);
}
