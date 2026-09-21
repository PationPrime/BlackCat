import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// Videos of the download folder as cards; a card opens the player
@RoutePage()
class PlayerScreen extends StatelessWidget implements AutoRouteWrapper {
  static const _contentMaxWidth = 1200.0;
  static const _wideLayoutBreakpoint = 640.0;
  static const _minHorizontalPadding = 16.0;
  static const _minCardWidth = 240.0;
  static const _cardSpacing = 20.0;
  static const _rowSpacing = 28.0;

  /// Gap between the window title bar and the page header
  static const _minTopGap = 24.0;

  const PlayerScreen({super.key});

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<VideoLibraryController>(
        create: (context) => VideoLibraryController(
          videoLibraryRepository: context
              .read<VideoLibraryRepositoryInterface>(),
          settingsController: context.read<SettingsController>(),
        )..load(),
        child: this,
      );

  Widget _header(BuildContext context, VideoLibraryState libraryState) {
    final videoLibraryController = context.read<VideoLibraryController>();
    final folder = libraryState.folder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: LocaleKeys.app_player_title.tr(),
          subtitle: LocaleKeys.app_player_subtitle.tr(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconButton(
                icon: Icons.refresh_rounded,
                tooltip: LocaleKeys.app_player_refresh.tr(),
                onPressed: folder == null
                    ? null
                    : videoLibraryController.refresh,
              ),
              const SizedBox(width: 8),
              AppSecondaryButton(
                title: LocaleKeys.app_player_open_folder.tr(),
                compact: true,
                onPressed: folder == null
                    ? null
                    : () =>
                          context.read<FileSystemService>().openFolder(folder),
              ),
            ],
          ),
        ),
        if (folder != null) ...[
          const SizedBox(height: 12),
          Text(
            LocaleKeys.app_player_folder.tr(namedArgs: {'path': folder}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.captionRegular.copyWith(
              color: context.color.textHint,
            ),
          ),
        ],
        if (libraryState.failure case final failure?) ...[
          const SizedBox(height: 16),
          AppFailureBanner(
            message: failure.message,
            actions: [
              AppFailureBannerAction(
                title: LocaleKeys.app_player_retry.tr(),
                onPressed: videoLibraryController.refresh,
              ),
              AppFailureBannerAction(
                title: LocaleKeys.app_downloader_buttons_hide.tr(),
                onPressed: videoLibraryController.dismissFailure,
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _card(BuildContext context, LibraryVideoModel video) =>
      LibraryVideoCard(
        key: ValueKey(video.id),
        video: video,
        onPlayPressed: () => VideoPlayerDialog.show(context, video: video),
        onShowInFolderPressed: () =>
            context.read<FileSystemService>().revealInExplorer(video.path),
      );

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<AppNavigationController, AppNavigationState>(
    /// Coming back to the page reads the folder again: a file may have
    /// changed while the folder was not followed
    listenWhen: (previous, current) =>
        previous.tab != current.tab && current.tab == AppTabModel.player,
    listener: (context, _) => context.read<VideoLibraryController>().refresh(),
    child: BlocBuilder<VideoLibraryController, VideoLibraryState>(
      builder: (context, libraryState) {
        final videos = libraryState.videos;

        return AppScaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = math.max(
                _minHorizontalPadding,
                (constraints.maxWidth - _contentMaxWidth) / 2,
              );
              final verticalPadding =
                  constraints.maxWidth >= _wideLayoutBreakpoint ? 64.0 : 40.0;

              /// The app title bar lies over the top of the screen
              final topPadding = math.max(
                verticalPadding,
                MediaQuery.paddingOf(context).top + _minTopGap,
              );
              final contentWidth = constraints.maxWidth - horizontalPadding * 2;
              final columns = math.max(
                1,
                ((contentWidth + _cardSpacing) / (_minCardWidth + _cardSpacing))
                    .floor(),
              );
              final rows = (videos.length / columns).ceil();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _header(context, libraryState),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: switch (libraryState) {
                      VideoLibraryState(isLoading: true) when videos.isEmpty =>
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      VideoLibraryState(failure: null) when videos.isEmpty =>
                        SliverToBoxAdapter(
                          child: LibraryEmptyPlaceholder(
                            message: LocaleKeys.app_player_empty.tr(),
                            actionTitle: LocaleKeys.app_player_download_video
                                .tr(),
                            onActionPressed: () => context
                                .read<AppNavigationController>()
                                .selectTab(AppTabModel.home),
                          ),
                        ),
                      _ => SliverList.builder(
                        itemCount: rows,
                        itemBuilder: (context, row) => Padding(
                          padding: const EdgeInsets.only(bottom: _rowSpacing),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var column = 0;
                                column < columns;
                                column++
                              ) ...[
                                if (column > 0)
                                  const SizedBox(width: _cardSpacing),
                                Expanded(
                                  child: switch (row * columns + column) {
                                    final index when index < videos.length =>
                                      _card(context, videos[index]),
                                    _ => const SizedBox.shrink(),
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    },
                  ),

                  /// The download footer lies over the bottom
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          verticalPadding +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}
