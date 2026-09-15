import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../app_buttons/app_buttons.dart';

/// Сообщение об ошибке с необязательной кнопкой действия
class AppFailureBanner extends StatelessWidget {
  final String message;
  final String? actionTitle;
  final VoidCallback? onActionPressed;

  const AppFailureBanner({
    super.key,
    required this.message,
    this.actionTitle,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: context.color.errorBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.color.errorBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: SelectableText(
            message,
            style: context.text.captionRegular.copyWith(
              color: context.color.errorText,
            ),
          ),
        ),
        if (actionTitle is String) ...[
          const SizedBox(height: 12),
          AppPrimaryButton(
            title: actionTitle!,
            onPressed: onActionPressed,
            buttonColor: context.color.transparent,
            hoverColor: context.color.errorActionHover,
            titleColor: context.color.errorActionText,
            borderColor: context.color.errorActionBorder,
            titleStyle: context.text.captionMedium,
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ],
      ],
    ),
  );
}
