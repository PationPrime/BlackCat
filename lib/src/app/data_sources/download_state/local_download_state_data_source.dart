import 'dart:io';
import 'dart:math' as math;

import 'package:files_downloader/files_downloader.dart';
import 'package:path/path.dart' as p;

import '../../tools/tools.dart';

/// Slice progress of built-in downloads in their work folders.
///
/// The built-in downloader fills stream files in slices and keeps their
/// progress in `state_<downloadId>.fds`; yt-dlp writes the same files in
/// order. Without a state the file length is the downloaded length
abstract interface class LocalDownloadStateDataSource {
  /// Downloaded bytes of each stream file by its name, as far as the file
  /// on disk still holds them: a deleted or shortened file loses its slices.
  /// `null` when the download has no slice state: its files are written
  /// in order
  Future<Map<String, int>?> downloadedBytes({
    required String workDirectory,
    required String downloadId,
  });

  /// Turns sliced stream files into files written in order, the way yt-dlp
  /// continues them: each keeps its bytes up to the first gap, and the state
  /// goes. Stream files of a damaged state cannot be trusted and are deleted
  Future<void> toSequentialParts({
    required String workDirectory,
    required String downloadId,
  });
}

final class LocalDownloadStateDataSourceImpl
    implements LocalDownloadStateDataSource {
  const LocalDownloadStateDataSourceImpl();

  @override
  Future<Map<String, int>?> downloadedBytes({
    required String workDirectory,
    required String downloadId,
  }) async {
    final state = await FilesDownloader.readState(workDirectory, downloadId);

    if (state == null) return null;

    return {
      for (final file in state.files)
        file.identity: file.downloadedBytesWithin(
          await _lengthOf(p.join(workDirectory, file.identity)),
        ),
    };
  }

  @override
  Future<void> toSequentialParts({
    required String workDirectory,
    required String downloadId,
  }) async {
    final statePath = FilesDownloader.statePath(workDirectory, downloadId);

    if (!await File(statePath).exists()) return;

    final state = await FilesDownloader.readState(workDirectory, downloadId);

    if (state == null) {
      await _deleteStreamFiles(workDirectory);
    } else {
      for (final file in state.files) {
        final target = File(p.join(workDirectory, file.identity));

        if (!await target.exists()) continue;

        final output = await target.open(mode: FileMode.append);

        try {
          /// A shortened file is not padded with zeros up to the saved bytes
          await output.truncate(
            math.min(file.contiguousBytes, await output.length()),
          );
        } finally {
          await output.close();
        }
      }
    }

    await FilesDownloader.deleteState(workDirectory, downloadId);
  }

  static Future<int> _lengthOf(String path) async {
    final file = File(path);

    return await file.exists() ? await file.length() : 0;
  }

  static Future<void> _deleteStreamFiles(String workDirectory) async {
    await for (final entity in Directory(workDirectory).list()) {
      if (entity is File &&
          DownloadPartFiles.parse(p.basename(entity.path)) != null) {
        await entity.delete();
      }
    }
  }
}
