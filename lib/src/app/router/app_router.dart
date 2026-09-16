import 'package:auto_route/auto_route.dart';

import '../../modules/modules.dart';
import 'authorization_wrapper_router.dart';
import 'home_stack.dart';
import 'main_wrapper_router.dart';
import 'navigator_key_provider.dart';

part 'app_router.gr.dart';
part 'route_paths.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  AppRouter() : super(navigatorKey: NavigatorKeyProvider.instance);

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: RoutePaths.root,
      page: AuthorizationWrapperRouter.page,
      children: [
        AutoRoute(
          path: '',
          page: MainWrapperRouter.page,
          children: [
            /// Pages of the navigation bar, in the order of its buttons
            AutoRoute(
              path: '',
              page: HomeStackRoute.page,
              children: [
                AutoRoute(
                  path: RoutePaths.home,
                  page: HomeRoute.page,
                  initial: true,
                ),
                AutoRoute(
                  path: RoutePaths.downloads,
                  page: DownloadsRoute.page,
                ),
                AutoRoute(path: RoutePaths.settings, page: SettingsRoute.page),
                AutoRoute(
                  path: RoutePaths.donations,
                  page: DonationsRoute.page,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
