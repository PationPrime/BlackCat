import 'package:flutter/widgets.dart';

class NavigatorKeyProvider {
  static final GlobalKey<NavigatorState> _instance = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get instance => _instance;

  const NavigatorKeyProvider._();
}
