part of 'app_navigation_controller.dart';

/// The user was sent to the settings to import cookies
class CookiesImportRequest extends Equatable {
  /// Grows with every request: the settings react to each one
  final int id;

  /// Page that asked for the cookies
  final AppTabModel returnTab;

  const CookiesImportRequest({required this.id, required this.returnTab});

  @override
  List<Object?> get props => [id, returnTab];
}

class AppNavigationState extends Equatable {
  final AppTabModel tab;

  /// Unfinished cookies import; `null` if the settings were opened as usual
  final CookiesImportRequest? cookiesImport;

  const AppNavigationState({this.tab = AppTabModel.home, this.cookiesImport});

  @override
  List<Object?> get props => [tab, cookiesImport];
}

final class AppNavigationInitialState extends AppNavigationState {
  const AppNavigationInitialState();
}
