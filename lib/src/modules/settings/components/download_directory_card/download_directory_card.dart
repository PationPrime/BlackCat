import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

import '../../../../generated/assets/assets.gen.dart';

/// Download folder: path, choosing another folder, returning to Downloads
class DownloadDirectoryCard extends StatelessWidget {
  /// `null` while the settings are loading
  final DownloadDirectoryModel? downloadDirectory;
  final VoidCallback? onChangePressed;
  final VoidCallback? onResetPressed;
  final VoidCallback? onOpenPressed;

  const DownloadDirectoryCard({
    super.key,
    this.downloadDirectory,
    this.onChangePressed,
    this.onResetPressed,
    this.onOpenPressed,
  });

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.app_settings_download_directory_title.tr(),
          style: context.text.bodyMedium.copyWith(
            color: context.color.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.app_settings_download_directory_description.tr(),
          style: context.text.captionRegular.copyWith(
            color: context.color.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.color.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.color.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Assets.icons.iconDownloadFolder.svg(
                color: context.color.iconPrimary,
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  downloadDirectory?.path ?? '',
                  maxLines: 1,
                  style: context.text.captionRegular.copyWith(
                    color: context.color.textPrimary,
                  ),
                ),
              ),
              if (downloadDirectory?.isDefault ?? false) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.color.accentSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    LocaleKeys.app_settings_download_directory_default_badge
                        .tr(),
                    style: context.text.footnoteRegular.copyWith(
                      color: context.color.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSecondaryButton(
              title: LocaleKeys.app_settings_download_directory_change.tr(),
              onPressed: downloadDirectory == null ? null : onChangePressed,
              compact: true,
            ),
            AppLinkButton(
              title: LocaleKeys.app_settings_download_directory_open.tr(),
              onPressed: downloadDirectory == null ? null : onOpenPressed,
            ),
            if (downloadDirectory case final directory?
                when !directory.isDefault)
              AppLinkButton(
                title: LocaleKeys.app_settings_download_directory_reset.tr(),
                titleColor: context.color.textSecondary,
                onPressed: onResetPressed,
              ),
          ],
        ),
      ],
    ),
  );
}
