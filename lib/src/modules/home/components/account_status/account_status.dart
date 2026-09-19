import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// YouTube account in the page header: the sign-in button, or the connected
/// account with signing out
class AccountStatus extends StatelessWidget {
  final AuthorizationState authorizationState;

  /// Signing out is not allowed while a download is running
  final bool signOutEnabled;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSignOutPressed;

  const AccountStatus({
    super.key,
    required this.authorizationState,
    this.signOutEnabled = true,
    this.onSignInPressed,
    this.onSignOutPressed,
  });

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

    if (authorizationState.isAuthorized) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.app_authorization_signed_in.tr(),
            style: context.text.captionRegular.copyWith(
              color: context.color.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          AppLinkButton(
            title: LocaleKeys.app_authorization_sign_out.tr(),
            titleColor: context.color.textSecondary,
            onPressed: signOutEnabled ? onSignOutPressed : null,
          ),
        ],
      );
    }

    return AppSecondaryButton(
      title: LocaleKeys.app_authorization_sign_in.tr(),
      onPressed: onSignInPressed,
      compact: true,
    );
  }
}
