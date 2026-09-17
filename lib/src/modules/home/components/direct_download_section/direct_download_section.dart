import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../../controllers/controllers.dart';

/// Downloading any file by its link with the built-in downloader: the link
/// field, the progress of the single download and its buttons
class DirectDownloadSection extends StatelessWidget {
  static const _fieldHeight = 50.0;

  /// Width from which the field and the button go into one row
  static const _rowBreakpoint = 420.0;

  final DirectDownloadState state;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onStartPressed;
  final VoidCallback? onPausePressed;
  final VoidCallback? onResumePressed;
  final VoidCallback? onCancelPressed;
  final VoidCallback? onShowInFolderPressed;

  const DirectDownloadSection({
    super.key,
    required this.state,
    required this.controller,
    this.focusNode,
    this.onStartPressed,
    this.onPausePressed,
    this.onResumePressed,
    this.onCancelPressed,
    this.onShowInFolderPressed,
  });

  void _start() {
    if (state.isBusy) return;

    onStartPressed?.call(controller.text);
  }

  /// `Downloading 42% · 12 MB of 30 MB · 2 MB/s · 0:09 left · 4 connections`
  String _progressText() {
    final percent = '${state.percent.floor()}';
    final speed = AppFileSize.format(state.bytesPerSecond);
    final eta = AppFormatters.duration(state.remainingSeconds);
    final sizes = _sizes();

    final parts = switch (state.status) {
      DirectDownloadStatus.completed => [
        LocaleKeys.app_home_direct_saved.tr(
          namedArgs: {'path': state.savePath ?? state.fileName},
        ),
      ],
      DirectDownloadStatus.paused || DirectDownloadStatus.failed => [
        LocaleKeys.app_downloader_task_paused.tr(
          namedArgs: {'percent': percent},
        ),
        ?sizes,
      ],

      /// The servers are still being asked: there is no progress to show
      _ when state.isIndeterminate => [
        LocaleKeys.app_downloader_progress_preparing.tr(),
      ],
      _ => [
        LocaleKeys.app_downloader_progress_downloading.tr(
          namedArgs: {'percent': percent},
        ),
        ?sizes,
        if (speed != null)
          LocaleKeys.app_downloader_progress_speed.tr(
            namedArgs: {'value': speed},
          ),
        if (eta != null)
          LocaleKeys.app_downloader_progress_eta.tr(namedArgs: {'value': eta}),
        if (state.activeConnections > 0)
          LocaleKeys.app_home_direct_connections.tr(
            namedArgs: {'value': '${state.activeConnections}'},
          ),
      ],
    };

    return parts.join(' · ');
  }

  String? _sizes() {
    final downloaded = AppFileSize.format(state.downloadedBytes);
    final total = AppFileSize.format(state.totalBytes);

    if (downloaded == null || total == null) return null;

    return LocaleKeys.app_downloader_progress_downloaded.tr(
      namedArgs: {'downloaded': downloaded, 'total': total},
    );
  }

  Widget _form(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      /// A desktop keyboard Enter is handled before the text input:
      /// the download starts once, from either Enter key
      final input = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _start,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): _start,
        },
        child: AppTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          height: _fieldHeight,
          hintText: LocaleKeys.app_home_direct_url_hint.tr(),
          onSubmitted: (_) => _start(),
        ),
      );

      final button = AppPrimaryButton(
        title: LocaleKeys.app_home_direct_start.tr(),
        onPressed: state.isBusy ? null : _start,
        buttonColor: context.color.buttonNeutral,
        hoverColor: context.color.buttonNeutralHover,
        titleColor: context.color.onButtonNeutral,
      );

      if (constraints.maxWidth < _rowBreakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [input, const SizedBox(height: 12), button],
        );
      }

      return SizedBox(
        height: _fieldHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: input),
            const SizedBox(width: 12),
            button,
          ],
        ),
      );
    },
  );

  Widget _progress(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              _progressText(),
              style: context.text.captionRegular.copyWith(
                color: context.color.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (state.canResume)
            AppIconButton(
              icon: Icons.play_arrow_rounded,
              tooltip: LocaleKeys.app_downloader_buttons_resume.tr(),
              iconColor: context.color.accent,
              onPressed: onResumePressed,
            )
          else if (!state.status.isCompleted)
            AppIconButton(
              icon: Icons.pause_rounded,
              tooltip: LocaleKeys.app_downloader_buttons_pause.tr(),
              onPressed: state.status.isDownloading ? onPausePressed : null,
            ),
          if (state.status.isCompleted)
            AppIconButton(
              icon: Icons.folder_open_rounded,
              tooltip: LocaleKeys.app_downloader_buttons_show_in_folder.tr(),
              onPressed: onShowInFolderPressed,
            ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: LocaleKeys.app_downloader_buttons_remove.tr(),
            onPressed: onCancelPressed,
          ),
        ],
      ),
      const SizedBox(height: 10),
      AppProgressBar(
        /// Progress changes once per interval: the bar moves between
        /// the values all this time
        animationDuration: DirectDownloadController.progressInterval,
        value: state.percent / 100,
        pulsing: state.isIndeterminate,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.app_home_direct_title.tr(),
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.app_home_direct_subtitle.tr(),
          style: context.text.captionRegular.copyWith(
            color: context.color.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _form(context),
        if (state.errorMessage case final errorMessage?) ...[
          const SizedBox(height: 12),
          AppFailureBanner(message: errorMessage),
        ],
        if (state.hasProgress) ...[
          const SizedBox(height: 16),
          _progress(context),
        ],
      ],
    ),
  );
}
