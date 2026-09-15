import 'package:flutter/widgets.dart';

import 'design_system/design_system.dart';
import 'downloader_app.dart';
import 'repositories/repositories.dart';
import 'router/app_router.dart';
import 'services/services.dart';
import 'shared_controllers/shared_controllers.dart';

class RunnerApp extends StatelessWidget {
  final AppThemeType appThemeType;
  final AppRouter appRouter;
  final FileSystemService fileSystemService;
  final AuthenticationRepositoryInterface authenticationRepository;
  final VideoRepositoryInterface videoRepository;
  final AuthorizationController authorizationController;

  const RunnerApp({
    super.key,
    required this.appThemeType,
    required this.appRouter,
    required this.fileSystemService,
    required this.authenticationRepository,
    required this.videoRepository,
    required this.authorizationController,
  });

  @override
  Widget build(BuildContext context) => DownloaderApp(
    appThemeType: appThemeType,
    appRouter: appRouter,
    fileSystemService: fileSystemService,
    authenticationRepository: authenticationRepository,
    videoRepository: videoRepository,
    authorizationController: authorizationController,
  );
}
