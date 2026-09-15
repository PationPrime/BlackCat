import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../shared_controllers/shared_controllers.dart';

/// Starts a silent check of the saved YouTube sign-in.
/// The app works without signing in, so screens open right away
@RoutePage(name: 'AuthorizationWrapperRouter')
class AuthorizationWrapperRouterPage extends StatefulWidget {
  const AuthorizationWrapperRouterPage({super.key});

  @override
  State<AuthorizationWrapperRouterPage> createState() =>
      _AuthorizationWrapperRouterPageState();
}

class _AuthorizationWrapperRouterPageState
    extends State<AuthorizationWrapperRouterPage> {
  @override
  void initState() {
    super.initState();
    context.read<AuthorizationController>().checkAuthorization();
  }

  @override
  Widget build(BuildContext context) => const AutoRouter();
}
