import 'package:auto_route/auto_route.dart';

import '../../modules/modules.dart';
import 'authorization_wrapper_router.dart';
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
            AutoRoute(
              path: RoutePaths.downloader,
              page: DownloaderRoute.page,
              initial: true,
            ),
          ],
        ),
      ],
    ),
  ];
}
