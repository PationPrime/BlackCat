part of 'dependencies_install_dialog.dart';

enum _StepStatus {
  waiting,
  preparing,
  downloading,
  verifying,
  extracting,
  done,

  /// Found on the computer before the installation
  alreadyInstalled,
  failed;

  bool get isRunning =>
      this == preparing ||
      this == downloading ||
      this == verifying ||
      this == extracting;
}

/// One program of the installation: name, purpose, step and progress
class _DependencyInstallStep extends StatelessWidget {
  static const _iconSize = 20.0;

  /// Readable names of the runtimes yt-dlp can use
  static const _runtimeTitles = {
    'deno': 'Deno',
    'node': 'Node.js',
    'bun': 'Bun',
  };

  final DependencyKind kind;
  final _StepStatus status;

  /// The installed program, if any
  final DependencyToolModel? tool;

  /// Step of this program while it is being installed
  final DependencyInstallProgressModel? progress;

  const _DependencyInstallStep({
    required this.kind,
    required this.status,
    this.tool,
    this.progress,
  });

  String get _title => switch (kind) {
    DependencyKind.ytDlp =>
      LocaleKeys.app_dependencies_install_dialog_yt_dlp_title.tr(),
    DependencyKind.jsRuntime =>
      _runtimeTitles[tool?.name] ??
          LocaleKeys.app_dependencies_install_dialog_js_runtime_title.tr(),
  };

  String get _description => switch (kind) {
    DependencyKind.ytDlp =>
      LocaleKeys.app_dependencies_install_dialog_yt_dlp_description.tr(),
    DependencyKind.jsRuntime =>
      LocaleKeys.app_dependencies_install_dialog_js_runtime_description.tr(),
  };

  String get _statusText => switch (status) {
    _StepStatus.waiting =>
      LocaleKeys.app_dependencies_install_dialog_status_waiting.tr(),
    _StepStatus.preparing =>
      LocaleKeys.app_dependencies_install_dialog_status_preparing.tr(),
    _StepStatus.downloading => _downloadingText,
    _StepStatus.verifying =>
      LocaleKeys.app_dependencies_install_dialog_status_verifying.tr(),
    _StepStatus.extracting =>
      LocaleKeys.app_dependencies_install_dialog_status_extracting.tr(),
    _StepStatus.done =>
      LocaleKeys.app_dependencies_install_dialog_status_done.tr(),
    _StepStatus.alreadyInstalled =>
      LocaleKeys.app_dependencies_install_dialog_status_installed.tr(
        namedArgs: {'version': tool?.version ?? ''},
      ),
    _StepStatus.failed =>
      LocaleKeys.app_dependencies_install_dialog_status_failed.tr(),
  };

  String get _downloadingText {
    final received = AppFileSize.format(progress?.receivedBytes);
    final total = AppFileSize.format(progress?.totalBytes);

    if (received == null) {
      return LocaleKeys.app_dependencies_install_dialog_status_preparing.tr();
    }

    return total == null
        ? LocaleKeys.app_dependencies_install_dialog_status_downloading_unknown
              .tr(namedArgs: {'received': received})
        : LocaleKeys.app_dependencies_install_dialog_status_downloading.tr(
            namedArgs: {'received': received, 'total': total},
          );
  }

  Widget _icon(BuildContext context) => SizedBox.square(
    dimension: _iconSize,
    child: switch (status) {
      _ when status.isRunning => Padding(
        padding: const EdgeInsets.all(2),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.color.accent,
        ),
      ),
      _StepStatus.done || _StepStatus.alreadyInstalled => Icon(
        Icons.check_circle_rounded,
        size: _iconSize,
        color: context.color.accent,
      ),
      _StepStatus.failed => Icon(
        Icons.error_outline_rounded,
        size: _iconSize,
        color: context.color.errorText,
      ),
      _ => Icon(
        Icons.radio_button_unchecked_rounded,
        size: _iconSize,
        color: context.color.iconDisabled,
      ),
    },
  );

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(14),
    backgroundColor: context.color.surface,
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _icon(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: context.text.bodyMedium.copyWith(
                      color: context.color.textPrimary,
                    ),
                  ),
                  Text(
                    _description,
                    style: context.text.captionRegular.copyWith(
                      color: context.color.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _statusText,
                textAlign: TextAlign.end,
                style: context.text.captionRegular.copyWith(
                  color: status == _StepStatus.failed
                      ? context.color.errorText
                      : context.color.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (status == _StepStatus.downloading) ...[
          const SizedBox(height: 10),
          AppProgressBar(
            value: progress?.fraction ?? 1,
            pulsing: progress?.fraction == null,
            height: 6,
          ),
        ],
      ],
    ),
  );
}
