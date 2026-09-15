import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Local-only diagnostics for timing issues. This never sends a network request.
class GameTraceService {
  GameTraceService._();

  static final instance = GameTraceService._();
  static const _maxRecords = 2000;
  static const _sessionRandomBound = 1 << 30;
  static const _enabledByDefine = bool.fromEnvironment('BG_TRACE');

  final Stopwatch _stopwatch = Stopwatch()..start();
  final Queue<String> _records = Queue<String>();
  final ValueNotifier<int> recordCount = ValueNotifier<int>(0);
  final String _sessionId = createSessionId();
  int _sequence = 0;
  bool? _enabled;

  @visibleForTesting
  static String createSessionId({DateTime? timestamp, Random? random}) {
    final timestampPart = (timestamp ?? DateTime.now())
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(36);
    final randomPart = (random ?? Random())
        .nextInt(_sessionRandomBound)
        .toRadixString(36);
    return '$timestampPart-$randomPart';
  }

  bool get enabled => _enabled ??= _resolveEnabled();

  bool _resolveEnabled() {
    if (kDebugMode || _enabledByDefine) return true;
    return kIsWeb && Uri.base.queryParameters['trace'] == '1';
  }

  void trace(String event, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    final record = <String, Object?>{
      'session_id': _sessionId,
      'seq': ++_sequence,
      'event': event,
      'wall_utc': DateTime.now().toUtc().toIso8601String(),
      'mono_ms': _stopwatch.elapsedMilliseconds,
      'platform': defaultTargetPlatform.name,
      'kIsWeb': kIsWeb,
      ...fields,
    };
    final line = '[BG_TRACE] ${jsonEncode(record)}';
    if (_records.length == _maxRecords) _records.removeFirst();
    _records.addLast(line);
    recordCount.value = _records.length;
    debugPrint(line);
  }

  String export() => _records.join('\n');

  @visibleForTesting
  void resetForTest({bool? enabled}) {
    _records.clear();
    _sequence = 0;
    _enabled = enabled;
    recordCount.value = 0;
  }
}

/// A tiny, trace-only escape hatch for copying local diagnostics from release web.
class GameTraceOverlay extends StatefulWidget {
  const GameTraceOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<GameTraceOverlay> createState() => _GameTraceOverlayState();
}

class _GameTraceOverlayState extends State<GameTraceOverlay> {
  bool _copied = false;

  Future<void> _copyTrace() async {
    await Clipboard.setData(
      ClipboardData(text: GameTraceService.instance.export()),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!GameTraceService.instance.enabled) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          right: 4,
          child: SafeArea(
            child: Material(
              color: Colors.black.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _copyTrace,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: GameTraceService.instance.recordCount,
                    builder: (_, count, _) => Text(
                      _copied ? 'COPIED' : 'TRACE $count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
