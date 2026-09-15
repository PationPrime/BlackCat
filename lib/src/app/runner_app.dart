import 'package:flutter/widgets.dart';

import 'design_system/design_system.dart';
import 'downloader_app.dart';
import 'models/models.dart';
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
  final SettingsRepositoryInterface settingsRepository;
  final DownloadQueueRepositoryInterface downloadQueueRepository;
  final AuthorizationController authorizationController;
  final SettingsController settingsController;
  final AppWindowController appWindowController;
  final SystemTrayController systemTrayController;

  /// Language of the first frame: the one saved in the settings
  final AppLanguageModel initialLanguage;

  const RunnerApp({
    super.key,
    required this.appThemeType,
    required this.appRouter,
    required this.fileSystemService,
    required this.authenticationRepository,
    required this.videoRepository,
    required this.settingsRepository,
    required this.downloadQueueRepository,
    required this.authorizationController,
    required this.settingsController,
    required this.appWindowController,
    required this.systemTrayController,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) => DownloaderApp(
    appThemeType: appThemeType,
    appRouter: appRouter,
    fileSystemService: fileSystemService,
    authenticationRepository: authenticationRepository,
    videoRepository: videoRepository,
    settingsRepository: settingsRepository,
    downloadQueueRepository: downloadQueueRepository,
    authorizationController: authorizationController,
    settingsController: settingsController,
    appWindowController: appWindowController,
    systemTrayController: systemTrayController,
    initialLanguage: initialLanguage,
  );
}
