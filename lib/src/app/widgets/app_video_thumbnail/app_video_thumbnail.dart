import 'dart:io';

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// 16:9 video thumbnail. Without a thumbnail or on a loading error: an empty plate
class AppVideoThumbnail extends StatelessWidget {
  final String? url;

  /// Local copy of the thumbnail: shown first, [url] is the fallback
  /// if the file is missing
  final String? filePath;
  final BorderRadius borderRadius;

  const AppVideoThumbnail({
    super.key,
    this.url,
    this.filePath,
    this.borderRadius = BorderRadius.zero,
  });

  Widget? _networkImage() => url is String
      ? Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        )
      : null;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: context.color.background,
        child: filePath is String
            ? Image.file(
                File(filePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _networkImage() ?? const SizedBox.shrink(),
              )
            : _networkImage(),
      ),
    ),
  );
}
