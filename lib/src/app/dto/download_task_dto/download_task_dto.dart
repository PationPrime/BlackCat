import 'package:flutter/foundation.dart';

import '../../models/models.dart';

part 'download_stream_dto.dart';

/// A download as it is stored in the queue database
@immutable
class DownloadTaskDto {
  final String id;
  final String videoId;
  final String videoUrl;
  final String title;
  final String? channel;
  final double? durationSeconds;
  final String? thumbnail;
  final int? viewCount;

  final String qualityId;
  final QualityKind qualityKind;
  final String qualityLabel;
  final int? qualityResolution;
  final int? qualitySize;
  final bool qualityIsAac;

  final DownloadTaskStatus status;
  final DownloadTaskSection section;
  final int position;
  final int downloadedBytes;
  final int? totalBytes;

  final String? filePath;
  final int? fileSizeBytes;
  final String? thumbnailPath;
  final DateTime? completedAt;
  final String? failureMessage;
  final bool failureNeedsSignIn;

  final DateTime createdAt;
  final DateTime updatedAt;

  final List<DownloadStreamDto> streams;

  const DownloadTaskDto({
    required this.id,
    required this.videoId,
    required this.videoUrl,
    required this.title,
    required this.qualityId,
    required this.qualityKind,
    required this.status,
    required this.section,
    required this.createdAt,
    required this.updatedAt,
    this.channel,
    this.durationSeconds,
    this.thumbnail,
    this.viewCount,
    this.qualityLabel = '',
    this.qualityResolution,
    this.qualitySize,
    this.qualityIsAac = false,
    this.position = 0,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.filePath,
    this.fileSizeBytes,
    this.thumbnailPath,
    this.completedAt,
    this.failureMessage,
    this.failureNeedsSignIn = false,
    this.streams = const [],
  });

  factory DownloadTaskDto.fromModel(DownloadTaskModel task) => DownloadTaskDto(
    id: task.id,
    videoId: task.video.id,
    videoUrl: task.video.url,
    title: task.video.title,
    channel: task.video.channel,
    durationSeconds: task.video.duration?.toDouble(),
    thumbnail: task.video.thumbnail,
    viewCount: task.video.viewCount,
    qualityId: task.quality.id,
    qualityKind: task.quality.kind,
    qualityLabel: task.quality.label,
    qualityResolution: task.quality.resolution,
    qualitySize: task.quality.size,
    qualityIsAac: task.quality.isAac,
    status: task.status,
    section: task.section,
    position: task.position,
    downloadedBytes: task.downloadedBytes,
    totalBytes: task.totalBytes,
    filePath: task.filePath,
    fileSizeBytes: task.fileSizeBytes,
    thumbnailPath: task.thumbnailPath,
    completedAt: task.completedAt,
    failureMessage: task.failureMessage,
    failureNeedsSignIn: task.failureNeedsSignIn,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    streams: [
      for (final stream in task.streams) DownloadStreamDto.fromModel(stream),
    ],
  );

  DownloadTaskModel toModel() => DownloadTaskModel(
    id: id,
    video: VideoInfoModel(
      id: videoId,
      title: title,
      url: videoUrl,
      qualities: const [],
      channel: channel,
      duration: durationSeconds,
      thumbnail: thumbnail,
      viewCount: viewCount,
    ),
    quality: QualityModel(
      id: qualityId,
      kind: qualityKind,
      label: qualityLabel,
      resolution: qualityResolution,
      size: qualitySize,
      isAac: qualityIsAac,
    ),
    status: status,
    section: section,
    position: position,
    streams: [for (final stream in streams) stream.toModel()],
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    filePath: filePath,
    fileSizeBytes: fileSizeBytes,
    thumbnailPath: thumbnailPath,
    completedAt: completedAt,
    failureMessage: failureMessage,
    failureNeedsSignIn: failureNeedsSignIn,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
