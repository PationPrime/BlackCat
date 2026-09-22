import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';

/// Work folder files of an Instagram download, the same for both engines
abstract final class InstagramFiles {
  /// Streams of a choice as the download task keeps them
  static List<DownloadStreamModel> streamsOf(InstagramChoice choice) => [
    DownloadStreamModel(
      role: DownloadStreamRole.video,
      itag: choice.video.key,
      contentLength: choice.video.size ?? 0,
    ),
    if (choice.audio case final audio?)
      DownloadStreamModel(
        role: DownloadStreamRole.audio,
        itag: audio.key,
        contentLength: audio.size ?? 0,
      ),
  ];

  /// Where every stream of a choice goes: `<prefix><key>.mp4` for a ready
  /// file, `.video.mp4` and `.audio.m4a` for DASH
  static List<InstagramStreamTarget> targetsOf(
    InstagramChoice choice, {
    required String workDirectory,
    required String prefix,
  }) {
    String path(InstagramStreamDto stream, String suffix) =>
        p.join(workDirectory, '$prefix${stream.key}$suffix');

    final video = choice.video;

    return [
      (
        stream: video,
        path: path(
          video,
          video.kind == InstagramStreamKind.file ? '.mp4' : '.video.mp4',
        ),
      ),
      if (choice.audio case final audio?)
        (stream: audio, path: path(audio, '.audio.m4a')),
    ];
  }

  /// Wipes files of another quality: another one was chosen. The yt-dlp
  /// `.part` files of the [files] stay
  static Future<void> deleteStale(
    String workDirectory, {
    required String prefix,
    required List<InstagramStreamTarget> files,
    required Future<void> Function(String path) deleteFile,
  }) async {
    final keep = {
      for (final file in files) ...[
        p.basename(file.path),
        '${p.basename(file.path)}.part',
      ],
    };

    await for (final entity in Directory(workDirectory).list()) {
      final name = p.basename(entity.path);

      if (entity is File && name.startsWith(prefix) && !keep.contains(name)) {
        await deleteFile(entity.path);
      }
    }
  }

  /// Muxes DASH video and audio into the MP4 the download gives
  static Future<String> mux(
    List<InstagramStreamTarget> files, {
    required String workDirectory,
    required MediaMuxerService mediaMuxerService,
    required FileSystemService fileSystemService,
    DownloadCancellation? cancellation,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    final lengths = await Future.wait([
      for (final file in files) fileSystemService.fileLength(file.path),
    ]);
    final total = lengths.fold<int>(0, (sum, bytes) => sum + bytes);
    final output = p.join(
      workDirectory,
      '${DownloadPartFiles.outputBaseName}.mp4',
    );

    onProgress?.call(
      DownloadProgressModel(
        DownloadStage.processing,
        100,
        downloadedBytes: total,
        totalBytes: total,
      ),
    );

    await mediaMuxerService.muxToMp4(
      inputs: [for (final file in files) file.path],
      outputPath: output,
    );

    /// The streams are deleted only after the check: a cancelled download
    /// will mux the file again from the same streams
    if (cancellation?.isCancelled ?? false) {
      throw VideoException(const VideoErrorCodes().canceled);
    }

    for (final file in files) {
      await fileSystemService.deleteFile(file.path);
    }

    return output;
  }
}
