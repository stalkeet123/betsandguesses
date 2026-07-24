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

## Faz 10 - Anonymous Auth, RPC Yazma Siniri ve Private Realtime

Durum: `CANLIDA AKTIF, STATIK DOGRULAMA TAMAM`

- Migration: `supabase/migrations/20260715110000_secure_anonymous_game_api.sql`
- Rollback: `supabase/rollbacks/20260715110000_secure_anonymous_game_api.sql`
- Her kurulum Supabase Anonymous Auth ile kalici bir `auth.uid()` alir. Room ve
  player sahipligi tahmin edilebilir device ID yerine bu kimlige baglanir.
- Dashboard'da `Allow anonymous sign-ins` ayari etkinlestirilip kaydedildi;
  canli Auth endpoint'i gercek bir anonymous access token ile dogrulandi.
- Oda kurma/katilma, hazirlik, baglanti, oyun baslatma, soru secme, tahmin,
  bahis, settlement, oyun bitirme ve lobi reset yazimlari dogrudan tablo
  mutation'i yerine parametre dogrulayan atomik `*_v2` RPC'lerine tasindi.
- Soru cevabi oyun fazi aciklanmadan istemciye verilmez. `questions` tablosu
  authenticated ve anon istemci okumalarina kapatildi.
- Room Broadcast ve Presence kanali private yapildi. Realtime topic erisimi
  room uyeligi ile sinirlandi; Postgres Changes ise JWT + tablo RLS ile korunur.
- `anon` oyun tablolarinda sifir yetkiye sahiptir. `authenticated` yalnizca
  RLS kapsaminda SELECT yapabilir; tablo INSERT/UPDATE/DELETE izinleri yoktur.
- Canli katalog sorgusu anon read/write=`false`, authenticated direct
  insert=`false`, question select=`false`, secure RPC execute=`true`, anon RPC
  execute=`false` ve iki Realtime policy sonucunu dogruladi.
- Supabase Security Advisor sonucu `0 error / 19 warning`dir. Uyarilarin tamami
  signed-in oyunculara bilincli olarak acilan, kendi icinde auth/uyelik/faz
  kontrolu yapan `SECURITY DEFINER` komut RPC'leridir; genis tablo RLS uyarilari
  artik yoktur.
- `dart analyze` temiz gecti. Kullanici istegiyle build ve oyun testi
  calistirilmadi.

## Faz 11 - Secure Bet Client Action Type Hotfix

Durum: `CANLIDA AKTIF`

- Migration: `supabase/migrations/20260715120000_fix_secure_bet_client_action_type.sql`
- Rollback: `supabase/rollbacks/20260715120000_fix_secure_bet_client_action_type.sql`
- Canli `bets.client_action_id` kolonu `text`, secure RPC parametresi `uuid`
  oldugu icin ilk bahis cagrisi `text = uuid` operator hatasiyla geri donuyordu.
- Idempotency anahtari karsilastirma ve INSERT sirasinda acikca `text`e cevrildi;
  slot, bakiye, faz ve oyuncu sahipligi kontrolleri aynen korundu.
- Canli fonksiyon govdesi `compare_cast=true`, `insert_cast=true` ve
  `auth_execute=true` katalog sonucuyla dogrulandi.

## Faz 12 - MVP Oyun Hissi ve Bet Dayanikliligi

Durum: `CANLIDA AKTIF, MANUEL OYUN KABULU BEKLIYOR`

- Migration: `supabase/migrations/20260715130000_first_round_transition.sql`
- Rollback: `supabase/rollbacks/20260715130000_first_round_transition.sql`
- Ilk oyun baslangici da sonraki turlar gibi sunucu zamanli `question` fazina
  alindi. Round 1 katmani uc saniye gorunur, ardindan onceden secilmis ayni
  soru atomik claim ile `guessing` fazina gecirilir.
- Host deadline'da birincil claim yapar; diger oyuncular `900 ms` failover ile
  hosttan bagimsiz ilerleme yolunu korur.
- Basarili DB bahis yazimi artik gecici Broadcast hatasi yuzunden geri alinmaz.
  Place/move/remove RPC hatalari local state'i geri alir ve snapshot resync ile
  belirsiz ag sonucunu authoritative veriden duzeltir.
- Snapshot optimistic chip'i RPC cevabindan once temizlerse server cevabi
  listeye yeniden eklenir. Gec kalan eski-round cevabi yeni tura sizmaz.
- Tahmin numpad, silme/temizleme, tahmin gonderme ve sonraki tur butonlarina
  dusuk seviyeli chip-tap sesi ile selection haptic eklendi. Button ve chip
  kaynaklari oyun oncesinde preload edilir.
- Canli katalog dogrulamasi question phase, uc saniyelik deadline, preselected
  question korumasi ve iki authenticated RPC izni icin `true` dondu.
- `dart analyze` temiz gecti. Kullanici istegiyle build ve otomatik oyun testi
  calistirilmadi.

## Faz 13 - Senkron Round Ritmi ve Sabit Lobi

Durum: `CANLIDA AKTIF, MANUEL GORSEL KABUL BEKLIYOR`

- Migration: `supabase/migrations/20260715140000_stabilize_round_transition_timing.sql`
- Rollback: `supabase/rollbacks/20260715140000_stabilize_round_transition_timing.sql`
- Round transition penceresi iki saniyeden uc saniyeye cikarildi. Ilk round
  deadline'i canli `start_game_v2` tarafinda, sonraki round'lar ortak client
  sabitiyle `claim_game_phase_v1` tarafinda ayni sureyi kullanir.
- Whoosh round basina tek kez calar ve overlay'in ilk frame'i cizildikten sonra
  tetiklenir. Tekrarlanan room snapshot/Broadcast event'leri sesi cogaltmaz.
- Tahmin yuzeyi ile bahis masasi arasina `430 ms` yatay slide/fade gecisi
  eklendi. Faz ve timer degismez; animasyon yalnizca sunucu event'inin gorsel
  sunumudur.
- Lobi oyuncu paneli `322 px` sabit viewport oldu. Oyuncu sayisi arttikca panel
  veya sayfa olcegi degismez; liste kendi icinde scroll olur ve tum satirlar her
  Realtime update'inde yeniden giris animasyonu oynamaz.
- Canli katalog sorgusu uc saniyelik ilk-round deadline, question phase ve
  authenticated execute izni icin `true` dondu.

## Faz 14 - Tek Saniyelik Round Gecisi ve Ses Siralamasi

Durum: `CANLIDA AKTIF, STATIK DOGRULAMA TAMAM`

- Migration: `supabase/migrations/20260715150000_one_second_round_transition.sql`
- Rollback: `supabase/rollbacks/20260715150000_one_second_round_transition.sql`
- Ilk round ve sonraki round katmanlari ortak server deadline ile bir saniyeye
  indirildi. Host olmayan istemcinin failover payi `900 ms` yerine `250 ms`dir.
- `question` gecis fazinda BGM hemen durur ve whoosh ilk frame'de bir kez calar.
  Soru muzigi ancak authoritative `guessing` fazi basladiginda devreye girer.
- Canli katalog sorgusu `start_game_v2` govdesinde bir saniyelik deadline ve
  authenticated execute izni icin `true / true` dondu.
- `dart analyze` temiz gecti.

## Sonraki Adim

Bir Web + bir mobil istemciyle tek bir normal tam oyun kabul turu yapilmalidir:
Round 1 katmani/whoosh, tahmin-bahis yatay gecisi, sabit lobi paneli ve ikinci
tur gecisi ayni akista gozlenmelidir.

## Faz 15 - Party Challenge Modu

Durum: `CANLIDA AKTIF, MANUEL COKLU OYUNCU KABULU BEKLIYOR`

- `20260724090000` ile `20260724140000` arasindaki alti Party migration'i
  2026-07-24 tarihinde canli projede tek transaction olarak uygulandi.
- Classic oda ve oyun RPC'leri degistirilmedi; mevcut odalar `classic`
  varsayimina sahip.
- Party verileri dogrudan client tablo erisimine kapali, faza gore filtrelenen
  snapshot ve authenticated RPC komutlariyla calisiyor.
- Canli katalog dogrulamasi `game_mode=true`, `6` Party tablosu, `17` client
  RPC'si ve `12` aktif challenge sonucu verdi.
- Flutter analiz temiz, Party/Room/Game model testleri basarili.

## Faz 16 - Ayri Performans Ekrani ve Party Recap

Durum: `CANLIDA AKTIF, MANUEL KAMERA VE COKLU OYUNCU KABULU BEKLIYOR`

- Migration:
  `supabase/migrations/20260724150000_party_performance_media.sql`
- Rollback:
  `supabase/rollbacks/20260724150000_party_performance_media.sql`
- Party bahis suresi Classic'ten ayrilarak `20` saniyeye indirildi; Classic
  bahis suresi `45` saniye olarak korundu.
- Betting deadline'i bitmeden performans route'u acilmaz. Ready, action, sonuc
  girisi ve sonuc onayi artik betting board ustundeki popup yerine
  `/party/performance/:roomCode` ekraninda calisir.
- Performans saatini yalnizca host baslatir. Tum challenge'lar authoritative
  sunucu deadline'i ile `60` saniye calisir.
- Oda uyeleri performans sirasinda tur basina toplam uc private JPEG
  yukleyebilir. Bucket okuma/yukleme politikalari room uyeligiyle sinirlidir.
- Oyun sonu Party Recap, gercek sonuc, oda medyani, en yakin tahmin ve tur
  fotografini 4:5 paylasim kartinda birlestirir.
- Migration 2026-07-24 tarihinde Supabase SQL Editor ile canli projeye
  uygulandi. Katalog dogrulamasi `media_table=true`, `private_bucket=true`,
  `4` media/recap RPC'si, `3` Storage policy'si ve host-start gate sonucu
  `true` dondu.
- Flutter analiz temiz, `24` test basarili ve release Web build basarili.

## Faz 17 - Party Moment Storage RLS Hotfix

Durum: `CANLIDA AKTIF, MANUEL KAMERA KABULU BEKLIYOR`

- Migration:
  `supabase/migrations/20260724160000_fix_party_moment_storage_policy.sql`
- Rollback:
  `supabase/rollbacks/20260724160000_fix_party_moment_storage_policy.sql`
- Storage insert/delete policy'lerinin `players` tablosunu istemci RLS
  baglaminda sorgulamasi nedeniyle olusan `403 Unauthorized` giderildi.
- Oda, oyuncu, auth kullanicisi ve baglanti durumu kontrolu
  `security definer` bir helper'a tasindi. Bucket gizliligi, yalnizca JPEG
  kabulu ve `room/round/player/file` path siniri korundu.
- Migration 2026-07-24 tarihinde Supabase SQL Editor ile canli projeye
  uygulandi. Katalog dogrulamasi helper varligi, authenticated execute izni,
  anon engeli, `3` Party Storage policy'si ve upload/delete helper baglantilari
  icin `true / true / true / 3 / true / true` dondu.
