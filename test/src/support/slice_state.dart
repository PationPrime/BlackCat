// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:files_downloader/files_downloader.dart';
import 'package:files_downloader/src/state/download_state_file.dart';

/// Leaves what the built-in downloader leaves after a pause: stream files
/// of the full size with [written] bytes at the start of their slices,
/// and their slice state
void writeSlicedDownload({
  required String workDirectory,
  required String downloadId,
  required int sliceSize,
  required List<({String name, List<int> content, List<int> counters})> files,
}) {
  for (final file in files) {
    final bytes = List<int>.filled(file.content.length, 0);

    for (var slice = 0; slice < file.counters.length; slice++) {
      final start = slice * sliceSize;

      bytes.setRange(
        start,
        start + file.counters[slice],
        file.content.sublist(start, start + file.counters[slice]),
      );
    }

    File('$workDirectory${Platform.pathSeparator}${file.name}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  DownloadStateFile.createSync(
    FilesDownloader.statePath(workDirectory, downloadId),
    sliceSize: sliceSize,
    entries: [
      for (final file in files)
        StateFileEntry(
          identity: file.name,
          length: file.content.length,
          acceptsRanges: true,
        ),
    ],
    counters: [for (final file in files) file.counters],
  );
}
