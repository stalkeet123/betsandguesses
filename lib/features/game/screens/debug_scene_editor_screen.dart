import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../widgets/poker_chip.dart';

/// A local-only still scene for preparing store and social screenshots.
///
/// This screen deliberately has no providers, timers, audio, networking, game
/// transitions, or persistence. The route that exposes it only exists in debug
/// builds.
class DebugSceneEditorScreen extends StatefulWidget {
  const DebugSceneEditorScreen({super.key});

  @override
  State<DebugSceneEditorScreen> createState() => _DebugSceneEditorScreenState();
}

class _DebugSceneEditorScreenState extends State<DebugSceneEditorScreen> {
  static const _defaultQuestion =
      'How many slices of pizza could your group finish in one night?';

  String _question = _defaultQuestion;
  List<int> _boundaries = _defaultBoundaries();
  bool _showChrome = true;
  int? _selectedChipId;
  int _nextChipId = 5;
  List<_SceneChip> _chips = _defaultChips();

  static List<int> _defaultBoundaries() => [15, 28, 51, 120];

  static List<_SceneChip> _defaultChips() => const [
    _SceneChip(
      id: 1,
      label: '50',
      color: AppColors.burgundy,
      position: Offset(0.73, 0.19),
      rotation: -0.16,
    ),
    _SceneChip(
      id: 2,
      label: '100',
      color: AppColors.neonPurple,
      position: Offset(0.82, 0.43),
      rotation: 0.12,
    ),
    _SceneChip(
      id: 3,
      label: '10',
      color: AppColors.neonBlue,
      position: Offset(0.69, 0.69),
      rotation: -0.08,
    ),
    _SceneChip(
      id: 4,
      label: '500',
      color: AppColors.chipGold,
      position: Offset(0.86, 0.84),
      rotation: 0.19,
    ),
  ];

  void _reset() {
    setState(() {
      _question = _defaultQuestion;
      _boundaries = _defaultBoundaries();
      _chips = _defaultChips();
      _selectedChipId = null;
      _nextChipId = 5;
    });
  }

  Future<void> _editQuestion() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _QuestionEditorDialog(initialValue: _question),
    );
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _question = value);
  }

  Future<void> _editRanges() async {
    final value = await showDialog<List<int>>(
      context: context,
      builder: (context) => _RangeEditorDialog(initialValues: _boundaries),
    );
    if (value == null || !mounted) return;
    setState(() => _boundaries = value);
  }

  Future<void> _addChip() async {
    final chip = await _showChipEditor(
      _SceneChip(
        id: _nextChipId,
        label: '50',
        color: AppColors.burgundy,
        position: const Offset(0.75, 0.5),
      ),
      isNew: true,
    );
    if (chip == null || !mounted) return;
    setState(() {
      _chips = [..._chips, chip];
      _selectedChipId = chip.id;
      _nextChipId++;
    });
  }

  Future<void> _editSelectedChip() async {
    final index = _chips.indexWhere((chip) => chip.id == _selectedChipId);
    if (index == -1) return;
    final edited = await _showChipEditor(_chips[index]);
    if (edited == null || !mounted) return;
    setState(() {
      final next = [..._chips];
      next[index] = edited;
      _chips = next;
    });
  }

  Future<_SceneChip?> _showChipEditor(
    _SceneChip initial, {
    bool isNew = false,
  }) {
    return showModalBottomSheet<_SceneChip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChipEditorSheet(initial: initial, isNew: isNew),
    );
  }

  void _deleteSelectedChip() {
    if (_selectedChipId == null) return;
    setState(() {
      _chips = _chips.where((chip) => chip.id != _selectedChipId).toList();
      _selectedChipId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _showChrome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_showChrome) setState(() => _showChrome = true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: _StillGameSceneBackground()),
                Positioned.fill(
                  child: _StillGameScene(
                    question: _question,
                    boundaries: _boundaries,
                  ),
                ),
                for (final chip in _chips)
                  _buildMovableChip(chip, constraints.biggest),
                if (!_showChrome)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPress: () => setState(() => _showChrome = true),
                    ),
                  ),
                if (_showChrome) ...[
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 8,
                    right: 8,
                    child: _buildToolbar(),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: MediaQuery.paddingOf(context).bottom + 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'Tap a chip to select • drag to move • long-press to edit',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMovableChip(_SceneChip chip, Size canvasSize) {
    final selected = _showChrome && chip.id == _selectedChipId;
    return Positioned(
      left: chip.position.dx * canvasSize.width - chip.size / 2,
      top: chip.position.dy * canvasSize.height - chip.size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showChrome
            ? () => setState(() => _selectedChipId = chip.id)
            : null,
        onLongPress: _showChrome
            ? () {
                setState(() => _selectedChipId = chip.id);
                _editSelectedChip();
              }
            : null,
        onPanStart: _showChrome
            ? (_) => setState(() => _selectedChipId = chip.id)
            : null,
        onPanUpdate: _showChrome
            ? (details) {
                final index = _chips.indexWhere((item) => item.id == chip.id);
                if (index == -1) return;
                final nextPosition = Offset(
                  (chip.position.dx + details.delta.dx / canvasSize.width)
                      .clamp(0.0, 1.0),
                  (chip.position.dy + details.delta.dy / canvasSize.height)
                      .clamp(0.0, 1.0),
                );
                setState(() {
                  final next = [..._chips];
                  next[index] = chip.copyWith(position: nextPosition);
                  _chips = next;
                });
              }
            : null,
        child: Transform.rotate(
          angle: chip.rotation,
          child: Container(
            padding: EdgeInsets.all(selected ? 4 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: AppColors.neonCyan,
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: PokerChip(
              label: chip.label,
              color: chip.color,
              size: chip.size,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final hasSelection = _selectedChipId != null;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xEE111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Row(
        children: [
          _toolButton(
            Icons.arrow_back_rounded,
            () => Navigator.pop(context),
            'Back',
          ),
          _toolButton(Icons.title_rounded, _editQuestion, 'Question'),
          _toolButton(Icons.view_stream_rounded, _editRanges, 'Bet ranges'),
          _toolButton(Icons.add_circle_outline_rounded, _addChip, 'Add chip'),
          _toolButton(
            Icons.tune_rounded,
            hasSelection ? _editSelectedChip : null,
            'Edit chip',
          ),
          _toolButton(
            Icons.delete_outline_rounded,
            hasSelection ? _deleteSelectedChip : null,
            'Delete chip',
          ),
          _toolButton(Icons.refresh_rounded, _reset, 'Reset'),
          const Spacer(),
          _toolButton(
            Icons.visibility_rounded,
            () => setState(() {
              _selectedChipId = null;
              _showChrome = false;
            }),
            'Clean preview',
            accent: true,
          ),
        ],
      ),
    );
  }

  Widget _toolButton(
    IconData icon,
    VoidCallback? onPressed,
    String tooltip, {
    bool accent = false,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 21,
      color: accent ? AppColors.brassLight : Colors.white,
      disabledColor: Colors.white24,
      icon: Icon(icon),
    );
  }
}

class _ChipEditorSheet extends StatefulWidget {
  final _SceneChip initial;
  final bool isNew;

  const _ChipEditorSheet({required this.initial, required this.isNew});

  @override
  State<_ChipEditorSheet> createState() => _ChipEditorSheetState();
}

class _ChipEditorSheetState extends State<_ChipEditorSheet> {
  late _SceneChip _draft;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _labelController = TextEditingController(text: widget.initial.label);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _apply() {
    final label = _labelController.text.trim();
    Navigator.pop(context, _draft.copyWith(label: label.isEmpty ? ' ' : label));
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + keyboardInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          decoration: AppColors.leatherPanel(borderRadius: 24),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      widget.isNew ? 'ADD CHIP' : 'EDIT CHIP',
                      style: GoogleFonts.outfit(
                        color: AppColors.ivory,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    PokerChip(
                      label: _labelController.text.isEmpty
                          ? ' '
                          : _labelController.text,
                      color: _draft.color,
                      size: _draft.size,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('chip-value-field'),
                  controller: _labelController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CHIP VALUE'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _chipColors.map((color) {
                    final selected = color == _draft.color;
                    return InkWell(
                      onTap: () => setState(
                        () => _draft = _draft.copyWith(color: color),
                      ),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.white24,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                _slider(
                  label: 'SIZE',
                  value: _draft.size,
                  min: 26,
                  max: 76,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(size: value)),
                ),
                _slider(
                  label: 'ROTATION',
                  value: _draft.rotation,
                  min: -pi,
                  max: pi,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(rotation: value)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _apply,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('APPLY'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionEditorDialog extends StatefulWidget {
  final String initialValue;

  const _QuestionEditorDialog({required this.initialValue});

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('QUESTION'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 7,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Type any screenshot question…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _apply, child: const Text('APPLY')),
      ],
    );
  }
}

class _RangeEditorDialog extends StatefulWidget {
  final List<int> initialValues;

  const _RangeEditorDialog({required this.initialValues});

  @override
  State<_RangeEditorDialog> createState() => _RangeEditorDialogState();
}

class _RangeEditorDialogState extends State<_RangeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.initialValues
        .map((value) => TextEditingController(text: '$value'))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateBoundary(String? raw, int index) {
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) return 'Enter a whole number';

    if (index > 0) {
      final previous = int.tryParse(_controllers[index - 1].text.trim());
      if (previous != null && value <= previous) {
        return 'Must be greater than $previous';
      }
    }
    return null;
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _controllers
          .map((controller) => int.parse(controller.text.trim()))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'LOWER OUTER BOUNDARY',
      'LOWER INNER BOUNDARY',
      'UPPER INNER BOUNDARY',
      'UPPER OUTER BOUNDARY',
    ];

    return AlertDialog(
      title: const Text('BET RANGES'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter four boundary values in ascending order. They control '
                  'all five betting sections.',
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _controllers.length; i++) ...[
                  TextFormField(
                    controller: _controllers[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    textInputAction: i == _controllers.length - 1
                        ? TextInputAction.done
                        : TextInputAction.next,
                    decoration: InputDecoration(labelText: labels[i]),
                    validator: (value) => _validateBoundary(value, i),
                    onFieldSubmitted: i == _controllers.length - 1
                        ? (_) => _apply()
                        : null,
                  ),
                  if (i != _controllers.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _apply, child: const Text('APPLY')),
      ],
    );
  }
}

const _chipColors = [
  AppColors.neonPink,
  AppColors.feltLight,
  AppColors.neonBlue,
  AppColors.neonCyan,
  AppColors.burgundy,
  AppColors.neonPurple,
  AppColors.chipGold,
  AppColors.brass,
];

class _SceneChip {
  final int id;
  final String label;
  final Color color;
  final Offset position;
  final double size;
  final double rotation;

  const _SceneChip({
    required this.id,
    required this.label,
    required this.color,
    required this.position,
    this.size = 42,
    this.rotation = 0,
  });

  _SceneChip copyWith({
    String? label,
    Color? color,
    Offset? position,
    double? size,
    double? rotation,
  }) {
    return _SceneChip(
      id: id,
      label: label ?? this.label,
      color: color ?? this.color,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
    );
  }
}

class _StillGameSceneBackground extends StatelessWidget {
  const _StillGameSceneBackground();

  @override
  Widget build(BuildContext context) {
    return const CachedAssetImage(AppAssetPaths.background, fit: BoxFit.cover);
  }
}

class _StillGameScene extends StatelessWidget {
  final String question;
  final List<int> boundaries;

  const _StillGameScene({required this.question, required this.boundaries});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 700;
                    final tightGap = compact ? 4.0 : 6.0;
                    final gap = compact ? 8.0 : 10.0;
                    return Column(
                      children: [
                        const Expanded(
                          flex: 20,
                          child: CachedAssetImage(
                            AppAssetPaths.logo,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: tightGap),
                        const SizedBox(
                          height: 42,
                          child: Row(
                            children: [
                              Expanded(
                                child: _SceneInfoPill(
                                  icon: Icons.groups_rounded,
                                  label: 'Round 4/8',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _SceneInfoPill(
                                  icon: Icons.timer_rounded,
                                  label: '0:30',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        Expanded(
                          flex: 29,
                          child: _SceneQuestionCard(question: question),
                        ),
                        SizedBox(height: gap),
                        const SizedBox(height: 102, child: _SceneChipTray()),
                        SizedBox(height: gap),
                        const Expanded(flex: 26, child: _SceneLeaderboard()),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: _SceneBoard(boundaries: boundaries)),
          ],
        ),
      ),
    );
  }
}

class _SceneInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SceneInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.feltDark, AppColors.felt.withValues(alpha: 0.9)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneQuestionCard extends StatelessWidget {
  final String question;

  const _SceneQuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF1), Color(0xFFF6E7C9), Color(0xFFFFFCF4)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ivory, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AppColors.brass)),
              const SizedBox(width: 6),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 11,
                color: AppColors.felt,
              ),
              const SizedBox(width: 6),
              Text(
                'QUESTION',
                style: GoogleFonts.outfit(
                  color: AppColors.felt,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 1, color: AppColors.brass)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 165),
                  child: Text(
                    question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'RehnCondensed',
                      color: Color(0xFF0A2C59),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneChipTray extends StatelessWidget {
  const _SceneChipTray();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: AppColors.brassLight),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Text(
                  'SELECT A CHIP',
                  style: TextStyle(
                    color: AppColors.ivory,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: AppColors.brassLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PokerChip(label: '10', color: AppColors.neonBlue, size: 42),
                PokerChip(label: '50', color: AppColors.burgundy, size: 42),
                PokerChip(label: '100', color: AppColors.neonPurple, size: 42),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _stat('BANK', '850')),
              const SizedBox(width: 6),
              Expanded(child: _stat('ON TABLE', '150')),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _stat(String label, String value) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brassLight.withValues(alpha: 0.28)),
      ),
      child: FittedBox(
        child: Text(
          '$label  $value',
          style: const TextStyle(
            color: AppColors.brassLight,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SceneLeaderboard extends StatelessWidget {
  const _SceneLeaderboard();

  @override
  Widget build(BuildContext context) {
    const players = [('Alex', '1,250'), ('Taylor', '980'), ('Sam', '850')];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.feltDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brass.withValues(alpha: 0.42),
          width: 1.6,
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
      ),
      child: Column(
        children: [
          const Text(
            'LEADERBOARD     BANK',
            style: TextStyle(
              color: AppColors.ivory,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          for (var i = 0; i < players.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == players.length - 1 ? 0 : 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppColors.brassLight.withValues(alpha: 0.13)
                        : Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: i == 0
                              ? AppColors.brassLight
                              : AppColors.ivory,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          players[i].$1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        players[i].$2,
                        style: const TextStyle(
                          color: AppColors.brassLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SceneBoard extends StatelessWidget {
  final List<int> boundaries;

  const _SceneBoard({required this.boundaries});

  static const _slots = [
    (
      index: 4,
      asset: AppAssetPaths.boardGreen,
      odds: '4 TO 1',
      top: 0.020,
      height: 0.182,
      gold: false,
    ),
    (
      index: 3,
      asset: AppAssetPaths.boardBlack,
      odds: '3 TO 1',
      top: 0.217,
      height: 0.174,
      gold: false,
    ),
    (
      index: 2,
      asset: AppAssetPaths.boardGold,
      odds: '2 TO 1',
      top: 0.409,
      height: 0.180,
      gold: true,
    ),
    (
      index: 1,
      asset: AppAssetPaths.boardRed,
      odds: '3 TO 1',
      top: 0.609,
      height: 0.174,
      gold: false,
    ),
    (
      index: 0,
      asset: AppAssetPaths.boardGreen,
      odds: '4 TO 1',
      top: 0.798,
      height: 0.182,
      gold: false,
    ),
  ];

  String _titleFor(int index) {
    return switch (index) {
      4 => 'LARGER',
      3 => 'BETWEEN\n${boundaries[2]} & ${boundaries[3]}\n(INCLUSIVE)',
      2 => 'SWEET SPOT',
      1 => 'BETWEEN\n${boundaries[0]} & ${boundaries[1]}\n(INCLUSIVE)',
      _ => 'SMALLER',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final slot in _slots)
                Positioned(
                  left: (slot.gold ? -0.01 : 0.055) * constraints.maxWidth,
                  top: slot.top * constraints.maxHeight,
                  width: (slot.gold ? 1.02 : 0.89) * constraints.maxWidth,
                  height: slot.height * constraints.maxHeight,
                  child: _SceneBoardSlot(
                    asset: slot.asset,
                    title: _titleFor(slot.index),
                    odds: slot.odds,
                    gold: slot.gold,
                  ),
                ),
              for (var i = 0; i < boundaries.length; i++)
                Positioned(
                  left: 1,
                  right: 1,
                  top:
                      const [0.202, 0.397, 0.595, 0.790][i] *
                          constraints.maxHeight -
                      18,
                  height: 36,
                  child: _SceneBoundaryLabel(
                    value: boundaries.reversed.elementAt(i),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SceneBoundaryLabel extends StatelessWidget {
  final int value;

  const _SceneBoundaryLabel({required this.value});

  @override
  Widget build(BuildContext context) {
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.brass.withValues(alpha: 0.75),
                Colors.white70,
                AppColors.brass.withValues(alpha: 0.75),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        FractionallySizedBox(
          widthFactor: 0.54,
          heightFactor: 0.82,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF8C9),
                  Color(0xFFFFD25A),
                  Color(0xFFC98116),
                ],
              ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white70),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatted,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'RehnCondensed',
                  color: AppColors.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SceneBoardSlot extends StatelessWidget {
  final String asset;
  final String title;
  final String odds;
  final bool gold;

  const _SceneBoardSlot({
    required this.asset,
    required this.title,
    required this.odds,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(gold ? 18 : 10);
    return Container(
      padding: EdgeInsets.all(gold ? 5 : 4),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F4E9), Color(0xFF4B3D32), Color(0xFFFFFDF5)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 9, offset: Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(gold ? 12 : 6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedAssetImage(asset, fit: gold ? BoxFit.fill : BoxFit.cover),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: title.startsWith('BETWEEN')
                        ? GoogleFonts.outfit(
                            color: AppColors.ivory.withValues(alpha: 0.4),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          )
                        : GoogleFonts.rye(
                            color: gold ? AppColors.mahoganyDark : Colors.white,
                            fontSize: gold ? 20 : 27,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: RotatedBox(
                quarterTurns: 3,
                child: Center(
                  child: Text(
                    odds,
                    style: TextStyle(
                      color: (gold ? AppColors.mahoganyDark : Colors.white)
                          .withValues(alpha: 0.52),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
