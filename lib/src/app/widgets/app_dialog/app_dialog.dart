import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Dialog window: title, content and action buttons at the bottom right.
///
/// Long content scrolls, the title and buttons stay in place
class AppDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 480,
  });

  /// Shows the dialog over a dimmed screen
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) => showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: context.color.scrim,
    builder: builder,
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.color.dialog,
    surfaceTintColor: context.color.transparent,
    insetPadding: const EdgeInsets.all(24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.color.border),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: context.text.header4Semibold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(child: child),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
