import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/models.dart';

part 'app_navigation_state.dart';

/// Page of the navigation bar. Any part of the app switches pages through it,
/// the home stack follows it
final class AppNavigationController extends Cubit<AppNavigationState> {
  var _requestCounter = 0;

  AppNavigationController() : super(const AppNavigationInitialState());

  void _safeEmit(AppNavigationState state) {
    if (isClosed) return;

    emit(state);
  }

  /// Opens [tab]. Leaving the settings drops an unfinished cookies import
  void selectTab(AppTabModel tab) {
    if (tab == state.tab) return;

    _safeEmit(AppNavigationState(tab: tab));
  }

  /// Opens the settings at the cookies import. Once cookies are imported,
  /// [returnTab] opens again
  void openCookiesImport({required AppTabModel returnTab}) {
    _safeEmit(
      AppNavigationState(
        tab: AppTabModel.settings,
        cookiesImport: CookiesImportRequest(
          id: ++_requestCounter,
          returnTab: returnTab,
        ),
      ),
    );
  }

  /// Cookies are imported: back to the page that asked for them
  void finishCookiesImport() {
    final request = state.cookiesImport;

    if (request == null) return;

    _safeEmit(AppNavigationState(tab: request.returnTab));
  }
}
