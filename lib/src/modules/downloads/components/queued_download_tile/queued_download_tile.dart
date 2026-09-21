import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

import '../download_task_preview/download_task_preview.dart';

/// Queued video: drag handle, "Download now" and removal
class QueuedDownloadTile extends StatelessWidget {
  final DownloadTaskModel task;

  /// Position in the list: the row is dragged by it
  final int index;
  final VoidCallback? onStartPressed;
  final VoidCallback? onRemovePressed;

  const QueuedDownloadTile({
    super.key,
    required this.task,
    required this.index,
    this.onStartPressed,
    this.onRemovePressed,
  });

  String get _status {
    final percent = '${task.percent.floor()}';

    if (task.status.isPaused) {
      return LocaleKeys.app_downloader_task_paused.tr(
        namedArgs: {'percent': percent},
      );
    }

    return task.hasProgress
        ? LocaleKeys.app_downloader_task_queued_with_progress.tr(
            namedArgs: {'percent': percent},
          )
        : LocaleKeys.app_downloader_task_queued.tr();
  }

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
    child: Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: Tooltip(
            message: LocaleKeys.app_downloader_buttons_reorder.tr(),
            waitDuration: const Duration(milliseconds: 400),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 16,
                ),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: context.color.iconDisabled,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: DownloadTaskPreview(
            task: task,
            subtitle: Text(
              _status,
              style: context.text.captionRegular.copyWith(
                color: context.color.textSecondary,
              ),
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
