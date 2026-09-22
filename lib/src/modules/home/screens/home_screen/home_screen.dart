import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';

import '../../components/components.dart';

/// Videos by link: a tab for every video site, in the order of the child
/// routes. Each tab keeps its search while another one is open
@RoutePage()
class HomeScreen extends StatelessWidget {
  static const _tabTitles = [
    LocaleKeys.app_home_tabs_youtube,
    LocaleKeys.app_home_tabs_rutube,
    LocaleKeys.app_home_tabs_tiktok,
  ];

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AutoTabsScaffold(
    backgroundColor: context.color.transparent,

    /// The pages draw their background under the tabs
    extendBodyBehindAppBar: true,
    appBarBuilder: (context, tabsRouter) => AppBar(
      backgroundColor: context.color.transparent,
      surfaceTintColor: context.color.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      notificationPredicate: (_) => false,
      automaticallyImplyLeading: false,
      centerTitle: true,
      toolbarHeight: 64,
      title: HomeSourceTabs(
        titles: [for (final title in _tabTitles) title.tr()],
        selectedIndex: tabsRouter.activeIndex,
        onSelected: tabsRouter.setActiveIndex,
      ),
    ),
  );
}
