# İlaç Saatim V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude tasarımına sadık, çevrimdışı kişisel ilaç takibi ve sınırları görünür yerel hatırlatmalar sunan Android/iOS uygulaması.

**Architecture:** Özellik odaklı Flutter ekranları, built-in Navigator ve ChangeNotifier; tek SQLite store ve tek bildirim uzlaştırıcısı. Controller kullanıcı işlemini DB'ye yazar, ardından OS kuyruğunu günceller; widget içinde iş kuralı veya ayrı repository/use-case katman zinciri kurulmaz.

**Tech Stack:** Flutter 3.47.8 stable / Dart 3.13.7 (25 Ekim 2026'da doğrulandı); flutter_localizations, sqflite, path_provider, intl, flutter_local_notifications, timezone, flutter_timezone. Testlerde flutter_test, integration_test ve sqflite_common_ffi.

**Spec:** `../specs/2026-10-25-ilac-saatim-v1-design.md` (executor bunu önce okur); görsel kaynak proje kökündeki `claude-design/` klasörüdür.

## Global Constraints

- Android ve iOS, Türkçe, tek kişinin kendi ilaçlarını takibi. Hesap, sunucu ve internet gereksinimi yok.
- Her gün bir veya daha fazla sabit saat. Belirli haftalık günler, stok, barkod, aile, bulut ve yedekleme yok.
- Tema: Sistem (varsayılan), Açık, Koyu. Yazı: Sistem boyutu (1), Büyük (1.15), Çok büyük (1.3).
- En az 48 mantıksal piksel dokunma alanı; 640 maksimum içerik genişliği. Sistem TextScaler küçültülmez/clamp edilmez.
- Kullanıcı tarihli kuyruk ve görünür kapsamı kabul etti; süresiz teslimat ve OS arka plan çalışma garantisi yok.

## Review Focus

1. İsim/doz/saat değişikliği ve arşivleme geçmişi bozmamalı (Görev 2 SQLite snapshot testi).
2. UI/bildirim çift eylemi ve eski undo daha sonraki kaydı ezmemeli (Görev 2 revision ve Görev 3 stale-action testi).
3. Yazma/planlama arasında crash veya eşzamanlı değişiklik sonrası gerçek durum ve hazır kapsam tutarlı olmalı (Görev 3 generation/recovery testi).
4. Gece yarısı, DST ve saat dilimi değişimi çift/yanlış günlük doz üretmemeli (Görev 2/3 saat testleri).
5. %200 sistem yazısı + 1.3 uygulama büyütmesi ve klavye temel işlemleri kapatmamalı (Görev 4 widget ve Görev 5 cihaz testi).

## Bağımlılık kararı ve dosya sahipliği

| Alan | Sahip / dosyalar | Karar |
|---|---|---|
| Uygulama ve tema | Ana implementer: `lib/main.dart`, `lib/app.dart`, `lib/ui/`, `assets/fonts/` | Navigator, IndexedStack, ChangeNotifier/Listenable; provider/riverpod/bloc/go_router yok |
| Veri ve takvim kuralları | Veri worker: `lib/data/`, `lib/models/`, `lib/scheduling/dose_schedule.dart`, ilişkili `test/`; ana implementer native saklama/backup köprüsünü önce tamamlar | sqflite; plan sürümleri; tek store |
| Bildirimler ve native izinler | Bildirim worker: `lib/notifications/`, Android manifest/receiver, iOS bildirim delegate/category ayarları | Tek OS planlayıcı; mevcut backup köprüsünü ve UI/store dosyalarını korur |
| Ekranlar | UI worker: `lib/features/`, ilgili widget testleri | Model/API'ler kilitlendikten sonra diğer worker'la paralel ilerleyebilir |
| Birleştirme ve yayın kapısı | Ana implementer + salt-okunur QA/security reviewer | Ortak pubspec/lockfile ve bootstrap yalnız ana implementer tarafından değiştirilir |

Worker'lara birlikte çalıştıkları, başkalarının değişikliklerini geri almamaları ve sahiplik dışı değişiklikleri önce koordine etmeleri söylenir. Her küçük dosya için ayrı agent açılmaz; riskli sınırlar incelenir.

25 Ekim 2026 araştırma tabanı: sqflite 2.4.5, path_provider 2.1.6, intl 0.20.3, flutter_local_notifications 22.3.3, timezone 0.11.2, flutter_timezone 5.1.1; test için sqflite_common_ffi 2.4.5. Bunlar kurulumdan önce uyumluluk çözümlemesinden geçer; prerelease/override kullanılmaz. intl için flutter_localizations'ın SDK pin'i önceliklidir; çözülen tam sürümler pubspec.lock'a alınır.

Gerekçeler: Flutter tek başına SQLite, OS yerel bildirim ve cihaz IANA bölgesi sağlamıyor. path_provider özel uygulama klasörünü, intl Türkçe tarihleri sağlar. Ayarlar aynı DB'de tutulur; shared_preferences/secure-storage eklenmez. Yeni runtime paket yalnız mevcut araçlarla eksik kalan somut iş için eklenir.

## Görev 1 — Uygulama temeli ve tasarım sistemi

**Files:** `pubspec.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/ui/app_theme.dart`, `lib/ui/app_text_scaler.dart`, `lib/ui/app_content.dart`, `assets/fonts/`, `test/ui/app_theme_test.dart`.

**Interfaces:** `AppSettings(themeMode, textSize, showMedicationName)`; `AppTheme.light/dark`; `AppContent(child)`; `AppTextScaler(system, factor)`; uygulama bağımlılıkları constructor üzerinden verilir.

- [ ] Proje kökünde `flutter create --platforms=android,ios --project-name ilac_saatim .` ile iskelet oluştur; claude-design/docs/.verification içeriklerine dokunma. Varsayılan `com.example.ilac_saatim` geliştirme kimliği mağaza yayını için final kimlik sayılmaz. Git yoksa başlangıçta `git init`; ignore'da `.verification/` ve yerel build dosyaları bulunur; onay olmadan uzak repo/push yok.
- [ ] Tema ve ölçek testi yaz: varsayılan Sistem, ayrı dark palette, device scaler aynen korunup ek 1/1.15/1.3 büyüme. `flutter test test/ui/app_theme_test.dart` önce davranış eksikliğiyle, sonra doğru implementasyonla doğrulanır.
- [ ] Paketleri çözümle, Atkinson Hyperlegible Next fontunu ve orijinal lisansını resmi kaynaktan yerel asset olarak ekle; Türkçe karakterleri doğrula. Material 3 kontrolleri tasarım tokenlarına uyarla; sahte telefon kabuğunu taşıma.
- [ ] Bootstrap açılış durumunu ve 3 sekmeli shell'i kur. Bu görevde AppSettings ve enjekte edilen async settings loader tanımlanır; test/ilk shell varsayılan ayar döndüren loader kullanır. Gerçek DB bootstrap entegrasyonu Görev 2'de yapılır. Tercihler yüklenmeden içerik yanlış temada gösterilmez; başarısız loader veri silmeden tekrar dene ekranı gösterir.
- [ ] `flutter analyze` ve tema testi geçsin; ilk Android debug build alınsın. Android minSdk 24, compile/target SDK 36, Java/Kotlin derleme hedefi 17; iOS deployment target 13.0 başlangıç tabanı. Kurulu Android Studio JDK 21, Gradle uyumlu kaldıkça korunur; global JDK ayarı değiştirilmez. Paket/platform gereksinimi daha yüksekse ilk build kapısında plan notunu güncelle; sessiz platform desteği sözü verme.

## Görev 2 — Kalıcı veri ve geçmişi koruyan doz kuralları

**Files:** `lib/models/medication.dart`, `lib/models/dose.dart`, `lib/models/app_settings.dart`, `lib/data/medication_store.dart`, `lib/data/app_storage.dart`, `lib/scheduling/dose_schedule.dart`, `test/data/medication_store_test.dart`, `test/scheduling/dose_schedule_test.dart`.

**Interfaces:** `DoseKey(planId, localDate, minuteOfDay)`; `DoseOccurrence`; `MedicationDraft`; `DoseAction {take, skip, snooze}`; `DoseStatus {taken, skipped}`. `MedicationStore` üretir: `dosesFor(date, {medicationId})`, `saveMedication(draft, {medicationId})`, `archiveMedication(id)`, `restoreMedication(id)`, `applyDoseAction(key, action)`, `correctDose(key, status, takenAt)`, `undoDoseAction(key, expectedRevision)`, `loadSettings()`, `saveSettings(settings)`, `deleteAllData()`. Eylemler `ActionResult(changed, revision, undoToken)` döndürür; tüm I/O Future'dır. Null terminal durum kaydedilmedi/planlandı anlamına gelir; erteleme ayrı alandır. `Clock.now()` ve `DoseSchedule` testte sabit saatle çalışır.

- [ ] Gerçek SQLite FFI testleriyle aynı anda iki take → tek kayıt; 09.00 planını 12.00'de düzenleme → eski 09.00 snapshot'ı aynı; arşiv → dünün geçmişi aynı; yanlış eski undo → yeni revision aynı; save hatası → transaction rollback senaryolarını önce yaz ve çalıştır.
- [ ] İlk gerçek DB açılmadan önce `AppStorage` ve küçük MethodChannel ile Android no-backup dizinini/iOS Application Support klasörünün backup exclusion'ını kur; yardımcı SQLite dosyaları aynı klasörde olsun. Native klasör kurulumu başarısızsa normal backup dizinine sessiz fallback yapma. Beş tablo oluştur: `medications` (kalıcı kimlik/arşiv), immutable `medication_plans` (ad/doz/miktar/not/tarih ve yürürlük sınırları), `plan_times` (0..1439 dakika, plan içinde UNIQUE), `dose_records` (INTEGER id, plan+tarih+dakika UNIQUE, nullable terminal status, taken UTC/offset, snoozed UTC, revision), `settings` (tercihler, veri nesli, notificationGeneration/lastReconciledGeneration). Foreign key, transaction ve parametreli SQL kullan. Plan yürürlük sınırlarında UTC anı yanında değişiklik anındaki yerel tarih-saat snapshot'ını koru; tarihsel planı yeni cihaz bölgesiyle yeniden sınırlandırma.
- [ ] Takvimden geçmiş dozları plan snapshot'larıyla üret; tüm geçmiş günler için boş kayıt doldurma. Bildirim kuyruğuna alınan ileri dozlarda stable dose_records id rezerve et. Native ana bildirim id=`id*2`, erteleme id=`id*2+1`; tek rezerv kapsam uyarısı ayrı sabit id kullanır. Günlük saatlerden farklı gün/plan dozuna ID kayması olmasın.
- [ ] Plan değişimi/arşiv zamanında eski sürümü kapat; o ana kadar saati gelen veya zaten kaydedilmiş dozlar korunur. Yeni plan yalnız sonraki saatlere uygulanır. Restore yeni sürüm açar; süresi geçmiş planı tarih düzeltmeden yeniden aktif yapma. Delete-all transaction'ında veri neslini `Random.secure` ile yeniden üret ve bildirim temizleme niyetini kalıcı kaydet; eski payload ile yeni DB kimliği çakışmasını test et.
- [ ] Başlangıç/bitiş dahil, geçmişe hayali kayıt yok, gece yarısı erteleme, leap-day, DST boş/tekrarlı saat ve saat dilimi değişimi testlerini tamamla. Takvim günü `Duration(hours:24)` ile ilerletilmez. `flutter test test/data test/scheduling` geçsin; DB kapat/aç testi tercih ve kayıt kalıcılığını kanıtlasın. Gerçek settings loader ve DB startup/retry akışını Görev 1 shell'ine bağla.

## Görev 3 — Bildirim prototipi ve gerçek planlayıcı

**Files:** `lib/notifications/notification_service.dart`, `lib/notifications/notification_coordinator.dart`, `lib/notifications/notification_plan.dart`, `test/notifications/`, Android/iOS platform dosyaları. `lib/app_controller.dart` ortak entegrasyonunu ana implementer yapar.

**Interfaces:** `NotificationService.pending/schedule/cancel`, `NotificationCoordinator.reconcile() -> ReminderCoverage`, `handleAction(payload, action)`; `ReminderCoverage(readyThrough, isExact, permissionState, needsRefresh, lastError)`; payload `{v:1, dataGeneration, doseRecordId, planId}`. Testte yalnız OS adapter fake olur; plan kuralları ve SQLite gerçek kodla denenir.

- [ ] Önce kuyruk birim testlerini yaz: iOS toplam <=64 / normal <=60; Android <=400 / normal <=396; 17 doz/gün; erteleme önceliği; kapsamın ilk eksikte durması; eski payload ve aynı terminal işlemin no-op olması; DB commit sonrası OS hatasında generation farkının kalması ve restart'ta temizlenmesi. Uzlaştırmanın ortasında plan/gizlilik değişikliği → son sürüm kurulur; reset+yeni ilaç+eski payload → hiçbir yeni doza işlem yapılmaz.
- [ ] flutter_local_notifications'ı gerçek Android'de küçük teknik akışla doğrula: izinler, geleceğe kurulum, tıklama/cold-start action, iptal ve 10 dakika erteleme. Android Java/desugaring/boot receiver ve iOS notification category/delegate ayarlarını resmi sürüm README'sine göre kur. Arka plan isolate yerine foreground eylemleri seç; cold start payload'ını DB/tercihler açıldıktan sonra tam bir kez işle.
- [ ] One-shot queue ve generation reconciliation kur. İlaç/ayar değişikliği, terminal işlem, restore/archive, startup/resume tetikler. Tek uzlaştırma sırası olsun; yalnız başlangıçta okunan veri nesli ve notificationGeneration hâlâ aynıysa lastReconciledGeneration güncellenir, arada değişmişse yeni tur çalışır. Eski nesil payload herhangi bir DB yazımından önce reddedilir. Yeni kuyruk başarıyla kurulmadan kapsama ufkunu ileri taşıma; hatada işlem başarılı olabilir ama hatırlatma durumu eksik görünür.
- [ ] Tüm ileri dozlar sayıca tükenene veya platform kapasitesi dolana kadar sırala. Kapasite nedeniyle ileride bekleyen doz varsa 1 rezerv slotta kapsam yenileme uyarısı kur. Açık isim tercihi kapandığında mevcut bildirim içeriklerini de yenile. Terminal eylemde hem normal hem snooze iptal edilir; undo yalnız gelecekteki geçerli hatırlatmayı geri kurar, geçmiş bildirimi anında patlatmaz.
- [ ] Android exact izni yok/geri alınmış, reboot, çoklu eşzamanlı doz ve kapalı uygulama testini çalıştır. Mac + Xcode bulunduğunda iPhone'da aynı kontroller ve 64 sınırı zorunlu kapıdır; Windows sonucunu iOS onayı diye raporlama. Native timezone-change/reboot davranışı doğrulanmadıysa bu sınırlamayı yayın notunda tut.

## Görev 4 — Tasarımın çalışan ekranlara aktarımı

**Files:** `lib/app_controller.dart`, `lib/features/today/`, `lib/features/medications/`, `lib/features/history/`, `lib/features/settings/`, `lib/ui/dose_row.dart`, `lib/ui/dose_status_badge.dart`, `lib/ui/dose_action_panel.dart`, `test/features/`, `test/ui/responsive_test.dart`.

**Interfaces:** Tek `AppController extends ChangeNotifier` store/notification coordinator'ı constructor'dan alır, UI'ya immutable view verisi ve async komut sunar. Ekranlar SQL/plugin çağırmaz; kullanıcı eylemleri yukarıdaki store API'si ve coordinator üzerinden akar. UI worker store ve controller arayüzlerini değiştirmeden kullanır.

- [ ] İlk ilaç → bugün dozu → Aldım → Geçmiş akışı, kirli formdan geri çıkış, kayıt hatasında alanların korunması ve 5 saniye sabit panel/çift dokunma widget testlerini önce yaz.
- [ ] IndexedStack ile kök sekmelerini koru; Navigator ile ayrıntı, form, ayarlar/arşiv; modal sheet ile doz/düzeltme/filtre/saat seçimi. PopScope ve sistem geri jestleriyle veri kaybını önle. Tarih/saat seçiminde Flutter kontrollerini kullan; prototipteki sabit tarihleri taşıma.
- [ ] Bugün listesini gerçek plan sonuçlarından, Geçmiş'i immutable snapshot'lardan üret. Saati gelmemiş doz yanlışlıkla kaydedilmedi/atlandı sayılmaz. Formda ad+tarih+en az bir benzersiz saat zorunlu; “Belirli günler” görünmez. Ayarlar kalıcı tema/metin/isim tercihi, izin bilgisi, kapsam ufku ve onaylı veri temizleme sunar.
- [ ] 320/360/390/430/600/768 genişliklerde açık/koyu, sistem 1/1.5/2 ve ek uygulama 1.3; representative yatay görünüm testleri çalıştır. 17 doz/uzun ad/not, tek ilaç, boş/tamamlanan gün, izinsiz ve planlama hatası örnekleri kullan. Taşma hatası olmamalı; eylemler kaydırarak erişilebilir kalmalı.
- [ ] `flutter analyze` ve `flutter test` geçsin. Tasarımla ekran bazlı karşılaştırma yap; HTML galerisi ürün arayüzü olarak taşınmaz. Klavye, SafeArea ve Semantics cihaz doğrulamasına açıkça devredilir.

## Görev 5 — Gizlilik, cihaz doğrulaması ve teslim

**Files:** `integration_test/app_flow_test.dart`, `docs/verification/device-checklist.md`, native backup kuralları ve saklama köprüsü; gerekiyorsa ilgili test/fix dosyaları.

**Interfaces:** Görev 2'de kurulan Android no-backup özel klasörü/iOS backup dışlama köprüsünü doğrula; bu aşamada ilk kez dizin taşıma yapma. Yeni genel platform framework'ü yok.

- [ ] Sağlık DB/yardımcı dosyalarının OS backup ve transfer dışlama kurallarını doğrula; log/bildirim payload'ı ve release manifestini incele. İsim gizleme açık-kapalı sonrası pending ve delivered bildirim davranışını doğrula. Runtime font/ağ/analytics bağımlılığı bulunmasın.
- [ ] Restart sonrası ilaç/doz/tema/metin/arşiv kalıcılığı, offline akış ve onaydan vazgeçilen veri silmenin kayıtları korumasını integration testte doğrula. Gerçek veri üzerinde toplu işlem yapma; test DB/fixtures kullan.
- [ ] Android cihazda bildirim izni reddi/geri alma, exact izni, reboot/force-stop/güç tasarrufu, 23.55'te erteleme, TalkBack, klavye ve büyük sistem yazısı kontrol et. OS tarafından engellenen teslimatı uygulama başarılı diye göstermesin.
- [ ] Mac + Xcode üzerinde `flutter build ios --no-codesign`, iPhone'da VoiceOver, izin dönüşü, cold-start actions, kuyruk sınırı ve backup exclusion kontrol et. Mac/cihaz yoksa iOS yayın kapısı açık kalır; kullanıcıya “iki platformda tamam” denmez.
- [ ] Son salt-okunur QA/security incelemesi; `flutter analyze`, `flutter test`, `flutter build apk --debug` ve uygun cihazda `flutter test integration_test/app_flow_test.dart -d <device-id>`. Teslimde geçen/çalıştırılamayan kontrolleri ayır; mağaza hesabı, kalıcı bundle ID, signing ve yayın bu planın geliştirme sonrası ayrı aşamasıdır.

## Yürütme ve kapsam sınırı

- Şu tur yalnız plan belgeleri ve kullanıcının ayrıca istediği ortak Flutter SDK güncellemesini kapsar; uygulama iskeleti/üretim kodu henüz oluşturulmaz.
- Uygulama yürütmesi başladığında Görev 1 ve arayüzler ana implementerde; veri işi ardından bildirim/UI işleri sahiplikleriyle dağıtılır. Her teslimde küçük doğrulama, riskli DB/bildirim sınırlarında bağımsız inceleme; her ekran için yeni agent açılmaz.
- UI kontrolü tasarım sadakatidir; yeni tasarım keşfi veya ürün kapsamı genişletme değildir. Test edilen OS davranışı ile yalnız prototipte simüle edilen davranış ayrı tutulur.
