# Performance and RAM Optimization Report

Project: `witsgame` / Tahmin.io Flutter app
Date: 2026-07-10

## Executive Summary

The main RAM and performance risks are concentrated in three areas:

1. Audio assets are large and eagerly loaded at startup.
2. The game screen has broad rebuilds across a very large widget tree.
3. Startup image caching is intentionally high and warms multiple images immediately.

The highest-return optimization is to convert long `.wav` tracks to compressed formats and lazy-load audio by game phase. The next most valuable change is to narrow Riverpod watches and `setState` zones in `game_screen.dart`.

## Key Measurements

- `assets/` source folder: about 36.9 MB.
- `assets/sound/`: about 25.4 MB across 12 files.
- Largest current source audio files:
  - `686020__yellowtree__elevator-music.wav`: 9.93 MB.
  - `mixkit-game-show-suspense-waiting-667.wav`: 7.03 MB.
  - `saat.wav`: 2.95 MB.
  - `arka plan.mp3`: 1.04 MB.
- Existing debug APK in `build/app/outputs/...`: about 133.47 MB.
- `lib/features/game/screens/game_screen.dart`: 5061 lines, with the largest rebuild surface in the app.

Note: the existing `build/flutter_assets` manifest appears stale and contains old sound files that are not currently present under `assets/sound`. Run `flutter clean` before doing final size comparisons.

## Priority Findings

### P0 - Eager audio loading can consume significant RAM

File: `lib/core/services/audio_service.dart`

`AudioService` loads every audio asset during construction:

- `AudioService(this._prefs)` calls `_initPlayers()` immediately.
- `_initPlayers()` calls `SoLoud.instance.loadAsset(...)` for all background music, suspense music, ticking, time-up, chip, payout, and fanfare sounds.

Why it matters:

- Several sources are large `.wav` files.
- Long `.wav` tracks can cost much more in decoded memory than their file size.
- Users on the home screen or lobby do not need all game-phase sounds loaded yet.

Recommended fixes:

- Convert long music/effect files from `.wav` to compressed `.mp3`, `.ogg`, or another SoLoud-supported streaming-friendly format.
- Lazy-load by use case:
  - Load main/lobby BGM only when the app or lobby starts.
  - Load suspense music only when entering question/guessing phase.
  - Load result/fanfare sounds only before reveal/scoring.
- Add an `ensureLoaded(AudioCue cue)` helper so each cue loads once on demand.
- Consider unloading rarely used sources after phase transitions if SoLoud exposes an unload/dispose API for `AudioSource`.

Expected impact: high RAM reduction and faster cold start, especially on low-memory Android devices.

### P0 - Large widget rebuilds in `game_screen.dart`

File: `lib/features/game/screens/game_screen.dart`

`build()` watches broad state:

- `ref.watch(gameStateProvider)`
- `ref.watch(currentPlayerProvider)`

The betting board also watches broad state inside `_buildBettingBoardAsset()`:

- `ref.watch(gameStateProvider)`
- `ref.watch(currentPlayerProvider)`

Realtime callbacks then frequently mutate state and call `setState(() {})` in the same flow. Examples include phase changes, answer reveal, game started, resync, guess/bet mutations, and reveal sequence transitions.

Why it matters:

- The game screen is very large and visually dense.
- A whole-screen rebuild during betting, reveal animation, or timer events increases frame time and garbage creation.
- Broad watches cause unrelated UI to rebuild when only a small field changes.

Recommended fixes:

- Replace broad watches with `select` where possible:
  - watch only `phase`, `currentRound`, `currentQuestion`, `bets`, `scores`, etc.
- Move the betting board into a separate `ConsumerWidget` or `ConsumerStatefulWidget`.
- Move question card, score panel, host controls, and timer into independent widgets with narrow provider dependencies.
- Avoid pairing Riverpod state updates with `setState(() {})` unless local state changed.
- Use `Consumer` only around the exact subtrees that need provider updates.

Expected impact: high FPS improvement and lower transient allocation during live game play.

### P1 - Image cache is capped high for a narrow asset set

Files:

- `lib/main.dart`
- `lib/core/widgets/cached_asset_image.dart`

Current setup:

- `imageCache.maximumSize = 80`
- `imageCache.maximumSizeBytes = 96 << 20`
- `AppAssetPaths.warmUpImages(context)` precaches background, logo, and four board assets.

Why it matters:

- 96 MB is a large ceiling for an app with only a handful of main image assets.
- Startup warmup competes with Supabase init, audio init, and first-route work.
- The app also constrains content to max width 460, so many devices do not need large decoded images.

Recommended fixes:

- Lower `maximumSizeBytes` to a measured target, for example 32-48 MB.
- Only precache `background` and `logo` on first frame.
- Defer board image warmup until navigating to the game screen or entering betting.
- Use device-aware cache widths:
  - `min(MediaQuery.sizeOf(context).width * devicePixelRatio, assetMaxWidth)`
  - cap backgrounds to the displayed logical width rather than a fixed 1080 when the app is constrained to 460 logical px.

Expected impact: moderate RAM reduction and smoother cold start.

### P1 - Question cache loads all questions into memory

File: `lib/features/game/services/game_service.dart`

Current behavior:

- `prefetchQuestions()` loads `questions.select()` with no column list or limit.
- Lobby startup calls `prefetchQuestions()`.
- `getRandomQuestion()` filters and shuffles the full cached question list.

Why it matters:

- This is fine for a small database, but memory and network cost grow linearly with question count.
- `select()` pulls all columns even if only a subset is needed for gameplay/category lists.

Recommended fixes:

- Select only needed columns for gameplay.
- For category UI, query distinct categories or a lightweight category endpoint instead of hydrating full questions.
- For random question selection, prefer server-side filtering by category and exclude used IDs with a bounded query.
- If keeping a cache, store lightweight DTOs and only hydrate the full question when selected.

Expected impact: low today if question count is small, high as content scales.

### P1 - Realtime/listeners should be scoped outside build where possible

File: `lib/features/room/screens/lobby_screen.dart`

Current behavior:

- `ref.listen(playersStreamProvider(room.id), ...)` and `ref.listen(roomStreamProvider(room.id), ...)` are called inside `build()`.

Riverpod supports this pattern, but in this screen it also triggers `setState` with collapsed player lists, which rebuilds the whole lobby body.

Recommended fixes:

- Move stream handling into dedicated `Consumer` subtrees or provider-derived state.
- Compute active/collapsed players in a provider instead of repeatedly in widget state.
- Rebuild only the player list and start/ready controls when player data changes.

Expected impact: moderate lobby smoothness improvement, especially with frequent presence changes.

### P2 - Sequential score updates can increase latency

File: `lib/features/player/services/player_service.dart`

Original behavior:

- `updateScores()` loops over players and awaits each update serially.

Applied fix:

- `updateScores()` now uses `Future.wait(...)` over the existing per-player `updateScore(...)` method.

Expected impact: lower round-end latency. RAM impact is minimal.

### P2 - Build memory settings are very high

File: `android/gradle.properties`

Original setting:

- `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m ...`

Why it matters:

- This does not increase app RAM usage.
- It can make local/CI builds consume excessive memory and hide inefficient build behavior.

Applied fix:

- Reduced Gradle JVM args to `-Xmx4G`, `MaxMetaspaceSize=1G`, and `ReservedCodeCacheSize=256m`.
- Track build time and peak memory before and after.

Expected impact: lower build-machine RAM usage.

## Release Size Recommendations

File: `android/app/build.gradle.kts`

Release resource shrinking and code minification are now enabled.

Applied release options:

- Enabled `isMinifyEnabled = true`.
- Enabled `isShrinkResources = true`.
- Added `android/app/proguard-rules.pro` with conservative warning rules for RevenueCat and Supabase-related packages.
- Build an AAB for Play Store distribution instead of relying on APK size.
- Run final size checks after `flutter clean`.

## Verification Plan

Use real devices or emulators in profile/release mode:

1. Clean stale outputs:
   - `flutter clean`
   - `flutter pub get`
2. Measure release size:
   - `flutter build appbundle --release --analyze-size`
3. Measure startup and gameplay:
   - `flutter run --profile`
   - Open DevTools memory view.
   - Record heap after launch, after lobby, after game start, after betting, after results, and after returning home.
4. Measure frame rendering:
   - Use DevTools Performance view during betting and reveal animations.
   - Look for rebuild spikes and shader/raster jank.
5. Android-specific memory:
   - `adb shell dumpsys meminfo com.hubword.app`
   - capture before and after audio lazy-loading changes.

## Implementation Status

1. Audio lazy-loading: applied.
2. Initial game-screen rebuild reduction: applied.
3. Reduced/deferred image warmup: applied.
4. Lightweight question prefetching: applied.
5. Lobby realtime rebuild guards: applied.
6. Parallel score updates: applied.
7. Release shrinking and lower Gradle build heap: applied.

Remaining optional work:

- Convert/compress the largest `.wav` files after installing an encoder such as `ffmpeg`, `lame`, or `sox`.
- Split `game_screen.dart` into smaller provider-aware widgets for a deeper rebuild reduction.
- Generate a fresh release size report after `flutter clean`.

## Tooling Notes

- `flutter analyze` and `dart analyze lib` were attempted but timed out after 120 seconds in the sandbox.
- Local audio conversion was checked, but `ffmpeg`, `lame`, and `sox` were not available in the environment.
- `git status` was blocked by Git safe-directory ownership checks in the sandbox, so no repository status assumptions were made.
