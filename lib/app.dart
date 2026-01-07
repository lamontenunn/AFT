import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/settings_state.dart';
import 'theme/army_theme.dart';
import 'router/app_router.dart';
import 'features/auth/auth_side_effects.dart';
import 'features/auth/password_reset_links.dart';
import 'features/auth/reset_password_screen.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  String? _lastResetCode;

  @override
  void initState() {
    super.initState();
    _cacheInitialResetCode();
    _initAppLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleIncomingLink(initial);
      }
      _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    } catch (_) {}
  }

  void _cacheInitialResetCode() {
    final routeName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final uri = Uri.tryParse(routeName);
    if (uri == null) return;
    final code = PasswordResetLinks.extractOobCode(uri);
    if (code != null) {
      _lastResetCode = code;
    }
  }

  void _handleIncomingLink(Uri link) {
    final code = PasswordResetLinks.extractOobCode(link);
    if (code == null || code == _lastResetCode) return;
    _lastResetCode = code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(oobCode: code),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authSideEffectsProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'AFT Firebase Demo',
      debugShowCheckedModeBanner: false,
      theme: ArmyTheme.light,
      darkTheme: ArmyTheme.dark,
      themeMode: settings.themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
      navigatorKey: _navigatorKey,
    );
  }
}
