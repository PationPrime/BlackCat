import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../app_buttons/app_buttons.dart';

/// Button under the error message
class AppFailureBannerAction {
  final String title;
  final VoidCallback? onPressed;

  const AppFailureBannerAction({required this.title, this.onPressed});
}

/// Error message with optional action buttons
class AppFailureBanner extends StatelessWidget {
  final String message;
  final List<AppFailureBannerAction> actions;

  const AppFailureBanner({
    super.key,
    required this.message,
    this.actions = const [],
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
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                AppPrimaryButton(
                  title: action.title,
                  onPressed: action.onPressed,
                  buttonColor: context.color.transparent,
                  hoverColor: context.color.errorActionHover,
                  titleColor: context.color.errorActionText,
                  borderColor: context.color.errorActionBorder,
                  titleStyle: context.text.captionMedium,
                  borderRadius: 8,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}
