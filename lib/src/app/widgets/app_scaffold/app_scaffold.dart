import 'package:flutter/material.dart';

import 'app_background_glow.dart';

class AppScaffold extends Scaffold {
  AppScaffold({
    super.key,
    super.appBar,
    super.floatingActionButton,
    super.bottomNavigationBar,
    super.backgroundColor,
    super.resizeToAvoidBottomInset,
    bool showBackgroundGlow = true,
    Widget? body,
  }) : super(
         body: Stack(
           children: [
             if (showBackgroundGlow)
               const Positioned.fill(child: AppBackgroundGlow()),
             if (body is Widget) Positioned.fill(child: body),
           ],
         ),
       );
}
