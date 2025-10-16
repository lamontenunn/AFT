import 'package:flutter/material.dart';

/// Deprecated legacy HomeScreen (pre-Riverpod).
/// Router now points to FeatureHomeScreen (lib/features/home/home_screen.dart).
/// This stub remains to avoid analyzer/import errors if referenced accidentally.
@Deprecated('Use FeatureHomeScreen in lib/features/home/home_screen.dart')
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Legacy HomeScreen is deprecated. Use FeatureHomeScreen.'),
      ),
    );
  }
}
