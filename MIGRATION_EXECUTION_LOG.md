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

Durum: `TAMAMLANDI`

- Geri donus commit'i: `7f1cf99 Optimize realtime lifecycle and game rebuilds`
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

## Faz 4 - Atomik Oyun Akisi Komutlari

Durum: `CANLIDA AKTIF`

- Migration: `supabase/migrations/20260715043000_game_flow_commands.sql`
- Rollback: `supabase/rollbacks/20260715043000_game_flow_commands.sql`
- `start_game_v1` oyuncu baslangic skorlarini, oda durumunu, ilk soruyu ve
  sunucu deadline'ini tek transaction icinde yazar.
- `claim_game_phase_v1` round ve beklenen faz eslesmesine gore tek kazananli,
  sunucu zamani tabanli faz gecisi yapar.
- `reset_room_to_lobby_v1` guess/bet temizligi ile oda resetini tek transaction
  icinde tamamlar.
- Yeni client RPC'ler kuruluysa atomik yolu, kurulu degilse legacy yolu
  kullanir; gercek SQL/ag hatalari sessizce legacy yazima dusmez.
- Migration Supabase SQL Editor ile 2026-07-15 tarihinde uygulandi.
- Uc RPC imzasi ile anon/authenticated rollerinin tum execute izinleri
  read-only katalog sorgusuyla dogrulandi.
- Publishable anon key smoke testinde sahte oda icin faz claim'i `200/null`,
  start ve reset komutlari beklenen `P0002 Room not found` sonucunu verdi;
  canli oyun verisi degismedi.

## Faz 5 - Guvenilir Canli Bet Konumu ve Ilk Soru Sesi

Durum: `CANLIDA AKTIF, MANUEL OYUN TESTI BEKLIYOR`

- Bir Web + bir mobil ve iki telefon testinde ikinci turdan sonra diger
  oyuncunun chip'lerinin gorunmedigi dogrulandi.
- Chip konumu yalnizca gecici broadcast payload'inda tasiniyordu; DB satirinda
  konum ve Postgres Realtime fallback'i yoktu.
- Migration: `supabase/migrations/20260715060000_reliable_bet_realtime.sql`
- Rollback: `supabase/rollbacks/20260715060000_reliable_bet_realtime.sql`
- `bets.position_x/y` kolonlari, `REPLICA IDENTITY FULL` ve oda filtreli
  `supabase_realtime` yayini canlida etkinlestirildi.
- Broadcast hizli yol olarak korundu; DB insert/update/delete event'leri
  authoritative telafi ve reconnect yolu oldu.
- Realtime kanal kurulumu artik `subscribed` onayini bekliyor.
- Yeni round server snapshot'i yerel tahmin metnini, chip secimini ve round UI
  gecici alanlarini temizliyor.
- Ilk soru muzigi ve soru acilma efekti lobide onceden yukleniyor; question
  muzigi gecisi 350 ms fade ile basliyor.
- Canli katalog sorgusu iki kolonu, publication uyeligini ve replica identity
  `f` degerini dogruladi. Publishable key ile PostgREST kolon sorgusu gecti.
- Statik analiz temiz ve 17 otomatik test basarili.

### Ilk Manuel Test Sonrasi Duzeltmeler

- Migration dosyasi repoya eklendi ve ayni SQL Supabase Dashboard SQL Editor
  uzerinden canli projede elle calistirildi. Bu nedenle degisiklik migration
  history ekraninda degil, `bets` kolonlari ve publication katalogunda gorunur.
- Realtime kanalinin 10 saniyelik subscribe bekleyisi oyun baslangicindan
  ayrildi; timer, soru sesi ve navigasyon artik bu bekleyisin arkasinda degil.
- Host `game_started` broadcast'ini beklemeden oyun ekranina geciyor. Guest
  hem broadcast hem de authoritative room stream yolunda beklemeden geciyor.
- Oyun komutlari kanal kurulurken en fazla 750 ms broadcast bekliyor; DB
  mutation'i transport yuzunden kilitlenmiyor. Realtime retry basarili olunca
  kacirilan state tek snapshot ile uzlastiriliyor.
- Soru acilis efekti soru sorgusuna degil round numarasina baglandi ve ilk
  frame'de tetikleniyor.
- Diger oyuncularin koordinati cizimde kullanilmiyor. Yalnizca slot bilgisiyle
  slotun altindan baslayan, hafif ust uste binen duzenli chip sirasi ciziliyor;
  mevcut oyuncu kendi chip'lerini serbest konumlandirmaya devam ediyor.
- Elevator WAV 10.4 MB'dan 1.73 MB'a, question WAV 7.37 MB'dan 1.84 MB'a
  indirildi. Parca sureleri korundu; ilk Web indirme/decode yuku azaldi.
- Kullanici istegiyle bu duzeltme paketinde build ve otomatik test
  calistirilmadi; yalnizca `dart analyze` calistirildi ve temiz gecti.

## Faz 6 - Authoritative Room Senkronizasyonu

Durum: `CANLIDA AKTIF, MANUEL OYUN TESTI BEKLIYOR`

- Migration: `supabase/migrations/20260715070000_authoritative_room_sync.sql`
- Rollback: `supabase/rollbacks/20260715070000_authoritative_room_sync.sql`
- Oyun ekrani oda bazli `rooms` UPDATE event'lerini authoritative state olarak
  dinliyor. Broadcast dusse veya gecikse bile round, phase, question ve server
  deadline tek snapshot ile uzlastiriliyor.
- Broadcast yalnizca hizli yol olarak kaldi; polling eklenmedi. Bu nedenle bos
  yere periyodik Supabase sorgusu veya yazimi olusmuyor.
- Yeni round veya soru degisiminde eski soru, tahmin metni, chip secimi ve round
  UI gecici alanlari yeni soru gelmeden temizleniyor.
- `claim_game_phase_v1`, yeni `question` fazina girerken eski
  `current_question_id` degerini artik tasimiyor.
- Migration 2026-07-15 tarihinde Supabase SQL Editor ile canli projeye
  uygulandi. Uygulama oncesi katalog kontrolu `false`, uygulama sonrasi `true`
  donerek yeni fonksiyon govdesini dogruladi.
- Kullanici istegiyle build ve otomatik test calistirilmadi; `dart analyze`
  temiz gecti.

## Faz 7 - Mac Bazli Taban Bankroll

Durum: `CANLIDA AKTIF, MANUEL OYUN TESTI BEKLIYOR`

- Her yeni oyun tum oyuncular icin kosulsuz `15` bakiye ile basliyor; onceki
  oyunun kazanci yeni oyuna tasinmiyor.
- Tur sonunda `15` altinda kalan bakiye sonraki tur icin `15`e tamamlaniyor;
  `15` uzerindeki kazanc mac boyunca korunuyor.
- Legacy istemci settlement yolu ile atomik Supabase settlement yolu ayni
  minimum bankroll kuralina getirildi.
- Migration: `supabase/migrations/20260715080000_reset_match_bankroll.sql`
- Rollback: `supabase/rollbacks/20260715080000_reset_match_bankroll.sql`
- Lobiye atomik donus artik oyuncu skorlarini ayni transaction icinde `15`e
  sifirliyor. Legacy fallback yolu da ayni reseti yapiyor.
- Migration 2026-07-15 tarihinde Supabase SQL Editor ile canli projeye
  uygulandi. Fonksiyon govdesi kontrolu uygulama oncesi `false`, uygulama
  sonrasi `true` dondu.

## Faz 8 - Sunucu Zamanli Sonuc ve Yeni Tur Gecisi

Durum: `CANLIDA AKTIF, MANUEL GORSEL TEST BEKLIYOR`

- Migration: `supabase/migrations/20260715090000_authoritative_reveal_deadline.sql`
- Rollback: `supabase/rollbacks/20260715090000_authoritative_reveal_deadline.sql`
- Sonuc ekrani suresi butun istemcilerde ayni sunucu deadline'ina baglandi ve
  `7` saniyeye cikarildi.
- Yeni round baslamadan once `2` saniyelik authoritative `question` fazi
  eklendi. Bu sure ayri route acmadan oyun ekraninin ustundeki tam ekran round
  animasyonunu gosteriyor.
- Faz sahibi istemci soruyu deadline'da baslatir. Diger istemciler `900 ms`
  failover payiyla ayni komutu deneyebilir; atomik phase claim tekrar yazimi
  engeller ve host dusse bile oyun devam eder.
- Room Realtime event'i veya reconnect snapshot'i geldikten sonra hem sonuc
  cikisi hem soru baslangici ortak deadline'dan yeniden planlanir.
- Migration 2026-07-15 tarihinde Supabase SQL Editor ile canli projeye
  uygulandi. Trigger katalog kontrolu uygulama oncesi `false`, uygulama sonrasi
  `true` dondu.
- `dart analyze` temiz gecti. Kullanici istegiyle build ve otomatik oyun testi
  calistirilmadi.

## Faz 9 - Eski RPC Yetkileri ve Canli Advisor Temizligi

Durum: `CANLIDA AKTIF`

- Migration: `supabase/migrations/20260715100000_harden_legacy_rpc_permissions.sql`
- Rollback: `supabase/rollbacks/20260715100000_harden_legacy_rpc_permissions.sql`
- Salt-okuma `game_server_time()` fonksiyonu `SECURITY INVOKER` yapildi.
- Kullanilmayan eski `transition_game_phase(...)` RPC'sinin public, anon ve
  authenticated execute izinleri kaldirildi.
- Canli katalog dogrulamasi `game_server_time` icin definer=`false`, anon
  execute=`true`; legacy phase RPC icin anon execute=`false` sonucunu verdi.
- Supabase Security Advisor `10` uyaridan `6` uyariya indi. Kalan alti uyari
  anonim oyuncu modelindeki genis INSERT/UPDATE RLS politikalaridir.
- Supabase Performance Advisor sonucu `0 error / 0 warning`; mevcut oneriler
  yalnizca bilgi seviyesindedir.

## Sonraki Adim

Bir Web + bir mobil istemciyle yeni round animasyonu, iki saniyelik bekleme ve
sonuc ekraninin yedi saniye gorunmesi manuel kabul edilmelidir. Kontrollu beta
oncesinde baska zorunlu performans migration'i yoktur. Genel kullanima acik
surumden once anonim oyuncular icin guvenilir kimlik ve RPC-odakli yazma modeli
kurularak kalan alti RLS uyarisi kapatilmalidir.
