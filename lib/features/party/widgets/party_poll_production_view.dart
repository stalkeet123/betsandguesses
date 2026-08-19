import 'package:flutter/material.dart';

class PartyPollViewPlayer {
  final String id;
  final int slotIndex;
  final String name;
  final int score;

  const PartyPollViewPlayer({
    required this.id,
    required this.slotIndex,
    required this.name,
    required this.score,
  });
}

class PartyPollViewBet {
  final String id;
  final String? bettorPlayerId;
  final String targetPlayerId;
  final int targetSlotIndex;
  final int chips;
  final double? positionX;
  final double? positionY;
  final bool? won;

  const PartyPollViewBet({
    required this.id,
    required this.targetPlayerId,
    required this.targetSlotIndex,
    required this.chips,
    this.bettorPlayerId,
    this.positionX,
    this.positionY,
    this.won,
  });
}

typedef PartyPollBetRequested =
    void Function(
      String targetPlayerId,
      int targetSlotIndex,
      double? positionX,
      double? positionY,
    );

class PartyPollProductionView extends StatelessWidget {
  final int roundNumber;
  final int maxRounds;
  final Duration remaining;
  final bool isReveal;
  final String questionText;
  final String questionRules;
  final List<PartyPollViewPlayer> players;
  final List<PartyPollViewBet> bets;
  final Set<String> winningPlayerIds;
  final int score;
  final int betTotal;
  final int betLimit;
  final int availableChips;
  final int? selectedChipValue;
  final ValueChanged<int> onChipSelected;
  final PartyPollBetRequested onBetRequested;

  const PartyPollProductionView({
    super.key,
    required this.roundNumber,
    required this.maxRounds,
    required this.remaining,
    required this.isReveal,
    required this.questionText,
    required this.questionRules,
    required this.players,
    required this.bets,
    required this.winningPlayerIds,
    required this.score,
    required this.betTotal,
    required this.betLimit,
    required this.availableChips,
    required this.selectedChipValue,
    required this.onChipSelected,
    required this.onBetRequested,
  });

  @override
  Widget build(BuildContext context) {
    // Production Party presentation is extracted from GameScreen in 6A.2+.
    // Do not redesign this view.
    return const SizedBox.expand();
  }
}
