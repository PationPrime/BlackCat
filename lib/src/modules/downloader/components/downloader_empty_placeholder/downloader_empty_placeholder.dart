import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Empty screen section: a hint about what will appear in it
class DownloaderEmptyPlaceholder extends StatelessWidget {
  final String message;

  const DownloaderEmptyPlaceholder({super.key, required this.message});

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    backgroundColor: context.color.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: context.text.captionRegular.copyWith(
        color: context.color.textHint,
      ),
    ),
  );
}
