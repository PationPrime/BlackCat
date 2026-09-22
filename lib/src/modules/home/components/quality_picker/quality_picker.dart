import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// Quality selection: resolutions and "Audio only" with the approximate size
class QualityPicker extends StatelessWidget {
  final List<QualityModel> qualities;
  final String selectedQualityId;

  /// The quality does not change during a download
  final bool enabled;
  final ValueChanged<String>? onSelected;

  const QualityPicker({
    super.key,
    required this.qualities,
    required this.selectedQualityId,
    this.enabled = true,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        LocaleKeys.app_downloader_video_quality.tr().toUpperCase(),
        style: context.text.overlineRegular,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final quality in qualities)
            AppSelectableChip(
              title: DownloadTaskText.quality(quality),
              subtitle: switch (AppFileSize.format(quality.size)) {
                final size? => '~$size',
                null => null,
              },
              selected: quality.id == selectedQualityId,
              onPressed: enabled ? () => onSelected?.call(quality.id) : null,
            ),
        ],
      ),
    ],
  );
}
