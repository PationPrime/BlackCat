import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Failed download reason with retry and sign-in buttons
class DownloadTaskFailure extends StatelessWidget {
  final DownloadTaskModel task;
  final VoidCallback? onRetryPressed;

  /// The sign-in button is shown if signing in to YouTube will most likely help
  final String? signInTitle;
  final VoidCallback? onSignInPressed;

  const DownloadTaskFailure({
    super.key,
    required this.task,
    this.onRetryPressed,
    this.signInTitle,
    this.onSignInPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SelectableText(
        task.failureMessage ?? LocaleKeys.app_downloader_task_failed.tr(),
        style: context.text.captionRegular.copyWith(
          color: context.color.errorText,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppSecondaryButton(
            title: LocaleKeys.app_downloader_buttons_retry.tr(),
            onPressed: onRetryPressed,
            compact: true,
          ),
          if (task.failureNeedsSignIn && signInTitle is String)
            AppSecondaryButton(
              title: signInTitle!,
              onPressed: onSignInPressed,
              compact: true,
            ),
        ],
      ),
    ],
  );
}
