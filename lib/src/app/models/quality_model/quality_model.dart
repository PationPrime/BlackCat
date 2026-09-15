import 'package:equatable/equatable.dart';

enum QualityKind { video, audio }

extension QualityKindX on QualityKind {
  bool get isVideo => this == QualityKind.video;
  bool get isAudio => this == QualityKind.audio;
}

/// Вариант качества для скачивания: разрешение видео или только звук
class QualityModel extends Equatable {
  static const audioId = 'audio';

  /// `1080`, `720`… или [audioId]
  final String id;
  final QualityKind kind;

  /// Подпись разрешения, например `1080p60`. Для звука пустая
  final String label;
  final int? resolution;

  /// Примерный размер файла в байтах
  final int? size;

  /// Звук в AAC: сохраняется как M4A
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
