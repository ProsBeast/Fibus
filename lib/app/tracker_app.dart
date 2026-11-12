import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/tracker/providers/tracking_provider.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';
import 'package:fibus/tracker/screens/active_tracking_screen.dart';
import 'package:fibus/tracker/screens/assigned_buses_screen.dart';
import 'package:fibus/tracker/screens/sign_in_screen.dart';
import 'package:fibus/tracker/screens/takeover_screen.dart';
import 'package:fibus/tracker/screens/trip_preview_screen.dart';

/// Root widget for the Fibus Tracker (Operator) application.
///
/// Configures dependency injection via [MultiProvider], sets up declarative
/// routing via [GoRouter] with authentication guards, and applies [FibusTheme].
class TrackerApp extends StatefulWidget {
  const TrackerApp({super.key});

  @override
  State<TrackerApp> createState() => _TrackerAppState();
}

class _TrackerAppState extends State<TrackerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authService = AuthService.instance;

    _router = GoRouter(
      initialLocation: '/buses',
      refreshListenable: authService,
      redirect: (BuildContext context, GoRouterState state) {
        final isAuthenticated = authService.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/sign-in';

        // 1. If not authenticated and attempting to view protected route -> redirect to /sign-in
        if (!isAuthenticated && !isLoggingIn) {
          return '/sign-in';
        }

        // 2. If authenticated and currently on /sign-in -> redirect to /buses
        if (isAuthenticated && isLoggingIn) {
          return '/buses';
        }

        // 3. Root redirect
        if (state.matchedLocation == '/') {
          return '/buses';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => const SignInScreen(),
        ),
        GoRoute(
          path: '/buses',
          builder: (context, state) => const AssignedBusesScreen(),
        ),
        GoRoute(
          path: '/trip-preview/:busId',
          builder: (context, state) {
            final busId = state.pathParameters['busId'] ?? '';
            return TripPreviewScreen(busId: busId);
          },
        ),
        GoRoute(
          path: '/tracking/:busId',
          builder: (context, state) {
            final busId = state.pathParameters['busId'] ?? '';
            return ActiveTrackingScreen(busId: busId);
          },
        ),
        GoRoute(
          path: '/takeover/:busId',
          builder: (context, state) {
            final busId = state.pathParameters['busId'] ?? '';
            return TakeoverScreen(busId: busId);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        ChangeNotifierProvider<TrackingProvider>(
          create: (_) => TrackingProvider(),
        ),
        ChangeNotifierProxyProvider<TrackingProvider, TripLifecycleProvider>(
          create: (ctx) => TripLifecycleProvider(
            trackingProvider: ctx.read<TrackingProvider>(),
          ),
          update: (ctx, tracking, lifecycle) {
            lifecycle?.updateTrackingProvider(tracking);
            return lifecycle ??
                TripLifecycleProvider(trackingProvider: tracking);
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'Fibus Tracker',
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
