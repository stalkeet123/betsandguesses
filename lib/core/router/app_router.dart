import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/room/screens/lobby_screen.dart';
import '../../features/game/screens/game_screen.dart';
import '../../features/game/screens/results_screen.dart';
import '../../features/game/screens/debug_scene_editor_screen.dart';
import '../../features/party/screens/party_performance_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/paywall/screens/paywall_screen.dart';

import 'package:flutter/widgets.dart';

/// Global route observer for stopping animations when screens are hidden
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// App router using GoRouter
final appRouter = GoRouter(
  initialLocation: '/',
  observers: [routeObserver],
  redirect: (context, state) {
    if (kIsWeb && state.uri.path == '/premium') return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) {
        final roomCode = state.uri.queryParameters['room'];
        return HomeScreen(prefilledRoomCode: roomCode);
      },
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) {
        return const OnboardingScreen();
      },
    ),
    GoRoute(
      path: '/premium',
      name: 'premium',
      builder: (context, state) {
        return const PaywallScreen();
      },
    ),
    GoRoute(
      path: '/lobby/:roomCode',
      name: 'lobby',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode']!;
        return LobbyScreen(roomCode: roomCode);
      },
    ),
    GoRoute(
      path: '/game/:roomCode',
      name: 'game',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode']!;
        return GameScreen(roomCode: roomCode);
      },
    ),
    GoRoute(
      path: '/party/performance/:roomCode',
      name: 'party-performance',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode']!;
        return PartyPerformanceScreen(roomCode: roomCode);
      },
    ),
    GoRoute(
      path: '/results/:roomCode',
      name: 'results',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode']!;
        return ResultsScreen(roomCode: roomCode);
      },
    ),
    if (kDebugMode)
      GoRoute(
        path: '/debug/scene-editor',
        name: 'debug-scene-editor',
        builder: (context, state) => const DebugSceneEditorScreen(),
      ),
  ],
);
