import 'package:flutter/material.dart';

/// A page over the app background: clear, so the lava lamp of the page
/// area shows through
class AppScaffold extends Scaffold {
  AppScaffold({
    super.key,
    super.appBar,
    super.floatingActionButton,
    super.bottomNavigationBar,
    Color? backgroundColor,
    super.resizeToAvoidBottomInset,
    Widget? body,
  }) : super(
         backgroundColor: backgroundColor ?? Colors.transparent,
         body: Stack(
           children: [if (body is Widget) Positioned.fill(child: body)],
         ),
       );
}
