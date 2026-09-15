import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../shared_controllers/shared_controllers.dart';

/// Запускает тихую проверку сохранённого входа в YouTube.
/// Приложение работает и без входа, поэтому экраны открываются сразу
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
