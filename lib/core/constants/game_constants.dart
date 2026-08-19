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

  /// The bank score represents net profit/loss. Every player starts with 15 chips 
  /// worth of credit. If they lose those 15 chips, their bank score becomes -15 
  /// and their betting limit becomes 0 (they are out of chips).
  static int bettingLimitForBank(int bank) {
    final limit = startingScore + bank;
    return limit < 0 ? 0 : limit;
  }

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
    '#FF8DA1', // Soft Rose
    '#68A6FF', // Soft Blue
    '#58D68D', // Soft Green
    '#B088F9', // Soft Purple
    '#FFC85C', // Soft Orange
    '#48E5C2', // Soft Teal
    '#FF9AA2', // Soft Pink
    '#A8E6CF', // Soft Mint
    '#FFD3B6', // Soft Peach
    '#818CFF', // Soft Indigo
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
