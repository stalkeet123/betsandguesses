import 'package:flutter/material.dart';

class AppAssetPaths {
  AppAssetPaths._();

  static const background = 'assets/background.webp';
  static const logo = 'assets/logo.webp';
  static const boardRed = 'assets/1.webp';
  static const boardBlack = 'assets/2.webp';
  static const boardGreen = 'assets/3.webp';
  static const boardGold = 'assets/4.webp';

  static const _criticalWarmupAssets = <String, int>{
    background: 1080,
    logo: 760,
  };

  static const _deferredWarmupAssets = <String, int>{
    boardRed: 720,
    boardBlack: 720,
    boardGreen: 720,
    boardGold: 720,
  };

  static const _cacheWidths = <String, int>{
    ..._criticalWarmupAssets,
    ..._deferredWarmupAssets,
  };

  static int cacheWidthFor(String asset) {
    return _cacheWidths[asset] ?? 720;
  }

  static Future<void> warmUpImages(BuildContext context) async {
    Future<void> warmGroup(Map<String, int> assets) {
      return Future.wait(
        assets.entries.map(
          (entry) => precacheImage(
            ResizeImage(AssetImage(entry.key), width: entry.value),
            context,
          ),
        ),
      );
    }

    await warmGroup(_criticalWarmupAssets);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!context.mounted) return;
    await Future.wait(
      _deferredWarmupAssets.entries.map(
        (entry) => precacheImage(
          ResizeImage(AssetImage(entry.key), width: entry.value),
          context,
        ),
      ),
    );
  }
}

class CachedAssetImage extends StatelessWidget {
  final String asset;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;

  const CachedAssetImage(
    this.asset, {
    super.key,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth ?? AppAssetPaths.cacheWidthFor(asset),
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
    );
  }
}
