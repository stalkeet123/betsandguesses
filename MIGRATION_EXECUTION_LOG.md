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

## Sonraki Adim

Faz 0'in sonraki ve tek kapsamli isi, mevcut davranisi degistirmeden kritik saf oyun kurallari ve model donusumleri icin characterization testleri eklemektir. Runtime controller, Realtime, timer, audio veya Supabase semasi bu adimda degismeyecektir.
