import 'package:flutter/material.dart';

/// Pressable area with hover and keyboard focus, without the Material ripple
class AppPressable extends StatefulWidget {
  /// [highlighted]: the cursor is over the area or it has focus
  final Widget Function(BuildContext context, bool highlighted) builder;
  final VoidCallback? onPressed;

  const AppPressable({super.key, required this.builder, this.onPressed});

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();

            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: widget.builder(context, enabled && (_hovered || _focused)),
        ),
      ),
    );
  }
}
