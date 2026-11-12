import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/commuter/providers/alert_session_provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/commuter/screens/choose_commute_screen.dart';
import 'package:fibus/commuter/screens/dashboard_screen.dart';
import 'package:fibus/commuter/screens/home_pin_screen.dart';
import 'package:fibus/commuter/screens/settings_screen.dart';
import 'package:fibus/commuter/screens/sign_in_screen.dart';
import 'package:fibus/services/auth_service.dart';

/// The root Commuter application widget wrapping state providers, go_router routing,
/// and the dark commuter theme.
class CommuterApp extends StatefulWidget {
  const CommuterApp({super.key});

  @override
  State<CommuterApp> createState() => _CommuterAppState();
}

class _CommuterAppState extends State<CommuterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authService = AuthService.instance;

    _router = GoRouter(
      initialLocation: authService.isAuthenticated ? '/dashboard' : '/sign-in',
      refreshListenable: authService,
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/sign-in';

        // Unauthenticated users must sign in
        if (!isAuthenticated && !isLoggingIn) {
          return '/sign-in';
        }

        // Authenticated users should not stay on sign-in
        if (isAuthenticated && isLoggingIn) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => const SignInScreen(),
        ),
        GoRoute(
          path: '/home-pin',
          builder: (context, state) => const HomePinScreen(),
        ),
        GoRoute(
          path: '/choose-commute',
          builder: (context, state) => const ChooseCommuteScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        ChangeNotifierProvider<CommuteProvider>(
          create: (_) => CommuteProvider(),
        ),
        // Alerts follow the live recommendation computed by CommuteProvider.
        ChangeNotifierProxyProvider<CommuteProvider, AlertSessionProvider>(
          create: (_) => AlertSessionProvider(),
          update: (_, commute, alerts) =>
              (alerts ?? AlertSessionProvider())..syncFromCommute(commute),
        ),
      ],
      child: MaterialApp.router(
        title: 'Fibus Commuter',
        debugShowCheckedModeBanner: false,
        builder: FibusSystemBars.builder,
        theme: FibusTheme.light,
        darkTheme: FibusTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
