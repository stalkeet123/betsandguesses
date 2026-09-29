import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

const appLocalePreferenceKey = 'app_locale';
const supportedLanguageCodes = {'en', 'tr'};

class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref
        .read(sharedPrefsProvider)
        .getString(appLocalePreferenceKey);
    return Locale(supportedLanguageCodes.contains(code) ? code! : 'en');
  }

  Future<void> setLanguage(String languageCode) async {
    final code = supportedLanguageCodes.contains(languageCode)
        ? languageCode
        : 'en';
    state = Locale(code);
    await ref.read(sharedPrefsProvider).setString(appLocalePreferenceKey, code);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);
