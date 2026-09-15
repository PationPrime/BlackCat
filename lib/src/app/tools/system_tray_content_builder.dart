import 'package:easy_localization/easy_localization.dart';

import '../localization/lang/locale_keys.g.dart';
import '../models/models.dart';
import 'system_tray_text.dart';

/// Keys of the tray menu items
abstract final class SystemTrayMenuKeys {
  /// Title and progress of the active download: opens the app window
  static const activeDownload = 'active_download';
  static const openWindow = 'open_window';
  static const hideWindow = 'hide_window';
  static const quit = 'quit';
}

/// Tray menu and tooltip in the current app language
abstract final class SystemTrayContentBuilder {
  static SystemTrayContentModel build(DownloadTaskModel? activeTask) {
    final appTitle = LocaleKeys.app_title.tr();

    final downloadItems = activeTask == null
        ? [
            SystemTrayMenuActionModel(
              key: SystemTrayMenuKeys.activeDownload,
              label: LocaleKeys.app_tray_no_active_download.tr(),
              enabled: false,
            ),
          ]
        : [
            SystemTrayMenuActionModel(
              key: SystemTrayMenuKeys.activeDownload,
              label: SystemTrayText.ellipsize(activeTask.video.title),
            ),
            SystemTrayMenuActionModel(
              key: SystemTrayMenuKeys.activeDownload,
              label: progressOf(activeTask),
            ),
          ];

    return SystemTrayContentModel(
      menu: [
        ...downloadItems,
        const SystemTrayMenuSeparatorModel(),
        SystemTrayMenuActionModel(
          key: SystemTrayMenuKeys.openWindow,
          label: LocaleKeys.app_tray_open.tr(),
        ),
        SystemTrayMenuActionModel(
          key: SystemTrayMenuKeys.hideWindow,
          label: LocaleKeys.app_tray_hide.tr(),
        ),
        const SystemTrayMenuSeparatorModel(),
        SystemTrayMenuActionModel(
          key: SystemTrayMenuKeys.quit,
          label: LocaleKeys.app_tray_quit.tr(),
        ),
      ],
      toolTip: activeTask == null
          ? appTitle
          : [
              appTitle,
              SystemTrayText.ellipsize(activeTask.video.title),
              progressOf(activeTask),
            ].join('\n'),
    );
  }

  /// Short download state: the percent, a pause or muxing
  static String progressOf(DownloadTaskModel task) {
    final percent = '${task.percent.floor()}';

    return switch (task.status) {
      DownloadTaskStatus.processing =>
        LocaleKeys.app_downloader_progress_processing.tr(),
      DownloadTaskStatus.paused => LocaleKeys.app_downloader_task_paused.tr(
        namedArgs: {'percent': percent},
      ),

      /// Streams are not selected yet: the size and the percent are unknown
      DownloadTaskStatus.downloading when task.totalBytes == null =>
        LocaleKeys.app_downloader_progress_preparing.tr(),
      _ => LocaleKeys.app_downloader_progress_downloading.tr(
        namedArgs: {'percent': percent},
      ),
    };
  }
}
