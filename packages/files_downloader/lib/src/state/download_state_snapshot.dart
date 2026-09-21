/// What a state file tells about one file of a download
final class FileStateSnapshot {
  final String identity;

  /// `null` when the size was unknown
  final int? length;
  final bool acceptsRanges;
  final String? validator;

  /// Downloaded bytes of each slice, counted from its start
  final List<int> sliceCounters;
  final int sliceSize;

  const FileStateSnapshot({
    required this.identity,
    required this.length,
    required this.acceptsRanges,
    required this.validator,
    required this.sliceCounters,
    required this.sliceSize,
  });

  int get downloadedBytes => sliceCounters.fold(0, (a, b) => a + b);

  bool get isComplete => length != null && downloadedBytes >= length!;

  /// Downloaded bytes a file of [fileLength] bytes on disk really holds:
  /// a missing (`0`) or shortened file keeps only the slice bytes that fit
  /// in it. A file of the full size is trusted as it is
  int downloadedBytesWithin(int fileLength) {
    if (fileLength == length) return downloadedBytes;

    var bytes = 0;

    for (var slice = 0; slice < sliceCounters.length; slice++) {
      final onDisk = fileLength - slice * sliceSize;

      if (onDisk <= 0) break;

      bytes += sliceCounters[slice] < onDisk ? sliceCounters[slice] : onDisk;
    }

    return bytes;
  }

  /// Bytes from the start of the file up to its first gap: as much as
  /// a downloader that writes in order can continue from.
  /// A file of an unknown size is always downloaded anew
  int get contiguousBytes {
    final length = this.length;

    if (length == null) return 0;

    var bytes = 0;

    for (var slice = 0; slice < sliceCounters.length; slice++) {
      final sliceLength = slice == sliceCounters.length - 1
          ? length - slice * sliceSize
          : sliceSize;

      bytes += sliceCounters[slice];

      if (sliceCounters[slice] < sliceLength) break;
    }

    return bytes;
  }

  @override
  String toString() =>
      'FileStateSnapshot($identity: $downloadedBytes/$length, '
      'contiguous $contiguousBytes)';
}

/// What a state file tells about a download
final class DownloadStateSnapshot {
  final int sliceSize;
  final List<FileStateSnapshot> files;

  const DownloadStateSnapshot({required this.sliceSize, required this.files});

  int get downloadedBytes =>
      files.fold(0, (sum, file) => sum + file.downloadedBytes);

  /// `null` when the size of any file is unknown
  int? get totalBytes => files.any((file) => file.length == null)
      ? null
      : files.fold<int>(0, (sum, file) => sum + file.length!);

  FileStateSnapshot? fileByIdentity(String identity) =>
      files.where((file) => file.identity == identity).firstOrNull;
}
