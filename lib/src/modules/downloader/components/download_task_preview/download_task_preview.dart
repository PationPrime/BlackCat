import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../quality_picker/quality_picker.dart';

/// Thumbnail, title, quality and channel of a download. Below them: [subtitle],
/// the download state
class DownloadTaskPreview extends StatelessWidget {
  static const _thumbnailWidth = 112.0;

  final DownloadTaskModel task;
  final Widget? subtitle;

  const DownloadTaskPreview({super.key, required this.task, this.subtitle});

  String get _meta => [
    QualityPicker.titleOf(task.quality),
    task.video.channel,
    AppFormatters.duration(task.video.duration),
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: _thumbnailWidth,
        child: AppVideoThumbnail(
          url: task.video.thumbnail,
          filePath: task.thumbnailPath,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium.copyWith(
                color: context.color.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.captionRegular.copyWith(
                color: context.color.textTertiary,
              ),
            ),
            if (subtitle case final subtitle?) ...[
              const SizedBox(height: 6),
              subtitle,
            ],
          ],
        ),
      ),
    ],
  );
}
