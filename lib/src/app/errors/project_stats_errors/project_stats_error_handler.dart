part of 'project_stats_errors.dart';

/// Errors of the GitHub stats: the page shows no numbers instead of them
class ProjectStatsErrorHandler extends ErrorHandler<ProjectStatsErrorCodes> {
  const ProjectStatsErrorHandler({
    super.errorCodes = const ProjectStatsErrorCodes(),
  });

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {};
}
