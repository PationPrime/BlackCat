import 'package:equatable/equatable.dart';

/// A desktop system BlackCat is released for
enum ReleasePlatformModel { macos, windows, linux }

/// BlackCat on GitHub: stars of the repository and downloads of the latest
/// release
class ProjectStatsModel extends Equatable {
  /// `null` when GitHub did not tell them
  final int? stars;

  /// Tag of the latest release: `v0.1.0`. `null` without a release or when
  /// GitHub did not tell it
  final String? version;

  /// Downloads of the latest release files, by the system they are for
  final Map<ReleasePlatformModel, int> downloads;

  const ProjectStatsModel({
    this.stars,
    this.version,
    this.downloads = const {},
  });

  /// Downloads of the latest release for [platform]: 0 when the release has
  /// no file for it, `null` without a release
  int? downloadsOf(ReleasePlatformModel platform) =>
      version == null ? null : downloads[platform] ?? 0;

  @override
  List<Object?> get props => [stars, version, downloads];
}
