import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../app_pressable/app_pressable.dart';

/// Rounded button. A disabled button is semi-transparent
class AppPrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  /// Defaults to the accent button
  final Color? buttonColor;
  final Color? hoverColor;
  final Color? titleColor;
  final Color? borderColor;
  final TextStyle? titleStyle;
  final double borderRadius;
  final EdgeInsets padding;
  final Duration animationDuration;

  const AppPrimaryButton({
    super.key,
    required this.title,
    this.onPressed,
    this.buttonColor,
    this.hoverColor,
    this.titleColor,
    this.borderColor,
    this.titleStyle,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? 0.5 : 1,
    child: AppPressable(
      onPressed: onPressed,
      builder: (context, highlighted) => AnimatedContainer(
        duration: animationDuration,
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted
              ? hoverColor ?? context.color.accentHover
              : buttonColor ?? context.color.accent,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderColor is! Color ? null : Border.all(color: borderColor!),
        ),
        child: Text(
          title,
          style: (titleStyle ?? context.text.bodyMedium).copyWith(
            color: titleColor ?? context.color.onAccent,
          ),
        ),
      ),
    ),
  );
}
