import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/logger/app_logger.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';

part 'project_stats_state.dart';

/// Stars of BlackCat on GitHub and downloads of its latest release, for the
/// support page
final class ProjectStatsController extends Cubit<ProjectStatsState> {
  static const _appLogger = AppLogger(where: 'ProjectStatsController');

  final ProjectStatsRepositoryInterface _projectStatsRepository;

  ProjectStatsController({required this._projectStatsRepository})
    : super(const ProjectStatsState());

  void _safeEmit(ProjectStatsState state) {
    if (isClosed) return;

    emit(state);
  }

  /// The numbers of the last load stay while new ones are loading
  Future<void> load({bool refresh = false}) async {
    if (state.status.isLoading) return;

    _safeEmit(state.copyWith(status: ProjectStatsStatus.loading));

    final statsResponse = await _projectStatsRepository.getStats(
      refresh: refresh,
    );

    if (statsResponse.isFailed) {
      _appLogger.logFailure(
        statsResponse.failure!,
        'Failed to load the GitHub stats',
      );
      _safeEmit(state.copyWith(status: ProjectStatsStatus.failed));

      return;
    }

    _safeEmit(
      state.copyWith(
        status: ProjectStatsStatus.loaded,
        stats: statsResponse.requireData,
      ),
    );
  }
}
