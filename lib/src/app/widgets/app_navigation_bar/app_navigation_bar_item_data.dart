part of 'app_navigation_bar.dart';

/// Navigation bar button
class AppNavigationBarItemData extends Equatable {
  final String title;
  final String svgPictureFilePath;

  /// Number next to the title, e.g. unfinished downloads.
  /// Hidden when `null` or zero
  final int? badge;

  const AppNavigationBarItemData({
    required this.title,
    required this.svgPictureFilePath,
    this.badge,
  });

  @override
  List<Object?> get props => [title, svgPictureFilePath, badge];
}
