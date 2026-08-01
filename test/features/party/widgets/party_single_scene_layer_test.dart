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
      find.text('Get in position. The host will start the timer.'),
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

    expect(find.text('START 60 SECONDS'), findsOneWidget);
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
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.text('LIVE CHALLENGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('host can finish an attempt before the timer expires', (
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

    expect(find.text('RECORD ATTEMPT'), findsOneWidget);
    expect(find.text('00:47'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('attempt result offers tries and failure without typing', (
    tester,
  ) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.attempt,
      ),
      player: host,
    );

    expect(find.text('1ST TRY'), findsOneWidget);
    expect(find.text('5TH TRY'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('binary result is entered inline without a dialog', (
    tester,
  ) async {
    final host = _player(id: 'host', isHost: true);
    await _pumpScene(
      tester,
      snapshot: _snapshot(
        phase: PartyRoundPhase.resultEntry,
        challengeType: PartyChallengeType.binary,
      ),
      player: host,
    );

    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScene(
  WidgetTester tester, {
  required PartySnapshot snapshot,
  required Player player,
  int secondsRemaining = 60,
}) async {
  tester.view.physicalSize = const Size(900, 700);
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
            secondsRemaining: secondsRemaining,
            commandInFlight: false,
            stageTop: 235,
            onStartAction: noAction,
            onOpenResultEntry: noAction,
            onSubmitResult: noResult,
            onConfirmResult: noAction,
            onDisputeResult: noAction,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Player _player({required String id, bool isHost = false}) {
  return Player(
    id: id,
    roomId: 'room',
    deviceId: 'device-$id',
    name: id,
    isHost: isHost,
    joinedAt: DateTime.utc(2026),
  );
}

PartySnapshot _snapshot({
  required PartyRoundPhase phase,
  bool performerReady = false,
  PartyChallengeType challengeType = PartyChallengeType.count,
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
          ? now.add(const Duration(seconds: 60))
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
          ? now.add(const Duration(seconds: 60))
          : null,
      performer: const PartyParticipant(id: 'performer', name: 'Alex'),
      witness: const PartyParticipant(id: 'host', name: 'Host'),
      challenge: PartyChallenge(
        id: 'challenge',
        text: switch (challengeType) {
          PartyChallengeType.binary => 'Can Alex land the shot?',
          PartyChallengeType.attempt =>
            'On which attempt will Alex land the shot?',
          PartyChallengeType.count => 'How many push-ups can Alex do?',
        },
        rules: 'One clean attempt.',
        answerUnit: switch (challengeType) {
          PartyChallengeType.binary => 'result',
          PartyChallengeType.attempt => 'attempt',
          PartyChallengeType.count => 'push-ups',
        },
        durationSeconds: 60,
        maxResult: challengeType == PartyChallengeType.attempt ? 5 : 100,
        betBoundaries: challengeType == PartyChallengeType.count
            ? const [10, 20, 30, 40]
            : const [],
        type: challengeType,
        performerSuccessBonus: 3,
      ),
      submittedGuessCount: 0,
      performerReady: performerReady,
      ownGuess: null,
      guesses: const [],
      bets: const [],
      proposedResult: null,
      performerBonus: 0,
    ),
    scores: const {'host': 100, 'performer': 100},
  );
}
