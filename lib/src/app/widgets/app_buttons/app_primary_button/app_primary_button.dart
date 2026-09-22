import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../app_pressable/app_pressable.dart';

/// Rounded button. A disabled button is semi-transparent
class AppPrimaryButton extends StatelessWidget {
  static const _spinnerSize = 18.0;

  /// Share of the font size the title is lifted by
  static const _opticalLift = 0.1;

  final String title;
  final VoidCallback? onPressed;

  /// Work of the button is in progress: a spinner stands in for the title,
  /// the button keeps its width and is not pressed again
  final bool loading;

  /// What a screen reader says while [loading]
  final String? loadingLabel;

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
    this.loading = false,
    this.loadingLabel,
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
  Widget build(BuildContext context) {
    final contentColor = titleColor ?? context.color.onAccent;
    final style = (titleStyle ?? context.text.bodyMedium).copyWith(
      color: contentColor,
    );

    /// Segoe UI and the other system fonts keep room for accents above
    /// the letters, so a title centered by its line sits low: lowercase
    /// letters most of all. The title is lifted to look centered
    final titleText = Transform.translate(
      offset: Offset(0, -(style.fontSize ?? 14) * _opticalLift),
      child: Text(title, style: style),
    );

    return Opacity(
      /// A loading button is busy, not disabled
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: AppPressable(
        onPressed: loading ? null : onPressed,
        builder: (context, highlighted) => AnimatedContainer(
          duration: animationDuration,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted
                ? hoverColor ?? context.color.accentHover
                : buttonColor ?? context.color.accent,
            borderRadius: BorderRadius.circular(borderRadius),
            border: borderColor is! Color
                ? null
                : Border.all(color: borderColor!),
          ),
          child: loading
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    /// The hidden title keeps the width of the button
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: titleText,
                    ),
                    SizedBox.square(
                      dimension: _spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        color: contentColor,
                        semanticsLabel: loadingLabel ?? title,
                      ),
                    ),
                  ],
                )
              : titleText,
        ),
      ),
    );
  }
}
