import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

import '../../../../generated/assets/assets.gen.dart' show Assets;

part 'library_video_thumbnail.dart';

/// A video of the download folder: thumbnail with the play button
/// and the duration, title and where the user stopped
class LibraryVideoCard extends StatefulWidget {
  final LibraryVideoModel video;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onShowInFolderPressed;
  final VoidCallback? onDeletePressed;

  const LibraryVideoCard({
    super.key,
    required this.video,
    this.onPlayPressed,
    this.onShowInFolderPressed,
    this.onDeletePressed,
  });

  @override
  State<LibraryVideoCard> createState() => _LibraryVideoCardState();
}

class _LibraryVideoCardState extends State<LibraryVideoCard> {
  var _hovered = false;

  String get _details {
    final video = widget.video;
    final progress = video.isWatched
        ? LocaleKeys.app_player_watched.tr()
        : video.resumePosition > Duration.zero
        ? LocaleKeys.app_player_stopped_at.tr(
            namedArgs: {
              'time':
                  AppFormatters.duration(
                    video.resumePosition.inMilliseconds / 1000,
                  ) ??
                  '',
            },
          )
        : null;

    return [
      ?progress,
      ?AppFileSize.format(video.sizeBytes),
      ?AppFormatters.dateTime(video.modifiedAt),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryVideoThumbnail(
          video: widget.video,
          hovered: _hovered,
          onPlayPressed: widget.onPlayPressed,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onPlayPressed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium.copyWith(
                        color: context.color.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.captionRegular.copyWith(
                        color: context.color.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            AppIconButton(
              svgPictureIconPath: Assets.icons.iconFolder.path,
              tooltip: LocaleKeys.app_player_show_in_folder.tr(),
              onPressed: widget.onShowInFolderPressed,
            ),
            AppIconButton(
              svgPictureIconPath: Assets.icons.iconTrashEmpty.path,
              tooltip: LocaleKeys.app_player_delete.tr(),
              onPressed: widget.onDeletePressed,
            ),
          ],
        ),
      ],
    ),
  );
}
