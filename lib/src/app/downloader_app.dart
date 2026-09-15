import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../modules/modules.dart';
import 'design_system/design_system.dart';
import 'downloader_app_view.dart';
import 'repositories/repositories.dart';
import 'router/app_router.dart';
import 'services/services.dart';
import 'shared_controllers/shared_controllers.dart';

class DownloaderApp extends StatelessWidget {
  final AppThemeType appThemeType;
  final AppRouter appRouter;
  final FileSystemService fileSystemService;
  final AuthenticationRepositoryInterface authenticationRepository;
  final VideoRepositoryInterface videoRepository;
  final AuthorizationController authorizationController;

  const DownloaderApp({
    super.key,
    required this.appThemeType,
    required this.appRouter,
    required this.fileSystemService,
    required this.authenticationRepository,
    required this.videoRepository,
    required this.authorizationController,
  });

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FileSystemService>.value(value: fileSystemService),
      RepositoryProvider<AuthenticationRepositoryInterface>.value(
        value: authenticationRepository,
      ),
      RepositoryProvider<VideoRepositoryInterface>.value(
        value: videoRepository,
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthorizationController>.value(
          value: authorizationController,
        ),
        BlocProvider<AppThemeController>(
          create: (context) =>
              AppThemeController(initialThemeType: appThemeType),
        ),
        BlocProvider<DownloaderController>(
          create: (context) => DownloaderController(
            videoRepository: context.read<VideoRepositoryInterface>(),
            authorizationController: context.read<AuthorizationController>(),
          ),
        ),
      ],
      child: DownloaderAppView(appRouter: appRouter),
    ),
  );
}
