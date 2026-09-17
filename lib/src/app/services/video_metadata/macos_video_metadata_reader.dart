part of 'video_metadata_service.dart';

/// Spotlight for the duration and Quick Look for the thumbnail Finder shows
final class _MacOsVideoMetadataReader implements _VideoMetadataReader {
  const _MacOsVideoMetadataReader();

  @override
  Future<(Duration?, Uint8List?)> read(
    String videoPath, {
    required bool withThumbnail,
  }) async {
    final (duration, thumbnail) = await (
      _durationOf(videoPath),
      withThumbnail ? _thumbnailOf(videoPath) : Future<Uint8List?>.value(),
    ).wait;

    return (duration, thumbnail);
  }

  /// `123.45`, or `(null)` when Spotlight does not know it
  static Future<Duration?> _durationOf(String videoPath) async {
    final output = await VideoMetadataServiceImpl._runTool('mdls', [
      '-raw',
      '-name',
      'kMDItemDurationSeconds',
      videoPath,
    ]);
    final seconds = double.tryParse(output ?? '');

    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }

  /// Quick Look writes `<file name>.png` into the given folder, or nothing
  static Future<Uint8List?> _thumbnailOf(String videoPath) =>
      VideoMetadataServiceImpl._withTempFolder((folder) async {
        await VideoMetadataServiceImpl._runTool('qlmanage', [
          '-t',
          '-s',
          '${PlayerConstants.thumbnailWidth}',
          '-o',
          folder.path,
          videoPath,
        ]);

        final bytes = await VideoMetadataServiceImpl._firstImageIn(folder);

        return bytes == null ? null : VideoMetadataServiceImpl._toJpeg(bytes);
      });
}
