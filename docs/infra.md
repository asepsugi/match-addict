# Infra — platform, build, deploy, PWA

Pemilik: tech-infra. Baca kalau menyentuh `android/`, `ios/`, `web/`, `tool/build_web.sh`, workflow deploy, service
worker, ikon app, atau titik sentuh platform. Relay live score: `docs/live.md`.

## Target platform

- `android/`, `ios/`, dan `web/` semuanya ada. Bundle id / applicationId: **`id.matchaddict.app`** (label
  `Match Addict`; dulu `id.mabar.app`), minSdk 24, iOS minimum 15.
- Beranda tanpa header: banner lapangan naik sampai di bawah status bar (gambarnya ikut `MediaQuery.padding.top`) dengan
  ikon status bar putih lewat `AnnotatedRegion` (`MabarTheme.statusBarLight`); default gelap dipasang di `builder`
  `MaterialApp` supaya gaya putih tidak terbawa ke layar lain.
- Orientasi dikunci portrait di dua tempat — `SystemChrome` di `lib/main.dart` dan `UISupportedInterfaceOrientations`
  di `ios/Runner/Info.plist`; kalau menambah layar landscape, keduanya harus diubah bareng.
- Toolchain (per 2026-10-20): Android SDK di `~/Library/Android/sdk` dan Xcode 16.4 sudah terpasang (Mac Intel,
  Xcode 27 Apple Silicon saja). `app-release.apk` pernah di-build, tapi release masih ditandatangani **debug key**
  (`android/app/build.gradle.kts`) — perlu keystore sendiri sebelum dibagikan rutin / ke Play Store.

## Titik sentuh platform

Kode Dart-nya bebas platform (nol `kIsWeb`/`dart:html`/`Platform.*`). Titik sentuh platform cuma empat:

- Share sheet di `features/share/share_result_screen.dart` — `XFile.fromData` in-memory, jadi tidak ada
  permission/Info.plist yang perlu ditambah. Konsekuensinya share **wajib diuji di HP fisik**, bukan simulator.
- Kartu **"Pasang Match Addict di HP"** di Beranda (PWA saja). `features/home/app_install.dart` memilih implementasi
  lewat conditional export: `app_install_web.dart` (`dart:js_interop`) atau stub (native/test → selalu `none`, kartu
  tidak muncul). Logikanya di `window.mabarInstall` (`web/index.html`): `beforeinstallprompt` harus ditangkap di sana
  karena sering datang sebelum Flutter selesai dimuat. Chrome/Edge/Samsung Internet → tombolnya langsung memunculkan
  dialog pasang bawaan (tetap butuh satu ketukan konfirmasi; pasang diam-diam memang tidak bisa). iPhone/iPad tidak
  punya API pasang → tombolnya membuka panduan Bagikan → Tambah ke Layar Utama (`ios_install_sheet.dart`). Deteksi
  "sudah terpasang": dibuka dalam mode standalone, atau Chrome tidak lagi mengirim event-nya. Di tab Safari iOS status
  terpasang **tidak bisa** diketahui, jadi kartunya tetap muncul di sana. Closure yang dioper ke `.toJS` harus
  mengembalikan tipe JS/void — `() => x.value = y` gagal compile di web (tidak ketahuan di `flutter test`, jadi cek
  dengan `tool/build_web.sh`).
- "Buka Match Addict" di halaman live yang tidak ditemukan (`features/live/open_home.dart`, conditional export yang
  sama): web memuat ulang URL tanpa `#/live/…`; stub native kosong karena halaman live hanya ada di web.
- Back browser = back Android di PWA (`core/router/browser_back.dart`, conditional export yang sama). `appRouterConfig`
  (`app_router.dart`) membungkus go_router supaya rute **tidak pernah dilaporkan** ke browser; `web/index.html` menjaga
  riwayat dua entri (dasar + penjaga), menangkap `popstate` sebelum Flutter, memantul ke penjaga dengan
  `history.forward()`, lalu `window.mabarBack` (Dart) menutup sheet/dialog/layar teratas (false di Beranda → back
  berikutnya keluar app). Jangan kembali ke riwayat bawaan go_router: back membangun ulang tumpukan layar dari riwayat
  dan `extra` non-JSON (config turnamen) jadi null → layar abu-abu (bug 2026-10-25). Riwayat satu entri bawaan Flutter
  juga tidak dipakai: ia `pushState` lagi di tiap back tanpa ketukan, dan Chrome melewati entri seperti itu, jadi back
  kedua berturut-turut menutup app. Diuji di Chrome (`navigate back` = tombol back browser), tidak ikut `flutter test`.

## Ikon app

App icon Android/iOS/web digenerate dari `CourtPainter` + `MabarBall` (opsi A, frame 01j), bukan digambar terpisah:

```bash
flutter test tool/generate_app_icon.dart   # 3 PNG 1024×1024 ke assets/icon/
dart run flutter_launcher_icons             # sebar ke android/ + ios/ + web/icons + favicon
```

`tool/` sengaja di luar `test/` supaya generator tidak ikut `flutter test` biasa. Ulangi kedua perintah itu setiap kali
painter, `CourtLayout.icon`, atau bola berubah. Adaptive icon Android: komposisi ikon utuh dikecilkan ke 72/108 bagian
tengah (yang terlihat di mask), lapangan & run-off tetap sampai tepi latar, bola di foreground — jadi mask
bulat/squircle memotong gambar yang sama dengan ikon iOS. Warna PWA (`web/manifest.json`, `flutter_launcher_icons`) =
`paper`.

## Deploy web

Repo public `github.com/asepsugi/match-addict` (dulu `mabar`); tiap push ke `main` → `.github/workflows/deploy-web.yml`
(flutter test → `tool/build_web.sh --base-href /match-addict/` → GitHub Pages) → **https://asepsugi.github.io/match-addict/**.

- `base-href` harus sama dengan nama repo: push dengan nama repo lain membuat semua aset 404. Sub-path itu alasan
  `sw.js` didaftarkan relatif dan `start_url: "."` — jangan diganti jadi path absolut `/...`.
- Pages memberi `max-age=600` yang tidak bisa diatur, jadi update baru terlihat paling lambat ~10 menit + reload kedua
  (lihat service worker di bawah).
- Versi Flutter di workflow dipatok (3.47.4); naikkan bareng kalau toolchain lokal naik.

## PWA & service worker

- **Jangan** `flutter build web` langsung. Di Flutter 3.47 `flutter_service_worker.js` cuma meng-unregister dirinya,
  jadi offline ditangani `web/sw.js` sendiri (cache-first, didaftarkan di `index.html`).
- `tool/build_web.sh` membangun dengan `--no-web-resources-cdn` (CanvasKit dari server sendiri, bukan gstatic) lalu
  mengisi daftar precache + versi di `sw.js`; `canvaskit/` sengaja tidak di-precache (beberapa varian ~5MB) dan
  ter-cache saat dipakai.
- Daftar precache berisi URL: nama aset yang di-encode Flutter di disk (`Archivo%5Bwdth,wght%5D.ttf`) ditulis dengan
  `%25`; satu URL 404 saja menggagalkan `cache.addAll` dan service worker tidak pernah ter-install. Setelah build, cek
  semua URL di `PRECACHE` mengembalikan 200.
- Precache diambil dengan `cache: 'reload'`: tanpa itu cache versi baru bisa berisi file lama dari HTTP cache browser
  (pernah terjadi 2026-10-23: app lokal tertahan di build sebelum Race to murni).
- `web/flutter_bootstrap.js` memanggil `load()` tanpa `serviceWorkerSettings` — kalau SW Flutter didaftarkan,
  scope-nya sama dan ia mencopot `sw.js`. Offline sudah diuji: server dimatikan, reload, app tetap jalan.
- Update: `sw.js` baru terunduh di background saat app dibuka; pada pembukaan **berikutnya** `index.html`
  mengaktifkannya (`skipWaiting` via pesan) lalu reload sekali. Jadi setelah rebuild, versi baru baru terlihat di
  reload ke-2 — ini pernah bikin fitur baru "tidak muncul". Saat testing lokal pakai DevTools → Application → "Update
  on reload".

## Cara menjalankan & cek di browser

`flutter run` biasa untuk device. Untuk cek cepat di browser (dipakai selama ini):

```bash
tool/build_web.sh
cd build/web && python3 -m http.server 8897 --bind 127.0.0.1
```

- Setelah rebuild, **restart server**-nya — `flutter build web` mengganti direktori, server lama menyajikan isi lama.
- Di browser harus **hard reload** (⇧⌘R); Chrome meng-cache `main.dart.js`.
- `flutter run -d web-server` sempat dipakai tapi koneksi debug-nya putus tiap reload; build statis lebih stabil.
- Bandingkan dengan hi-fi v2: `python3 -m http.server 8898` di root proyek lalu buka `design/hifi.html` (atau lihat PNG
  di `design/frames/`).
