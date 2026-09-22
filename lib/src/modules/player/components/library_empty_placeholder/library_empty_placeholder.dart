import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// No videos in the download folder: a hint and the way to download one
class LibraryEmptyPlaceholder extends StatelessWidget {
  final String message;
  final String actionTitle;
  final VoidCallback? onActionPressed;

  const LibraryEmptyPlaceholder({
    super.key,
    required this.message,
    required this.actionTitle,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    backgroundColor: context.color.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Column(
      children: [
        Icon(
          Icons.video_library_outlined,
          size: 40,
          color: context.color.iconDisabled,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.captionRegular.copyWith(
            color: context.color.textHint,
          ),
        ),
        const SizedBox(height: 20),
        AppSecondaryButton(
          title: actionTitle,
          compact: true,
          onPressed: onActionPressed,
        ),
      ],
    ),
  );
}
