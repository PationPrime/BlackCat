import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_theme_config.dart';

part 'app_theme_state.dart';
part 'app_theme_constants.dart';

class AppThemeController extends Cubit<AppThemeState> {
  AppThemeController({
    AppThemeType initialThemeType = AppThemeControllerConstants._darkThemeType,
  }) : super(AppThemeInitialState(themeType: initialThemeType));

  void toggleDarkOrLightTheme() {
    emit(
      state.copyWith(
        themeType: state.themeType.isDark
            ? AppThemeControllerConstants._lightThemeType
            : AppThemeControllerConstants._darkThemeType,
      ),
    );
  }

  void setThemeType(AppThemeType themeType) {
    emit(state.copyWith(themeType: themeType));
  }
}
