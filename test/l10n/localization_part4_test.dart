import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/l10n/app_localizations.dart';
import 'package:witsgame/features/party/presentation/party_poll_error_localizations.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final turkish = lookupAppLocalizations(const Locale('tr'));

  group('Part 4 Party Poll localization', () {
    test('localizes Party Poll core labels in English and Turkish', () {
      expect(english.partyPoll, 'PARTY POLL');
      expect(turkish.partyPoll, 'PARTY POLL');
      expect(english.roundProgress(2, 6), 'Round 2/6');
      expect(turkish.roundProgress(2, 6), 'Tur 2/6');
      expect(english.result, 'RESULT');
      expect(turkish.result, 'SONUÇ');
      expect(english.poll, 'POLL');
      expect(turkish.poll, 'OYLAMA');
      expect(english.leaderboard, 'LEADERBOARD');
      expect(turkish.leaderboard, 'SIRALAMA');
    });

    test('localizes chip picker states in English and Turkish', () {
      expect(english.chipsLocked, 'CHIPS LOCKED');
      expect(turkish.chipsLocked, 'FİŞLER KİLİTLENDİ');
      expect(english.tapChipRecall, 'TAP CHIP TO RECALL');
      expect(turkish.tapChipRecall, 'GERİ ALMAK İÇİN FİŞE DOKUN');
      expect(english.selectChip, 'SELECT A CHIP');
      expect(turkish.selectChip, 'BİR FİŞ SEÇ');
      expect(english.tapBetArea, 'TAP A BET AREA');
      expect(turkish.tapBetArea, 'FİŞ KOYACAĞIN ALANA DOKUN');
      expect(english.chipsLeft, 'CHIPS LEFT');
      expect(turkish.chipsLeft, 'KALAN FİŞ');
    });

    test('localizes Party Poll winner and result copy', () {
      expect(english.winner, 'WINNER');
      expect(turkish.winner, 'KAZANAN');
      expect(english.winners, 'WINNERS');
      expect(turkish.winners, 'KAZANANLAR');
      expect(english.majorityPick, 'MAJORITY PICK');
      expect(turkish.majorityPick, 'ÇOĞUNLUĞUN SEÇİMİ');
      expect(english.lockingResult, 'LOCKING RESULT');
      expect(turkish.lockingResult, 'SONUÇ KİLİTLENİYOR');
      expect(english.youWon(20), 'YOU WON +20');
      expect(turkish.youWon(20), '+20 KAZANDIN');
      expect(english.youLost(20), 'YOU LOST -20');
      expect(turkish.youLost(20), '-20 KAYBETTİN');
      expect(english.breakEven, 'BREAK EVEN');
      expect(turkish.breakEven, 'BAŞA BAŞ');
    });

    test('maps backend error codes to English and Turkish UI copy', () {
      const cases = <String, (String, String)>{
        'POLL_MAX_THREE_TARGETS': (
          'You can bet on up to 3 players per round.',
          'Her tur en fazla 3 oyuncuya fiş koyabilirsin.',
        ),
        'POLL_CHIP_ALREADY_USED': (
          'That chip is already used this round.',
          'Bu fişi bu turda zaten kullandın.',
        ),
        'INVALID_PARTY_POLL_CHIP': (
          'Choose an available 5, 10, or 20 chip.',
          "Kullanılabilir 5, 10 veya 20'lik bir fiş seç.",
        ),
        'INSUFFICIENT_CHIPS': (
          'You do not have enough chips left this round.',
          'Bu tur için yeterli fişin kalmadı.',
        ),
        'INVALID_POLL_TARGET': (
          'That player is not available for betting.',
          'Bu oyuncuya fiş koyamazsın.',
        ),
        'BETTING_WINDOW_CLOSED': (
          'Betting has closed for this round.',
          'Bu tur için fiş koyma süresi bitti.',
        ),
        'BETTING_DEADLINE_MISSING': (
          'Betting has closed for this round.',
          'Bu tur için fiş koyma süresi bitti.',
        ),
        'INVALID_BET_MOVE': (
          'That bet can no longer be moved.',
          'Bu fiş artık taşınamaz.',
        ),
        'INVALID_BET_POSITION': (
          'That bet can no longer be moved.',
          'Bu fiş artık taşınamaz.',
        ),
      };

      for (final entry in cases.entries) {
        expect(
          partyPollErrorMessageForCode(english, entry.key),
          entry.value.$1,
          reason: entry.key,
        );
        expect(
          partyPollErrorMessageForCode(turkish, entry.key),
          entry.value.$2,
          reason: entry.key,
        );
      }
      expect(
        partyPollErrorMessageForCode(english, 'P0001'),
        'Party Poll request failed. Please try again.',
      );
      expect(
        partyPollErrorMessageForCode(turkish, 'P0001'),
        'Party Poll işlemi başarısız oldu. Tekrar dene.',
      );
    });
    test('localizes Party Poll validation and action errors', () {
      expect(
        english.chooseAvailableChip,
        'Choose an available 5, 10, or 20 chip.',
      );
      expect(
        turkish.chooseAvailableChip,
        "Kullanılabilir 5, 10 veya 20'lik bir fiş seç.",
      );
      expect(english.chipAlreadyUsed, 'That chip is already used this round.');
      expect(turkish.chipAlreadyUsed, 'Bu fişi bu turda zaten kullandın.');
      expect(english.targetLimit, 'You can bet on up to 3 players per round.');
      expect(
        turkish.targetLimit,
        'Her tur en fazla 3 oyuncuya fiş koyabilirsin.',
      );
      expect(english.betPlacementFailed, 'Bet could not be placed.');
      expect(turkish.betPlacementFailed, 'Fiş yerleştirilemedi.');
      expect(english.betMoveFailed, 'Bet could not be moved.');
      expect(turkish.betMoveFailed, 'Fiş taşınamadı.');
      expect(english.betRemoveFailed, 'Bet could not be removed.');
      expect(turkish.betRemoveFailed, 'Fiş kaldırılamadı.');
      expect(english.loadingPartyPoll, 'Loading Party Poll...');
      expect(turkish.loadingPartyPoll, 'Party Poll yükleniyor...');
      expect(english.retry, 'RETRY');
      expect(turkish.retry, 'TEKRAR DENE');
    });
  });
}
