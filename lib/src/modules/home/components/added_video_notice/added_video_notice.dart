import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// Confirmation that the video went to the downloads, with a way to open them
class AddedVideoNotice extends StatelessWidget {
  final String title;
  final VoidCallback? onOpenDownloadsPressed;
  final VoidCallback? onDismissPressed;

  const AddedVideoNotice({
    super.key,
    required this.title,
    this.onOpenDownloadsPressed,
    this.onDismissPressed,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    decoration: BoxDecoration(
      color: context.color.accentSubtle,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 18, color: context.color.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              LocaleKeys.app_home_added.tr(namedArgs: {'title': title}),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.captionRegular.copyWith(
                color: context.color.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        AppLinkButton(
          title: LocaleKeys.app_home_open_downloads.tr(),
          onPressed: onOpenDownloadsPressed,
        ),
        const SizedBox(width: 4),
        AppIconButton(
          icon: Icons.close_rounded,
          tooltip: LocaleKeys.app_downloader_buttons_hide.tr(),
          onPressed: onDismissPressed,
        ),
      ],
    ),
  );
}
