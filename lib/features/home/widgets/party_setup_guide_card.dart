import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../party/theme/party_palette.dart';

/// Party setup guidance that deliberately uses the panel space it receives.
class PartySetupGuideCard extends StatelessWidget {
  const PartySetupGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final density = constraints.maxHeight >= 170 * textScale
            ? _PartyGuideDensity.full
            : constraints.maxHeight >= 100 * textScale
            ? _PartyGuideDensity.compact
            : _PartyGuideDensity.singleLine;
        final padding = density == _PartyGuideDensity.full ? 14.0 : 8.0;

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PartyPalette.nightDeep.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: PartyPalette.orangeSoft.withValues(alpha: 0.38),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: switch (density) {
              _PartyGuideDensity.full => const _PartyGuideRules(
                rules: [
                  _PartyGuideRuleData(
                    icon: Icons.person_search_rounded,
                    title: 'PICK A PLAYER',
                    description: 'Choose who best fits the prompt.',
                  ),
                  _PartyGuideRuleData(
                    icon: Icons.casino_rounded,
                    title: 'PLACE YOUR CHIPS',
                    description: 'Your chips are your vote and your risk.',
                  ),
                  _PartyGuideRuleData(
                    icon: Icons.emoji_events_rounded,
                    title: 'HIGHEST TOTAL WINS',
                    description: 'Winning chips score; losing chips cost you.',
                  ),
                ],
              ),
              _PartyGuideDensity.compact => const _PartyGuideRules(
                compact: true,
                rules: [
                  _PartyGuideRuleData(
                    icon: Icons.how_to_vote_rounded,
                    title: 'PICK + BET',
                    description: 'Pick a player and put chips behind them.',
                  ),
                  _PartyGuideRuleData(
                    icon: Icons.emoji_events_rounded,
                    title: 'WIN THE POLL',
                    description: 'Highest total wins; your chips are at risk.',
                  ),
                ],
              ),
              _PartyGuideDensity.singleLine => Center(
                child: Text(
                  'Pick a player • Bet chips • Highest total wins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: PartyPalette.cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            },
          ),
        );
      },
    );
  }
}

enum _PartyGuideDensity { full, compact, singleLine }

class _PartyGuideRules extends StatelessWidget {
  const _PartyGuideRules({required this.rules, this.compact = false});

  final List<_PartyGuideRuleData> rules;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rules.length; index++) ...[
          Expanded(
            child: _PartyGuideRule(rule: rules[index], compact: compact),
          ),
          if (index < rules.length - 1)
            Container(
              height: 1,
              color: PartyPalette.orangeSoft.withValues(alpha: 0.16),
            ),
        ],
      ],
    );
  }
}

class _PartyGuideRuleData {
  const _PartyGuideRuleData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _PartyGuideRule extends StatelessWidget {
  const _PartyGuideRule({required this.rule, required this.compact});

  final _PartyGuideRuleData rule;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 28.0 : 36.0;
    final titleSize = compact ? 11.5 : 13.0;
    final descriptionSize = compact ? 10.5 : 11.5;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PartyPalette.orange.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(compact ? 9 : 11),
          ),
          child: Icon(
            rule.icon,
            size: compact ? 16 : 20,
            color: PartyPalette.orangeSoft,
          ),
        ),
        SizedBox(width: compact ? 8 : 11),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rule.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: PartyPalette.cream,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rule.description,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: PartyPalette.creamMuted.withValues(alpha: 0.9),
                  fontSize: descriptionSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
