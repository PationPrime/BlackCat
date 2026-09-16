part of 'app_navigation_bar.dart';

/// Navigation bar button
class AppNavigationBarItemData extends Equatable {
  final String title;
  final IconData icon;

  /// Number next to the title, e.g. unfinished downloads.
  /// Hidden when `null` or zero
  final int? badge;

  const AppNavigationBarItemData({
    required this.title,
    required this.icon,
    this.badge,
  });

  @override
  List<Object?> get props => [title, icon, badge];
}
