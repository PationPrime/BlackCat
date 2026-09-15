import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../app_pressable/app_pressable.dart';

/// Текстовая кнопка, подчёркивается при наведении
class AppLinkButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  /// По умолчанию — акцентный цвет
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
