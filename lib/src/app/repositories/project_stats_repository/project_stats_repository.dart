import '../../constants/constants.dart';
import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../tools/tools.dart';
import 'project_stats_repository_interface.dart';

final class ProjectStatsRepository implements ProjectStatsRepositoryInterface {
  final RemoteProjectStatsDataSource _remoteProjectStatsDataSource;
  final DateTime Function() _now;

  ProjectStatsModel? _stats;
  DateTime? _loadedAt;

  ProjectStatsRepository({
    required this._remoteProjectStatsDataSource,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  ErrorHandler<ProjectStatsErrorCodes> get errorHandler =>
      const ProjectStatsErrorHandler();

  @override
  Future<OperationResult<ProjectStatsModel>> getStats({
    bool refresh = false,
  }) async {
    if (_stats case final stats?
        when !refresh &&
            _now().difference(_loadedAt!) < ProjectConstants.statsLifetime) {
      return ok(stats);
    }

    /// Both requests go at once; one of them may fail alone
    final (stars, release) = await (
      _settle(_remoteProjectStatsDataSource.getStars()),
      _settle(_remoteProjectStatsDataSource.getLatestRelease()),
    ).wait;

    if (stars.error != null && release.error != null) {
      return fail(
        errorHandler.handleError(stars.error!, stackTrace: stars.stackTrace),
      );
    }

    final stats = ProjectStatsModel(
      stars: stars.value,
      version: release.value?.tag,
      downloads: _downloadsOf(release.value),
    );

    /// A partial answer is asked again next time
    if (stars.error == null && release.error == null) {
      _stats = stats;
      _loadedAt = _now();
    }

    return ok(stats);
  }

  /// The value or the error of a request, without throwing
  static Future<({T? value, Object? error, StackTrace? stackTrace})> _settle<T>(
    Future<T> request,
  ) async {
    try {
      return (value: await request, error: null, stackTrace: null);
    } catch (error, stackTrace) {
      return (value: null, error: error, stackTrace: stackTrace);
    }
  }

  /// Downloads of the release files, added up for every system
  static Map<ReleasePlatformModel, int> _downloadsOf(
    GitHubReleaseDto? release,
  ) {
    final downloads = <ReleasePlatformModel, int>{};

    for (final asset in release?.assets ?? const <GitHubReleaseAssetDto>[]) {
      if (ReleaseAssetPlatform.of(asset.name) case final platform?) {
        downloads[platform] = (downloads[platform] ?? 0) + asset.downloadCount;
      }
    }

    return downloads;
  }
}
