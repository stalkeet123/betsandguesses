import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/constants/supabase_constants.dart';
import 'core/widgets/cached_asset_image.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 50;
  imageCache.maximumSizeBytes = 48 << 20;

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full-screen immersive
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConstants.anonKey,
  );

  try {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      await supabase.auth.signInAnonymously();
    }
  } catch (error, stackTrace) {
    debugPrint('Secure session initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(const _StartupFailureApp());
    return;
  }

  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const TahminApp(),
    ),
  );
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Secure connection unavailable',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and restart the app.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TahminApp extends ConsumerStatefulWidget {
  const TahminApp({super.key});

  @override
  ConsumerState<TahminApp> createState() => _TahminAppState();
}

class _TahminAppState extends ConsumerState<TahminApp>
    with WidgetsBindingObserver {
  bool _didWarmUpImages = false;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setScreenAwake(true);
  }

  void _setScreenAwake(bool enabled) {
    final operation = enabled ? WakelockPlus.enable() : WakelockPlus.disable();
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        debugPrint('Screen wakelock update failed: $error');
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setScreenAwake(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setScreenAwake(true);
        ref.read(audioServiceProvider).setAppActive(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _setScreenAwake(false);
        ref.read(audioServiceProvider).setAppActive(false);
        break;
      case AppLifecycleState.inactive:
        // Inactive is often a brief focus change. Restarting the native audio
        // engine here causes audible cuts when a dialog or system UI appears.
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didWarmUpImages) return;
    _didWarmUpImages = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppAssetPaths.warmUpStartupImages(context).catchError((_) {});
      // On mobile, start music immediately (no autoplay restriction).
      // On web, we wait for the first user interaction (handled by Listener below).
      if (!kIsWeb) {
        ref.read(audioServiceProvider).startMainBgm();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bets & Guesses',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return Container(
          color: const Color(
            0xFF0F0805,
          ), // Dark luxury casino leather background for desktop borders
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: child != null
                  ? kIsWeb
                        ? Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) {
                              if (!_hasInteracted) {
                                _hasInteracted = true;
                                ref
                                    .read(audioServiceProvider)
                                    .unlockFromUserGesture();
                              }
                            },
                            child: ClipRect(child: child),
                          )
                        : ClipRect(child: child)
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
