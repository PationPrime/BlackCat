import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/byte_ranges.dart';
import 'download_state_snapshot.dart';

/// A file of a download as its state remembers it
final class StateFileEntry {
  final String identity;

  /// `null` when the server did not report the size
  final int? length;
  final bool acceptsRanges;
  final String? validator;

  const StateFileEntry({
    required this.identity,
    required this.length,
    required this.acceptsRanges,
    this.validator,
  });

  /// A file of an unknown size has one open slice: its counter only shows
  /// progress, such a file is always downloaded from the start
  int sliceCountFor(int sliceSize) {
    final length = this.length;

    return length == null
        ? 1
        : SliceLayout(fileLength: length, sliceSize: sliceSize).sliceCount;
  }

  bool matches(StateFileEntry other, {required bool checkValidator}) =>
      identity == other.identity &&
      length == other.length &&
      acceptsRanges == other.acceptsRanges &&
      (!checkValidator || validator == other.validator);
}

/// `state_<id>.fds`: progress of every slice of every file of a download.
///
/// Little-endian layout:
/// ```text
/// 0   8   magic "FDSSTATE"
/// 8   4   version
/// 12  4   file count
/// 16  8   slice size
/// 24  8   offset of the slice counters
/// 32  4   FNV-1a checksum of everything before the counters,
///         with this field zeroed
/// 36  4   reserved
/// 40  ... files: length (int64, -1 unknown), slice count (uint32),
///         flags (uint32: 1 ranges, 2 validator), identity and validator
///         lengths (uint16 each), identity and validator in UTF-8
/// ... the counters, aligned to 8: downloaded bytes of each slice (int64),
///         the slices of every file in a row
/// ```
///
/// The header is written once; a counter is rewritten in place, so
/// a checkpoint costs a few bytes. A slice is always downloaded from its
/// start, so its counter is also its contiguous downloaded length.
/// Not safe for concurrent writers: one download owns the file
final class DownloadStateFile {
  static const magic = 'FDSSTATE';
  static const version = 1;

  static const _fixedHeaderLength = 40;
  static const _checksumOffset = 32;
  static const _flagRanges = 1;
  static const _flagValidator = 2;

  static final _unsafeIdCharacters = RegExp(r'[^A-Za-z0-9._-]');

  final String path;
  final int sliceSize;
  final List<StateFileEntry> entries;

  final List<int> _firstCounters;
  final Int64List _counters;
  final int _countersOffset;
  final _dirty = <int>{};

  RandomAccessFile? _file;

  DownloadStateFile._({
    required this.path,
    required this.sliceSize,
    required this.entries,
    required this._counters,
    required this._countersOffset,
  }) : _firstCounters = _firstCountersOf(entries, sliceSize);

  /// `state_<id>.fds`; characters unsafe in file names become `_`
  static String fileName(String id) =>
      'state_${id.replaceAll(_unsafeIdCharacters, '_')}.fds';

  static List<int> _firstCountersOf(
    List<StateFileEntry> entries,
    int sliceSize,
  ) {
    var next = 0;

    return [
      for (final entry in entries)
        () {
          final first = next;

          next += entry.sliceCountFor(sliceSize);

          return first;
        }(),
    ];
  }

  /// Creates the file anew. [counters] are the downloaded bytes of each slice
  /// of each file; missing ones are zero
  static DownloadStateFile createSync(
    String path, {
    required int sliceSize,
    required List<StateFileEntry> entries,
    List<List<int>>? counters,
  }) {
    final header = BytesBuilder();
    final fixed = ByteData(_fixedHeaderLength);

    fixed.buffer.asUint8List().setAll(0, ascii.encode(magic));
    fixed
      ..setUint32(8, version, Endian.little)
      ..setUint32(12, entries.length, Endian.little)
      ..setInt64(16, sliceSize, Endian.little);
    header.add(fixed.buffer.asUint8List());

    for (final entry in entries) {
      final identity = utf8.encode(entry.identity);
      final validator = utf8.encode(entry.validator ?? '');
      final fields = ByteData(20)
        ..setInt64(0, entry.length ?? -1, Endian.little)
        ..setUint32(8, entry.sliceCountFor(sliceSize), Endian.little)
        ..setUint32(
          12,
          (entry.acceptsRanges ? _flagRanges : 0) |
              (entry.validator == null ? 0 : _flagValidator),
          Endian.little,
        )
        ..setUint16(16, identity.length, Endian.little)
        ..setUint16(18, validator.length, Endian.little);

      header
        ..add(fields.buffer.asUint8List())
        ..add(identity)
        ..add(validator);
    }

    final countersOffset = (header.length + 7) & ~7;

    header.add(Uint8List(countersOffset - header.length));

    final bytes = header.takeBytes();

    ByteData.sublistView(bytes)
      ..setInt64(24, countersOffset, Endian.little)
      ..setUint32(_checksumOffset, _checksum(bytes), Endian.little);

    final state = DownloadStateFile._(
      path: path,
      sliceSize: sliceSize,
      entries: List.unmodifiable(entries),
      counters: Int64List(
        entries.fold<int>(
          0,
          (sum, entry) => sum + entry.sliceCountFor(sliceSize),
        ),
      ),
      countersOffset: countersOffset,
    );

    for (var file = 0; file < entries.length; file++) {
      final initial = counters == null || file >= counters.length
          ? const <int>[]
          : counters[file];

      for (var slice = 0; slice < initial.length; slice++) {
        state._counters[state._index(file, slice)] = state._clamp(
          file,
          slice,
          initial[slice],
        );
      }
    }

    File(path).parent.createSync(recursive: true);
    File(path).writeAsBytesSync([
      ...bytes,
      ...state._counters.buffer.asUint8List(),
    ], flush: true);

    return state;
  }

  /// `null` when the file is missing, is not a state or is damaged
  static DownloadStateFile? readSync(String path) {
    try {
      final file = File(path);

      return file.existsSync() ? parse(file.readAsBytesSync(), path) : null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<DownloadStateFile?> read(String path) async {
    try {
      final file = File(path);

      return await file.exists() ? parse(await file.readAsBytes(), path) : null;
    } on FileSystemException {
      return null;
    }
  }

  /// `null` for bytes that are not a whole, undamaged state
  static DownloadStateFile? parse(Uint8List bytes, String path) {
    if (bytes.length < _fixedHeaderLength ||
        ascii.decode(bytes.sublist(0, 8), allowInvalid: true) != magic) {
      return null;
    }

    final data = ByteData.sublistView(bytes);

    if (data.getUint32(8, Endian.little) != version) return null;

    final fileCount = data.getUint32(12, Endian.little);
    final sliceSize = data.getInt64(16, Endian.little);
    final countersOffset = data.getInt64(24, Endian.little);

    if (sliceSize <= 0 ||
        countersOffset < _fixedHeaderLength ||
        countersOffset > bytes.length ||
        data.getUint32(_checksumOffset, Endian.little) !=
            _checksum(bytes.sublist(0, countersOffset))) {
      return null;
    }

    final entries = <StateFileEntry>[];
    var offset = _fixedHeaderLength;

    try {
      for (var index = 0; index < fileCount; index++) {
        final length = data.getInt64(offset, Endian.little);
        final sliceCount = data.getUint32(offset + 8, Endian.little);
        final flags = data.getUint32(offset + 12, Endian.little);
        final identityLength = data.getUint16(offset + 16, Endian.little);
        final validatorLength = data.getUint16(offset + 18, Endian.little);

        offset += 20;

        final identity = utf8.decode(
          bytes.sublist(offset, offset + identityLength),
        );

        offset += identityLength;

        final validator = utf8.decode(
          bytes.sublist(offset, offset + validatorLength),
        );

        offset += validatorLength;

        final entry = StateFileEntry(
          identity: identity,
          length: length < 0 ? null : length,
          acceptsRanges: flags & _flagRanges != 0,
          validator: flags & _flagValidator != 0 ? validator : null,
        );

        if (entry.sliceCountFor(sliceSize) != sliceCount) return null;

        entries.add(entry);
      }
    } on RangeError {
      return null;
    } on FormatException {
      return null;
    }

    if (offset > countersOffset) return null;

    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.sliceCountFor(sliceSize),
    );

    if (bytes.length < countersOffset + total * 8) return null;

    final counters = Int64List(total);
    final stored = ByteData.sublistView(bytes, countersOffset);

    for (var index = 0; index < total; index++) {
      counters[index] = stored.getInt64(index * 8, Endian.little);
    }

    final state = DownloadStateFile._(
      path: path,
      sliceSize: sliceSize,
      entries: List.unmodifiable(entries),
      counters: counters,
      countersOffset: countersOffset,
    );

    /// A counter damaged by a torn write never claims bytes outside its slice
    for (var file = 0; file < entries.length; file++) {
      for (var slice = 0; slice < state.sliceCount(file); slice++) {
        final index = state._index(file, slice);

        counters[index] = state._clamp(file, slice, counters[index]);
      }
    }

    return state;
  }

  /// FNV-1a over [bytes] with the checksum field taken as zero
  static int _checksum(Uint8List bytes) {
    var hash = 0x811c9dc5;

    for (var index = 0; index < bytes.length; index++) {
      final byte = index >= _checksumOffset && index < _checksumOffset + 4
          ? 0
          : bytes[index];

      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }

    return hash;
  }

  int sliceCount(int file) => entries[file].sliceCountFor(sliceSize);

  /// The range of a slice; `null` for the open slice of a file
  /// of an unknown size
  ByteRange? sliceRange(int file, int slice) {
    final length = entries[file].length;

    return length == null
        ? null
        : SliceLayout(fileLength: length, sliceSize: sliceSize).slice(slice);
  }

  int _index(int file, int slice) {
    RangeError.checkValidIndex(slice, null, 'slice', sliceCount(file));

    return _firstCounters[file] + slice;
  }

  int _clamp(int file, int slice, int value) => value.clamp(
    0,
    sliceRange(file, slice)?.length ?? math.pow(2, 53).toInt(),
  );

  /// Downloaded bytes of a slice, counted from its start
  int counter(int file, int slice) => _counters[_index(file, slice)];

  List<int> counters(int file) => [
    for (var slice = 0; slice < sliceCount(file); slice++) counter(file, slice),
  ];

  bool isSliceComplete(int file, int slice) {
    final range = sliceRange(file, slice);

    return range != null && counter(file, slice) >= range.length;
  }

  int downloadedBytes(int file) => counters(file).fold(0, (a, b) => a + b);

  /// Kept in memory until [flushSync]
  void setCounter(int file, int slice, int value) {
    final index = _index(file, slice);
    final clamped = _clamp(file, slice, value);

    if (_counters[index] == clamped) return;

    _counters[index] = clamped;
    _dirty.add(index);
  }

  void resetFile(int file) {
    for (var slice = 0; slice < sliceCount(file); slice++) {
      setCounter(file, slice, 0);
    }
  }

  /// Writes the changed counters and flushes them to disk
  void flushSync() {
    if (_dirty.isEmpty) return;

    final file = _file ??= File(path).openSync(mode: FileMode.append);
    final value = ByteData(8);

    for (final index in _dirty) {
      value.setInt64(0, _counters[index], Endian.little);
      file
        ..setPositionSync(_countersOffset + index * 8)
        ..writeFromSync(value.buffer.asUint8List());
    }

    _dirty.clear();
    file.flushSync();
  }

  /// The file is closed even when the last counters could not be written
  void closeSync() {
    try {
      flushSync();
    } finally {
      _file?.closeSync();
      _file = null;
    }
  }

  void deleteSync() {
    _dirty.clear();
    _file?.closeSync();
    _file = null;

    final file = File(path);

    if (file.existsSync()) file.deleteSync();
  }

  DownloadStateSnapshot snapshot() => DownloadStateSnapshot(
    sliceSize: sliceSize,
    files: [
      for (var file = 0; file < entries.length; file++)
        FileStateSnapshot(
          identity: entries[file].identity,
          length: entries[file].length,
          acceptsRanges: entries[file].acceptsRanges,
          validator: entries[file].validator,
          sliceCounters: List.unmodifiable(counters(file)),
          sliceSize: sliceSize,
        ),
    ],
  );
}
