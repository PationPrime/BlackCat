import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../app_pressable/app_pressable.dart';

/// Text button, underlined on hover
class AppLinkButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  /// Defaults to the accent color
  final Color? titleColor;

  const AppLinkButton({
    super.key,
    required this.title,
    this.onPressed,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = titleColor ?? context.color.accent;

    return AppPressable(
      onPressed: onPressed,
      builder: (context, highlighted) => Text(
        title,
        style: context.text.captionRegular.copyWith(
          color: color,
          decoration: highlighted ? TextDecoration.underline : null,
          decorationColor: color,
        ),
      ),
    );
  }
}
