part of 'downloader_header.dart';

class _DownloaderAccountStatus extends StatelessWidget {
  final AuthorizationState authorizationState;
  final bool signOutEnabled;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSignOutPressed;

  const _DownloaderAccountStatus({
    required this.authorizationState,
    required this.signOutEnabled,
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

    return AppPrimaryButton(
      title: LocaleKeys.app_authorization_sign_in.tr(),
      onPressed: onSignInPressed,
      buttonColor: context.color.transparent,
      hoverColor: context.color.hoverOverlay,
      titleColor: context.color.textSecondary,
      borderColor: context.color.border,
      titleStyle: context.text.captionMedium,
      borderRadius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
