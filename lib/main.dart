import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'src/app/design_system/design_system.dart';
import 'src/app/module/module.dart';
import 'src/app/widgets/widgets.dart';

Future<void> main(List<String> args) async {
  /// Sign-in window title bar: a separate Flutter engine launched with these arguments
  if (runWebViewTitleBarWidget(
    args,
    backgroundColor: AppThemeColors.dark.surface,
    builder: AppSignInTitleBar.builder,
  )) {
    return;
  }

  await AppModule.instance.initApp(args);
}
