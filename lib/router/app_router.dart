import 'package:flutter/material.dart';
import 'package:aft_firebase_app/shell/aft_scaffold.dart';
import 'package:aft_firebase_app/features/home/home_screen.dart';
import 'package:aft_firebase_app/screens/standards_screen.dart';
import 'package:aft_firebase_app/features/saves/saved_sets_screen.dart';
import 'package:aft_firebase_app/features/auth/sign_in_page.dart';
import 'package:aft_firebase_app/features/auth/auth_gate.dart';

class Routes {
  static const String home = '/';
  static const String standards = '/standards';
  static const String savedSets = '/saved-sets';
  static const String signIn = '/sign-in';
}

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const AuthGate(),
        );
      case Routes.standards:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const StandardsScreen(),
        );
      case Routes.savedSets:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SavedSetsScreen(),
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
