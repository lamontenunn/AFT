import 'package:flutter/material.dart';
import 'theme/army_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AFT Firebase Demo',
      debugShowCheckedModeBanner: false,
      theme: ArmyTheme.dark,
      // Blank screen; background comes from ArmyTheme.dark scaffoldBackgroundColor
      home: const Scaffold(
        body: SizedBox.shrink(),
      ),
    );
  }
}
