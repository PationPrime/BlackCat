import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// YouTube account in the page header. Cookies come first: adding them is
/// the button, the Google sign-in window is a link next to it. A signed-in
/// account shows where it came from, with signing out
class AccountStatus extends StatelessWidget {
  final AuthorizationState authorizationState;

  /// Signing out is not allowed while a download is running
  final bool signOutEnabled;

  /// Adds cookies, or updates the imported ones
  final VoidCallback? onAddCookiesPressed;

  /// The Google sign-in window: the page warns before opening it
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSignOutPressed;

  const AccountStatus({
    super.key,
    required this.authorizationState,
    this.signOutEnabled = true,
    this.onAddCookiesPressed,
    this.onSignInPressed,
    this.onSignOutPressed,
  });

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: context.text.captionRegular.copyWith(
      color: context.color.textTertiary,
    ),
  );

  Widget _signOut(BuildContext context) => AppLinkButton(
    title: LocaleKeys.app_authorization_sign_out.tr(),
    titleColor: context.color.textSecondary,
    onPressed: signOutEnabled ? onSignOutPressed : null,
  );

  @override
  Widget build(BuildContext context) {
    if (authorizationState.isBusy) {
      return Text(
        authorizationState.isChecking
            ? LocaleKeys.app_authorization_checking.tr()
            : LocaleKeys.app_authorization_waiting.tr(),
        style: context.text.captionRegular.copyWith(
          color: context.color.textHint,
        ),
      );
    }

    return switch (authorizationState.session) {
      final session? when session.isImported => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(context, LocaleKeys.app_authorization_signed_in_cookies.tr()),
          const SizedBox(width: 12),
          AppLinkButton(
            title: LocaleKeys.app_authorization_update.tr(),
            onPressed: onAddCookiesPressed,
          ),
          const SizedBox(width: 12),
          _signOut(context),
        ],
      ),
      _? => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(context, LocaleKeys.app_authorization_signed_in.tr()),
          const SizedBox(width: 12),
          _signOut(context),
        ],
      ),
      null => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLinkButton(
            title: LocaleKeys.app_authorization_sign_in.tr(),
            titleColor: context.color.textSecondary,
            onPressed: onSignInPressed,
          ),
          const SizedBox(width: 16),
          AppSecondaryButton(
            title: LocaleKeys.app_authorization_add_cookies.tr(),
            onPressed: onAddCookiesPressed,
            compact: true,
          ),
        ],
      ),
    };
  }
}
