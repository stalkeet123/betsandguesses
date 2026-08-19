import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/cached_asset_image.dart';
import '../theme/party_palette.dart';

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
    return Stack(
      children: [
        const Positioned.fill(child: _PartyTableBackground()),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final compact = height < 700;
                  final gap = compact ? 8.0 : 10.0;
                  final logoTop = 6.0;
                  final logoHeight = compact ? 76.0 : 92.0;
                  final timerHeight = compact ? 39.0 : 42.0;
                  final leftColumnWidth = (width - 4) / 2;
                  final left = 6.0;
                  final leftWidth = leftColumnWidth - 12;
                  final boardLeft = leftColumnWidth + 4;
                  final boardWidth = width - boardLeft;
                  final timerBetTop = logoTop + logoHeight + 4;
                  final questionBetTop = timerBetTop + timerHeight + gap;
                  final chipHeight = compact ? 96.0 : 102.0;
                  final rawQuestionHeight =
                      height -
                      questionBetTop -
                      chipHeight -
                      (gap * 2) -
                      (compact ? 100 : 120) -
                      8;
                  final questionBetHeight = min(
                    height * (compact ? .28 : .29),
                    max(compact ? 112.0 : 132.0, rawQuestionHeight),
                  );
                  final chipTop = questionBetTop + questionBetHeight + gap;
                  final playersTop = chipTop + chipHeight + gap;
                  final playersHeight = max(72.0, height - playersTop - 8);
                  return Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: logoTop,
                        width: leftWidth,
                        height: logoHeight,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: CachedAssetImage(
                            AppAssetPaths.logo,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        left: left,
                        top: timerBetTop,
                        width: leftWidth,
                        height: timerHeight,
                        child: _roundTimer(),
                      ),
                      Positioned(
                        left: left,
                        top: questionBetTop,
                        width: leftWidth,
                        height: questionBetHeight,
                        child: _questionCard(),
                      ),
                      Positioned(
                        left: left,
                        top: chipTop,
                        width: leftWidth,
                        height: chipHeight,
                        child: const SizedBox.expand(),
                      ),
                      Positioned(
                        left: left,
                        top: playersTop,
                        width: leftWidth,
                        height: playersHeight,
                        child: const SizedBox.expand(),
                      ),
                      Positioned(
                        left: boardLeft,
                        top: 0,
                        width: boardWidth,
                        height: height,
                        child: const SizedBox.expand(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundTimer() {
    final seconds = max(0, remaining.inSeconds);
    return Row(
      children: [
        Expanded(
          child: _infoPill(
            Icons.groups_rounded,
            'Round $roundNumber/$maxRounds',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoPill(
            isReveal ? Icons.emoji_events_rounded : Icons.timer_rounded,
            isReveal
                ? 'RESULT'
                : seconds > 0
                ? '0:${seconds.toString().padLeft(2, '0')}'
                : '--:--',
          ),
        ),
      ],
    );
  }

  Widget _infoPill(IconData icon, String label) => Container(
    decoration: BoxDecoration(
      color: PartyPalette.surfaceRaised.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .32)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: PartyPalette.orangeSoft),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: PartyPalette.cream,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .45,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _questionCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    decoration: BoxDecoration(
      color: PartyPalette.surface.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PartyPalette.orangeSoft.withValues(alpha: .32)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .24),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: PartyPalette.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'GROUP POLL · EVERYONE VOTES',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: PartyPalette.orangeSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          questionRules,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: PartyPalette.blueMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: Text(
              questionText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: PartyPalette.cream,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PartyTableBackground extends StatelessWidget {
  const _PartyTableBackground();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: PartyPalette.backgroundGradient),
    child: Stack(
      children: [
        const Positioned(
          top: -120,
          left: -80,
          child: _SoftPartyOrb(
            size: 310,
            color: PartyPalette.orange,
            opacity: .11,
          ),
        ),
        const Positioned(
          right: -90,
          bottom: -130,
          child: _SoftPartyOrb(
            size: 360,
            color: PartyPalette.sage,
            opacity: .12,
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _PartyBackgroundGrainPainter()),
        ),
      ],
    ),
  );
}

class _SoftPartyOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _SoftPartyOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          Colors.transparent,
        ],
      ),
    ),
  );
}

class _PartyBackgroundGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .018);
    const spacing = 26.0;
    for (double y = 8; y < size.height; y += spacing) {
      for (double x = 8; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), .65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
