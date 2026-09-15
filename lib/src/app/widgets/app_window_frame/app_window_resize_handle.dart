part of 'app_window_frame.dart';

/// Invisible strip at a window edge: dragging it resizes the window
class _AppWindowResizeHandle extends StatelessWidget {
  static const _thickness = 5.0;
  static const _cornerSize = 12.0;

  final AppWindowResizeEdge edge;
  final ValueChanged<AppWindowResizeEdge>? onResizeStarted;

  const _AppWindowResizeHandle({required this.edge, this.onResizeStarted});

  MouseCursor get _cursor => switch (edge) {
    AppWindowResizeEdge.top ||
    AppWindowResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
    AppWindowResizeEdge.left ||
    AppWindowResizeEdge.right => SystemMouseCursors.resizeLeftRight,
    AppWindowResizeEdge.topLeft ||
    AppWindowResizeEdge.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    AppWindowResizeEdge.topRight ||
    AppWindowResizeEdge.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
  };

  @override
  Widget build(BuildContext context) {
    final handle = MouseRegion(
      cursor: _cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onResizeStarted?.call(edge),
      ),
    );

    return switch (edge) {
      AppWindowResizeEdge.top => Positioned(
        top: 0,
        left: _cornerSize,
        right: _cornerSize,
        height: _thickness,
        child: handle,
      ),
      AppWindowResizeEdge.bottom => Positioned(
        bottom: 0,
        left: _cornerSize,
        right: _cornerSize,
        height: _thickness,
        child: handle,
      ),
      AppWindowResizeEdge.left => Positioned(
        left: 0,
        top: _cornerSize,
        bottom: _cornerSize,
        width: _thickness,
        child: handle,
      ),
      AppWindowResizeEdge.right => Positioned(
        right: 0,
        top: _cornerSize,
        bottom: _cornerSize,
        width: _thickness,
        child: handle,
      ),
      AppWindowResizeEdge.topLeft => Positioned(
        top: 0,
        left: 0,
        width: _cornerSize,
        height: _cornerSize,
        child: handle,
      ),
      AppWindowResizeEdge.topRight => Positioned(
        top: 0,
        right: 0,
        width: _cornerSize,
        height: _cornerSize,
        child: handle,
      ),
      AppWindowResizeEdge.bottomLeft => Positioned(
        bottom: 0,
        left: 0,
        width: _cornerSize,
        height: _cornerSize,
        child: handle,
      ),
      AppWindowResizeEdge.bottomRight => Positioned(
        bottom: 0,
        right: 0,
        width: _cornerSize,
        height: _cornerSize,
        child: handle,
      ),
    };
  }
}
