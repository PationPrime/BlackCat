import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Free space of the volume a path is on
abstract interface class DiskSpace {
  /// Bytes the current user can still write on the volume of [path].
  /// The path may not exist yet: its nearest existing folder is asked.
  /// `null` when the system cannot tell
  int? availableBytes(String path);
}

/// Free space from the system on Windows, macOS and Linux: the platform call
/// first, the `df` command if the call is not available
final class SystemDiskSpace implements DiskSpace {
  const SystemDiskSpace();

  @override
  int? availableBytes(String path) {
    final folder = _existingFolder(path);

    if (folder == null) return null;

    try {
      if (Platform.isWindows) return _windowsAvailableBytes(folder);

      if (Platform.isMacOS || Platform.isLinux) {
        return _statvfsAvailableBytes(folder) ?? _dfAvailableBytes(folder);
      }
    } on Object {
      /// A system without the call: nothing to compare with
    }

    return null;
  }

  /// The folder itself if it exists, otherwise its nearest existing parent
  static String? _existingFolder(String path) {
    var current = p.normalize(p.absolute(path));

    while (true) {
      if (Directory(current).existsSync()) return current;

      final parent = p.dirname(current);

      if (parent == current) return null;

      current = parent;
    }
  }

  /// `GetDiskFreeSpaceExW`: bytes available to the caller, quotas included
  static int? _windowsAvailableBytes(String folder) {
    final function = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          ),
          int Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          )
        >('GetDiskFreeSpaceExW');

    /// A folder path must end with a separator
    final name = (folder.endsWith(r'\') ? folder : '$folder\\').toNativeUtf16();
    final available = calloc<Uint64>();

    try {
      return function(name, available, nullptr, nullptr) == 0
          ? null
          : available.value;
    } finally {
      calloc
        ..free(name)
        ..free(available);
    }
  }

  /// `statvfs` of the C library. Offsets of `struct statvfs` on 64-bit
  /// systems: `f_frsize` is at 8 on both; `f_bavail` is a 64-bit number at 32
  /// on Linux and a 32-bit one at 24 on macOS (Darwin scales `f_frsize`
  /// to keep the block counts in 32 bits)
  static int? _statvfsAvailableBytes(String folder) {
    if (sizeOf<IntPtr>() != 8) return null;

    final function = DynamicLibrary.process()
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Uint8>),
          int Function(Pointer<Utf8>, Pointer<Uint8>)
        >('statvfs');

    final name = folder.toNativeUtf8();

    /// Bigger than the structure on any of the systems
    final buffer = calloc<Uint8>(512);

    try {
      if (function(name, buffer) != 0) return null;

      final data = buffer.asTypedList(512).buffer.asByteData();
      final blockSize = data.getUint64(8, Endian.host);
      final blocks = Platform.isMacOS
          ? data.getUint32(24, Endian.host)
          : data.getUint64(32, Endian.host);

      return blockSize == 0 ? null : blocks * blockSize;
    } finally {
      calloc
        ..free(name)
        ..free(buffer);
    }
  }

  /// `df -Pk`: the available kilobytes stand right before the capacity
  /// percentage; a device name may contain spaces, so the columns are
  /// found by the percentage
  static int? _dfAvailableBytes(String folder) {
    final result = Process.runSync('df', ['-Pk', folder]);

    if (result.exitCode != 0) return null;

    final lines = '${result.stdout}'.trim().split('\n');

    if (lines.length < 2) return null;

    final columns = lines.last.trim().split(RegExp(r'\s+'));
    final capacity = columns.indexWhere(
      (column) => RegExp(r'^\d+%$').hasMatch(column),
    );
    final kilobytes = capacity > 0 ? int.tryParse(columns[capacity - 1]) : null;

    return kilobytes == null ? null : kilobytes * 1024;
  }
}
