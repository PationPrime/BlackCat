import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Interface language: one option per supported language
class LanguageCard extends StatelessWidget {
  final AppLanguageModel selectedLanguage;
  final ValueChanged<AppLanguageModel>? onLanguageSelected;

  const LanguageCard({
    super.key,
    required this.selectedLanguage,
    this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.app_settings_language_title.tr(),
          style: context.text.bodyMedium.copyWith(
            color: context.color.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.app_settings_language_description.tr(),
          style: context.text.captionRegular.copyWith(
            color: context.color.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final language in AppLanguageModel.values)
              AppSelectableChip(
                title: language.nativeName,
                selected: language == selectedLanguage,
                onPressed: onLanguageSelected == null
                    ? null
                    : () => onLanguageSelected!(language),
              ),
          ],
        ),
      ],
    ),
  );
}
