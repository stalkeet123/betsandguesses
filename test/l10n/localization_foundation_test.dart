import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witsgame/core/providers/core_providers.dart';
import 'package:witsgame/core/providers/locale_provider.dart';
import 'package:witsgame/l10n/l10n.dart';

Future<ProviderContainer> _containerWithPreferences(
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(preferences)],
  );
}

void main() {
  test('uses English when no locale preference is stored', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider), const Locale('en'));
  });

  test('uses the stored Turkish locale', () async {
    final container = await _containerWithPreferences({
      appLocalePreferenceKey: 'tr',
    });
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider), const Locale('tr'));
  });

  test('falls back to English for an unsupported stored locale', () async {
    final container = await _containerWithPreferences({
      appLocalePreferenceKey: 'de',
    });
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider), const Locale('en'));
  });

  test('persists a language selected through the notifier', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);

    await container.read(appLocaleProvider.notifier).setLanguage('tr');

    expect(container.read(appLocaleProvider), const Locale('tr'));
    expect(
      container.read(sharedPrefsProvider).getString(appLocalePreferenceKey),
      'tr',
    );
  });

  test('exposes English and Turkish as the supported locales', () {
    expect(
      supportedAppLocales,
      containsAll([const Locale('en'), const Locale('tr')]),
    );
  });

  testWidgets('localized settings text updates after switching language', (
    tester,
  ) async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            return MaterialApp(
              locale: ref.watch(appLocaleProvider),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: supportedAppLocales,
              home: Builder(builder: (context) => Text(context.l10n.settings)),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);

    await container.read(appLocaleProvider.notifier).setLanguage('tr');
    await tester.pumpAndSettle();

    expect(find.text('AYARLAR'), findsOneWidget);
  });
}
