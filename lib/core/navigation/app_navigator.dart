import 'package:flutter/material.dart';

/// Global navigator key for routing from services (deep links, notifications).
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get state => key.currentState;

  static BuildContext? get context => key.currentContext;
}
