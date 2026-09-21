import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/tools/tools.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// YouTube cookies.txt, the recommended way to sign in: how to export it
/// from a browser and when to update it, the imported file and its
/// replacement or removal. Below, the Google sign-in window as the last
/// resort, with the reason why
class CookiesCard extends StatelessWidget {
  static const _steps = [
    LocaleKeys.app_settings_cookies_step_1,
    LocaleKeys.app_settings_cookies_step_2,
    LocaleKeys.app_settings_cookies_step_3,
    LocaleKeys.app_settings_cookies_step_4,
    LocaleKeys.app_settings_cookies_step_5,
    LocaleKeys.app_settings_cookies_step_6,
  ];

  /// The signed-in account; `null` when signed out
  final AccountSessionModel? session;

  /// The user came here to import cookies: the card stands out
  final bool highlighted;
  final bool isImporting;

  /// The last import succeeded
  final bool isImported;
  final String? failureMessage;

  /// Deleting is not allowed while a download is running
  final bool removeEnabled;
  final VoidCallback? onChoosePressed;
  final VoidCallback? onRemovePressed;
  final VoidCallback? onGuidePressed;
  final VoidCallback? onDismissFailurePressed;

  /// The Google sign-in window: the settings warn before opening it.
  /// `null` hides the button, e.g. while signing in
  final VoidCallback? onSignInPressed;

  const CookiesCard({
    super.key,
    this.session,
    this.highlighted = false,
    this.isImporting = false,
    this.isImported = false,
    this.failureMessage,
    this.removeEnabled = true,
    this.onChoosePressed,
    this.onRemovePressed,
    this.onGuidePressed,
    this.onDismissFailurePressed,
    this.onSignInPressed,
  });

  Widget _instructions(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.color.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.color.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.app_settings_cookies_steps_title.tr(),
          style: context.text.captionMedium.copyWith(
            color: context.color.textPrimary,
          ),
        ),
        for (final (index, step) in _steps.indexed) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '${index + 1}.',
                  style: context.text.captionRegular.copyWith(
                    color: context.color.accent,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  step.tr(),
                  style: context.text.captionRegular.copyWith(
                    color: context.color.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Text(
          LocaleKeys.app_settings_cookies_refresh_title.tr(),
          style: context.text.captionMedium.copyWith(
            color: context.color.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.app_settings_cookies_refresh.tr(),
          style: context.text.captionRegular.copyWith(
            color: context.color.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AppLinkButton(
                title: LocaleKeys.app_settings_cookies_guide.tr(),
                onPressed: onGuidePressed,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: context.color.accent,
            ),
          ],
        ),
      ],
    ),
  );

  /// The Google sign-in window is still there, with the reason to avoid it
  Widget _googleSignIn(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Divider(height: 1, color: context.color.border),
      const SizedBox(height: 16),
      Text(
        LocaleKeys.app_settings_cookies_google_title.tr(),
        style: context.text.captionMedium.copyWith(
          color: context.color.textPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        LocaleKeys.app_settings_cookies_google_description.tr(),
        style: context.text.captionRegular.copyWith(
          color: context.color.textTertiary,
        ),
      ),
      if (onSignInPressed case final onPressed?) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: AppLinkButton(
            title: LocaleKeys.app_settings_cookies_google_sign_in.tr(),
            titleColor: context.color.textSecondary,
            onPressed: onPressed,
          ),
        ),
      ],
    ],
  );

  Widget _status(BuildContext context) {
    final hasImportedFile = session?.isImported ?? false;

    final (title, subtitle) = switch (session) {
      final session? when session.isImported => (
        session.cookiesFilePath!,
        switch (AppFormatters.dateTime(session.importedAt)) {
          final date? => LocaleKeys.app_settings_cookies_imported_at.tr(
            namedArgs: {'date': date},
          ),
          null => null,
        },
      ),
      _? => (LocaleKeys.app_settings_cookies_sign_in_window_active.tr(), null),
      null => (LocaleKeys.app_settings_cookies_not_imported.tr(), null),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.color.border),
      ),
      child: Row(
        children: [
          Icon(
            hasImportedFile ? Icons.task_outlined : Icons.description_outlined,
            size: 18,
            color: hasImportedFile
                ? context.color.accent
                : context.color.iconPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  title,
                  maxLines: 3,
                  style: context.text.captionRegular.copyWith(
                    color: hasImportedFile
                        ? context.color.textPrimary
                        : context.color.textTertiary,
                  ),
                ),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    style: context.text.footnoteRegular.copyWith(
                      color: context.color.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(20),
    borderColor: highlighted ? context.color.accent : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                LocaleKeys.app_settings_cookies_title.tr(),
                style: context.text.bodyMedium.copyWith(
                  color: context.color.textPrimary,
                ),
              ),
            ),

            /// Cookies are the recommended way until they are in use
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.color.accentSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session?.isImported ?? false
                    ? LocaleKeys.app_settings_cookies_imported_badge.tr()
                    : LocaleKeys.app_settings_cookies_recommended_badge.tr(),
                style: context.text.footnoteRegular.copyWith(
                  color: context.color.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.app_settings_cookies_description.tr(),
          style: context.text.captionRegular.copyWith(
            color: context.color.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        _instructions(context),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: context.color.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                LocaleKeys.app_settings_cookies_warning.tr(),
                style: context.text.footnoteRegular.copyWith(
                  color: context.color.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _status(context),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSecondaryButton(
              title: isImporting
                  ? LocaleKeys.app_settings_cookies_importing.tr()
                  : LocaleKeys.app_settings_cookies_choose.tr(),
              onPressed: isImporting ? null : onChoosePressed,
              compact: true,
            ),
            if (session?.isImported ?? false)
              AppLinkButton(
                title: LocaleKeys.app_settings_cookies_remove.tr(),
                titleColor: context.color.textSecondary,
                onPressed: removeEnabled && !isImporting
                    ? onRemovePressed
                    : null,
              ),
          ],
        ),
        if (isImported) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              LocaleKeys.app_settings_cookies_success.tr(),
              style: context.text.captionRegular.copyWith(
                color: context.color.accent,
              ),
            ),
          ),
        ],
        if (failureMessage case final message?) ...[
          const SizedBox(height: 12),
          AppFailureBanner(
            message: message,
            actions: [
              AppFailureBannerAction(
                title: LocaleKeys.app_downloader_buttons_hide.tr(),
                onPressed: onDismissFailurePressed,
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _googleSignIn(context),
      ],
    ),
  );
}
