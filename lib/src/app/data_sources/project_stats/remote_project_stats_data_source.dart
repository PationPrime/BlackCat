import 'package:dio/dio.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../dto/dto.dart';

/// PeekyCat on GitHub: the repository and its latest release
abstract interface class RemoteProjectStatsDataSource {
  /// Stars of the repository
  Future<int> getStars();

  /// The latest published release, without drafts and pre-releases.
  /// `null` when the repository has no release yet
  Future<GitHubReleaseDto?> getLatestRelease();
}

final class RemoteProjectStatsDataSourceImpl
    implements RemoteProjectStatsDataSource {
  static final _options = Options(
    responseType: ResponseType.json,
    headers: const {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  );

  final ApiProvider _apiProvider;

  /// The repository in the GitHub API: another server in tests
  final String _repositoryApiUrl;

  const RemoteProjectStatsDataSourceImpl({
    required this._apiProvider,
    this._repositoryApiUrl = ProjectConstants.repositoryApiUrl,
  });

  @override
  Future<int> getStars() async {
    final response = await _apiProvider.github.dio.get<Map<String, dynamic>>(
      _repositoryApiUrl,
      options: _options,
    );

    return (response.data?['stargazers_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<GitHubReleaseDto?> getLatestRelease() async {
    try {
      final response = await _apiProvider.github.dio.get<Map<String, dynamic>>(
        '$_repositoryApiUrl/releases/latest',
        options: _options,
      );

      return switch (response.data) {
        final json? => GitHubReleaseDto.fromJson(json),
        null => null,
      };
    } on DioException catch (error) {
      /// A repository without a release has no latest one
      if (error.response?.statusCode == 404) return null;

      rethrow;
    }
  }
}
