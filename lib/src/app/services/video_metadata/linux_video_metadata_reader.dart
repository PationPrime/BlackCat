part of 'video_metadata_service.dart';

/// The thumbnail the file manager has already made, or one made by
/// ffmpegthumbnailer or FFmpeg; the duration from ffprobe. Whatever tool
/// is not installed is skipped
final class _LinuxVideoMetadataReader implements _VideoMetadataReader {
  /// Thumbnail sizes of the freedesktop.org cache, the biggest first
  static const _cacheSizes = ['xx-large', 'x-large', 'large', 'normal'];

  /// A frame this far into the video: the first one is often black
  static const _frameOffset = Duration(seconds: 5);

  const _LinuxVideoMetadataReader();

  @override
  Future<(Duration?, Uint8List?)> read(
    String videoPath, {
    required bool withThumbnail,
  }) async {
    final duration = await _durationOf(videoPath);

    if (!withThumbnail) return (duration, null);

    final image =
        await _cachedThumbnailOf(videoPath) ??
        await _generatedThumbnailOf(videoPath, duration);

    return (
      duration,
      image == null ? null : await VideoMetadataServiceImpl._toJpeg(image),
    );
  }

  static Future<Duration?> _durationOf(String videoPath) async {
    final output = await VideoMetadataServiceImpl._runTool('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      videoPath,
    ]);
    final seconds = double.tryParse(output ?? '');

    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }

  /// The freedesktop.org cache: `<md5 of the file URI>.png`, made no earlier
  /// than the file changed
  static Future<Uint8List?> _cachedThumbnailOf(String videoPath) async {
    final environment = Platform.environment;
    final cacheHome =
        environment['XDG_CACHE_HOME'] ??
        p.join(environment['HOME'] ?? '', '.cache');
    final name = '${md5.convert(utf8.encode('${Uri.file(videoPath)}'))}.png';

    try {
      final videoModified = await File(videoPath).lastModified();

      for (final size in _cacheSizes) {
        final thumbnail = File(p.join(cacheHome, 'thumbnails', size, name));

        if (await thumbnail.exists() &&
            !(await thumbnail.lastModified()).isBefore(videoModified)) {
          return await thumbnail.readAsBytes();
        }
      }
    } on FileSystemException {
      return null;
    }

    return null;
  }

  static Future<Uint8List?> _generatedThumbnailOf(
    String videoPath,
    Duration? duration,
  ) => VideoMetadataServiceImpl._withTempFolder((folder) async {
    final output = p.join(folder.path, 'thumbnail.png');

    await VideoMetadataServiceImpl._runTool('ffmpegthumbnailer', [
      '-i',
      videoPath,
      '-o',
      output,
      '-s',
      '${PlayerConstants.thumbnailWidth}',
    ]);

    if (!await File(output).exists()) {
      final offset = duration == null || duration > _frameOffset * 2
          ? _frameOffset
          : duration ~/ 2;

      await VideoMetadataServiceImpl._runTool('ffmpeg', [
        '-v',
        'error',
        '-ss',
        '${offset.inMilliseconds / 1000}',
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=${PlayerConstants.thumbnailWidth}:-2',
        '-y',
        output,
      ]);
    }

    return VideoMetadataServiceImpl._firstImageIn(folder);
  });
}
