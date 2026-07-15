# Bets & Guesses - Kademeli Gecis Yurutme Gunlugu

Baslangic tarihi: 2026-07-15  
Calisma dali: `codex/staged-game-foundation`  
Dokunulmaz geri donus noktasi: `f462726`  

## Calisma Sozlesmesi

- Ayni adimda yalnizca tek davranis veya tek altyapi siniri degisir.
- Her degisiklikten once mevcut davranis ve etkilenen dosyalar kaydedilir.
- Her adim Android ve Web icin ayri dogrulanir.
- Otomatik kontroller gecmeden kullanici testine cikilmaz.
- Kullanici yalnizca gozlem sonucunu bildirir; teknik teshis gelistiricinin sorumlulugundadir.
- Kullanici `olmadi` dediginde sonraki faza gecilmez. Log, hata ve state farki ayni adim icinde incelenir.
- Her basarili adim ayri commit ve geri donus noktasi olur.
- Canli Supabase degisikligi migration, rollback ve istemci uyumlulugu olmadan yapilmaz.
- Eski yol kanitlanmis yeni yol devreye alinmadan kaldirilmaz.

## Faz 0 - Baseline

Durum: Otomatik baseline tamamlandi, manuel oyun akisi onayi bekliyor.

### Kaynak durumu

- Baslangic commit'i: `f462726 Revert "WIP: Update game engine and state management"`
- Uygulama kaynak kodunda takip edilmeyen veya commit edilmemis degisiklik yok.
- Baslangicta yalnizca mimari raporlar takip disiydi.
- `lib/` altinda 41 kaynak dosyasi bulunuyor.
- Projede `test/` ve `integration_test/` testi bulunmuyor.

### Otomatik kontroller

| Kontrol | Sonuc | Not |
|---|---|---|
| `flutter analyze` | Gecti | Derlemeyi engelleyen hata yok; `home_screen.dart` icinde bir kullanilmayan import uyarisi var. |
| `flutter build apk --debug` | Gecti | `build/app/outputs/flutter-apk/app-debug.apk` uretildi. |
| `flutter build web` | Gecti | `build/web` uretildi; Wasm dry run basarili. |
| Otomatik oyun akisi testi | Yok | Ilk guvenlik agi adiminda eklenecek. |

### Manuel baseline kabul akisi

Asagidaki akis mevcut surumun davranisini kaydetmek icindir; bu asamada kod degisikligi yoktur.

1. Iki oyuncuyla oda olustur ve katil.
2. Iki oyuncuyu hazir yap ve oyunu baslat.
3. Birinci turda tahmin ve bahisleri tamamla.
4. Ikinci turda chip'lerin bahis sonrasinda gorunur kaldigini kontrol et.
5. Mobil uygulamayi timer calisirken arka plana alip tekrar ac.
6. Oyun sonu sonuclarina ve tekrar oyna akimina ulas.
7. Ana ekrana donunce oyun muziginin durdugunu kontrol et.

Manuel sonuc: `BEKLIYOR`

## Faz 1 - Istemci Stabilizasyonu

Durum: `TAMAMLANDI`

- Geri donus commit'i: `9d2f762 Stabilize game sync audio and replay flow`
- Sunucu deadline tabanli timer ve lifecycle resync devreye alindi.
- Faz gecislerine kosullu DB claim eklendi; birden fazla client ayni fazi
  ilerletemiyor.
- Reconnect snapshot, eski round event filtresi ve bet reconciliation eklendi.
- SoLoud hot-restart baslatma hatasi ve faz bazli muzik gecisleri duzeltildi.
- Play Again eski guess/bet verisini temizliyor ve tum client'lari lobiye
  donduruyor.
- 14 saf oyun/senkronizasyon testi eklendi.
- Android debug ve Web build basarili.

## Faz 2 - Realtime ve Rebuild Maliyeti

Durum: `KOD TAMAM, COMMIT BEKLIYOR`

- Ayni oda kanalinin acma/kapatma islemleri siraya alindi.
- Broadcast, devam eden kanal degisiminin bitmesini bekliyor.
- Oda ve oyuncu stream provider'lari `autoDispose` oldu.
- Bet ekraninda soru, timer, chip bankasi, skor seridi ve board ayri Riverpod
  rebuild sinirlarina ayrildi.
- Player, guess ve bet sorgulari modelin kullandigi kolonlarla sinirlandi.
- `flutter analyze`, 14 test, Android debug ve Web build basarili.

## Bilinen Server Tarafi Siniri

Round settlement halen birden fazla client yazimindan olusuyor. Tam cozum tek
Postgres transaction/RPC'dir. Repoda Supabase migration baseline'i, RLS
politikalari ve canli schema dump'i bulunmadigi icin bu fonksiyon tahminle
eklenmedi. Sonraki server adimi once canli semayi migration baseline olarak
Git'e almak, sonra idempotent settlement RPC ve rollback eklemektir.

## Faz 3 - Atomik Round Settlement

Durum: `CANLIDA AKTIF`

- Migration: `supabase/migrations/20260715033000_atomic_round_settlement.sql`
- Rollback: `supabase/rollbacks/20260715033000_atomic_round_settlement.sql`
- `settle_game_round_v1` tek transaction icinde winner, bet sonucu, oyuncu
  skorlari ve room phase alanlarini yazar.
- Room update'lerinde `state_version` otomatik artar.
- Ayni round ikinci kez settle edilirse yeni mutation yapilmaz.
- Yeni client RPC kuruluysa atomik yolu, kurulu degilse mevcut legacy yolu
  kullanir. Bu nedenle migration ve client farkli zamanlarda yayinlanabilir.
- RPC disindaki SQL/ag hatalari legacy yazima dusmez; snapshot resync yapar.
- `flutter analyze` ve 15 test basarili.
- Migration Supabase SQL Editor ile 2026-07-15 tarihinde uygulandi.
- RPC imzasi, room state-version trigger'i ve anon/authenticated execute
  izinleri read-only SQL ile dogrulandi.
- Publishable anon key ile bos oda RPC smoke testi fonksiyona ulasti ve beklenen
  `Room not found` guard sonucunu verdi; canli oyun verisi degismedi.

## Sonraki Adim

Yeni client ile iki oyunculu bir round settlement smoke testi yap. Sonraki
server adimindan once bu migration ve rollback dosyalarini kaynak kabul et.
