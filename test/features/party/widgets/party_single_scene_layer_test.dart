import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/constants/game_constants.dart';
import 'package:witsgame/features/party/models/party_snapshot.dart';
import 'package:witsgame/features/party/widgets/party_single_scene_layer.dart';
import 'package:witsgame/features/player/models/player_model.dart';
import 'package:witsgame/features/room/models/room_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('performer waits without an extra ready confirmation', (
    tester,
  ) async {
    final player = _player(id: 'performer');
    await _pumpScene(
      tester,
      snapshot: _snapshot(phase: PartyRoundPhase.ready),
      player: player,
    );

    expect(find.text('I AM READY'), findsNothing);
    expect(find.text('GET READY'), findsOneWidget);
    expect(
      find.text('Get into position! The host will start your countdown.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('host can start without waiting for a performer tap', (
    tester,
  ) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(phase: PartyRoundPhase.ready),
      player: host,
    );

    expect(find.text('START 60s TIMER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live stage keeps timer and camera action in one scene', (
    tester,
  ) async {
    final spectator = _player(id: 'spectator');
    await _pumpScene(
      tester,
      snapshot: _snapshot(phase: PartyRoundPhase.action),
      player: spectator,
      secondsRemaining: 43,
    );

    expect(find.text('00:43'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(find.text('LIVE PERFORMANCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage panel fits a compact phone viewport', (tester) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(phase: PartyRoundPhase.resultEntry),
      player: host,
      surfaceSize: const Size(340, 667),
      stageTop: 220,
    );

    expect(find.text('RECORD THE RESULT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('party-result-key-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('host can end a Count early when the set is over', (
    tester,
  ) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(phase: PartyRoundPhase.action),
      player: host,
      secondsRemaining: 43,
    );

    expect(find.text('FINISH & RECORD'), findsOneWidget);
    expect(find.text('00:43'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('live stage keeps the current player bet visible', (
    tester,
  ) async {
    final spectator = _player(id: 'spectator');
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.action,
        bets: const [
          PartyBetSnapshot(
            id: 'bet',
            slotIndex: 2,
            chips: 50,
            playerId: 'spectator',
          ),
        ],
      ),
      player: spectator,
      secondsRemaining: 43,
    );

    expect(find.text('YOUR BET - 20-30 - 50 CHIPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('poll bet summary names the selected player', (tester) async {
    final spectator = _player(id: 'spectator');
    final alex = _player(id: 'alex', name: 'Alex');
    final bea = _player(id: 'bea', name: 'Bea');
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.action,
        challengeType: PartyChallengeType.poll,
        bets: const [
          PartyBetSnapshot(
            id: 'poll-bet',
            slotIndex: 1,
            chips: 20,
            playerId: 'spectator',
          ),
        ],
      ),
      player: spectator,
      players: [alex, bea, spectator],
    );

    expect(find.text('YOUR BET - BEA - 20 CHIPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'count result uses an embedded numpad without opening a keyboard',
    (tester) async {
      int? submittedResult;
      final host = _player(id: 'host', isHost: true);
      await _pumpScene(
        tester,
        snapshot: _snapshot(phase: PartyRoundPhase.resultEntry),
        player: host,
        onSubmitResult: (result) async => submittedResult = result,
      );

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('party-result-key-4')));
      await tester.tap(find.byKey(const ValueKey('party-result-key-2')));
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('party-result-key-submit')));
      await tester.pump();
      expect(submittedResult, 42);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('host can select winner in Versus duel', (tester) async {
    int? submittedResult;
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.versus,
      ),
      player: host,
      onSubmitResult: (result) async => submittedResult = result,
    );

    expect(find.text('ALEX WON'), findsOneWidget);
    expect(find.text('HOST WON'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('party-choice-1')));
    await tester.pump();
    expect(submittedResult, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('host can select winner in Showdown all-play', (tester) async {
    int? submittedResult;
    final host = _player(id: 'host', isHost: true);
    final p1 = _player(id: 'p1', name: 'Alice');
    final p2 = _player(id: 'p2', name: 'Bob');
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.showdown,
      ),
      player: host,
      players: [p1, p2],
      onSubmitResult: (result) async => submittedResult = result,
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('party-showdown-winner-1')));
    await tester.pump();
    expect(submittedResult, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friends wait while the host enters Versus result', (
    tester,
  ) async {
    final spectator = _player(id: 'spectator');
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.versus,
      ),
      player: spectator,
    );

    expect(find.text('RECORDING WINNER'), findsOneWidget);
    expect(find.byKey(const ValueKey('party-choice-0')), findsNothing);
    expect(find.byKey(const ValueKey('party-choice-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attempt stage uses five tries without a countdown', (
    tester,
  ) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.action,
        challengeType: PartyChallengeType.attempt,
      ),
      player: host,
      secondsRemaining: 47,
    );

    expect(find.text('RECORD RESULT'), findsOneWidget);
    expect(find.text('UP TO'), findsOneWidget);
    expect(find.text('5 TRIES'), findsOneWidget);
    expect(find.text('00:47'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('host can finish a quick binary dare before time expires', (
    tester,
  ) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.action,
        challengeType: PartyChallengeType.binary,
        durationSeconds: 10,
      ),
      player: host,
      secondsRemaining: 18,
    );

    expect(find.text('RECORD RESULT'), findsOneWidget);
    expect(find.text('00:18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('attempt result offers tries and failure without typing', (
    tester,
  ) async {
    int? submittedResult;
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.attempt,
      ),
      player: host,
      onSubmitResult: (result) async => submittedResult = result,
    );

    expect(find.text('3RD TRY'), findsOneWidget);
    expect(find.text("FAILED"), findsOneWidget);
    await tester.tap(find.text('3RD TRY'));
    await tester.pump();
    expect(submittedResult, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('binary result is entered inline without a dialog', (
    tester,
  ) async {
    int? submittedResult;
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.binary,
      ),
      player: host,
      onSubmitResult: (result) async => submittedResult = result,
    );

    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    await tester.tap(find.text('SUCCESS'));
    await tester.pump();
    expect(submittedResult, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScene(
  WidgetTester tester, {
  required PartySnapshot snapshot,
  required Player player,
  List<Player> players = const [],
  int secondsRemaining = 60,
  Size surfaceSize = const Size(430, 932),
  double stageTop = 235,
  Future<void> Function(int)? onSubmitResult,
  Future<void> Function(int)? onSubmitChoice,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Future<void> noAction() async {}
  Future<void> noResult(int _) async {}

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PartySingleSceneLayer(
            snapshot: snapshot,
            currentPlayer: player,
            players: players,
            secondsRemaining: secondsRemaining,
            commandInFlight: false,
            stageTop: stageTop,
            onStartAction: noAction,
            onOpenResultEntry: noAction,
            onSubmitResult: onSubmitResult ?? noResult,
            onSubmitChoice: onSubmitChoice ?? noResult,
            onConfirmResult: noAction,
            onDisputeResult: noAction,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Player _player({required String id, String? name, bool isHost = false}) {
  return Player(
    id: id,
    roomId: 'room',
    deviceId: 'device-$id',
    name: name ?? id,
    isHost: isHost,
    joinedAt: DateTime.utc(2026),
  );
}

PartySnapshot _snapshot({
  required PartyRoundPhase phase,
  bool performerReady = false,
  PartyChallengeType challengeType = PartyChallengeType.count,
  int durationSeconds = 60,
  List<PartyBetSnapshot> bets = const [],
}) {
  final now = DateTime.utc(2026);
  return PartySnapshot(
    room: Room(
      id: 'room',
      code: 'PARTY',
      hostId: 'host',
      status: RoomStatus.playing,
      currentRound: 1,
      maxRounds: 8,
      gameMode: GameMode.party,
      roundPhase: phase.gamePhase,
      stateVersion: 4,
      phaseStartedAt: now,
      phaseEndsAt: phase == PartyRoundPhase.action
          ? now.add(Duration(seconds: durationSeconds))
          : null,
      createdAt: now,
    ),
    stateVersion: 4,
    turnIndex: 0,
    turnCount: 8,
    round: PartyRoundSnapshot(
      number: 1,
      phase: phase,
      phaseStartedAt: now,
      phaseEndsAt: phase == PartyRoundPhase.action
          ? now.add(Duration(seconds: durationSeconds))
          : null,
      performer: const PartyParticipant(id: 'performer', name: 'Alex'),
      witness: const PartyParticipant(id: 'host', name: 'Host'),
      challenge: PartyChallenge(
        id: 'challenge',
        text: switch (challengeType) {
          PartyChallengeType.binary => 'Can Alex land the shot?',
          PartyChallengeType.choice => 'Which would Alex choose?',
          PartyChallengeType.attempt =>
            'On which attempt will Alex land the shot?',
          PartyChallengeType.count => 'How many push-ups can Alex do?',
          PartyChallengeType.versus => 'Who will win the duel?',
          PartyChallengeType.showdown => 'Who has the highest screen time?',
          PartyChallengeType.poll => 'Who is most likely to win?',
        },
        rules: 'One clean attempt.',
        answerUnit: switch (challengeType) {
          PartyChallengeType.binary ||
          PartyChallengeType.choice ||
          PartyChallengeType.versus => 'choice',
          PartyChallengeType.attempt => 'attempt',
          PartyChallengeType.count => 'push-ups',
          PartyChallengeType.showdown || PartyChallengeType.poll => 'player',
        },
        durationSeconds: durationSeconds,
        maxResult: challengeType == PartyChallengeType.attempt ? 5 : 100,
        betBoundaries: challengeType == PartyChallengeType.count
            ? const [10, 20, 30, 40]
            : const [],
        type: challengeType,
        optionA: challengeType == PartyChallengeType.choice ? 'Music' : null,
        optionB: challengeType == PartyChallengeType.choice
            ? 'Movies and TV'
            : null,
        performerSuccessBonus: 3,
      ),
      submittedGuessCount: 0,
      performerReady: performerReady,
      ownGuess: null,
      guesses: const [],
      bets: bets,
      proposedResult: null,
      performerBonus: 0,
    ),
    scores: const {'host': 100, 'performer': 100},
  );
}
