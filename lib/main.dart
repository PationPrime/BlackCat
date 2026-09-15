import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'src/app/design_system/design_system.dart';
import 'src/app/module/module.dart';
import 'src/app/widgets/widgets.dart';

Future<void> main(List<String> args) async {
  /// Заголовок окна входа — отдельный движок Flutter, запущенный с этими аргументами
  if (runWebViewTitleBarWidget(
    args,
    backgroundColor: AppThemeColors.dark.surface,
    builder: AppSignInTitleBar.builder,
  )) {
    return;
  }

  await AppModule.instance.initApp(args);
}
