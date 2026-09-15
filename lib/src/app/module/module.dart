import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';

import '../api/api.dart';
import '../data_sources/data_sources.dart';
import '../design_system/design_system.dart';
import '../localization/lang/locale_keys.g.dart';
import '../logger/app_logger.dart';
import '../repositories/repositories.dart';
import '../router/app_router.dart';
import '../runner_app.dart';
import '../services/services.dart';
import '../session/session_store.dart';
import '../shared_controllers/shared_controllers.dart';

final class AppModule {
  AppModule._();

  static final instance = AppModule._();

  static const _appLogger = AppLogger(where: 'AppModule');

  static late final ApiProvider _apiProvider;
  static late final FileSystemService _fileSystemService;
  static late final AuthenticationRepositoryInterface _authenticationRepository;
  static late final VideoRepositoryInterface _videoRepository;
  static late final AuthorizationController _authorizationController;
  static late final AppRouter _appRouter;

  Future<void> initApp(List<String> args) async {
    FlutterError.onError = (details) {
      _appLogger.logError(
        'FlutterError: ${details.exception}',
        stackTrace: details.stack,
      );

      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _appLogger.logError('PlatformError: $error', stackTrace: stackTrace);

      return false;
    };

    await runZonedGuarded(
      () async {
        await _configureDependencies();

        _apiProvider = ApiProvider();

        _fileSystemService = FileSystemServiceImpl();

        final localAuthenticationDataSource = LocalAuthenticationDataSourceImpl(
          fileSystemService: _fileSystemService,
        );

        final signInWebViewPlatform = SignInWebViewPlatform(
          profileFolder: localAuthenticationDataSource.signInProfileFolder,
          windowTitle: LocaleKeys.app_authorization_window_title.tr,
        );

        /// flutter_web_auth_2 на Windows работает через эту реализацию
        FlutterWebAuth2Platform.instance = signInWebViewPlatform;

        _authenticationRepository = AuthenticationRepository(
          localDataSource: localAuthenticationDataSource,
          webDataSource: WebAuthenticationDataSourceImpl(
            signInWebViewPlatform: signInWebViewPlatform,
            localAuthenticationDataSource: localAuthenticationDataSource,
          ),
        );

        final sessionStore = SessionStore(
          localAuthenticationDataSource: localAuthenticationDataSource,
        );

        _videoRepository = YouTubeVideoRepository(
          remoteYouTubeDataSource: RemoteYouTubeDataSourceImpl(
            apiProvider: _apiProvider,
            sessionStore: sessionStore,
            localPlayerDataSource: LocalPlayerDataSourceImpl(
              fileSystemService: _fileSystemService,
            ),
          ),
          remoteMediaStreamDataSource: RemoteMediaStreamDataSourceImpl(
            apiProvider: _apiProvider,
          ),
          challengeSolverService: ChallengeSolverServiceImpl(
            jsEngineService: WebViewJsEngineServiceImpl(
              fileSystemService: _fileSystemService,
            ),
            loadScript: (name) => rootBundle.loadString('assets/ejs/$name'),
          ),
          mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
          fileSystemService: _fileSystemService,
          sessionStore: sessionStore,
        );

        _authorizationController = AuthorizationController(
          authenticationRepository: _authenticationRepository,
        );

        _appRouter = AppRouter();

        runApp(
          RunnerApp(
            appThemeType: const AppDarkTheme(),
            appRouter: _appRouter,
            fileSystemService: _fileSystemService,
            authenticationRepository: _authenticationRepository,
            videoRepository: _videoRepository,
            authorizationController: _authorizationController,
          ),
        );
      },
      (error, stackTrace) {
        _appLogger.logError(
          'Internal YT Download error: $error',
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> _configureDependencies() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await EasyLocalization.ensureInitialized();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Failed to configure dependencies: $error'),
        stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    await _authorizationController.close();
  }
}
