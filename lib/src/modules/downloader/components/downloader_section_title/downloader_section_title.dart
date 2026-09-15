import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';

/// Screen section title with the item count and an action on the right
class DownloaderSectionTitle extends StatelessWidget {
  final String title;

  /// Hidden when equal to zero
  final int? count;
  final Widget? trailing;

  const DownloaderSectionTitle({
    super.key,
    required this.title,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Row(
      children: [
        Text(title.toUpperCase(), style: context.text.overlineRegular),
        if (count case final count? when count > 0) ...[
          const SizedBox(width: 8),
          Text(
            '$count',
            style: context.text.overlineRegular.copyWith(
              color: context.color.textTertiary,
            ),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}
