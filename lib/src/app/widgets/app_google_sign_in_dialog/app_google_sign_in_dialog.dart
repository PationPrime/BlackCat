import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../app_buttons/app_buttons.dart';
import '../app_dialog/app_dialog.dart';

/// The way the user chose to sign in to YouTube
enum AppGoogleSignInChoice {
  /// Cookies from the browser: the recommended way
  addCookies,

  /// The Google sign-in window of the app, knowing the risks
  signIn,
}

/// Signing in with a Google account in the app window is a last resort:
/// the app is open source and not registered in the Google Cloud Console,
/// and the password is typed into the app window. The dialog tells so and
/// offers cookies first; the window stays one button away for those who
/// want it
class AppGoogleSignInDialog extends StatelessWidget {
  static const _maxWidth = 520.0;

  /// The account already uses imported cookies: they are updated, not added
  final bool cookiesImported;

  const AppGoogleSignInDialog({super.key, this.cookiesImported = false});

  /// The chosen way; `null` if the dialog was closed
  static Future<AppGoogleSignInChoice?> show(
    BuildContext context, {
    bool cookiesImported = false,
  }) => AppDialog.show<AppGoogleSignInChoice>(
    context,
    builder: (_) => AppGoogleSignInDialog(cookiesImported: cookiesImported),
  );

  /// Shows the dialog and goes the chosen way: [onAddCookies] or [onSignIn]
  static Future<void> run(
    BuildContext context, {
    required VoidCallback onAddCookies,
    required Future<void> Function() onSignIn,
    bool cookiesImported = false,
  }) async {
    final choice = await show(context, cookiesImported: cookiesImported);

    switch (choice) {
      case AppGoogleSignInChoice.addCookies:
        onAddCookies();
      case AppGoogleSignInChoice.signIn:
        await onSignIn();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    void choose(AppGoogleSignInChoice choice) =>
        Navigator.of(context).pop(choice);

    return AppDialog(
      title: LocaleKeys.app_authorization_google_dialog_title.tr(),
      maxWidth: _maxWidth,
      actions: [
        AppSecondaryButton(
          title: LocaleKeys.app_authorization_google_dialog_cancel.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppSecondaryButton(
          title: LocaleKeys.app_authorization_google_dialog_sign_in_anyway.tr(),
          onPressed: () => choose(AppGoogleSignInChoice.signIn),
        ),
        AppPrimaryButton(
          title: cookiesImported
              ? LocaleKeys.app_authorization_update_cookies.tr()
              : LocaleKeys.app_authorization_add_cookies.tr(),
          onPressed: () => choose(AppGoogleSignInChoice.addCookies),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Point(
              icon: Icons.code_rounded,
              text: LocaleKeys.app_authorization_google_dialog_open_source.tr(),
            ),
            const SizedBox(height: 14),
            _Point(
              icon: Icons.warning_amber_rounded,
              text: LocaleKeys.app_authorization_google_dialog_risks.tr(),
            ),
            const SizedBox(height: 14),
            _Point(
              icon: Icons.cookie_outlined,
              text: LocaleKeys.app_authorization_google_dialog_cookies.tr(),
              accent: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  /// The recommended way stands out
  final bool accent;

  const _Point({required this.icon, required this.text, this.accent = false});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 20,
        color: accent ? context.color.accent : context.color.iconPrimary,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: context.text.captionRegular.copyWith(
            color: accent
                ? context.color.textPrimary
                : context.color.textSecondary,
          ),
        ),
      ),
    ],
  );
}
