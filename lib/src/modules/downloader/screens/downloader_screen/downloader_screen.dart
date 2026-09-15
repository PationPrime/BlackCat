import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

@RoutePage()
class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;

  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onUrlSubmitted(String url) {
    if (url.trim().isEmpty) {
      _urlFocusNode.requestFocus();

      return;
    }

    context.read<DownloaderController>().fetchVideoInfo(url);
  }

  /// Текст кнопки под ошибкой, которую исправит вход в YouTube
  String _signInActionTitle(AuthorizationState authorizationState) =>
      authorizationState.isInProgress
      ? LocaleKeys.app_authorization_waiting.tr()
      : authorizationState.isAuthorized
      ? LocaleKeys.app_downloader_buttons_refresh_sign_in_and_retry.tr()
      : LocaleKeys.app_downloader_buttons_sign_in_and_retry.tr();

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthorizationController, AuthorizationState>(
        /// Ошибки входа и выхода показываются в общем сообщении экрана
        listenWhen: (previous, current) =>
            current.failure != null && current.failure != previous.failure,
        listener: (context, authorizationState) => context
            .read<DownloaderController>()
            .showFailure(authorizationState.failure!),
        child: BlocBuilder<AuthorizationController, AuthorizationState>(
          builder: (context, authorizationState) =>
              BlocBuilder<DownloaderController, DownloaderState>(
                builder: (context, downloaderState) => AppScaffold(
                  body: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: constraints.maxWidth >= _wideLayoutBreakpoint
                            ? 64
                            : 40,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _contentMaxWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DownloaderHeader(
                                authorizationState: authorizationState,
                                signOutEnabled: !downloaderState.isJobActive,
                                onSignInPressed: context
                                    .read<AuthorizationController>()
                                    .signIn,
                                onSignOutPressed: context
                                    .read<AuthorizationController>()
                                    .signOut,
                              ),
                              const SizedBox(height: 32),
                              UrlSearchForm(
                                controller: _urlController,
                                focusNode: _urlFocusNode,
                                loading: downloaderState.isInfoLoading,
                                enabled: downloaderState.canSearch,
                                onSubmitted: _onUrlSubmitted,
                              ),

                              /// Сообщение об ошибке; если поможет вход в YouTube — с кнопкой входа
                              if (downloaderState.failure case final failure?) ...[
                                const SizedBox(height: 16),
                                AppFailureBanner(
                                  message: failure.message,
                                  actionTitle:
                                      failure is VideoFailure &&
                                          failure.needsSignIn
                                      ? _signInActionTitle(authorizationState)
                                      : null,
                                  onActionPressed: authorizationState.isBusy
                                      ? null
                                      : context
                                            .read<DownloaderController>()
                                            .signInAndRetry,
                                ),
                              ],
                              if (downloaderState.videoInfo
                                  case final videoInfo?) ...[
                                const SizedBox(height: 32),
                                VideoCard(
                                  videoInfo: videoInfo,
                                  children: [
                                    QualityPicker(
                                      qualities: videoInfo.qualities,
                                      selectedQualityId:
                                          downloaderState.selectedQualityId,
                                      enabled: !downloaderState.isJobActive,
                                      onSelected: context
                                          .read<DownloaderController>()
                                          .selectQuality,
                                    ),
                                    if (downloaderState.job case final job?)
                                      DownloadProgressView(
                                        job: job,
                                        onShowInFolderPressed:
                                            job.filePath is String
                                            ? () => context
                                                  .read<FileSystemService>()
                                                  .revealInExplorer(
                                                    job.filePath!,
                                                  )
                                            : null,
                                      )
                                    else
                                      AppPrimaryButton(
                                        title: LocaleKeys
                                            .app_downloader_buttons_download
                                            .tr(),
                                        onPressed: downloaderState.canDownload
                                            ? context
                                                  .read<DownloaderController>()
                                                  .download
                                            : null,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      );
}
