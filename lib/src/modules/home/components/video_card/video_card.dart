import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/tools/tools.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// Found video card: thumbnail, title, channel, duration, views.
/// Below them: [children], quality selection and download
class VideoCard extends StatelessWidget {
  final VideoInfoModel videoInfo;
  final List<Widget> children;

  const VideoCard({
    super.key,
    required this.videoInfo,
    this.children = const [],
  });

  String get _meta => [
    videoInfo.channel,
    AppFormatters.duration(videoInfo.duration),
    if (videoInfo.viewCount != null)
      LocaleKeys.app_downloader_video_views.tr(
        namedArgs: {'count': AppFormatters.count(videoInfo.viewCount)!},
      ),
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (videoInfo.thumbnail is String)
          AppVideoThumbnail(url: videoInfo.thumbnail),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                videoInfo.title,
                style: context.text.header4Semibold,
              ),
              if (_meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _meta,
                  style: context.text.captionRegular.copyWith(
                    color: context.color.textTertiary,
                  ),
                ),
              ],
              for (final child in children) ...[
                const SizedBox(height: 20),
                child,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
