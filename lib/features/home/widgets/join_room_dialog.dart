import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_asset_image.dart';
import '../../../features/room/providers/room_providers.dart';

class JoinRoomDialog extends ConsumerStatefulWidget {
  final String playerName;
  final String? initialCode;

  const JoinRoomDialog({super.key, required this.playerName, this.initialCode});

  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog> {
  final _codeController = TextEditingController();
  final _random = Random();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != GameConstants.roomCodeLength) {
      setState(() => _error = 'Room code must be ${GameConstants.roomCodeLength} characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roomService = ref.read(roomServiceProvider);
      final playerService = ref.read(playerServiceProvider);
      final room = await roomService.findRoomByCode(code);
      if (room == null) {
        setState(() => _error = 'Room not found.');
        return;
      }

      if (!room.canJoinLobby) {
        setState(() => _error = 'That table is already playing.');
        return;
      }

      final existingPlayers = await playerService.getPlayers(room.id);
      final usedColors = existingPlayers.map((p) => p.avatarColor).toSet();
      final availableColor = _pickAvatarColor(usedColors);

      final player = await playerService.joinRoom(
        roomId: room.id,
        name: widget.playerName,
        avatarColor: availableColor,
      );

      ref.read(currentPlayerProvider.notifier).set(player);
      ref.read(currentRoomProvider.notifier).set(room);

      if (mounted) {
        Navigator.of(context).pop();
        context.goNamed('lobby', pathParameters: {'roomCode': room.code});
      }
    } catch (e) {
      setState(() => _error = 'Could not join: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _pickAvatarColor(Set<String> usedColors) {
    final availableColors = GameConstants.avatarColors.where((color) => !usedColors.contains(color)).toList();
    final palette = availableColors.isEmpty ? GameConstants.avatarColors : availableColors;
    return palette[_random.nextInt(palette.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFAEC), Color(0xFFEBCB82), Color(0xFFFFF8DE)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.ivory.withValues(alpha: 0.88), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 86,
              child: CachedAssetImage(
                AppAssetPaths.logo,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JOIN TABLE',
              style: const TextStyle(
                fontFamily: 'RehnCondensed',
                color: Color(0xFF0A2C59),
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: GameConstants.roomCodeLength,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                letterSpacing: 6,
                fontWeight: FontWeight.w900,
                color: AppColors.ivory,
              ),
              decoration: InputDecoration(
                hintText: 'CODE',
                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 4,
                ),
                counterText: '',
              ),
              onSubmitted: (_) => _join(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mahogany,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _join,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                      )
                    : const Text('JOIN TABLE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
