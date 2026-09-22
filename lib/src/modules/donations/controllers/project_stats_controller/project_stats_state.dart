part of 'project_stats_controller.dart';

enum ProjectStatsStatus {
  initial,
  loading,
  loaded,

  /// GitHub told nothing: the page shows no numbers
  failed;

  bool get isLoading => this == loading;
}

class ProjectStatsState extends Equatable {
  final ProjectStatsStatus status;
  final ProjectStatsModel? stats;

  const ProjectStatsState({
    this.status = ProjectStatsStatus.initial,
    this.stats,
  });

  ProjectStatsState copyWith({
    ProjectStatsStatus? status,
    ProjectStatsModel? stats,
  }) => ProjectStatsState(
    status: status ?? this.status,
    stats: stats ?? this.stats,
  );

  @override
  List<Object?> get props => [status, stats];
}
