import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

import '../download_task_failure/download_task_failure.dart';
import '../download_task_preview/download_task_preview.dart';

/// Failed download: the reason with a retry, "Download now" and removal
class FailedDownloadTile extends StatelessWidget {
  final DownloadTaskModel task;
  final VoidCallback? onStartPressed;
  final VoidCallback? onRemovePressed;
  final VoidCallback? onRetryPressed;

  /// The sign-in and cookies import buttons are shown if signing in
  /// to YouTube will most likely help
  final String? signInTitle;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onImportCookiesPressed;

  const FailedDownloadTile({
    super.key,
    required this.task,
    this.onStartPressed,
    this.onRemovePressed,
    this.onRetryPressed,
    this.signInTitle,
    this.onSignInPressed,
    this.onImportCookiesPressed,
  });

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(12),
    borderColor: context.color.errorBorder,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DownloadTaskPreview(
            task: task,
            subtitle: DownloadTaskFailure(
              task: task,
              onRetryPressed: onRetryPressed,
              signInTitle: signInTitle,
              onSignInPressed: onSignInPressed,
              onImportCookiesPressed: onImportCookiesPressed,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppIconButton(
          icon: Icons.play_arrow_rounded,
          tooltip: LocaleKeys.app_downloader_buttons_start_now.tr(),
          iconColor: context.color.accent,
          onPressed: onStartPressed,
        ),
        AppIconButton(
          icon: Icons.close_rounded,
          tooltip: LocaleKeys.app_downloader_buttons_remove.tr(),
          onPressed: onRemovePressed,
        ),
      ],
    ),
  );
}
