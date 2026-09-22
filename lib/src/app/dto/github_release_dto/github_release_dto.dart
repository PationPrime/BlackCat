import 'package:equatable/equatable.dart';

/// A file of a GitHub release
class GitHubReleaseAssetDto extends Equatable {
  final String name;

  /// How many times the file was downloaded
  final int downloadCount;

  const GitHubReleaseAssetDto({
    required this.name,
    required this.downloadCount,
  });

  factory GitHubReleaseAssetDto.fromJson(Map<String, dynamic> json) =>
      GitHubReleaseAssetDto(
        name: '${json['name'] ?? ''}',
        downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [name, downloadCount];
}

/// A published GitHub release: its tag and files
class GitHubReleaseDto extends Equatable {
  /// `v0.1.0`
  final String tag;
  final List<GitHubReleaseAssetDto> assets;

  const GitHubReleaseDto({required this.tag, required this.assets});

  factory GitHubReleaseDto.fromJson(Map<String, dynamic> json) =>
      GitHubReleaseDto(
        tag: '${json['tag_name'] ?? json['name'] ?? ''}',
        assets: [
          for (final asset
              in (json['assets'] as List? ?? const []).whereType<Map>())
            GitHubReleaseAssetDto.fromJson(asset.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [tag, assets];
}
