import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../../models/models.dart';
import '../app_buttons/app_buttons.dart';

part 'app_window_button.dart';
part 'app_window_resize_handle.dart';
part 'app_window_title_bar.dart';

/// Window frame drawn by the app instead of the system one: a title bar over
/// the screens and resize strips at the edges the platform does not resize.
///
/// Screens get the title bar height as the top [MediaQueryData.padding],
/// so their content starts below the buttons. With the system frame
/// the child is shown as is
class AppWindowFrame extends StatelessWidget {
  static const titleBarHeight = 32.0;

  final AppWindowFrameModel frame;
  final bool isMaximized;

  /// A full-screen window shows only the screens
  final bool isFullScreen;
  final Widget child;
  final VoidCallback? onMinimizePressed;
  final VoidCallback? onToggleMaximizePressed;
  final VoidCallback? onClosePressed;
  final VoidCallback? onDragStarted;
  final ValueChanged<AppWindowResizeEdge>? onResizeStarted;

  const AppWindowFrame({
    super.key,
    required this.frame,
    required this.isMaximized,
    required this.child,
    this.isFullScreen = false,
    this.onMinimizePressed,
    this.onToggleMaximizePressed,
    this.onClosePressed,
    this.onDragStarted,
    this.onResizeStarted,
  });

  @override
  Widget build(BuildContext context) {
    if (!frame.isCustom || isFullScreen) return child;

    final mediaQuery = MediaQuery.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(
                top: mediaQuery.padding.top + titleBarHeight,
              ),
            ),
            child: child,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _AppWindowTitleBar(
            frame: frame,
            isMaximized: isMaximized,
            onMinimizePressed: onMinimizePressed,
            onToggleMaximizePressed: onToggleMaximizePressed,
            onClosePressed: onClosePressed,
            onDragStarted: onDragStarted,
          ),
        ),

        /// A maximized window is not resized by its edges
        if (!isMaximized)
          for (final edge in frame.resizeEdges)
            _AppWindowResizeHandle(edge: edge, onResizeStarted: onResizeStarted),
      ],
    );
  }
}
