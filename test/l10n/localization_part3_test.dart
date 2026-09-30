import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/l10n/app_localizations.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final turkish = lookupAppLocalizations(const Locale('tr'));

  group('Part 3 localized lobby copy', () {
    test('covers lobby state and actions in English and Turkish', () {
      expect(english.classicLobby, 'CLASSIC LOBBY');
      expect(turkish.classicLobby, 'CLASSIC ODASI');
      expect(english.ready, 'READY');
      expect(turkish.ready, 'HAZIR');
      expect(english.notReady, 'NOT READY');
      expect(turkish.notReady, 'HAZIR DEĞİL');
      expect(english.startGame, 'START GAME');
      expect(turkish.startGame, 'OYUNU BAŞLAT');
    });

    test('formats the free player limit for both locales', () {
      expect(english.freeLimit(8, 3), 'Free limit: 8 players (3 in lobby)');
      expect(turkish.freeLimit(8, 3), 'Ücretsiz sınır: 8 oyuncu (odada 3)');
    });
  });

  group('Part 3 localized results copy', () {
    test('covers the results screen labels in English and Turkish', () {
      expect(english.gameOver, 'GAME OVER!');
      expect(turkish.gameOver, 'OYUN BİTTİ!');
      expect(english.finalLeaderboard, 'Final leaderboard');
      expect(turkish.finalLeaderboard, 'Final sıralaması');
      expect(english.finalScore, 'FINAL SCORE');
      expect(turkish.finalScore, 'FİNAL PUANI');
      expect(english.backToLobby, 'BACK TO LOBBY');
      expect(turkish.backToLobby, 'ODAYA DÖN');
    });
  });

  group('Part 3 localized Classic copy', () {
    test('covers the core Classic game labels in English and Turkish', () {
      expect(english.yourGuess, 'YOUR GUESS');
      expect(turkish.yourGuess, 'TAHMİNİN');
      expect(english.submitGuess, 'SUBMIT GUESS');
      expect(turkish.submitGuess, 'TAHMİNİ GÖNDER');
      expect(english.leaderboard, 'LEADERBOARD');
      expect(turkish.leaderboard, 'SIRALAMA');
      expect(
        english.betLimit(10),
        'You reached your betting limit of 10 chips!',
      );
      expect(turkish.betLimit(10), '10 fişlik limite ulaştın!');
    });

    test('uses localized board slot labels without changing boundaries', () {
      expect(english.larger, 'LARGER');
      expect(turkish.larger, 'DAHA BÜYÜK');
      expect(english.sweetSpot, 'SWEET SPOT');
      expect(turkish.sweetSpot, 'TAM İSABET');
      expect(english.smaller, 'SMALLER');
      expect(turkish.smaller, 'DAHA KÜÇÜK');
      expect(english.betweenInclusive(10, 20), 'BETWEEN\n10 & 20\n(INCLUSIVE)');
      expect(turkish.betweenInclusive(10, 20), '10 - 20\n(DAHİL)');
    });
  });
}
