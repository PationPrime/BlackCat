part of 'dependency_model.dart';

enum DependencyInstallStage {
  downloading,

  /// Comparing the file with the published SHA-256
  verifying,

  /// Taking the program out of the archive
  extracting,

  done;

  bool get isDone => this == done;
}

/// Installation step of one program
class DependencyInstallProgressModel extends Equatable {
  final DependencyKind kind;
  final DependencyInstallStage stage;
  final int receivedBytes;

  /// `null` while the size is unknown
  final int? totalBytes;

  const DependencyInstallProgressModel({
    required this.kind,
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes,
  });

  /// From 0 to 1; `null` for a step without a known size
  double? get fraction => switch (totalBytes) {
    final total?
        when total > 0 && stage == DependencyInstallStage.downloading =>
      (receivedBytes / total).clamp(0, 1).toDouble(),
    _ => null,
  };

  @override
  List<Object?> get props => [kind, stage, receivedBytes, totalBytes];
}
