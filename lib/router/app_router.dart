import 'package:flutter/material.dart';
import 'package:aft_firebase_app/shell/aft_scaffold.dart';
import 'package:aft_firebase_app/features/home/home_screen.dart';
import 'package:aft_firebase_app/screens/standards_screen.dart';

class Routes {
  static const String home = '/';
  static const String standards = '/standards';
}

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const AftScaffold(child: FeatureHomeScreen()),
        );
      case Routes.standards:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const StandardsScreen(),
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
