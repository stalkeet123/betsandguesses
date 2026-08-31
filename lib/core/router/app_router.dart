import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/room/screens/lobby_screen.dart';
import '../../features/game/screens/game_screen.dart';
import '../../features/party/screens/party_poll_game_screen.dart';
import '../../features/room/models/room_model.dart';
import '../../features/room/providers/room_providers.dart';
import '../providers/core_providers.dart';
import '../../features/game/screens/results_screen.dart';
import '../../features/game/screens/debug_scene_editor_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/paywall/screens/paywall_screen.dart';

import 'package:flutter/material.dart';

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
        final entryPoint = state.extra is String
            ? state.extra as String
            : 'unknown';
        return PaywallScreen(entryPoint: entryPoint);
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
        return _GameRouteGate(roomCode: roomCode);
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

class _GameRouteGate extends ConsumerStatefulWidget {
  final String roomCode;
  const _GameRouteGate({required this.roomCode});
  @override
  ConsumerState<_GameRouteGate> createState() => _GameRouteGateState();
}

class _GameRouteGateState extends ConsumerState<_GameRouteGate> {
  bool _isResolving = false;
  bool _notFound = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRoomIfNeeded());
  }

  @override
  void didUpdateWidget(covariant _GameRouteGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomCode.toLowerCase() != widget.roomCode.toLowerCase()) {
      _notFound = false;
      _resolveRoomIfNeeded();
    }
  }

  Future<void> _resolveRoomIfNeeded() async {
    final currentRoom = ref.read(currentRoomProvider);
    if (_isMatchingRoom(currentRoom) || _isResolving) return;
    _isResolving = true;
    try {
      final room = await ref
          .read(roomServiceProvider)
          .findRoomByCode(widget.roomCode);
      if (!mounted) return;
      if (room == null) {
        setState(() => _notFound = true);
        return;
      }
      ref.read(currentRoomProvider.notifier).set(room);
    } finally {
      _isResolving = false;
    }
  }

  bool _isMatchingRoom(Room? room) =>
      room != null && room.code.toLowerCase() == widget.roomCode.toLowerCase();
  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    if (_isMatchingRoom(room)) {
      return room!.gameMode.name == 'party'
          ? PartyPollGameScreen(roomCode: widget.roomCode)
          : GameScreen(roomCode: widget.roomCode);
    }
    if (_notFound) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ROOM NOT FOUND'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.goNamed('home'),
                child: const Text('BACK TO HOME'),
              ),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
