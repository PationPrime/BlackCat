import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

part 'dependency_install_step.dart';

/// yt-dlp installation: each program with its step and download progress.
/// The installation starts as soon as the dialog opens
class DependenciesInstallDialog extends StatefulWidget {
  static const _maxWidth = 520.0;

  const DependenciesInstallDialog({super.key});

  /// `true`: yt-dlp is ready when the dialog closes
  static Future<bool> show(BuildContext context) async {
    final dependenciesController = context.read<DependenciesController>();

    await AppDialog.show<void>(
      context,
      barrierDismissible: false,
      builder: (_) => const DependenciesInstallDialog(),
    );

    return dependenciesController.state.status.isReady;
  }

  @override
  State<DependenciesInstallDialog> createState() =>
      _DependenciesInstallDialogState();
}

class _DependenciesInstallDialogState extends State<DependenciesInstallDialog> {
  @override
  void initState() {
    super.initState();

    final dependenciesController = context.read<DependenciesController>();

    if (dependenciesController.state.status.canInstall) {
      unawaited(dependenciesController.install());
    }
  }

  _StepStatus _stepStatusOf(DependencyKind kind, DependenciesState state) {
    final installedTool = switch (kind) {
      DependencyKind.ytDlp => state.setup?.ytDlp,
      DependencyKind.jsRuntime => state.setup?.jsRuntime,
    };

    if (state.installed.contains(kind)) {
      return _StepStatus.done;
    }

    if (!state.installing.contains(kind)) {
      return installedTool == null
          ? _StepStatus.waiting
          : _StepStatus.alreadyInstalled;
    }

    final progress = state.progress;

    if (state.status.isInstalling) {
      if (progress?.kind == kind) {
        return switch (progress!.stage) {
          DependencyInstallStage.downloading => _StepStatus.downloading,
          DependencyInstallStage.verifying => _StepStatus.verifying,
          DependencyInstallStage.extracting => _StepStatus.extracting,
          DependencyInstallStage.done => _StepStatus.done,
        };
      }

      /// Nothing reported yet: the first program is being prepared
      return progress == null && state.installing.first == kind
          ? _StepStatus.preparing
          : _StepStatus.waiting;
    }

    return state.status.isFailed ? _StepStatus.failed : _StepStatus.waiting;
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DependenciesController, DependenciesState>(
    builder: (context, dependenciesState) {
      final dependenciesController = context.read<DependenciesController>();
      final status = dependenciesState.status;

      return PopScope(
        canPop: !status.isBusy,
        child: AppDialog(
          title: LocaleKeys.app_dependencies_install_dialog_title.tr(),
          maxWidth: DependenciesInstallDialog._maxWidth,
          actions: [
            if (status.isBusy)
              AppSecondaryButton(
                title: LocaleKeys.app_dependencies_install_dialog_cancel.tr(),
                onPressed: status.isInstalling
                    ? dependenciesController.cancelInstall
                    : null,
              )
            else if (status.isReady)
              AppPrimaryButton(
                title: LocaleKeys.app_dependencies_install_dialog_done.tr(),
                onPressed: () => Navigator.of(context).pop(),
              )
            else ...[
              AppSecondaryButton(
                title: LocaleKeys.app_dependencies_install_dialog_close.tr(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppPrimaryButton(
                title: LocaleKeys.app_dependencies_install_dialog_retry.tr(),
                onPressed: dependenciesController.install,
              ),
            ],
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  LocaleKeys.app_dependencies_install_dialog_description.tr(),
                  style: context.text.captionRegular.copyWith(
                    color: context.color.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (status == DependenciesStatus.checking)
                  Text(
                    LocaleKeys.app_dependencies_install_dialog_checking.tr(),
                    style: context.text.captionRegular.copyWith(
                      color: context.color.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  for (final (index, kind)
                      in DependencyKind.values.indexed) ...[
                    if (index > 0) const SizedBox(height: 12),
                    _DependencyInstallStep(
                      kind: kind,
                      status: _stepStatusOf(kind, dependenciesState),
                      tool: switch (kind) {
                        DependencyKind.ytDlp => dependenciesState.setup?.ytDlp,
                        DependencyKind.jsRuntime =>
                          dependenciesState.setup?.jsRuntime,
                      },
                      progress: dependenciesState.progress?.kind == kind
                          ? dependenciesState.progress
                          : null,
                    ),
                  ],
                if (dependenciesState.failure case final failure?
                    when status.isFailed) ...[
                  const SizedBox(height: 20),
                  AppFailureBanner(message: failure.message),
                ],
                if (status.isReady) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      LocaleKeys.app_dependencies_install_dialog_success.tr(
                        namedArgs: {
                          'version':
                              dependenciesState.setup?.ytDlp?.version ?? '',
                        },
                      ),
                      style: context.text.bodyMedium.copyWith(
                        color: context.color.accent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
