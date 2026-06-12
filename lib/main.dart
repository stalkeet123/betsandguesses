import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/supabase_constants.dart';
import 'core/widgets/cached_asset_image.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 80;
  imageCache.maximumSizeBytes = 96 << 20;

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full-screen immersive
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

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
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const TahminApp(),
    ),
  );
}

class TahminApp extends StatefulWidget {
  const TahminApp({super.key});

  @override
  State<TahminApp> createState() => _TahminAppState();
}

class _TahminAppState extends State<TahminApp> {
  bool _didWarmUpImages = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didWarmUpImages) return;
    _didWarmUpImages = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppAssetPaths.warmUpImages(context).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tahmin.io',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return Container(
          color: const Color(0xFF0F0805), // Dark luxury casino leather background for desktop borders
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: child != null ? ClipRect(child: child) : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
