import 'package:flutter/material.dart';

import 'app_localizations.dart';
export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

final supportedAppLocales = AppLocalizations.supportedLocales;
