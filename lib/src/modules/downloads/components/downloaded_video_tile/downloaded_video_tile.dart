import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/tools/tools.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

import '../download_task_preview/download_task_preview.dart';

/// Downloaded video: thumbnail, file size, completion time
/// and a link to the file in Explorer
class DownloadedVideoTile extends StatelessWidget {
  final DownloadTaskModel task;
  final VoidCallback? onShowInFolderPressed;

  /// Removes the video from the list; the file stays in the download folder
  final VoidCallback? onRemovePressed;

  const DownloadedVideoTile({
    super.key,
    required this.task,
    this.onShowInFolderPressed,
    this.onRemovePressed,
  });

  String get _details => [
    AppFileSize.format(task.fileSizeBytes),
    if (AppFormatters.dateTime(task.completedAt ?? task.updatedAt)
        case final date?)
      LocaleKeys.app_downloader_task_completed_at.tr(namedArgs: {'date': date}),
  ].whereType<String>().join(' · ');

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DownloadTaskPreview(
            task: task,
            subtitle: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _details,
                  style: context.text.captionRegular.copyWith(
                    color: context.color.textSecondary,
                  ),
                ),
                AppLinkButton(
                  title: LocaleKeys.app_downloader_buttons_show_in_folder.tr(),
                  onPressed: onShowInFolderPressed,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppIconButton(
          icon: Icons.close_rounded,
          tooltip: LocaleKeys.app_downloader_buttons_remove.tr(),
          onPressed: onRemovePressed,
        ),
      ],
    ),
  );
}
