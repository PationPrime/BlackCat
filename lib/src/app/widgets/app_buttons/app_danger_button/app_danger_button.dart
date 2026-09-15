import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../app_primary_button/app_primary_button.dart';

/// Button for an irreversible action: deletion
class AppDangerButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  const AppDangerButton({super.key, required this.title, this.onPressed});

  @override
  Widget build(BuildContext context) => AppPrimaryButton(
    title: title,
    onPressed: onPressed,
    buttonColor: context.color.errorBackground,
    hoverColor: context.color.errorActionHover,
    titleColor: context.color.errorActionText,
    borderColor: context.color.errorActionBorder,
  );
}
