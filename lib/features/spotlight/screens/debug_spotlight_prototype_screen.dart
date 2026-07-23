import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/spotlight_palette.dart';

/// Local-only visual prototype for the proposed "Who Knows Me?" mode.
///
/// It intentionally has no providers, audio, timers, realtime subscriptions,
/// room mutations, or persistence. It is opened only behind [kDebugMode] from
/// the home screen.
class DebugSpotlightPrototypeScreen extends StatefulWidget {
  const DebugSpotlightPrototypeScreen({super.key});

  @override
  State<DebugSpotlightPrototypeScreen> createState() =>
      _DebugSpotlightPrototypeScreenState();
}

class _DebugSpotlightPrototypeScreenState
    extends State<DebugSpotlightPrototypeScreen> {
  static const _stageLabels = ['ANSWER', 'GUESS', 'PICK', 'BET', 'REVEAL'];
  int _stage = 0;
  int? _trustPick = 0;

  void _next() {
    if (_stage >= _stageLabels.length - 1) {
      setState(() => _stage = 0);
      return;
    }
    setState(() => _stage++);
  }

  void _previous() {
    if (_stage == 0) return;
    setState(() => _stage--);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: SpotlightPalette.ink,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: SpotlightPalette.mint,
          selectionColor: SpotlightPalette.violetDeep,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SpotlightPalette.ink.withValues(alpha: 0.72),
          hintStyle: GoogleFonts.inter(color: SpotlightPalette.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: SpotlightPalette.cream.withValues(alpha: 0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: SpotlightPalette.mint,
              width: 1.5,
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: SpotlightPalette.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _PrototypeHeader(
                  stage: _stage,
                  labels: _stageLabels,
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: KeyedSubtree(
                            key: ValueKey(_stage),
                            child: _buildStage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _PrototypeControls(
                  stage: _stage,
                  stageCount: _stageLabels.length,
                  onBack: _previous,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    return switch (_stage) {
      0 => const _SecretAnswerStage(),
      1 => const _GuessStage(),
      2 => _TrustPickStage(
        selectedIndex: _trustPick,
        onSelected: (value) => setState(() => _trustPick = value),
      ),
      3 => const _BetStage(),
      _ => _RevealStage(trustPick: _trustPick),
    };
  }
}

class _PrototypeHeader extends StatelessWidget {
  final int stage;
  final List<String> labels;
  final VoidCallback onClose;

  const _PrototypeHeader({
    required this.stage,
    required this.labels,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to home',
                onPressed: onClose,
                color: SpotlightPalette.cream,
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'WHO KNOWS ME?',
                    style: GoogleFonts.outfit(
                      color: SpotlightPalette.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SpotlightPalette.mint.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: SpotlightPalette.mint.withValues(alpha: 0.36),
                  ),
                ),
                child: Text(
                  'PROTOTYPE',
                  style: GoogleFonts.inter(
                    color: SpotlightPalette.mint,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(labels.length, (index) {
              final active = index == stage;
              final completed = index < stage;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == labels.length - 1 ? 0 : 5,
                  ),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? SpotlightPalette.coral
                              : completed
                              ? SpotlightPalette.violet
                              : SpotlightPalette.panelRaised,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[index],
                        maxLines: 1,
                        style: GoogleFonts.inter(
                          color: active
                              ? SpotlightPalette.cream
                              : SpotlightPalette.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PlayerTurnCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accent;

  const _PlayerTurnCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.accent = SpotlightPalette.violet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SpotlightPalette.panelDecoration(accent: accent),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: SpotlightPalette.heroGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: SpotlightPalette.violet.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Text(
              'M',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: SpotlightPalette.cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: SpotlightPalette.textSoft,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String label;
  final String question;
  final Color accent;

  const _QuestionCard({
    required this.label,
    required this.question,
    this.accent = SpotlightPalette.coral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SpotlightPalette.cream,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF3D3443),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question,
            style: GoogleFonts.outfit(
              color: SpotlightPalette.ink,
              fontSize: 27,
              height: 1.06,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecretAnswerStage extends StatelessWidget {
  const _SecretAnswerStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PlayerTurnCard(
          eyebrow: 'SPOTLIGHT PLAYER',
          title: "Maya's turn",
          subtitle: 'Hand Maya the phone. Nobody else should peek.',
          accent: SpotlightPalette.mint,
        ),
        const SizedBox(height: 16),
        const _QuestionCard(
          label: 'FOR MAYA ONLY',
          question: 'How many unread messages are currently on your phone?',
          accent: SpotlightPalette.mint,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: SpotlightPalette.panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR REAL ANSWER',
                style: GoogleFonts.inter(
                  color: SpotlightPalette.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('spotlight-secret-answer'),
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(
                  color: SpotlightPalette.cream,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a number',
                  suffixIcon: Icon(
                    Icons.lock_rounded,
                    color: SpotlightPalette.mint,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your answer stays hidden until the final reveal.',
                style: GoogleFonts.inter(
                  color: SpotlightPalette.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuessStage extends StatelessWidget {
  const _GuessStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PlayerTurnCard(
          eyebrow: 'EVERYONE EXCEPT MAYA',
          title: 'How well do you know her?',
          subtitle: 'Maya answered privately. Now lock in your guess.',
          accent: SpotlightPalette.coral,
        ),
        const SizedBox(height: 16),
        const _QuestionCard(
          label: 'GUESS ABOUT MAYA',
          question: "How many unread messages are currently on Maya's phone?",
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: SpotlightPalette.panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR GUESS',
                style: GoogleFonts.inter(
                  color: SpotlightPalette.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('spotlight-guess'),
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(
                  color: SpotlightPalette.cream,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
                decoration: const InputDecoration(hintText: 'Your best guess'),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: _ReadyPill(name: 'ALEX', ready: true)),
                  SizedBox(width: 8),
                  Expanded(child: _ReadyPill(name: 'JORDAN', ready: true)),
                  SizedBox(width: 8),
                  Expanded(child: _ReadyPill(name: 'SAM', ready: false)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadyPill extends StatelessWidget {
  final String name;
  final bool ready;

  const _ReadyPill({required this.name, required this.ready});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: ready
            ? SpotlightPalette.mint.withValues(alpha: 0.12)
            : SpotlightPalette.ink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? SpotlightPalette.mint.withValues(alpha: 0.38)
              : SpotlightPalette.cream.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.more_horiz_rounded,
            size: 13,
            color: ready ? SpotlightPalette.mint : SpotlightPalette.textMuted,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: ready
                    ? SpotlightPalette.cream
                    : SpotlightPalette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPickStage extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _TrustPickStage({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const players = [
      ('Alex', 'A', SpotlightPalette.coral),
      ('Jordan', 'J', SpotlightPalette.violet),
      ('Sam', 'S', SpotlightPalette.lemon),
    ];

    return Column(
      children: [
        const _PlayerTurnCard(
          eyebrow: 'MAYA\'S BONUS PICK',
          title: 'Who knows you best?',
          subtitle: 'Pick before their guesses are revealed. Nail it for +3.',
          accent: SpotlightPalette.lemon,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: SpotlightPalette.panelDecoration(),
          child: Column(
            children: List.generate(players.length, (index) {
              final player = players[index];
              final selected = index == selectedIndex;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == players.length - 1 ? 0 : 10,
                ),
                child: InkWell(
                  key: ValueKey('trust-pick-$index'),
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? SpotlightPalette.violet.withValues(alpha: 0.15)
                          : SpotlightPalette.ink.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? SpotlightPalette.violet
                            : SpotlightPalette.cream.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: player.$3,
                          foregroundColor: SpotlightPalette.ink,
                          child: Text(
                            player.$2,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            player.$1,
                            style: GoogleFonts.outfit(
                              color: SpotlightPalette.cream,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected
                              ? SpotlightPalette.violet
                              : SpotlightPalette.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _BetStage extends StatelessWidget {
  const _BetStage();

  @override
  Widget build(BuildContext context) {
    const guesses = [
      ('ALEX', '48', SpotlightPalette.coral),
      ('JORDAN', '96', SpotlightPalette.violet),
      ('SAM', '210', SpotlightPalette.lemon),
    ];

    return Column(
      children: [
        const _PlayerTurnCard(
          eyebrow: 'GUESSES ARE IN',
          title: 'Back the best guess',
          subtitle: "Maya can't bet this round — she already knows the answer.",
          accent: SpotlightPalette.violet,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          decoration: SpotlightPalette.panelDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'PLACE YOUR CHIP',
                    style: GoogleFonts.inter(
                      color: SpotlightPalette.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'CLOSEST WINS',
                    style: GoogleFonts.inter(
                      color: SpotlightPalette.mint,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final guess in guesses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: SpotlightPalette.ink.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: guess.$3.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 36,
                          decoration: BoxDecoration(
                            color: guess.$3,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            guess.$1,
                            style: GoogleFonts.inter(
                              color: SpotlightPalette.textSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          guess.$2,
                          style: GoogleFonts.outfit(
                            color: SpotlightPalette.cream,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const _MiniChip(label: '1'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: SpotlightPalette.heroGradient,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: SpotlightPalette.violet.withValues(alpha: 0.28),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RevealStage extends StatelessWidget {
  final int? trustPick;

  const _RevealStage({required this.trustPick});

  @override
  Widget build(BuildContext context) {
    const names = ['Alex', 'Jordan', 'Sam'];
    final pickedName = names[(trustPick ?? 0).clamp(0, names.length - 1)];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: SpotlightPalette.heroGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: SpotlightPalette.violet.withValues(alpha: 0.3),
                blurRadius: 38,
                offset: const Offset(0, 18),
                spreadRadius: -12,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                "MAYA'S REAL ANSWER",
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '83',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'unread messages',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: SpotlightPalette.panelDecoration(),
          child: Column(
            children: [
              const _ResultRow(
                place: '1',
                name: 'Jordan',
                guess: '96',
                distance: '13 away',
                color: SpotlightPalette.violet,
                winner: true,
              ),
              const SizedBox(height: 9),
              const _ResultRow(
                place: '2',
                name: 'Alex',
                guess: '48',
                distance: '35 away',
                color: SpotlightPalette.coral,
              ),
              const SizedBox(height: 9),
              const _ResultRow(
                place: '3',
                name: 'Sam',
                guess: '210',
                distance: '127 away',
                color: SpotlightPalette.lemon,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: SpotlightPalette.mint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SpotlightPalette.mint.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "Maya trusted $pickedName${pickedName == 'Jordan' ? ' — nailed it! +3' : ''}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: SpotlightPalette.mint,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String place;
  final String name;
  final String guess;
  final String distance;
  final Color color;
  final bool winner;

  const _ResultRow({
    required this.place,
    required this.name,
    required this.guess,
    required this.distance,
    required this.color,
    this.winner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: winner
            ? color.withValues(alpha: 0.14)
            : SpotlightPalette.ink.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: winner ? color.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Text(
            '#$place',
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: SpotlightPalette.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  distance,
                  style: GoogleFonts.inter(
                    color: SpotlightPalette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            guess,
            style: GoogleFonts.outfit(
              color: SpotlightPalette.cream,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (winner) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.workspace_premium_rounded,
              color: SpotlightPalette.lemon,
              size: 21,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrototypeControls extends StatelessWidget {
  final int stage;
  final int stageCount;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _PrototypeControls({
    required this.stage,
    required this.stageCount,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: SpotlightPalette.inkSoft.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: SpotlightPalette.cream.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton.filled(
              tooltip: 'Previous stage',
              onPressed: stage == 0 ? null : onBack,
              style: IconButton.styleFrom(
                backgroundColor: SpotlightPalette.panelRaised,
                disabledBackgroundColor: SpotlightPalette.panel,
                foregroundColor: SpotlightPalette.cream,
                disabledForegroundColor: SpotlightPalette.textMuted,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('spotlight-next-stage'),
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: SpotlightPalette.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                icon: Icon(
                  stage == stageCount - 1
                      ? Icons.refresh_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  stage == stageCount - 1 ? 'REPLAY FLOW' : 'NEXT STAGE',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
