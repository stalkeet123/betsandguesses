import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/room/screens/lobby_screen.dart';
import '../../features/game/screens/game_screen.dart';
import '../../features/game/screens/results_screen.dart';

/// App router using GoRouter
final appRouter = GoRouter(
  initialLocation: '/',
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
      path: '/results/:roomCode',
      name: 'results',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode']!;
        return ResultsScreen(roomCode: roomCode);
      },
    ),
  ],
);
