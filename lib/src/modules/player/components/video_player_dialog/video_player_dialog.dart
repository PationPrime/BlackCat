import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peeky_cat/src/app/constants/constants.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/services/services.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

import '../../../../generated/assets/assets.gen.dart';
import '../../controllers/controllers.dart';

part 'video_player_controls.dart';
part 'video_player_flash.dart';
part 'video_player_surface.dart';
part 'video_progress_bar.dart';
part 'video_seek_indicator.dart';
part 'video_speed_button.dart';
part 'video_volume_control.dart';

/// YouTube-like player of a library video: a dialog over 80% of the window
/// that expands to the whole screen
class VideoPlayerDialog extends StatefulWidget {
  const VideoPlayerDialog({super.key});

  /// Plays [video] from where the user stopped. The watch position is saved
  /// when the dialog closes
  static Future<void> show(
    BuildContext context, {
    required LibraryVideoModel video,
  }) {
    final videoLibraryController = context.read<VideoLibraryController>();

    return showDialog<void>(
      context: context,
      barrierColor: context.color.scrim,
      useSafeArea: false,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider<VideoLibraryController>.value(
            value: videoLibraryController,
          ),
          BlocProvider<VideoPlaybackController>(
            create: (context) => VideoPlaybackController(
              videoPlayerService: context.read<VideoPlayerService>(),
              videoLibraryController: videoLibraryController,
              video: video,
            )..open(),
          ),
        ],
        child: const VideoPlayerDialog(),
      ),
    );
  }

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  static const _resizeDuration = Duration(milliseconds: 200);

  late final AppWindowController _appWindowController;

  @override
  void initState() {
    super.initState();

    _appWindowController = context.read<AppWindowController>();
  }

  @override
  void dispose() {
    /// The window does not stay full screen without the video
    if (_appWindowController.state.isFullScreen) {
      unawaited(_appWindowController.setFullScreen(false));
    }

    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final isFullScreen = context.select(
      (AppWindowController controller) => controller.state.isFullScreen,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction = isFullScreen
            ? 1.0
            : PlayerConstants.dialogWindowFraction;

        return Center(
          child: AnimatedContainer(
            duration: _resizeDuration,
            curve: Curves.easeOutCubic,
            width: constraints.maxWidth * fraction,
            height: constraints.maxHeight * fraction,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.color.player,
              borderRadius: BorderRadius.circular(isFullScreen ? 0 : 16),
              border: isFullScreen
                  ? null
                  : Border.all(color: context.color.border),
              boxShadow: [
                BoxShadow(
                  color: context.color.player.withValues(alpha: 0.5),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: _VideoPlayerSurface(
                isFullScreen: isFullScreen,
                onToggleFullScreen: _appWindowController.toggleFullScreen,
                onClose: _close,
              ),
            ),
          ),
        );
      },
    );
  }
}
