import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../design_system/design_system.dart';
import '../app_pressable/app_pressable.dart';

/// Icon button with a tooltip. Highlighted on hover,
/// a disabled button is semi-transparent
class AppIconButton extends StatelessWidget {
  final String svgPictureIconPath;

  /// Hover tooltip and label for the screen reader
  final String tooltip;
  final VoidCallback? onPressed;

  /// Defaults to [AppThemeColors.iconPrimary]
  final Color? iconColor;

  /// Defaults to [AppThemeColors.hoverOverlay]
  final Color? hoverColor;
  final double size;
  final double iconSize;
  final Duration animationDuration;

  const AppIconButton({
    super.key,
    required this.svgPictureIconPath,
    required this.tooltip,
    this.onPressed,
    this.iconColor,
    this.hoverColor,
    this.size = 32,
    this.iconSize = 18,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 400),
    child: Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: AppPressable(
        onPressed: onPressed,
        builder: (context, highlighted) => AnimatedContainer(
          duration: animationDuration,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted
                ? hoverColor ?? context.color.hoverOverlay
                : context.color.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: SvgPicture.asset(
              svgPictureIconPath,
              color: iconColor ?? context.color.iconPrimary,
              width: iconSize,
              height: iconSize,
            ),
          ),
        ),
      ),
    ),
  );
}
