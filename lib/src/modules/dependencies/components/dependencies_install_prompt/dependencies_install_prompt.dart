import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

import '../dependencies_fallback_dialog/dependencies_fallback_dialog.dart';
import '../dependencies_install_dialog/dependencies_install_dialog.dart';

/// Installs yt-dlp as soon as the check finds it missing. If the installation
/// fails, explains that videos can still be downloaded by the built-in
/// downloader and how to sign in for it
class DependenciesInstallPrompt extends StatefulWidget {
  final Widget child;

  const DependenciesInstallPrompt({super.key, required this.child});

  @override
  State<DependenciesInstallPrompt> createState() =>
      _DependenciesInstallPromptState();
}

class _DependenciesInstallPromptState extends State<DependenciesInstallPrompt> {
  var _isPrompting = false;

  @override
  void initState() {
    super.initState();

    /// The check may finish before the screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) => _installIfMissing());
  }

  Future<void> _installIfMissing() async {
    if (!mounted ||
        _isPrompting ||
        !context.read<DependenciesController>().state.status.isMissing) {
      return;
    }

    _isPrompting = true;

    try {
      await _install();
    } finally {
      _isPrompting = false;
    }
  }

  Future<void> _install() async {
    final dependenciesController = context.read<DependenciesController>();
    final authorizationController = context.read<AuthorizationController>();
    final appNavigationController = context.read<AppNavigationController>();

    DependenciesFallbackAction? action;

    do {
      if (!mounted) return;

      final installed = await DependenciesInstallDialog.show(context);

      if (installed || !mounted) return;

      action = await DependenciesFallbackDialog.show(
        context,
        signedIn: authorizationController.state.isAuthorized,
        reason: dependenciesController.state.failure?.message,
      );
    } while (action == DependenciesFallbackAction.retryInstall);

    void importCookies() => appNavigationController.openCookiesImport(
      returnTab: appNavigationController.state.tab,
    );

    switch (action) {
      case DependenciesFallbackAction.addVideo:
        appNavigationController.selectTab(AppTabModel.home);
      case DependenciesFallbackAction.signIn:
        if (!mounted) return;

        /// The Google window only after the warning, which offers cookies
        await AppGoogleSignInDialog.run(
          context,
          onAddCookies: importCookies,
          onSignIn: authorizationController.signIn,
        );
      case DependenciesFallbackAction.importCookies:
        importCookies();
      case DependenciesFallbackAction.retryInstall || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<DependenciesController, DependenciesState>(
        listenWhen: (previous, current) =>
            previous.status != current.status && current.status.isMissing,
        listener: (context, _) => _installIfMissing(),
        child: widget.child,
      );
}
