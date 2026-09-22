import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// The app and its version: what to name in a bug report
class AboutCard extends StatelessWidget {
  /// `null` while it is read, or when the build does not tell it
  final AppVersionModel? appVersion;

  const AboutCard({super.key, this.appVersion});

  String? get _versionText => switch (appVersion) {
    final version? when version.hasBuildNumber =>
      LocaleKeys.app_settings_about_version_with_build.tr(
        namedArgs: {'version': version.version, 'build': version.buildNumber},
      ),
    final version? => LocaleKeys.app_settings_about_version.tr(
      namedArgs: {'version': version.version},
    ),
    null => null,
  };

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.app_settings_about_title.tr(),
          style: context.text.bodyMedium.copyWith(
            color: context.color.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const AppIconLogo(size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.app_title.tr(),
                    style: context.text.bodyMedium.copyWith(
                      color: context.color.textPrimary,
                    ),
                  ),
                  if (_versionText case final version?)
                    /// Selectable: the version goes into bug reports
                    SelectableText(
                      version,
                      style: context.text.captionRegular.copyWith(
                        color: context.color.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
