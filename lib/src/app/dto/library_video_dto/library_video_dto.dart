import 'package:flutter/foundation.dart';

import '../../models/models.dart';

/// A player library video as it is stored in the database
@immutable
class LibraryVideoDto {
  final String id;
  final String path;
  final String title;
  final int sizeBytes;
  final DateTime modifiedAt;
  final int? durationMs;
  final int positionMs;
  final String? thumbnailPath;
  final bool isMetadataLoaded;
  final DateTime? watchedAt;

  const LibraryVideoDto({
    required this.id,
    required this.path,
    required this.title,
    required this.sizeBytes,
    required this.modifiedAt,
    this.durationMs,
    this.positionMs = 0,
    this.thumbnailPath,
    this.isMetadataLoaded = false,
    this.watchedAt,
  });

  factory LibraryVideoDto.fromModel(LibraryVideoModel video) => LibraryVideoDto(
    id: video.id,
    path: video.path,
    title: video.title,
    sizeBytes: video.sizeBytes,
    modifiedAt: video.modifiedAt,
    durationMs: video.duration?.inMilliseconds,
    positionMs: video.position.inMilliseconds,
    thumbnailPath: video.thumbnailPath,
    isMetadataLoaded: video.isMetadataLoaded,
    watchedAt: video.watchedAt,
  );

  LibraryVideoModel toModel() => LibraryVideoModel(
    id: id,
    path: path,
    title: title,
    sizeBytes: sizeBytes,
    modifiedAt: modifiedAt,
    duration: durationMs == null ? null : Duration(milliseconds: durationMs!),
    position: Duration(milliseconds: positionMs),
    thumbnailPath: thumbnailPath,
    isMetadataLoaded: isMetadataLoaded,
    watchedAt: watchedAt,
  );
}
