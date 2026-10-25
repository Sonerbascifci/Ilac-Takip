# İlaç Saatim — onaylı ilk faz ve uygulama kararları

Tarih: 25 Ekim 2026. Kaynak: bu sohbetin ürün kararları ve `claude-design/` dışa aktarımı. Bu belge uygulama kodu değildir.

## Ürün ve tasarım kaynağı

- Android ve iOS, Türkçe, tek kişinin kendi ilaçlarını takibi. Hesap, sunucu ve internet gereksinimi yok.
- Elle ilaç ekleme; her gün bir veya daha fazla sabit saat; başlangıç tarihi ve isteğe bağlı bitiş tarihi. Gün sınırları dahil.
- Ad, doz bilgisi, kullanım miktarı, saatler, tarihler ve isteğe bağlı not. Doz hesaplama veya tıbbi öneri yok.
- Bugün, İlaçlarım, Geçmiş sekmeleri; ikincil Ayarlar, ilaç ayrıntısı, arşiv ve form ekranları.
- Görsel referans `claude-design/IlacSaatimApp.dc.html`; ekran haritası ve tokenlar `claude-design/Ilac Saatim.dc.html`. `support.js`, sahte telefon çerçevesi, sunum galerisi ve örnek veriler ürüne taşınmaz.
- Tasarımdaki “Belirli günler” kapsam fazlasıdır; v1'e alınmaz. Arşivden geri alma korunur; geçmişe dönük doz üretmez. Süresi geçmiş ilaç geri alınırken tarihleri düzenlemek gerekir.
- Barkod, katalog, aile, stok, grafik, bulut ve yedekleme yok. Mevcut tasarım dosyaları değiştirilmeden referans olarak kalır.

## Doz ve geçmiş davranışı

- Sabit doz kimliği: plan sürümü + yerel takvim tarihi + gün içindeki dakika. Liste sırası, ad veya geçici ekran state'i kimlik değildir.
- “Aldım” ve “Atladım” kullanıcı beyanıdır. İşlem yoksa saati gelmemiş doz “Planlandı”, saati gelmiş doz “Kaydedilmedi” olur; alınmadığı varsayılmaz.
- “10 dakika ertele” işlem anından 10 dakika sonrasını hedefler; dozun planlanan saatini ve terminal durumunu değiştirmez. Geçmiş günler ertelenmez.
- İlk terminal eylem kazanır; aynı eylem tekrarında kayıt oluşmaz. Farklı terminal duruma geçiş açık düzeltme ekranından yapılır. Eski bildirim terminal kaydı yeniden açamaz.
- Ana eylem paneli işlemden sonra aynı doz üzerinde 5 saniye kalır. Kalıcı işlem hedefi düğmeye dokunulduğunda yakalanır; sonraki doz çift dokunmayla işaretlenmez.
- Alınma zamanı planlanan zamandan ayrı tutulur; UTC anı ve olayın yerel offset'i saklanır. Geçmişte gösterilen alınma saati seyahatte yeniden yorumlanmaz.
- Geçmiş tarih/ilaç filtresiyle incelenir, kayıt ve alınma zamanı düzeltilebilir; gelecekte bir alınma zamanı kaydedilemez. Geri alma sonraki bir düzeltmeyi ezmez.
- İlaç düzenlemesi önceki planı kapatır, yeni sürüm oluşturur. Bugün saati gelmiş dozlar ve tüm geçmiş korunur; yeni saatlerden yalnız kaydetme anından sonraki olanlar uygulanır. Eklenmeden önceki günler için hayali kullanım geçmişi yok.
- Arşivleme gelecek doz ve hatırlatmaları durdurur; kimlik/plan/kayıtları fiziksel silmez. Tüm verileri silme yalnız açık onayla yapılır ve tüm bildirimler de kaldırılır.

## Bildirimler — kullanıcı tarafından kabul edilen sınır

- Kullanıcı 25 Ekim 2026'da **tarihli kuyruk ve görünür kapsam** yaklaşımını seçti. Süresiz bildirim teslimi vaat edilmez.
- Her doz için tarihli tek bildirim. iOS: toplam en fazla 64; normal dozlar için 60, erteleme ve kapsam uyarısı için 4 rezerv. Android: toplam en fazla 400, normal dozlar için 396 ve 4 rezerv.
- V1'de bildirimdeki Aldım/Atladım/Ertele eylemleri uygulamayı açar ve seçilen eylemi ikinci dokunma istemeden uygular. Salt bildirime dokunma yalnız ilgili dozu açar.
- Tek uzlaştırıcı açılışta, resume'da, bildirim eyleminde, ilaç/ayar değişikliğinde DB'den OS kuyruğunu yeniler. Yanıtsız doz otomatik tekrar etmez.
- Ertelemeler önce yerleştirilir; yer kalmazsa en uzaktaki normal doz bekletilir. Kapsam uyarısına ayrılan 1 slot korunur. Yalnız eksiksiz kapsanan son ana kadar “Hatırlatmalar … tarihine kadar hazır” gösterilir; boşluk üzerinden kapsam iddiası yapılmaz.
- Kuyruk dolduğu için henüz planlanamayan daha ileri doz varsa, hazır son dozdan önce ve mümkünse 24 saat öncesine genel “Hatırlatma planını yenilemek için uygulamayı açın” bildirimi kurulur. 24 saatten kısa kapsamda ilk uygun gelecek ana ve uygulama içi uyarıya başvurulur; sessizce süresiz hazır denmez. Uyarının teslimi de OS kısıtlarına tabidir.
- Günlük 17 dozda 60 normal bildirim yaklaşık 3,5 günlük kapsamdır. Uygulama/bildirim etkileşimi olmadığında kuyruk kendiliğinden sonsuza kadar dolmaz. Arka plan görevleri garanti çözüm olarak kullanılmaz.
- Android: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED ve SCHEDULE_EXACT_ALARM. USE_EXACT_ALARM yok. Tam saat izni yoksa inexact plan ve “gecikebilir” uyarısı; bildirim izni yoksa takip çalışır ama hatırlatma hazır sayılmaz.
- DB kaydı önce transaction ile kalıcı olur. Sonra OS bildirimleri güncellenir. `notificationGeneration` her ilgili değişiklikte artar; yalnız aynı generation tamamen uzlaştırıldığında `lastReconciledGeneration` ilerler. Arada değişiklik/hata varsa yeniden denenir; kayıt kaybolmaz. Kapsam bilgisi yalnız başarıyla kurulan/uzlaştırılan bildirimlerden hesaplanır.
- Payload bir veri nesli kimliği de içerir. Tüm verileri silmede bu kimlik yenilenir; eski delivered notification, yeniden kullanılan sayısal kimlikle yeni bir dozu işaretleyemez.
- Planlar cihazın yerel duvar saatini izler. Açılış/resume'da IANA saat dilimi yeniden okunur; ileri dozlar yenilenir. Geçmiş değişmez. DST boşluğunda saat ilk geçerli ana taşınır; çift saatte yerel doz anahtarı başına tek olay vardır.
- Reboot, force-stop, güç tasarrufu ve uygulama kapalıyken saat dilimi değişimi gerçek cihaz doğrulama konularıdır; kesin teslimat sözü yok.

## Tema, erişilebilirlik ve gizlilik

- Tema: Sistem (varsayılan), Açık, Koyu. Tasarımın ayrı anlamsal paletleri kullanılır.
- Yazı: Sistem boyutu (1), Büyük (1.15), Çok büyük (1.3). Sistem TextScaler'ı korunur; ek büyütme uygulanır, sistem erişilebilirliği küçültülmez veya clamp edilmez.
- Atkinson Hyperlegible Next ve lisansı uygulamada yerel asset. Mono sunum fontu ürüne gerekmedikçe alınmaz. CDN/font isteği yapılmaz.
- En az 48 mantıksal piksel dokunma alanı; 640 maksimum içerik genişliği; minimum yükseklikler, satır kaydırma, SafeArea, klavyeye uyarlama ve azaltılmış hareket desteği.
- İsim/miktar/saat kritik bilgileri üç noktayla gizlenmez. Durum yalnız renkle anlatılmaz. Semantics ve odak sırası gerçek cihazda doğrulanır.
- SQLite ilk oluşturulduğu andan itibaren uygulamanın özel alanında. Android no-backup dizini ve açık cloud/device-transfer exclusion; iOS Application Support altında DB açılmadan önce klasör düzeyinde backup exclusion. SQLite yardımcı dosyaları da kapsanır. Bu kurulum son teslim aşamasına ertelenmez. OEM sınırları doğrulanmadan mutlak aktarım engelleme iddiası yapılmaz.
- İlaç adı kilit ekranında varsayılan gizli. Bildirim payload'ı yalnız kimlik/sürüm içerir. Loglara ilaç adı, not, doz ve geçmiş yazılmaz; analytics/crash SDK yok.
- Tema ve metin tercihleri açılışta okunur; yanlış tema parlaması önlenir. Yerel işlem sürerken yinelenen dokunma engellenir; hata alanları/form korunur. Yapay bekleme ekranı yok.

## Kaynaklar

- https://docs.flutter.dev/install/upgrade
- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin/zonedSchedule.html
- https://developer.android.com/develop/background-work/services/alarms
- https://pub.dev/packages/timezone
- https://pub.dev/packages/flutter_timezone
- https://docs.flutter.dev/cookbook/persistence/sqlite
- https://developer.android.com/identity/data/autobackup
- https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey
- https://docs.flutter.dev/platform-integration/ios/setup
