import 'package:witsgame/features/party/models/party_poll_snapshot.dart';
import 'package:witsgame/features/room/models/room_model.dart';

PartyPollSnapshot partyPollFixture({
  int version = 10,
  String roomId = 'party-room',
  PartyPollPhase phase = PartyPollPhase.betting,
}) => PartyPollSnapshot(
  room: Room(
    id: roomId,
    code: 'PARTY1',
    hostId: 'host',
    createdAt: DateTime.utc(2026),
  ),
  status: 'playing',
  stateVersion: version,
  round: PartyPollRound(
    number: 1,
    phase: phase,
    phaseStartedAt: DateTime.utc(2026),
    phaseEndsAt: DateTime.utc(2026, 1, 1, 0, 0, 30),
    question: const PartyPollQuestion(
      id: 'question',
      text: 'Who wins?',
      rules: 'Vote',
    ),
    players: const [],
    bets: const [],
    winningPlayerIds: const [],
  ),
  scores: const {},
  me: const PartyPollMe(
    playerId: 'host',
    score: 0,
    betLimit: 35,
    betTotal: 0,
    availableChips: 35,
  ),
);
