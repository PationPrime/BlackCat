import 'package:equatable/equatable.dart';

enum QualityKind { video, audio }

extension QualityKindX on QualityKind {
  bool get isVideo => this == QualityKind.video;
  bool get isAudio => this == QualityKind.audio;
}

/// Quality option to download: video resolution or audio only
class QualityModel extends Equatable {
  static const audioId = 'audio';

  /// `1080`, `720`… or [audioId]
  final String id;
  final QualityKind kind;

  /// Resolution label, e.g. `1080p60`. Empty for audio
  final String label;
  final int? resolution;

  /// Approximate file size in bytes
  final int? size;

  /// AAC audio: saved as M4A
  final bool isAac;

  const QualityModel({
    required this.id,
    required this.kind,
    this.label = '',
    this.resolution,
    this.size,
    this.isAac = false,
  });

  @override
  List<Object?> get props => [id, kind, label, resolution, size, isAac];
}
