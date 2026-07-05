import 'package:flutter/foundation.dart';

class RevenueCatConstants {
  RevenueCatConstants._();

  static const entitlementIdentifier = 'hubword';
  static const offeringIdentifier = 'ofrngc0dc81ffeb';

  static const dailyPassPackageIdentifier = 'daily_pass';
  static const lifetimePackageIdentifier = r'$rc_lifetime';

  static const dailyPassProductIdentifier = 'com.wordhub.app.dailypass';
  static const lifetimeProductIdentifier = 'com.wordhub.app.lifetimepass';

  static const androidApiKey = '';
  static const iosApiKey = 'appl_MzoHrbHNfoVGVENeszXsvCofQjG';
  static const webApiKey = '';

  static String get apiKey {
    if (kIsWeb) return webApiKey;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => androidApiKey,
      TargetPlatform.iOS => iosApiKey,
      TargetPlatform.macOS => iosApiKey,
      _ => '',
    };
  }

  static bool get hasApiKey => apiKey.trim().isNotEmpty;
}
