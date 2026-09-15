import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../app_buttons/app_buttons.dart';

/// Option from a group: a title and a muted hint on the right
class AppSelectableChip extends StatelessWidget {
  final String title;

  /// E.g. the approximate file size
  final String? subtitle;
  final bool selected;
  final VoidCallback? onPressed;

  const AppSelectableChip({
    super.key,
    required this.title,
    required this.selected,
    this.subtitle,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    child: AppPressable(
      onPressed: onPressed,
      builder: (context, highlighted) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.color.accentSubtle
              : context.color.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? context.color.accent
                : highlighted
                ? context.color.borderHover
                : context.color.border,
          ),
        ),
        child: Text.rich(
          TextSpan(
            text: title,
            children: [
              if (subtitle is String) ...[
                const WidgetSpan(child: SizedBox(width: 6)),
                TextSpan(
                  text: subtitle,
                  style: TextStyle(color: context.color.textHint),
                ),
              ],
            ],
          ),
          style: context.text.captionRegular.copyWith(
            color: selected
                ? context.color.textPrimary
                : context.color.textSecondary,
          ),
        ),
      ),
    ),
  );
}
