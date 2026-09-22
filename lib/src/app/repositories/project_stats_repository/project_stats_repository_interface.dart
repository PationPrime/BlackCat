import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

/// PeekyCat on GitHub: stars of the repository and downloads of the latest
/// release
abstract interface class ProjectStatsRepositoryInterface
    implements BaseRepositoryInterface {
  /// The stats, kept for [ProjectConstants.statsLifetime]: GitHub answers few
  /// requests without an account. [refresh]: ask GitHub anyway.
  /// What GitHub did not tell stays `null`; fails when it told nothing
  Future<OperationResult<ProjectStatsModel>> getStats({bool refresh = false});
}
