import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/settings_state.dart';
import 'theme/army_theme.dart';
import 'router/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'AFT Firebase Demo',
      debugShowCheckedModeBanner: false,
      theme: ArmyTheme.light,
      darkTheme: ArmyTheme.dark,
      themeMode: settings.themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
    );
  }
}
