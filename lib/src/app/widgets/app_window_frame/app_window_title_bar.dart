part of 'app_window_frame.dart';

/// App title bar: dragging moves the window, a double click maximizes it
class _AppWindowTitleBar extends StatelessWidget {
  final AppWindowFrameModel frame;
  final bool isMaximized;
  final VoidCallback? onMinimizePressed;
  final VoidCallback? onToggleMaximizePressed;
  final VoidCallback? onClosePressed;
  final VoidCallback? onDragStarted;

  const _AppWindowTitleBar({
    required this.frame,
    required this.isMaximized,
    this.onMinimizePressed,
    this.onToggleMaximizePressed,
    this.onClosePressed,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppWindowFrame.titleBarHeight,
    child: Row(
      children: [
        SizedBox(width: frame.leadingInset),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onDragStarted?.call(),
            onDoubleTap: onToggleMaximizePressed,
          ),
        ),
        if (frame.showsWindowButtons) ...[
          _AppWindowButton(
            glyph: _AppWindowGlyph.minimize,
            semanticLabel: LocaleKeys.app_window_minimize.tr(),
            onPressed: onMinimizePressed,
          ),
          _AppWindowButton(
            glyph: isMaximized
                ? _AppWindowGlyph.restore
                : _AppWindowGlyph.maximize,
            semanticLabel: isMaximized
                ? LocaleKeys.app_window_restore.tr()
                : LocaleKeys.app_window_maximize.tr(),
            onPressed: onToggleMaximizePressed,
          ),
          _AppWindowButton(
            glyph: _AppWindowGlyph.close,
            semanticLabel: LocaleKeys.app_window_close.tr(),
            onPressed: onClosePressed,
          ),
        ],
      ],
    ),
  );
}
