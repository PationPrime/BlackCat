import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../app_buttons/app_buttons.dart';
import 'app_dialog.dart';

/// Action confirmation. [destructive]: the action is irreversible,
/// the confirm button is highlighted with the error color
class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmTitle;
  final String cancelTitle;
  final bool destructive;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmTitle,
    required this.cancelTitle,
    this.destructive = false,
  });

  /// `true` only if the user confirmed the action
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmTitle,
    required String cancelTitle,
    bool destructive = false,
  }) async =>
      await AppDialog.show<bool>(
        context,
        builder: (context) => AppConfirmationDialog(
          title: title,
          message: message,
          confirmTitle: confirmTitle,
          cancelTitle: cancelTitle,
          destructive: destructive,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: title,
    actions: [
      AppSecondaryButton(
        title: cancelTitle,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      if (destructive)
        AppDangerButton(
          title: confirmTitle,
          onPressed: () => Navigator.of(context).pop(true),
        )
      else
        AppPrimaryButton(
          title: confirmTitle,
          onPressed: () => Navigator.of(context).pop(true),
        ),
    ],
    child: Text(
      message,
      style: context.text.bodyRegular.copyWith(
        color: context.color.textSecondary,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
