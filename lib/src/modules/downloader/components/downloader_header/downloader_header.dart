import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

part 'downloader_account_status.dart';

/// Header: app name, YouTube sign-in state and settings
class DownloaderHeader extends StatelessWidget {
  final AuthorizationState authorizationState;

  /// Signing out is not allowed while a download is running
  final bool signOutEnabled;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSignOutPressed;
  final VoidCallback? onSettingsPressed;

  const DownloaderHeader({
    super.key,
    required this.authorizationState,
    this.signOutEnabled = true,
    this.onSignInPressed,
    this.onSignOutPressed,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: context.color.accent,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          LocaleKeys.app_title.tr(),
          style: context.text.header5Semibold,
        ),
      ),
      _DownloaderAccountStatus(
        authorizationState: authorizationState,
        signOutEnabled: signOutEnabled,
        onSignInPressed: onSignInPressed,
        onSignOutPressed: onSignOutPressed,
      ),
      const SizedBox(width: 8),
      AppIconButton(
        icon: Icons.settings_outlined,
        tooltip: LocaleKeys.app_downloader_buttons_settings.tr(),
        onPressed: onSettingsPressed,
      ),
    ],
  );
}
