# Bets & Guesses - Yayin Oncesi Teknik Durum

Tarih: 2026-07-15

## Kisa Karar

- Kontrollu beta: Yeni round gecisinin manuel cihaz testi sonrasinda hazir.
- Performans ve maliyet: 100 adet dort kisilik eszamanli lobi icin uygun.
- Herkese acik production: Temel veri guvenligi hazir. Kalan konular cihaz kabul
  turu, abuse/CAPTCHA sertlestirmesi ve yuk altinda operasyon gozlemidir.

## Nereden Nereye Geldik

Eski sistemde client timer'i, host davranisi ve gecici Broadcast event'leri oyun
akisini tasiyordu. Reconnect, arka plan, Web gecikmesi veya event kaybi state'i
ayirabiliyordu. Round sonucu birden cok istemci yazimindan olusuyor, chip konumu
yalnizca gecici mesajda bulunuyor ve ilk soru sesleri oyun baslarken yukleniyordu.

Yeni sistemde Supabase oda satiri authoritative state'tir. Round, phase, soru,
`state_version` ve mutlak `phase_ends_at` butun istemcilerin ortak gercegidir.
Broadcast hizli gosterim yoludur; room/bet Postgres Changes ve snapshot yeniden
baglanma yoludur. Timer cihazda saymak yerine sunucu deadline'indan kalan sureyi
hesaplar. Host ayrilsa bile idempotent phase claim ile baska istemci oyunu
ilerletebilir.

## Guncel Teknik Yapi

1. Riverpod, room ve game state'i ayri tutar. Board, timer, skor ve soru secili
   provider parcalariyla rebuild olur.
2. Her istemci oda icin tek Realtime kanalina baglanir. Bu kanal Presence,
   Broadcast, `rooms` UPDATE ve `bets` degisikliklerini tasir.
3. Tahmin ve bahis authenticated oyuncunun kimligini, room uyeligini, round'u,
   fazi ve bakiyeyi kontrol eden RPC'lerle veritabanina yazilir. Broadcast
   yalnizca dusuk gecikme icin kullanilir; kacarsa DB event'i veya snapshot
   state'i tamamlar.
4. `*_v2` oyun komutlari kritik yazimlari atomik Postgres transaction olarak
   yapar. Client oyun tablolarina dogrudan INSERT/UPDATE/DELETE yapamaz.
5. Her oyun `15` parayla baslar. Round sonunda `15` altindaki oyuncu tekrar
   `15`e tamamlanir; ustundeki kazanc yalnizca o mac boyunca korunur.
6. Sonuclar `7` saniye, yeni-round katmani `2` saniye ortak server deadline ile
   gosterilir. Katman mevcut oyun ekranindadir; yeni route veya sayfa yoktur.
7. Sesler once yuklenir, soru/phase degisimi ses politikasini tetikler. Buyuk
   WAV dosyalari yaklasik 17.8 MB'dan 3.6 MB'a dusuruldu.
8. Polling yoktur. Realtime yeniden baglandiginda tek snapshot ile reconciliation
   yapilir; surekli bos DB sorgusu uretilmez.
9. Her kurulum Supabase Anonymous Auth ile `auth.uid()` alir. Room/player
   sahipligi bu kimlige baglidir; private Broadcast/Presence room uyeligiyle,
   Postgres Changes ise JWT ve RLS ile korunur.
10. Soru cevabi reveal/settlement fazindan once client payload'ina girmez;
    authenticated istemci `questions` tablosunu dogrudan okuyamaz.

## 100 Lobi Kapasite Tahmini

100 lobi x 4 oyuncu yaklasik `400` eszamanli Realtime baglantisidir. Supabase
Free plandaki `200` peak connection sinirini asar. Pro planin dahil `500`
baglantisina sigar, ancak reconnect dalgasi icin yalnizca 100 baglanti payi
kalir. Supabase Pro liste fiyati aylik `$25` seviyesinden baslar; dahil kota
uzeri peak connection ucreti 1.000 baglanti basina `$10` olarak listelenir.

Tipik 4 kisilik, 6 round bir oyun icin tahmini Realtime tuketimi:

- Round basina yaklasik `130-160` mesaj.
- Oyun basina yaklasik `800-1.000` mesaj.
- Ayni anda oynanan 100 oyunluk bir parti yaklasik `80.000-100.000` mesaj.
- Pro plandaki aylik `5 milyon` Realtime mesaj kotasinda yaklasik 5.000-6.250
  tam oyun vardir. Sonrasinda liste fiyati milyon mesaj basina `$2.50`dir.
- 100 lobi x 6 round icin kabaca 38 bin okuma ve 10 binin altinda action/RPC
  yazimi beklenir. Asil risk toplam sayi degil, ayni anda phase degisiminde
  olusan kisa burst'tur.

Bu hesap oyuncularin round basina bir tahmin ve iki bahis islemi yaptigi
varsayimidir. Chip'i cok sik tasima, reconnect ve Presence hareketi sayiyi
artirir. Gercek fatura icin dashboard olcumu esas alinmalidir.

Kaynaklar: [Supabase Pricing](https://supabase.com/pricing),
[Realtime peak connections](https://supabase.com/docs/guides/platform/manage-your-usage/realtime-peak-connections),
[Realtime messages](https://supabase.com/docs/guides/platform/manage-your-usage/realtime-messages).

## Nasil Yuk Testi Yapilir

1. Supabase Dashboard > Project Settings > Product Reports > Realtime ekraninda
   connected clients, Broadcast Events, Postgres Changes ve lag izlenir.
2. Once 10, sonra 50, sonra 100 lobi kademeli acilir. Her basamakta p95 phase
   propagation, reconnect, DB CPU, API p95 ve Realtime lag kaydedilir.
3. HTTP/RPC ve WebSocket senaryolari k6 ile calistirilir. Supabase'in kendi
   Realtime benchmarklari da k6 kullanir.
4. Mobil arka plan/geri donus, Web tab throttling, host kapanmasi ve kisa ag
   kesintisi her yuk seviyesinde ayrica denenir.

Kaynaklar: [Realtime Reports](https://supabase.com/docs/guides/realtime/reports),
[Supabase Realtime benchmarks](https://supabase.com/docs/guides/realtime/benchmarks),
[k6 WebSockets](https://grafana.com/docs/k6/latest/javascript-api/k6-websockets/).

## Yayin Kapilari

- Manuel: Bir Web + bir mobil ile en az uc round; yeni round animasyonu,
  timer, eski soru temizligi, chip gorunurlugu ve ses gecisleri.
- Olcekleme: 400 baglantili kademeli k6 testi ve dashboard metrik kaydi.
- Guvenlik: Anonymous Auth, RPC-only mutation, cevap gizliligi ve private
  Realtime tamamlandi. Acik Web yayini oncesi Turnstile/CAPTCHA ile bot oda
  olusturma ve anonymous sign-in kotasi korunmali.
- Operasyon: Production migration'larini Supabase CLI/CI ile sirali uygulama,
  rollback dosyalarini koruma ve hata/latency alarmi ekleme.

## Puanlama

- Oyun senkronizasyonu ve veri mimarisi: `8.5/10`
- Performans ve maliyet verimliligi: `8/10`
- Kontrollu beta hazirligi: `8/10` (manuel gecis testi bekliyor)
- Herkese acik production guvenligi: `8/10` (Auth/RLS/RPC tamam; CAPTCHA ve
  operasyon alarmlari sonraki sertlestirme)

Soru katalogu artik istemcilere dagitilmaz; kategori ve sonraki soru secimi
sunucu RPC'lerindedir. Free plan baslangic ve kontrollu beta icin yeterlidir;
Pro zorunlu degildir. Ancak Free plandaki 200 peak Realtime connection siniri
nedeniyle 100 adet dort kisilik eszamanli lobi hedefi Pro veya daha yuksek
kapasite gerektirir.
