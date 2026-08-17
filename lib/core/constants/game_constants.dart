class GameConstants {
  GameConstants._();

  static const int roomCodeLength = 6;
  static const int minPlayers = 2;
  static const int maxPlayers = 10;
  static const int freeMaxPlayers = 4;

  static const int defaultRounds = 8;
  static const int minRounds = 5;
  static const int freeMaxRounds = 6;
  static const int maxRounds = 12;
  static const String defaultCategory = 'Mixed';

  static const int partyDefaultChallengesPerPlayer = 2;
  static const int partyMinChallengesPerPlayer = 1;
  static const int partyFreeMaxChallengesPerPlayer = 2;
  static const int partyMaxChallengesPerPlayer = 4;

  static const int freeChipsPerRound = 2;
  static const int startingScore = 15;

  /// The bank is the competitive score and may be negative. The betting limit
  /// stays at least 15 so a losing player is never removed from the game.
  static int bettingLimitForBank(int bank) =>
      bank < startingScore ? startingScore : bank;

  // Visual slot layout: [Smaller] [Low range] [Sweet spot] [High range] [Larger]
  static const List<int> boardOdds = [4, 3, 2, 3, 4];
  static const String slotSmaller = 'SMALLER';
  static const String slotLarger = 'LARGER';

  static const int guessTimerSeconds = 30;
  static const int betTimerSeconds = 45;
  static const int partyBetTimerSeconds = 30;
  static const int roundResultsSeconds = 7;
  static const int partyRoundResultsSeconds = 10;
  static const int roundTransitionSeconds = 1;

  static const int maxGuessSlots = 4;

  static const List<String> avatarColors = [
    '#44D65F',
    '#1F9DFF',
    '#FF3B30',
    '#B45CFF',
    '#FFB020',
    '#00D4C8',
    '#FF5FA2',
    '#7CFF4D',
    '#FF7A1A',
    '#6D7CFF',
  ];
}

enum RoundPhase {
  idle,
  question,
  guessing,
  revealGuesses,
  betting,
  partyReady,
  partyAction,
  partyResultEntry,
  partyResultConfirm,
  revealAnswer,
  scoring;

  String get displayName {
    switch (this) {
      case RoundPhase.idle:
        return 'Waiting';
      case RoundPhase.question:
        return 'Question';
      case RoundPhase.guessing:
        return 'Guessing';
      case RoundPhase.revealGuesses:
        return 'Reveal Guesses';
      case RoundPhase.betting:
        return 'Betting';
      case RoundPhase.partyReady:
        return 'Get Ready';
      case RoundPhase.partyAction:
        return 'Challenge';
      case RoundPhase.partyResultEntry:
        return 'Enter Result';
      case RoundPhase.partyResultConfirm:
        return 'Confirm Result';
      case RoundPhase.revealAnswer:
        return 'Reveal Answer';
      case RoundPhase.scoring:
        return 'Scoring';
    }
  }

  static RoundPhase fromString(String value) {
    return RoundPhase.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RoundPhase.idle,
    );
  }
}

enum RoomStatus {
  waiting,
  playing,
  finished;

  static RoomStatus fromString(String value) {
    return RoomStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RoomStatus.waiting,
    );
  }
}

enum GameMode {
  classic,
  party;

  String get displayName => switch (this) {
    GameMode.classic => 'CLASSIC',
    GameMode.party => 'PARTY',
  };

  static GameMode fromString(String? value) {
    return GameMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => GameMode.classic,
    );
  }
}
