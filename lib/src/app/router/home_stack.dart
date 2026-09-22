import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/assets/assets.gen.dart';
import '../../modules/modules.dart';
import '../design_system/design_system.dart';
import '../localization/lang/locale_keys.g.dart';
import '../models/models.dart';
import '../shared_controllers/shared_controllers.dart';
import '../widgets/widgets.dart';
import 'app_router.dart';

/// Pages of the app: the navigation bar on the left, the current download
/// over the bottom of the pages. [AppNavigationController] picks the page,
/// the tabs keep the state of the pages visited before
@RoutePage()
class HomeStackScreen extends StatelessWidget {
  const HomeStackScreen({super.key});

  /// In the order of [AppTabModel]
  static const _tabs = <PageRouteInfo>[
    HomeRoute(),
    DownloadsRoute(),
    PlayerRoute(),
    SettingsRoute(),
    DonationsRoute(),
  ];

  @override
  Widget build(BuildContext context) => DependenciesInstallPrompt(
    child: AutoTabsRouter(
      routes: _tabs,
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        return BlocListener<AppNavigationController, AppNavigationState>(
          listenWhen: (previous, current) => previous.tab != current.tab,
          listener: (context, navigationState) =>
              tabsRouter.setActiveIndex(navigationState.tab.index),
          child: _HomeStackLayout(
            activeTab: AppTabModel.values[tabsRouter.activeIndex],
            child: child,
          ),
        );
      },
    ),
  );
}

class _HomeStackLayout extends StatelessWidget {
  /// Below this width the navigation bar shows only icons
  static const _compactBreakpoint = 840.0;

  final AppTabModel activeTab;
  final Widget child;

  const _HomeStackLayout({required this.activeTab, required this.child});

  @override
  Widget build(BuildContext context) => Material(
    color: context.color.background,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// The navigation bar takes the whole height of the window
            _HomeStackNavigationBar(activeTab: activeTab, compact: compact),
            Expanded(child: _HomeStackPages(child: child)),
          ],
        );
      },
    ),
  );
}

/// Pages with the footer over their bottom. Pages get the footer height
/// as the bottom [MediaQueryData.padding], so their content scrolls
/// out from under it
class _HomeStackPages extends StatelessWidget {
  final Widget child;

  const _HomeStackPages({required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    /// A full-screen video covers the whole window
    final fullScreen = context.select(
      (AppWindowController controller) => controller.state.isFullScreen,
    );

    return Stack(
      children: [
        /// One background for every page: the pages are clear
        Positioned.fill(child: AppLavaBackground(animate: !fullScreen)),
        Positioned.fill(
          child: MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(
                bottom: mediaQuery.padding.bottom + DownloadFooter.height,
              ),
            ),
            child: child,
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _HomeStackFooter(),
        ),
      ],
    );
  }
}

class _HomeStackNavigationBar extends StatelessWidget {
  final AppTabModel activeTab;
  final bool compact;

  const _HomeStackNavigationBar({
    required this.activeTab,
    required this.compact,
  });

  Widget _header(BuildContext context) {
    const logo = AppIconLogo();

    return Padding(
      /// The app title bar lies over the top of the window
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : 28,
        MediaQuery.paddingOf(context).top + 20,
        compact ? 0 : 16,
        20,
      ),
      child: compact
          ? Center(
              child: Tooltip(message: LocaleKeys.app_title.tr(), child: logo),
            )
          : Row(
              children: [
                logo,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocaleKeys.app_title.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.header5Semibold,
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unfinishedCount = context.select(
      (DownloadQueueController controller) =>
          controller.state.queue.length +
          (controller.state.activeTask == null ? 0 : 1),
    );

    return AppNavigationBar(
      compact: compact,
      selectedIndex: activeTab.index,
      onSelected: (index) => context.read<AppNavigationController>().selectTab(
        AppTabModel.values[index],
      ),
      header: _header(context),
      items: [
        for (final tab in AppTabModel.values)
          switch (tab) {
            AppTabModel.home => AppNavigationBarItemData(
              title: LocaleKeys.app_navigation_home.tr(),
              svgPictureFilePath: Assets.icons.iconNavbarHome.path,
            ),
            AppTabModel.downloads => AppNavigationBarItemData(
              title: LocaleKeys.app_navigation_downloads.tr(),
              svgPictureFilePath: Assets.icons.iconNavbarDownload.path,
              badge: unfinishedCount,
            ),
            AppTabModel.player => AppNavigationBarItemData(
              title: LocaleKeys.app_navigation_player.tr(),
              svgPictureFilePath: Assets.icons.iconNavbarPlayer.path,
            ),
            AppTabModel.settings => AppNavigationBarItemData(
              title: LocaleKeys.app_navigation_settings.tr(),
              svgPictureFilePath: Assets.icons.iconNavbarSettings.path,
            ),
            AppTabModel.donations => AppNavigationBarItemData(
              title: LocaleKeys.app_navigation_donations.tr(),
              svgPictureFilePath: Assets.icons.iconNavbarHeart.path,
            ),
          },
      ],
    );
  }
}

class _HomeStackFooter extends StatelessWidget {
  const _HomeStackFooter();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DownloadQueueController, DownloadQueueState>(
        builder: (context, queueState) {
          final downloadQueueController = context
              .read<DownloadQueueController>();

          return DownloadFooter(
            task: queueState.activeTask,
            queuedCount: queueState.queue.length,
            onOpenPressed: () => context
                .read<AppNavigationController>()
                .selectTab(AppTabModel.downloads),
            onPausePressed: downloadQueueController.pauseActiveTask,
            onResumePressed: downloadQueueController.resumeActiveTask,
          );
        },
      );
}
