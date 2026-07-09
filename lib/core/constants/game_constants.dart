class GameConstants {
  GameConstants._();

  static const int roomCodeLength = 6;
  static const int minPlayers = 2;
  static const int maxPlayers = 10;

  static const int defaultRounds = 8;
  static const int minRounds = 5;
  static const int maxRounds = 12;

  static const int freeChipsPerRound = 2;
  static const int startingScore = 15;

  // Visual slot layout: [Smaller] [Low range] [Sweet spot] [High range] [Larger]
  static const List<int> boardOdds = [4, 3, 2, 3, 4];
  static const String slotSmaller = 'SMALLER';
  static const String slotLarger = 'LARGER';

  static const int guessTimerSeconds = 45;
  static const int betTimerSeconds = 60;

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
