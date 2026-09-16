import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../app_buttons/app_buttons.dart';

/// YouTube account at the bottom of the navigation bar: the sign-in button,
/// or the connected account with signing out. [compact] shows only an icon
class AppAccountStatus extends StatelessWidget {
  static const _compactButtonSize = 44.0;

  final bool isChecking;
  final bool isSigningIn;
  final bool isSignedIn;

  /// Signing out is not allowed while a download is running
  final bool signOutEnabled;
  final bool compact;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSignOutPressed;

  const AppAccountStatus({
    super.key,
    required this.isChecking,
    required this.isSigningIn,
    required this.isSignedIn,
    this.signOutEnabled = true,
    this.compact = false,
    this.onSignInPressed,
    this.onSignOutPressed,
  });

  String? get _busyText => isChecking
      ? LocaleKeys.app_authorization_checking.tr()
      : isSigningIn
      ? LocaleKeys.app_authorization_waiting.tr()
      : null;

  Widget _compactButton(BuildContext context) => switch (_busyText) {
    final text? => AppIconButton(
      icon: Icons.hourglass_empty_rounded,
      tooltip: text,
      size: _compactButtonSize,
      iconSize: 20,
    ),
    null when isSignedIn => AppIconButton(
      icon: Icons.logout_rounded,
      tooltip: [
        LocaleKeys.app_authorization_signed_in.tr(),
        LocaleKeys.app_authorization_sign_out.tr(),
      ].join(' · '),
      size: _compactButtonSize,
      iconSize: 20,
      onPressed: signOutEnabled ? onSignOutPressed : null,
    ),
    null => AppIconButton(
      icon: Icons.login_rounded,
      tooltip: LocaleKeys.app_authorization_sign_in.tr(),
      iconColor: context.color.accent,
      size: _compactButtonSize,
      iconSize: 20,
      onPressed: onSignInPressed,
    ),
  };

  Widget _expandedContent(BuildContext context) => switch (_busyText) {
    final text? => Text(
      text,
      style: context.text.captionRegular.copyWith(
        color: context.color.textHint,
      ),
    ),
    null when isSignedIn => Row(
      children: [
        Icon(
          Icons.account_circle_outlined,
          size: 18,
          color: context.color.accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            LocaleKeys.app_authorization_signed_in.tr(),
            maxLines: 2,
            style: context.text.captionRegular.copyWith(
              color: context.color.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppLinkButton(
          title: LocaleKeys.app_authorization_sign_out.tr(),
          titleColor: context.color.textSecondary,
          onPressed: signOutEnabled ? onSignOutPressed : null,
        ),
      ],
    ),
    null => AppSecondaryButton(
      title: LocaleKeys.app_authorization_sign_in.tr(),
      onPressed: onSignInPressed,
      compact: true,
    ),
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.color.border)),
    ),
    child: compact
        ? Center(child: _compactButton(context))
        : _expandedContent(context),
  );
}
