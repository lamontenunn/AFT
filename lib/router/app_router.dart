import 'package:flutter/material.dart';
import 'package:aft_firebase_app/shell/aft_scaffold.dart';
import 'package:aft_firebase_app/features/home/home_screen.dart';
import 'package:aft_firebase_app/screens/standards_screen.dart';
import 'package:aft_firebase_app/features/saves/saved_sets_screen.dart';
import 'package:aft_firebase_app/features/auth/sign_in_page.dart';
import 'package:aft_firebase_app/features/auth/auth_gate.dart';
import 'package:aft_firebase_app/screens/settings_screen.dart';
import 'package:aft_firebase_app/features/proctor/proctor_screen.dart';

class Routes {
  static const String home = '/';
  static const String standards = '/standards';
  static const String savedSets = '/saved-sets';
  static const String proctor = '/proctor';
  static const String settings = '/settings';
  static const String signIn = '/sign-in';
}

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // No transition to prevent shell (AppBar/BottomNav) double-render during switches
            return child;
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      case Routes.standards:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AftScaffold(showHeader: false, child: StandardsScreen()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      case Routes.savedSets:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AftScaffold(showHeader: false, child: SavedSetsScreen()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      case Routes.proctor:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AftScaffold(showHeader: false, child: ProctorScreen()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      case Routes.settings:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AftScaffold(showHeader: false, child: SettingsScreen()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      case Routes.signIn:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SignInPage(),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
