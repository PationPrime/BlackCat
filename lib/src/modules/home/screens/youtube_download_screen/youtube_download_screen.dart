import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/failure/failure.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/dependencies/module.dart';
import 'package:black_cat/src/modules/downloads/controllers/controllers.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// YouTube videos by link: the search, the account and the sign-in that
/// many errors need
@RoutePage()
class YouTubeDownloadScreen extends StatelessWidget
    implements AutoRouteWrapper {
  const YouTubeDownloadScreen({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<AddVideoController>(
        create: (context) => AddVideoController(
          videoRepository: context.read<VideoRepositoryInterface>(),
          ytDlpVideoRepository: context.read<YtDlpVideoRepositoryInterface>(),
          authorizationController: context.read<AuthorizationController>(),
        ),
      ),
      BlocProvider<DirectDownloadController>(
        create: (context) => DirectDownloadController(
          fileSystemService: context.read<FileSystemService>(),
        ),
      ),
    ],
    child: this,
  );

  /// The search repeats on its own once cookies are imported
  static void _importCookies(BuildContext context) => context
      .read<AppNavigationController>()
      .openCookiesImport(returnTab: AppTabModel.home);

  /// Title of the button under an error that signing in to YouTube will fix
  static String _signInActionTitle(AuthorizationState authorizationState) =>
      authorizationState.isInProgress
      ? LocaleKeys.app_authorization_waiting.tr()
      : authorizationState.isAuthorized
      ? LocaleKeys.app_downloader_buttons_refresh_sign_in_and_retry.tr()
      : LocaleKeys.app_downloader_buttons_sign_in_and_retry.tr();

  static List<AppFailureBannerAction> _failureActions(
    BuildContext context,
    Failure failure,
    AuthorizationState authorizationState,
  ) {
    if (failure is! VideoFailure || !failure.needsSignIn) {
      return const [];
    }

    return [
      AppFailureBannerAction(
        title: _signInActionTitle(authorizationState),
        onPressed: authorizationState.isBusy
            ? null
            : context.read<AddVideoController>().signInAndRetry,
      ),
      AppFailureBannerAction(
        title: LocaleKeys.app_downloader_buttons_import_cookies.tr(),
        onPressed: authorizationState.isBusy
            ? null
            : () => _importCookies(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasRunningTask = context.select(
      (DownloadQueueController controller) => controller.state.hasRunningTask,
    );
    final dependenciesStatus = context.select(
      (DependenciesController controller) => controller.state.status,
    );

    return BlocListener<AuthorizationController, AuthorizationState>(
      /// Sign-in errors are shown in the page message
      listenWhen: (previous, current) =>
          current.failure != null && current.failure != previous.failure,
      listener: (context, authorizationState) => context
          .read<AddVideoController>()
          .showFailure(authorizationState.failure!),
      child: BlocBuilder<AuthorizationController, AuthorizationState>(
        builder: (context, authorizationState) => VideoSearchView(
          title: LocaleKeys.app_home_youtube_title.tr(),
          subtitle: LocaleKeys.app_home_youtube_subtitle.tr(),
          headerTrailing: AccountStatus(
            authorizationState: authorizationState,
            signOutEnabled: !hasRunningTask,
            onSignInPressed: context.read<AuthorizationController>().signIn,
            onSignOutPressed: context.read<AuthorizationController>().signOut,
          ),
          formFooter: DependenciesHint(
            status: dependenciesStatus,
            onInstallPressed: () => DependenciesInstallDialog.show(context),
          ),

          /// Error message; if signing in to YouTube will help, with
          /// the sign-in and the cookies import
          failureActions: (failure) =>
              _failureActions(context, failure, authorizationState),
        ),
      ),
    );
  }
}
