import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart' as win32;

import '../../constants/constants.dart';
import '../../models/models.dart';

part 'linux_video_metadata_reader.dart';
part 'macos_video_metadata_reader.dart';
part 'windows_video_metadata_reader.dart';

/// Duration and thumbnail of a video file as the system file manager
/// shows them
abstract interface class VideoMetadataService {
  /// Reads the duration and writes the thumbnail as JPEG into [thumbnailPath];
  /// without [thumbnailPath] only the duration is read. What the system
  /// does not know stays empty
  Future<VideoFileMetadataModel> read(
    String videoPath, {
    String? thumbnailPath,
  });
}

/// What one platform tells about a video file
abstract interface class _VideoMetadataReader {
  /// Duration and the JPEG thumbnail if [withThumbnail]
  Future<(Duration?, Uint8List?)> read(
    String videoPath, {
    required bool withThumbnail,
  });
}

final class VideoMetadataServiceImpl implements VideoMetadataService {
  /// A thumbnail handler of a broken file may hang: the library goes on
  static const _timeout = Duration(seconds: 30);

  static const _jpegQuality = 85;

  final _VideoMetadataReader? _reader;

  VideoMetadataServiceImpl() : _reader = _platformReader();

  static _VideoMetadataReader? _platformReader() {
    if (kIsWeb) return null;

    if (Platform.isWindows) return const _WindowsVideoMetadataReader();

    if (Platform.isMacOS) return const _MacOsVideoMetadataReader();

    if (Platform.isLinux) return const _LinuxVideoMetadataReader();

    return null;
  }

  @override
  Future<VideoFileMetadataModel> read(
    String videoPath, {
    String? thumbnailPath,
  }) async {
    final reader = _reader;

    if (reader == null) return const VideoFileMetadataModel();

    final (duration, thumbnail) = await reader
        .read(videoPath, withThumbnail: thumbnailPath != null)
        .timeout(_timeout, onTimeout: () => (null, null));

    if (thumbnailPath != null && thumbnail != null) {
      await Directory(p.dirname(thumbnailPath)).create(recursive: true);
      await File(thumbnailPath).writeAsBytes(thumbnail, flush: true);
    }

    return VideoFileMetadataModel(
      duration: duration != null && duration > Duration.zero ? duration : null,
      hasThumbnail: thumbnail != null,
    );
  }

  /// Any image the system gave, as a JPEG no bigger than the thumbnail size.
  /// Decoding runs off the UI isolate
  static Future<Uint8List?> _toJpeg(Uint8List bytes) => Isolate.run(() {
    final image = img.decodeImage(bytes);

    if (image == null) return null;

    const maxWidth = PlayerConstants.thumbnailWidth;
    const maxHeight = PlayerConstants.thumbnailHeight;
    final wide = image.width * maxHeight >= image.height * maxWidth;
    final fitted = image.width > maxWidth || image.height > maxHeight
        ? img.copyResize(
            image,
            width: wide ? maxWidth : null,
            height: wide ? null : maxHeight,
          )
        : image;

    return img.encodeJpg(fitted, quality: _jpegQuality);
  });

  /// Output of a command-line tool; `null` if it is missing, fails
  /// or runs too long
  static Future<String?> _runTool(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final process = await Process.start(executable, arguments);
      final output = process.stdout.transform(utf8.decoder).join();

      unawaited(process.stderr.drain<void>());

      final exitCode = await process.exitCode.timeout(
        _timeout,
        onTimeout: () {
          process.kill();

          return -1;
        },
      );

      return exitCode == 0 ? (await output).trim() : null;
    } on ProcessException {
      return null;
    }
  }

  /// A temporary folder for tools that write their result into a file
  static Future<T> _withTempFolder<T>(
    Future<T> Function(Directory folder) action,
  ) async {
    final folder = await Directory.systemTemp.createTemp('yt_download_thumb');

    try {
      return await action(folder);
    } finally {
      try {
        await folder.delete(recursive: true);
      } on FileSystemException {
        /// The system cleans its temporary folder itself
      }
    }
  }

  /// The first image in [folder]; tools name their output themselves
  static Future<Uint8List?> _firstImageIn(Directory folder) async {
    await for (final entity in folder.list()) {
      if (entity is File) return entity.readAsBytes();
    }

    return null;
  }
}
