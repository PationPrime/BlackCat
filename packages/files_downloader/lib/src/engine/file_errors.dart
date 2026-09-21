import 'dart:io';
import 'dart:math' as math;

import '../models/download_error.dart';

/// OS codes of a full disk or an exhausted disk quota
Set<int> get _diskFullCodes {
  if (Platform.isWindows) {
    /// `ERROR_HANDLE_DISK_FULL`, `ERROR_DISK_FULL`, `ERROR_DISK_QUOTA_EXCEEDED`
    return const {39, 112, 1295};
  }

  /// `ENOSPC` and `EDQUOT`
  if (Platform.isMacOS || Platform.isIOS) return const {28, 69};

  return const {28, 122};
}

/// OS codes with a cause of their own, never the free space: a missing
/// path, no rights, a file held by another program, a folder in place
/// of a file, a read-only disk, a bad name
Set<int> get _otherCauseCodes {
  if (Platform.isWindows) {
    /// `ERROR_FILE_NOT_FOUND`, `ERROR_PATH_NOT_FOUND`, `ERROR_ACCESS_DENIED`,
    /// `ERROR_WRITE_PROTECT`, `ERROR_SHARING_VIOLATION`,
    /// `ERROR_LOCK_VIOLATION`, `ERROR_INVALID_NAME`,
    /// `ERROR_FILENAME_EXCED_RANGE`, `ERROR_DIRECTORY`
    return const {2, 3, 5, 19, 32, 33, 123, 206, 267};
  }

  /// `EPERM`, `ENOENT`, `EACCES`, `ENOTDIR`, `EISDIR`, `EROFS`
  /// and `ENAMETOOLONG`
  if (Platform.isMacOS || Platform.isIOS) {
    return const {1, 2, 13, 20, 21, 30, 63};
  }

  return const {1, 2, 13, 20, 21, 30, 36};
}

/// The system says outright that the disk is full
bool isDiskFull(FileSystemException error) =>
    _diskFullCodes.contains(error.osError?.errorCode);

/// The error may come from a lack of space: a failed write, an input/output
/// error, an unknown cause. Errors with a cause of their own may not
bool mayBeDiskFull(FileSystemException error) =>
    isDiskFull(error) || !_otherCauseCodes.contains(error.osError?.errorCode);

/// A file error of a download. A full disk the system reports is taken
/// as is. An error that may come from a lack of space asks
/// [availableBytes] and is a full disk when less than [neededBytes]
/// is free, or less than [minimumFreeBytes]: nothing fits then.
/// Other errors are not checked
FilesDownloadError fileError(
  FileSystemException error, {
  required String path,
  required int neededBytes,
  required int? Function() availableBytes,
  required int minimumFreeBytes,
}) {
  if (!mayBeDiskFull(error)) return fileSystemError(error, path: path);

  final available = availableBytes();
  final full =
      isDiskFull(error) ||
      (available != null &&
          available < math.max(neededBytes, minimumFreeBytes));

  return full
      ? diskFullError(
          path: path,
          neededBytes: neededBytes,
          availableBytes: available,
        )
      : fileSystemError(error, path: path);
}

/// A full disk as a download error
FilesDownloadError diskFullError({
  required String? path,
  required int neededBytes,
  required int? availableBytes,
}) => FilesDownloadError(
  FilesDownloadErrorType.diskFull,
  [
    'Not enough disk space: the download needs ${_size(neededBytes)} more',
    if (availableBytes != null) '${_size(availableBytes)} is free',
  ].join(', '),
  path: path,
  neededBytes: neededBytes,
  availableBytes: availableBytes,
);

/// A file error that has nothing to do with free space
FilesDownloadError fileSystemError(FileSystemException error, {String? path}) =>
    FilesDownloadError(
      FilesDownloadErrorType.fileSystem,
      [
        error.message,
        if (error.osError?.message case final reason?
            when reason.trim().isNotEmpty)
          reason.trim(),
      ].join(': '),
      path: path ?? error.path,
    );

String _size(int bytes) =>
    '${(bytes / (1 << 30)).toStringAsFixed(2)} GiB ($bytes bytes)';
