import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Settings header: back to downloads and the title
class SettingsHeader extends StatelessWidget {
  final VoidCallback? onBackPressed;

  const SettingsHeader({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: LocaleKeys.app_settings_back.tr(),
        onPressed: onBackPressed,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          LocaleKeys.app_settings_title.tr(),
          style: context.text.header5Semibold,
        ),
      ),
    ],
  );
}
