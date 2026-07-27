# Party Mode — Tek Sahne UI Yol Haritası

Bu belge Party Mode'un bundan sonraki değişmez ürün, arayüz ve uygulama sözleşmesidir.
Amaç, ayrı bahis ve performans sayfaları arasında geçiş yapan yapıyı kaldırıp bütün turu
tek bir oyun sahnesinde akıcı biçimde tamamlamaktır.

## 1. Değişmez ürün kararı

- Party Mode bütün tur boyunca tek route ve tek oyun sahnesinde kalır.
- Bahis ekranı ana iskelettir; performans aşaması bu iskeletin dönüşmüş hâlidir.
- Kullanıcının algıladığı ana yapı yalnızca soru alanı ve bahis alanıdır; üçüncü bir
  "performance sayfası" tasarlanmaz.
- Performans bitince aynı iskelet yeniden bahis/sonuç görünümüne döner ve çipler dağıtılır.
- Yeni tam ekran sayfa, route geçişi, ikinci realtime bağlantısı veya ikinci bootstrap yoktur.
- Classic Mode'un akışı ve görünümü bu çalışma kapsamında değişmez.
- Kamera yalnızca aynı sahnenin üzerinde açılan tam ekran bir katmandır; yeni sayfa değildir.
- Medya cihazda yerel kalır. Bulut yükleme bu akışın parçası değildir.

## 2. Tek sahnenin sabit anatomisi

Sahnenin bazı parçaları bütün tur boyunca yerini korur:

1. Logo ve Party Mode kimliği
2. Arka plan ve temel renk sistemi
3. Tur/süre bilgisi
4. Soru kartının başlangıç konumu
5. Oyuncu bağlamı ve performer bilgisi
6. Sağdaki bahis alanının ana geometrisi
7. Kamera aksiyonunun sabit erişim noktası

Değişen şey sayfa veya ana iskelet değil; aynı bahis alanındaki kontrollerin durumu,
önceliği ve içeriğidir. Logo hiçbir aşamada kaybolmaz, taşınmaz veya yeniden kurulmaz.

### Geniş ekran yerleşimi

- Sol bölüm: yaklaşık `%44`; soru, tur bilgisi, seçili çip ve oyuncu bağlamı.
- Sağ bölüm: yaklaşık `%56`; bahis tahtası sabit ana alandır. Timer, görev durumu,
  sonuç girişi ve reveal bu alanın içinde bahis elemanlarıyla yer değiştirir veya
  onların üzerine oturur.
- Soru kartı animasyon sırasında yer değiştirmez. Sadece bir kez sıcak bir ışık/kenar vurgusu alır.
- Kamera tuşu sabit kabuğun içinde, bütün uygun aşamalarda aynı yerde bulunur.

### Dar ekran yerleşimi

- Soru ve tur bilgisi üstte sabit bağlam olarak kalır.
- Ana etkileşim alanı alttaki kullanılabilir alanı doldurur.
- Kamera katmanı her boyutta gerçek tam ekrandır; kapanınca aynı soru/bahis sahnesine dönülür.
- Dar ekranda da route değiştirilmez; yalnızca aynı sahne içindeki layout uyarlanır.

## 3. Görsel aşamalar

Tek doğruluk kaynağı sunucudan gelen `PartySnapshot` olur. Yerel state yalnızca geçici
animasyon ve kamera katmanı için kullanılır.

### A. BET OPEN

- Soru ilk andan itibaren doğru yerde görünür; önce başka bir tahmin ekranı gösterilmez.
- Bahis aralıkları, çip seçici ve oyuncular etkindir.
- Soru kartında kısa, sıcak ve tek seferlik bir vurgu çalışır.
- Bahis yapan kullanıcıya anında, net ve geri alınabilir görsel geribildirim verilir.
- Son saniyelerde yalnızca süre vurgusu güçlenir; ekran titreşmez ve neonlaşmaz.

### B. BET LOCK / DÖNÜŞÜM

Hedef süre: `420–520 ms`.

- Çip seçici kilitlenir ve kompaktlaşır.
- Yerleşen çipler son konumlarında kısa süre sabitlenir.
- Bahis aralıklarının içeriği matlaşır fakat ana geometri ve bahis ekranı kimliği kaybolmaz.
- Timer ve görev kontrolleri aynı bahis alanında açılır; bağımsız bir performans
  paneli, kartı veya sayfası oluşturulmaz.
- Arka plan, soru ve tur göstergesi hareket etmez.
- Aynı anda yalnızca bir baskın hareket kullanılır.

### C. READY

Yerleşim bütün rollerde aynıdır; yalnızca kontrol ve durum metni değişir.

- Performer: belirgin fakat sade `I'M READY` aksiyonu.
- Host: performer'ın hazır olma durumunu görür; hazır olmadan başlatamaz.
- Diğer oyuncular: kısa bekleme durumu ve `CAPTURE THE MOMENT` kamera aksiyonu.
- Host aynı zamanda performer ise iki ayrı ekran veya iki ayrı onay üretilmez; tek bir birincil aksiyon kullanılır.

### D. LIVE PERFORMANCE

- Bahis alanının merkezinde büyük ve çok okunaklı süre bulunur.
- Görev metni görünür kalır ancak timer ile yarışmaz.
- Performer: görev ve kalan süreyi görür.
- Host: gerekli olduğunda süreyi başlatan/kontrol eden tek güvenilir kontrolü görür.
- Diğer oyuncular: tam ekran kamera katmanını açabilir.
- Bahis tahtası düşük kontrastla görünür kalır; kullanıcı aynı ekranda olduğunu açıkça hisseder.
- Süre sıfıra geldiğinde istemci route değiştirmez. İdempotent sunucu aksiyonu istenir ve snapshot sonucu beklenir.

### E. RESULT ENTRY

- Timer aynı merkezde sonuç kontrolüne dönüşür.
- Sayısal görev: host için büyük, hızlı numeric input.
- İkili görev: host için `SUCCESS / FAILED`.
- Diğer kullanıcılar görev sonucunun girildiğini belirten sakin bir bekleme durumu görür.
- Kamera katmanı kapanmışsa sahne yeniden kurulmaz.

### F. RESULT REVIEW

Varsayılan inceleme süresi: `6 saniye`.

- Girilen gerçek sonuç herkesin ekranında büyük ve aynı anda görünür.
- Ayrı ayrı onay butonları yoktur.
- Her kullanıcı yalnızca hata varsa `OBJECT` kullanabilir.
- İtiraz gelmezse sonuç otomatik kesinleşir.
- İtiraz gelirse host düzeltme akışına döner; bahisler ve çekilen yerel görseller kaybolmaz.

### G. REVEAL / PAYOUT

- Performans katmanı geri çekilir ve aynı geometride bahis tahtası tekrar netleşir.
- Kazanan aralık önce vurgulanır.
- Ardından kazanan çipler ve puan değişimleri kısa bir animasyonla açıklanır.
- Payout sırasında yeni tur verisi eski turun üstüne yazılmaz.
- Reveal tamamlanınca sahne bir sonraki soruya aynı iskelet içinde hazırlanır.

## 4. Rol matrisi

| Aşama | Performer | Host | Diğer oyuncular |
| --- | --- | --- | --- |
| Bet | Bahis yapar | Bahis yapar | Bahis yapar |
| Ready | Hazır olduğunu bildirir | Hazır durumu izler/başlatır | Bekler, kamera açabilir |
| Live | Görevi yapar | Süreyi yönetir | İzler, kamera açabilir |
| Result entry | Bekler | Sonucu girer | Bekler |
| Review | İtiraz edebilir | İtiraz edebilir/düzeltir | İtiraz edebilir |
| Reveal | Sonucu görür | Sonucu görür | Sonucu görür |

Host ve performer aynı kişiyse ekran iki rolü tek, çakışmayan bir kontrol setinde birleştirir.

## 5. Animasyon kuralları

- Mikro geribildirim: `120–220 ms`.
- Sahne içi dönüşüm: `420–520 ms`.
- Reveal/payout: en fazla `900 ms`; bilgi okunmadan sonraki tura geçilmez.
- `AnimatedSwitcher` ile bütün ekranı değiştirmek yerine ortak geometri korunur.
- Soru kartı hareket etmez; yalnızca sıcak kenar ışığı bir tur dolaşır.
- Neon glow, sürekli pulse, çoklu zıplama ve casino parlamaları kullanılmaz.
- Hareket azaltma tercihi varsa dönüşümler fade/crossfade seviyesine iner.
- Animasyon hiçbir zaman ağ yanıtını saklayan sahte bir bekleme üretmez.

## 6. Görsel dil

- Zemin: sıcak, koyu gece mavisi.
- Yüzeyler: zeminden az ayrılan mat lacivert tonları.
- Birincil vurgu: yanık/sıcak turuncu.
- Metin: kırık beyaz ve krem.
- İkincil durumlar: düşük doygunluklu adaçayı ve erik tonları.
- Kırmızı yalnızca hata, itiraz ve son kritik saniyelerde kullanılır.
- Parlak neon, mor-pembe gradient patlamaları ve keskin ışıklı çerçeveler kullanılmaz.
- Party canlı ve sıcak görünür; Classic casino kimliği aynen korunur.

## 7. Teknik mimari sözleşmesi

### Tek sahip

- Party turunun realtime aboneliğinin sahibi tek sahnedir.
- Sahne bütün tur boyunca dispose edilmez.
- Görsel aşama `PartySnapshot -> PartyVisualStage` saf eşlemesiyle hesaplanır.
- Yerel timer veya animasyon phase gerçeği üretmez.
- Sunucu deadline ve phase değeri otoritedir.

### Kamera

- Kamera aynı route üzerinde tam ekran overlay olarak açılır.
- Bahis aşamasında cihaz kamera listesi arka planda hazırlanabilir.
- Controller yalnızca ilk gerçek kamera isteğinde initialize edilir.
- Aynı tur içinde controller mümkünse sıcak tutulur.
- Kamera izni reddi oyun akışını durdurmaz.
- Çekilen medya cihazda tutulur; yükleme ve storage bağımlılığı yoktur.
- Overlay kapanınca mevcut phase, timer ve realtime bağlantısı korunur.

### Güvenilirlik

- Tüm phase değiştiren RPC'ler idempotent olmalıdır.
- UI, aynı snapshot iki kez geldiğinde iki kez navigasyon/işlem yapmamalıdır.
- Aktif dönüşüm, live ve review sırasında sınırlı polling fallback kullanılabilir.
- Realtime geri geldiğinde polling bırakılır.
- Host kontrolleri yalnızca kullanıcı rolü ve authoritative phase üzerinden görünür.
- Oyuncu uygulamayı arka plana alıp döndüğünde güncel snapshot'tan doğru görsel aşama yeniden kurulur.

## 8. Kod dönüşüm planı

### Faz 0 — Sözleşmeyi kilitle

- Bu belge referans kabul edilir.
- Yeni görsel fikirler kabul kriterlerini bozuyorsa sonraki sürüme bırakılır.
- Mevcut Party değişiklikleri commit edilmeden önce tek sahne mimarisine taşınır.

### Faz 1 — Route'u kaldır, tam turu tek sahnede çalıştır

- `GameScreen` içindeki Party deneyimi kalıcı bir scene katmanına ayrılır.
- `party-performance` navigasyonu devre dışı bırakılır.
- Ready, live, result entry, review ve reveal aynı widget ağacına alınır.
- Görsel ciladan önce üç oyuncuyla tam tur kanıtlanır.

Çıkış kriteri:

- Bet bitiminden sonraki tura kadar route değişimi veya siyah/yükleme ekranı yoktur.
- Performer, host ve diğer oyuncular doğru kontrolleri güvenilir biçimde görür.

### Faz 2 — Ortak geometri ve dönüşümler

- Bahis tahtası ile performans sahnesi aynı layout sınırlarını paylaşır.
- Chip tray, ranges, timer ve result control için açık state geçişleri yazılır.
- Soru kartının sabit vurgu davranışı eklenir.
- Bütün dönüşümler tek bir animation spec'ten beslenir.

Çıkış kriteri:

- Ekran “başka sayfaya geçti” hissi vermeden bet → live → reveal dönüşür.
- Logo, soru alanı ve bahis alanının dış sınırları bütün dönüşüm boyunca sabit kalır.
- Taşma, sıçrama ve beklenmedik yeniden layout oluşmaz.

### Faz 3 — Kamera overlay ve performans

- Mevcut kamera kodu route/screen bağımlılığından ayrılır.
- Tam ekran kamera overlay'i tek sahneye bağlanır.
- Kamera açma düğmesi soru/bahis iskeletinin sabit bir parçası olur; phase değişirken
  farklı yerlere sıçramaz.
- İlk açılış gecikmesi ölçülür; discovery prewarm ve controller reuse uygulanır.
- Yerel çekimlerin tur boyunca korunması sağlanır.

Çıkış kriteri:

- Kamera açılıp kapanırken oyun state'i, timer ve kontrol görünürlüğü değişmez.
- İzin reddi ve kamerasız cihaz senaryosu akışı bozmaz.

### Faz 4 — Review, itiraz ve payout

- 6 saniyelik sessiz konsensüs tek sahneye bağlanır.
- Result entry → review → düzeltme/settle geçişleri tamamlanır.
- Bahis tahtasına dönüş ve kazanan range/çip animasyonu eklenir.
- Yeni tura geçmeden eski turun bütün görsel state'i temizlenir.

Çıkış kriteri:

- İtirazlı ve itirazsız akışlar aynı turda güvenilir biçimde tamamlanır.
- Payout görünür olmadan sonraki soru başlamaz.

### Faz 5 — Eski yapıyı temizle

- Ayrı `PartyPerformanceScreen` ve router kaydı kaldırılır.
- Eski overlay/rollback kodları temizlenir.
- Çift bootstrap, çift subscription ve artık kullanılmayan kamera bağımlılıkları kaldırılır.
- Classic Mode regresyon testi yapılır.

### Faz 6 — Cihaz ve çok oyunculu kalite kapısı

- Android gerçek cihaz, Chrome/web ve hedef ekran oranları test edilir.
- En az üç istemciyle senkronizasyon matrisi çalıştırılır.
- Frame timing, kamera açılış süresi ve phase yayılma gecikmesi ölçülür.
- Bu bölüm geçmeden soru üretimi/content aşamasına geçilmez.

## 9. Zorunlu test matrisi

- Host performer değil / host performer.
- Sayısal görev / success-failed görev.
- Herkes bahis yaptı / bir oyuncu süreyi kaçırdı.
- Performer hazır / performer geç hazır.
- Kamera izni verildi / reddedildi / cihazda kamera yok.
- Kamera açıkken süre başladı / kamera açıkken süre bitti.
- Sonuca itiraz yok / bir kişi itiraz etti.
- Realtime kısa süre koptu / uygulama arka plana gidip döndü.
- Oyuncu review sırasında yeniden bağlandı.
- Bir sonraki turda önceki çip, sonuç, timer ve kamera state'i kalmadı.
- Classic Mode'un lobby, guess, bet ve reveal akışı değişmedi.

## 10. Definition of Done

Party Mode UI ancak aşağıdakilerin tamamı doğruysa bitmiş sayılır:

- Lobby'den sonra tahmin ekranı bir kare bile görünmez; doğrudan bahis sahnesi gelir.
- Bahis sonunda route, loading screen veya siyah ekran oluşmaz.
- Soru ve ana sahne bağlamı bütün tur boyunca korunur.
- Logo hiçbir aşamada kaybolmaz veya konum değiştirmez.
- Kamera aksiyonu aynı sahneden erişilir ve kapanınca aynı görsel konuma dönülür.
- Performer onayı doğru anda bütün istemcilere ulaşır.
- Host start kontrolü normal realtime'da anlık, fallback ile en geç `1.5 saniye` içinde görünür.
- Kamera aç/kapat oyun state'ini ve timer'ı bozmaz.
- Süre sonunda host result kontrolünü güvenilir biçimde görür.
- Result review herkeste görünür; `OBJECT` ve otomatik settle çalışır.
- Reveal sırasında doğru aralık ve puan değişimi açıkça anlaşılır.
- Sonraki tur temiz state ile başlar.
- Party renkleri sıcak gece mavisi/turuncu çizgisindedir; neon yoktur.
- Classic Mode'da görsel veya işlevsel regresyon yoktur.
- Analyze, test, web build ve Android build başarılıdır.
- Gerçek cihazda kritik animasyonlarda belirgin takılma veya layout taşması yoktur.

Bu kalite kapısı geçildikten sonra Party görevleri ve soru tablosu çalışmalarına geçilir.
