import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/services/services.dart';

/// Real files and the real libmpv. Needs FFmpeg for the sample videos
/// and a Windows build of the app for libmpv:
/// `$env:PLAYER_LIVE='1'; flutter test test/src/app/services/video_player_live_test.dart`
final _enabled = Platform.environment['PLAYER_LIVE'] == '1';

/// libmpv the build of the app ships, the newest build first
String? _libmpv() => [
  for (final mode in ['Release', 'Profile', 'Debug'])
    p.join('build', 'windows', 'x64', 'runner', mode, 'libmpv-2.dll'),
].where((path) => File(path).existsSync()).firstOrNull;

/// A test video of [seconds] made by FFmpeg
Future<File> _sample(
  Directory folder,
  String name,
  List<String> codecArguments, {
  int seconds = 12,
}) async {
  final file = File(p.join(folder.path, name));
  final result = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=1280x720:rate=30:duration=$seconds',
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=440:duration=$seconds',
    ...codecArguments,
    '-shortest',
    file.path,
  ]);

  expect(result.exitCode, 0, reason: '${result.stderr}');

  return file;
}

Future<T> _next<T>(Stream<T> stream, bool Function(T value) test) =>
    stream.firstWhere(test).timeout(const Duration(seconds: 20));

void main() {
  late Directory folder;

  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('player-live');
  });

  tearDownAll(() async {
    try {
      await folder.delete(recursive: true);
    } on FileSystemException {
      /// The system may still hold a thumbnail handle
    }
  });

  test(
    'система отдаёт длительность и превью видео',
    () async {
      final video = await _sample(folder, 'clip.mp4', [
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
      ]);
      final thumbnail = p.join(folder.path, 'thumbnails', 'clip.jpg');
      final metadata = await VideoMetadataServiceImpl().read(
        video.path,
        thumbnailPath: thumbnail,
      );

      expect(metadata.duration?.inMilliseconds, closeTo(12000, 150));
      expect(metadata.hasThumbnail, isTrue);

      final image = img.decodeJpg(await File(thumbnail).readAsBytes())!;

      expect(image.width, lessThanOrEqualTo(640));
      expect(image.height, lessThanOrEqualTo(360));
      expect(image.width / image.height, closeTo(16 / 9, 0.05));

      /// Only the duration when the thumbnail is not asked for
      final durationOnly = await VideoMetadataServiceImpl().read(video.path);

      expect(durationOnly.duration, metadata.duration);
      expect(durationOnly.hasThumbnail, isFalse);

      /// A file the system cannot describe gives nothing
      final broken = File(p.join(folder.path, 'broken.mp4'))
        ..writeAsBytesSync([1, 2, 3]);
      final nothing = await VideoMetadataServiceImpl().read(
        broken.path,
        thumbnailPath: p.join(folder.path, 'none.jpg'),
      );

      expect(nothing.hasThumbnail, isFalse);
      expect(File(p.join(folder.path, 'none.jpg')).existsSync(), isFalse);
    },
    skip: _enabled ? false : 'PLAYER_LIVE=1',
  );

  test(
    'libmpv играет H.264, AV1 и VP9: старт с позиции, скорость, перемотка, конец видео',
    () async {
      MediaKit.ensureInitialized(libmpv: _libmpv());

      final player = Player();

      for (final (name, arguments) in [
        ('h264.mp4', ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac']),
        ('av1.mp4', ['-c:v', 'libsvtav1', '-c:a', 'aac']),
        (
          'vp9.webm',
          ['-c:v', 'libvpx-vp9', '-deadline', 'realtime', '-c:a', 'libopus'],
        ),
      ]) {
        final video = await _sample(folder, name, arguments, seconds: 8);
        final duration = _next(
          player.stream.duration,
          (value) => value > Duration.zero,
        );

        await player.open(Media(video.path, start: const Duration(seconds: 3)));

        expect(
          (await duration).inMilliseconds,
          closeTo(8000, 150),
          reason: name,
        );
        expect(
          player.state.position,
          greaterThanOrEqualTo(const Duration(seconds: 3)),
          reason: name,
        );
        expect(player.state.playing, isTrue, reason: name);

        await player.setRate(2);
        await player.setVolume(0);

        expect(player.state.rate, 2);

        await player.seek(const Duration(seconds: 6));
        await _next(
          player.stream.position,
          (value) => value >= const Duration(seconds: 6),
        );
        await _next(player.stream.completed, (value) => value);

        /// The position of the last frame, a little before the duration
        expect(
          player.state.position,
          greaterThan(const Duration(seconds: 7)),
          reason: name,
        );

        await player.setRate(1);
        await player.stop();
      }

      /// The app keeps one player: it is not disposed
    },
    skip: _enabled && _libmpv() != null
        ? false
        : 'PLAYER_LIVE=1 and a Windows build with libmpv',
  );
}
