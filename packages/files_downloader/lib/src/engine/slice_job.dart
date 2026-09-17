import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/byte_ranges.dart';
import '../models/download_request.dart';
import '../models/remote_file_info.dart';

/// A slice being downloaded: always from its start to its end, so the bytes
/// written so far are its contiguous prefix
final class SliceJob {
  final int file;
  final int slice;
  final DownloadFileRequest request;
  final RemoteFileInfo info;

  /// `null` for a file that is downloaded as a whole in one request
  final ByteRange? range;

  /// Bytes written from the slice start
  int downloaded;

  /// [downloaded] as of the last flush to disk: only these are saved
  /// in the state
  int durable;

  RandomAccessFile? output;
  CancelToken? cancelToken;
  bool finished = false;

  SliceJob({
    required this.file,
    required this.slice,
    required this.request,
    required this.info,
    required this.range,
    this.downloaded = 0,
  }) : durable = downloaded;

  /// The file gives parts: a broken request continues where it stopped
  bool get isResumable => range != null;

  bool get isComplete =>
      finished || (range != null && downloaded >= range!.length);

  /// Offset in the file of the next byte to write
  int get position => (range?.start ?? 0) + downloaded;

  void write(Uint8List bytes) {
    output!.writeFromSync(bytes);
    downloaded += bytes.length;
  }

  /// Everything written so far is on disk
  void flush() {
    final output = this.output;

    if (output == null || durable == downloaded) return;

    output.flushSync();
    durable = downloaded;
  }

  /// A file without parts starts over after a broken request
  void restart() {
    downloaded = 0;
    durable = 0;
    output
      ?..truncateSync(0)
      ..setPositionSync(0);
  }

  void close() {
    flush();
    output?.closeSync();
    output = null;
  }

  @override
  String toString() =>
      'SliceJob(${request.savePath}#$slice $range, $downloaded)';
}

/// How to read a response body into a slice
final class BodyPlan {
  /// Bytes of the body before the slice position
  final int skip;

  /// Bytes to write; `null` for the whole body of a file of an unknown size
  final int? take;

  /// Last byte the server promised to send: a body ending there is a short
  /// but valid part, not a broken connection
  final int? lastPromisedByte;

  const BodyPlan({
    required this.skip,
    required this.take,
    this.lastPromisedByte,
  });

  @override
  String toString() =>
      'BodyPlan(skip $skip, take $take, last $lastPromisedByte)';
}
