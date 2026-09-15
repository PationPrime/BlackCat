import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../app_primary_button/app_primary_button.dart';

/// Secondary button: transparent, with a border
class AppSecondaryButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  /// Compact button for rows and the header
  final bool compact;

  const AppSecondaryButton({
    super.key,
    required this.title,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => AppPrimaryButton(
    title: title,
    onPressed: onPressed,
    buttonColor: context.color.transparent,
    hoverColor: context.color.hoverOverlay,
    titleColor: context.color.textSecondary,
    borderColor: context.color.border,
    titleStyle: compact ? context.text.captionMedium : null,
    borderRadius: compact ? 8 : 12,
    padding: compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  );
}
