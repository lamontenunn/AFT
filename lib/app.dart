import 'package:flutter/material.dart';
import 'theme/army_theme.dart';
import 'router/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AFT Firebase Demo',
      debugShowCheckedModeBanner: false,
      theme: ArmyTheme.dark,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
    );
  }
}
