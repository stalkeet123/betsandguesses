import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';

class GuessInputPanel extends StatefulWidget {
  final RoundPhase phase;
  final bool hasSubmitted;
  final bool hasPlacedBets;
  final Function(int value) onSubmit;
  final VoidCallback? onLockBets;

  const GuessInputPanel({
    super.key,
    required this.phase,
    required this.hasSubmitted,
    required this.hasPlacedBets,
    required this.onSubmit,
    this.onLockBets,
  });

  @override
  State<GuessInputPanel> createState() => _GuessInputPanelState();
}

class _GuessInputPanelState extends State<GuessInputPanel> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim().replaceAll('.', '').replaceAll(',', '');
    if (text.isEmpty) return;

    final value = int.tryParse(text);
    if (value == null) return;

    setState(() => _isSubmitting = true);
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final canGuess = widget.phase == RoundPhase.guessing && !widget.hasSubmitted;
    final isBetting = widget.phase == RoundPhase.betting;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppColors.leatherPanel(borderRadius: 18),
      child: Column(
        children: [
          _StationHeader(
            icon: widget.hasSubmitted ? Icons.check_circle_rounded : Icons.edit_note_rounded,
            title: widget.hasSubmitted ? 'Guess sent' : 'Your guess',
            color: widget.hasSubmitted ? AppColors.neonGreen : AppColors.brassLight,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.brass.withValues(alpha: 0.58)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _controller,
                    enabled: canGuess,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 25,
                    ),
                    decoration: InputDecoration(
                      hintText: canGuess ? '?' : '--',
                      hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w900,
                      ),
                      fillColor: AppColors.ivory,
                      filled: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    canGuess
                        ? 'write the closest number'
                        : widget.hasSubmitted
                            ? 'face down on the table'
                            : 'wait for the next round',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.56),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: canGuess && !_isSubmitting ? _submit : null,
              icon: Icon(
                widget.hasSubmitted ? Icons.done_all_rounded : Icons.send_rounded,
                size: 18,
              ),
              label: Text(widget.hasSubmitted ? 'SENT' : 'SUBMIT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.hasSubmitted ? AppColors.neonGreen : AppColors.brass,
                foregroundColor: AppColors.ink,
                disabledBackgroundColor: AppColors.surfaceLight,
                disabledForegroundColor: AppColors.textMuted,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (isBetting) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: widget.hasPlacedBets ? null : widget.onLockBets,
                icon: Icon(
                  widget.hasPlacedBets ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 18,
                ),
                label: Text(widget.hasPlacedBets ? 'LOCKED' : 'LOCK BETS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.hasPlacedBets ? AppColors.neonGreen : AppColors.burgundy,
                  foregroundColor: widget.hasPlacedBets ? AppColors.ink : Colors.white,
                  disabledBackgroundColor: AppColors.surfaceLight,
                  disabledForegroundColor: AppColors.textMuted,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideX(begin: -0.04);
  }
}

class _StationHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _StationHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
