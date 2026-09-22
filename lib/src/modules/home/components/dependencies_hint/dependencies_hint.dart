import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// Which engine the search uses: yt-dlp, or the built-in downloader with
/// a way to install yt-dlp
class DependenciesHint extends StatelessWidget {
  final DependenciesStatus status;

  /// Opens the installation dialog
  final VoidCallback? onInstallPressed;

  const DependenciesHint({
    super.key,
    required this.status,
    this.onInstallPressed,
  });

  @override
  Widget build(BuildContext context) {
    final (message, actionTitle) = switch (status) {
      DependenciesStatus.ready => (
        LocaleKeys.app_downloader_dialog_ytdlp_hint.tr(),
        null,
      ),
      DependenciesStatus.installing => (
        LocaleKeys.app_downloader_dependencies_installing.tr(),
        LocaleKeys.app_downloader_dependencies_show.tr(),
      ),
      _ when status.canInstall => (
        LocaleKeys.app_downloader_dependencies_missing.tr(),
        LocaleKeys.app_downloader_dependencies_install.tr(),
      ),
      _ => (null, null),
    };

    if (message == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          message,
          style: context.text.captionRegular.copyWith(
            color: context.color.textTertiary,
          ),
        ),
        if (actionTitle case final title?)
          AppLinkButton(title: title, onPressed: onInstallPressed),
      ],
    );
  }
}
