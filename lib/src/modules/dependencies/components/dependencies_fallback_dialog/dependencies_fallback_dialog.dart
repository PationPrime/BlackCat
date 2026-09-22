import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

enum DependenciesFallbackAction {
  retryInstall,
  addVideo,
  signIn,
  importCookies,
}

/// yt-dlp was not installed: the built-in downloader still works. With a
/// YouTube sign-in (cookies or the Google window) the user can download right
/// away, otherwise the dialog offers cookies first and the Google sign-in
/// window as the last resort
class DependenciesFallbackDialog extends StatelessWidget {
  static const _maxWidth = 520.0;

  final bool signedIn;

  /// Why the installation failed
  final String? reason;

  const DependenciesFallbackDialog({
    super.key,
    required this.signedIn,
    this.reason,
  });

  /// The chosen action; `null` if the dialog was closed
  static Future<DependenciesFallbackAction?> show(
    BuildContext context, {
    required bool signedIn,
    String? reason,
  }) => AppDialog.show<DependenciesFallbackAction>(
    context,
    builder: (_) =>
        DependenciesFallbackDialog(signedIn: signedIn, reason: reason),
  );

  @override
  Widget build(BuildContext context) {
    void choose(DependenciesFallbackAction action) =>
        Navigator.of(context).pop(action);

    return AppDialog(
      title: LocaleKeys.app_dependencies_fallback_dialog_title.tr(),
      maxWidth: _maxWidth,
      actions: [
        AppSecondaryButton(
          title: LocaleKeys.app_dependencies_fallback_dialog_close.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppSecondaryButton(
          title: LocaleKeys.app_dependencies_fallback_dialog_retry.tr(),
          onPressed: () => choose(DependenciesFallbackAction.retryInstall),
        ),
        if (signedIn)
          AppPrimaryButton(
            title: LocaleKeys.app_dependencies_fallback_dialog_add_video.tr(),
            onPressed: () => choose(DependenciesFallbackAction.addVideo),
          )
        else ...[
          AppSecondaryButton(
            title: LocaleKeys.app_dependencies_fallback_dialog_sign_in.tr(),
            onPressed: () => choose(DependenciesFallbackAction.signIn),
          ),
          AppPrimaryButton(
            title: LocaleKeys.app_dependencies_fallback_dialog_import_cookies
                .tr(),
            onPressed: () => choose(DependenciesFallbackAction.importCookies),
          ),
        ],
      ],
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              signedIn
                  ? LocaleKeys
                        .app_dependencies_fallback_dialog_message_signed_in
                        .tr()
                  : LocaleKeys
                        .app_dependencies_fallback_dialog_message_signed_out
                        .tr(),
              style: context.text.bodyRegular.copyWith(
                color: context.color.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (reason case final reason?) ...[
              const SizedBox(height: 12),
              SelectableText(
                LocaleKeys.app_dependencies_fallback_dialog_reason.tr(
                  namedArgs: {'error': reason},
                ),
                style: context.text.captionRegular.copyWith(
                  color: context.color.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
