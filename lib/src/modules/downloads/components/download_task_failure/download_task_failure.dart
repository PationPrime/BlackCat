import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Failed download reason with retry, sign-in and cookies import buttons
class DownloadTaskFailure extends StatelessWidget {
  final DownloadTaskModel task;
  final VoidCallback? onRetryPressed;

  /// The sign-in and cookies import buttons are shown if signing in
  /// to YouTube will most likely help
  final String? signInTitle;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onImportCookiesPressed;

  const DownloadTaskFailure({
    super.key,
    required this.task,
    this.onRetryPressed,
    this.signInTitle,
    this.onSignInPressed,
    this.onImportCookiesPressed,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      AppSecondaryButton(
        title: LocaleKeys.app_downloader_buttons_retry.tr(),
        onPressed: onRetryPressed,
        compact: true,
      ),
      if (task.failureNeedsSignIn) ...[
        if (signInTitle case final title?)
          AppSecondaryButton(
            title: title,
            onPressed: onSignInPressed,
            compact: true,
          ),
        AppSecondaryButton(
          title: LocaleKeys.app_downloader_buttons_import_cookies.tr(),
          onPressed: onImportCookiesPressed,
          compact: true,
        ),
      ],
    ];

    return Column(
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
            /// A button fills the width it is given: here each keeps its own
            /// width, and the buttons line up and wrap when the row is full
            for (final button in buttons) IntrinsicWidth(child: button),
          ],
        ),
      ],
    );
  }
}
