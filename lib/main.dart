import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const TahminApp(),
    ),
  );
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(audioServiceProvider)
        .setAppActive(state == AppLifecycleState.resumed);
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
                                ref.read(audioServiceProvider).startMainBgm();
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
