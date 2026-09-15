import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Sign-in window title bar. Runs in a separate Flutter engine, so it sets
/// the theme itself. Shows the address: the password is entered on accounts.google.com
class AppSignInTitleBar extends StatelessWidget {
  const AppSignInTitleBar({super.key});

  /// For [runWebViewTitleBarWidget]
  static Widget builder(BuildContext context) => const AppSignInTitleBar();

  @override
  Widget build(BuildContext context) => Theme(
    data: AppThemeData.darkTheme,
    child: Builder(builder: _buildBar),
  );

  Widget _buildBar(BuildContext context) {
    final state = TitleBarWebViewState.of(context);
    final controller = TitleBarWebViewController.of(context);
    final address = Uri.tryParse(state.url ?? '');

    Widget icon(IconData data, VoidCallback? onPressed) => IconButton(
      padding: EdgeInsets.zero,
      iconSize: 16,
      color: context.color.iconPrimary,
      disabledColor: context.color.iconDisabled,
      onPressed: onPressed,
      icon: Icon(data),
    );

    return ColoredBox(
      color: context.color.surface,
      child: Row(
        children: [
          icon(Icons.arrow_back, state.canGoBack ? controller.back : null),
          icon(
            Icons.arrow_forward,
            state.canGoForward ? controller.forward : null,
          ),
          state.isLoading
              ? icon(Icons.close, controller.stop)
              : icon(Icons.refresh, controller.reload),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address == null
                  ? ''
                  : '${address.scheme}://${address.host}${address.path}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.footnoteRegular,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
