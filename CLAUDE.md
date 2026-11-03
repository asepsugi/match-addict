# Match Addict (dulu Mabar) — konteks proyek

App Flutter untuk host turnamen mabar tennis/padel (klub, 4–30 pemain, 1 device host, offline).

**Nama app = Match Addict** sejak 3.0.0 (keputusan host 2026-11-02): wordmark "Match Addict" (bukan huruf kecil), label
ikon, judul web, repo `asepsugi/match-addict`, web `asepsugi.github.io/match-addict/`, bundle id `id.matchaddict.app`,
paket Dart `match_addict`. Yang sengaja **tetap** "mabar": nama kelas/berkas internal (`MabarColors`, `MabarButton`,
`mabar_ball.dart`, `window.mabarInstall`, …), box Hive `tournament`, worker relay `mabar-live` (URL relay tidak berubah),
dan kata "mabar" sebagai istilah (main bareng) di teks maupun contoh nama turnamen ("Mabar Jumat PB Garuda").

**Sumber kebenaran, baca sebelum mengubah UI/logika:**
- `PRD.md` — produk, algoritma, aturan skor & ranking, **versi 2.1 sejalan dengan hi-fi v2** (diselaraskan 2026-10-22).
  Kalau keputusan host mengubah perilaku, perbarui PRD + hi-fi (`design/hifi.html` dan artifact online
  `H9ZVDUfYvEBXsoBqih4iov`, publish file yang sama) dalam perubahan yang sama.
- `design/hifi.html` — **hi-fi v2 final** (disetujui host 2026-10-21): Fondasi, Komponen, 107 frame (layar 390×844 + lembar gambar) +
  catatan perilaku, Cakupan. Acuan visual dan perilaku untuk semua pekerjaan UI berikutnya.
- `design/spec/` — paket implementasi v2. **Mulai dari `design/spec/README.md`** (urutan kerja, aturan golden), lalu
  `tokens.json`, `components.md`, `logic.md` (aturan logika yang berubah + data test), `screens/*.md` (per alur).
Fondasi, logika, komponen, painter lapangan, dan semua layar v2 sudah ada di `lib/` (langkah 1–5, golden per frame
di `test/hifi/`). Hi-fi lama (11 layar, Inter, hijau) ada di git: `git show dae32c9:hifi.html`.
Bagian "Status" di bawah: logika, provider, persistensi, dan platform yang berlaku; tampilan mengikuti hi-fi v2.

## Redesain v2 (final, implementasi bertahap)

Tujuannya tampilan yang tidak terkesan AI-generated: arah "papan skor pinggir lapangan" — biru court + tinta +
kuning bola, Archivo variabel (`assets/fonts/Archivo[wdth,wght].ttf`, sumbu `wdth` untuk angka condensed), ikon
Phosphor Bold, banner Beranda berupa sudut lapangan tampak atas (padel terracotta), ikon app dari painter yang sama.

- Semua keputusan sudah disetujui host; daftar lengkapnya di hi-fi → Cakupan. Jangan buka ulang keputusan itu.
- Perubahan logika (format skor Race to / Best of / Americano dengan data lama tetap terbaca, batas keypad, WO per
  format, status Final Mixed, undian seri dikunci per round, daftar prioritas istirahat, bug estimasi Lanjutkan)
  ada di `design/spec/logic.md`, lengkap dengan data test yang sama dengan angka di frame. **Sudah diimplementasi**
  (langkah 2) di service/model, belum di layar — lihat Status. Turnamen dari app lama (skor per set) **tidak dimuat**
  di app v2 (keputusan host 2026-10-22): format per set sudah dihapus dari kode, lihat Persistensi lokal.
- Verifikasi visual: `expectMatchesHifi(tester, layar, '<id frame>')` di `test/hifi/hifi_golden.dart` membandingkan
  render Flutter dengan `design/frames/<id>.png` (2x, Archivo dimuat; gagal → `build/hifi_diff/`). Jangan klaim
  layar sudah sesuai tanpa golden lolos.
- **Fondasi selesai** (langkah 1 di `design/spec/README.md`), semuanya di `lib/core/theme/`:
  - `mabar_theme.dart` — `MabarColors` (token v2 saja; token lama sudah dipetakan lewat tabel "Token lama → baru"
    di hi-fi dan dihapus), `MabarSpacing`, `MabarRadius`, `MabarSize` (tinggi sentuh, ukuran ikon), `MabarShadows`
    (hanya panel Beranda & menu ⋯; blur CSS dikonversi ke sigma Flutter), `MabarType` (skala huruf; angka besar =
    `numVariations` wdth 72 + `tabular`), dan `MabarTheme.light()`. Setiap `MabarType` membawa `fontFamily` sendiri:
    `ButtonStyle.textStyle`, judul dialog, dan isi snackbar **mengganti** gaya tema (tidak di-merge), jadi `TextStyle`
    tanpa keluarga di situ jatuh ke Roboto/SF. Semua slot `TextTheme` menulis `letterSpacing: 0` + `height`, kalau
    tidak geometri Material 3 ikut masuk.
  - `mabar_icons.dart` — `MabarIcons`, 32 ikon Phosphor Bold hi-fi sebagai `IconData` konstan dari
    `assets/fonts/Phosphor-Bold.ttf` (`@phosphor-icons/web@2.1.1`, MIT; codepoint dari `style.css`-nya). Paket
    `phosphor_flutter` **tidak** dipakai: tidak dirawat sejak 2024 dan gagal dikompilasi karena `IconData` sekarang
    `final class`. Jangan menambah `Icons.*` Material; ikon baru = konstanta baru di sini.
  - Inter dan `design-tokens.json` lama sudah dihapus. Warna PWA (`web/manifest.json`, `flutter_launcher_icons`) =
    `paper`; ikon app-nya baru diganti di langkah painter.
- **Komponen selesai** (langkah 3; 60+ golden per wilayah frame di `test/hifi/components/`). Generik di
  `lib/core/widgets/`: `mabar_controls` (MabarButton, MabarTextButton, MabarIconButton, MabarRowAction,
  MabarActionBar, MabarAppBar), `mabar_group` (MabarGroup/MabarRow, MabarSection, MabarGroupLabel/Note/Header),
  `mabar_inputs` (MabarSegmented, MabarStepper, MabarField, MabarChip/Wrap/Grid), `mabar_layers` (showMabarSheet,
  MabarOption, showMabarConfirm, showMabarMenu, showMabarToast), `match_score_row`, `numbered_lists` (RosterPreview,
  PairList), `mabar_ball`. Khusus layar di `features/<layar>/widgets/`: RoundTabs, RestingList, ScoreBoard/ScoreKeypad
  (di atas `ScoreEntry`), StandingTable, StatLine, NameListField, ModePicker/CourtSwatch/CourtColorGrid,
  HomePanel/HomeRowIcon/InstallStep, SharePoster (`share/widgets/`, preset pratinjau/Feed/Story, diekspor lewat
  `SharePosterTarget.exportPixelRatio`).
- **Layar v2 selesai: 01 Beranda, 02 Pemain, 03 Konfigurasi, 04 Pasangan, 05 Jadwal Fixed, 06 Jadwal Mixed, 07 Pemain, court & lanjutkan, 08 Input Skor, 09 Peringkat, 10 Detail, 11 Bagikan — semua layar** (`test/hifi/screens/<alur>_test.dart`, golden semua frame + perilaku).
  Pembungkus layar `hifiScreen(...)` di `test/hifi/screens/screen_harness.dart` (tema, safe area 47/34, override
  provider). Golden dialog/sheet/ketikan/gulir memakai `expectMatchesHifi(..., act: (tester) async {...})`. Tata letak lama sudah
  habis (`mabar_widgets.dart` dihapus). Layar "Cara Kerja Mixed" sudah dihapus: Konfigurasi Mixed ("Mulai Round 1") langsung push
  `/schedule`. Batas yang tidak tergambar di frame: durasi match maks 180 mnt, booking 1–12 jam per court.
  Pasangan: hasil acak bisa disuntik lewat `PairSetupScreen.random` (test memakai `Random` berskrip supaya sama
  dengan frame); "Ubah pemain" mem-pop dua layar (Pasangan + Konfigurasi) kembali ke Pemain yang masih terisi.
  Nama pemain di baris match, Input Skor, WO, riwayat Detail, Istirahat Fixed, dan caption = nama lengkap (keputusan host
  2026-10-25; dulu nama depan). `MatchScoreSide.names` (+ `prefix` "vs " di Detail); tidak muat → `_TeamNames` di
  `match_score_row.dart` memotong tiap nama sendiri, nama yang muat di separuh lebar tetap utuh (`.nm.split`/`.keep`
  di CSS, frame 06u). `pairNames` mengembalikan daftar nama. Fixture match boleh menulis nama lengkap kalau nama
  depannya kembar (06u).
  Jadwal: `clockProvider` (`tournament_controller.dart`) = jam sekarang, dipakai hitung mundur court dan
  `createdAt`; baris match + subjudul bersama di `features/schedule/widgets/schedule_match_row.dart`
  (`ScheduleMatchRow`, `scheduleSubtitle`, `pairNames`) untuk Fixed dan Mixed. Subjudul tanpa waktu; strip court 42 pt
  (`MatchScoreRow.badgeWidth`, Detail tetap 34) dan di round berjalan (`ActiveTournament.runningRound`) membawa kotak jam
  sisa booking court itu (`countdown`, "01:15", `core/time_text.dart`: ":" durasi, "20.02" jam dinding). Layar Jadwal
  dan Input Skor ditik lewat `core/minute_ticker.dart` di pergantian menit sejak `createdAt` (bukan `Timer.periodic`,
  yang bisa tertinggal 59 detik dari hasil Buat R…). Golden bertoleransi 2% piksel, jadi teks hitung mundur dicek
  dengan `find.text` terpisah, dan test layar yang menampilkan sisa wajib meng-override `clockProvider`. Golden yang butuh turnamen berjalan
  meng-override `tournamentProvider` dengan controller yang `build()`-nya mengembalikan turnamen itu (config
  `identical`, jadi `startIfNeeded` tidak membuat jadwal baru). Dialog Akhiri = `confirmFinishTournament` →
  `showMabarConfirm`. Fixed setelah diakhiri: ⋯ pudar dan mati (menunya kosong; keputusan host, 06c). Kedua layar jadwal memanggil
  `startIfNeeded` lewat `Future.microtask` (Riverpod melarang mengubah provider di `initState`); Mixed
  memunculkan sheet "Cara kerja Mixed" (`mixed/mixed_guide_sheet.dart`) sekali saat R1 baru dibuat.
  `schedule_widgets.dart` tinggal `confirmFinishTournament`. Fixture turnamen Mixed untuk golden ada di `test/hifi/screens/schedule_fixture.dart`
  (`mixedTournament`, `LoadedTournament`). Sheet Kelola pemain / Lanjutkan turnamen di `schedule/mixed/`;
  `MabarRowAction` tata letaknya 36 (seperti CSS) dengan area sentuh 44 lewat hit-test yang diperluas.
  Input Skor = `ScoreBoard` + `ScoreKeypad` di atas `ScoreEntry` (skor tersimpan → `ScoreEntry.edit`, "Perbarui
  skor"); feedback Americano menulis selisih ("menang +5"), format lain skornya. Jebakan CSS: dua tombol
  `flex: 1` / `flex: 2` membagi sisa lebar **setelah** padding tombol (Batal 129, Simpan WO 219), bukan 1:2 murni.
  Klasemen (dulu Peringkat, folder `leaderboard/`): kolom Main = `PlayerStanding.matchesPlayed` (WO ikut). Status subjudul dari `rankingStatus()` (`leaderboard_screen.dart`, "Sementara · R3 · 6 dari 6 match" /
  "Final · 4 round · 7 match"); golden memakai data `ranking_v2_test.dart` (fixture di `test/hifi/screens/ranking_fixture.dart`), Fixed 09c
  dengan jadwal yang cocok 10b. Detail: riwayat terbaru di atas, baris atas = tim sendiri (Mixed: nama sendiri
  dulu), menang WO "+n" pudar = `woPoints` ÷ jumlah menang WO. `MatchScoreRow` mematok tinggi baris tim 22,4 supaya
  riwayat (tanpa tinggi minimal) tidak bergeser 0,8 pt per baris. Fixture 06o (30 pemain, R1–R3 hasil generator) memakai id
  turnamen `t-06o-30` karena undian prioritas berseed id turnamen; `fixtureNames` berisi 30 nama berawalan unik.
  Dialog konfirmasi dipusatkan di layar penuh (`useSafeArea: false`, sesuai `.dialog { top: 50% }`).
- **Painter lapangan selesai** (langkah 4): `core/widgets/court_painter.dart` — `CourtPainter(t, toward, layout)`, satu
  gambar sudut lapangan untuk banner Beranda **dan** ikon app (jangan bikin gambar lapangan kedua). `t` = posisi garis
  tennis (0) → padel (1); warna `toward` menyapu dari dinding belakang dengan tepi tegas, tidak dicampur.
  `CourtLayout.banner` (60 pt/m, garis dipudarkan 35% lewat satu `saveLayer`) dan `CourtLayout.icon` (kanvas 1024, garis
  penuh). `features/home/widgets/court_banner.dart` — `CourtBanner(sport, live)`: wordmark, nama olahraga / `.liveblock`,
  animasi 01g (controller = posisi garis + `animateTo`, jadi berbalik di tengah jalan tidak meloncat; kurva
  `easeInOutCubic` Flutter tidak simetris). Gambarnya ikut safe area (frame: status bar 47 → baseline y 104).
  Golden 01b/01c/01e/01f di `test/hifi/components/court_banner_test.dart`.
- Golden per komponen: `hifiRect(frame, kelas, text:)` membaca `design/spec/rects.json` (posisi elemen yang diukur
  Chrome, ditulis `tool/hifi_extract.py`), `hifiStage` menaruh widget di posisi itu, `expectRegionMatchesHifi`
  membandingkan wilayahnya saja. Pembanding menyerap geseran 1 piksel perangkat (Chrome men-snap baseline, Flutter
  tidak); geseran 2 pt tetap gagal — sudah dibuktikan di `hifi_harness_test`. Gambar aset: `precacheHifiAssets`.
- Jebakan CSS→Flutter yang sudah makan korban: border CSS memakan tempat (border-box), `inset box-shadow` tidak;
  `Container` dengan border dekorasi otomatis menambah tebal border ke padding; mesin teks membulatkan tinggi tiap
  baris ke pt bulat (22,4 → 22, 25,6 → 26), jadi kotak yang tingginya dari jumlah baris perlu dikompensasi
  (NameListField, baris poster); `OutlineInputBorder` menggeser isi 4 pt kecuali `gapPadding: 0`; `flex: 1` (basis 0) membagi sisa ruang ke isi
  baris dan garis atas ada di luar bagian itu, jadi baris pertama tanpa garis 1 pt lebih pendek (poster `.rows`); `ButtonStyle.textStyle`
  mengganti gaya tema (makanya `MabarType` membawa `fontFamily`); `ThemeData` mengunci platform saat dibuat.
- Frame yang dulu tidak konsisten dengan aturannya sudah dibetulkan di hi-fi atas keputusan host (2026-10-22), jadi
  golden layar tidak perlu pengecualian: keypad 07a–07g/07i menggambar tombol mati sesuai aturan, Lanjutkan di banner
  46 pt dan Tambah di 08a/08b 48 pt (dulu kalah oleh `min-height: 52px` `.btn`), keyframe 200 ms 01g digambar dari
  aturan, gambar Feed/Story line-height 1,4. Kalau menemukan frame lain yang bertentangan dengan catatannya:
  berhenti dan tanya host, jangan memilih sendiri.
- Kalau `hifi_extract.py` mengubah banyak frame yang isinya tidak tersentuh sementara `rects.json` tetap sama, itu noise
  rasterisasi font sesaat (pernah terjadi 2026-10-22, ~60 golden gagal): jalankan ulang, jangan commit frame itu.
- Kalau hi-fi diubah: `python3 tool/hifi_extract.py` me-render ulang `design/frames/` dan menulis ulang
  `design/spec/screens/` + `components.md` (butuh Google Chrome + internet untuk font). Jangan edit hasilnya dengan tangan.
  Hi-fi diubah hanya untuk keputusan host, bukan untuk menyamakan kode; setiap keputusan dicatat juga di hi-fi →
  Cakupan → "Sudah disetujui", lalu artifact online dipublish ulang dari file yang sama.
- Membaca hi-fi: file ±320 KB tanpa base64 besar, aman dibaca per bagian (`<section class="flow" id="beranda">`,
  dst.). Untuk satu layar lebih ringkas baca `design/spec/screens/<alur>.md` + PNG frame-nya.

## Versioning app (PRD §12)

Semver `MAJOR.MINOR.PATCH+BUILD` di `pubspec.yaml`; `lib/core/app_version.dart` (`appVersion`) = `MAJOR.MINOR.PATCH`
(dijaga test) dan ikut tertulis di tiap simpanan turnamen. **Setiap perubahan dikategorikan:** MAJOR = perubahan besar
logika/desain atau data lama tidak kompatibel (`schemaVersion` naik → selalu MAJOR); MINOR = fitur/perilaku baru yang
kompatibel; PATCH = perbaikan bug/teks/visual kecil tanpa mengubah perilaku yang disepakati. Versi + `appVersion`
dinaikkan di commit yang membawa perubahan ke `main` (tiap push = deploy web), kategori tertinggi yang menang, `BUILD`
naik tiap rilis. Sebut kategorinya di pesan commit/PR (`[minor]`). Branch `redesain-v2-spec` = 2.0.0 (MAJOR: redesain +
format skor + data app lama tidak dimuat); 2.2.0 (MINOR) = Kelola court; 2.3.0 (MINOR) = nama turnamen;
2.4.0 (MINOR) = batas 30 pemain; 2.5.0 (MINOR) = live score; 2.6.0 (MINOR) = nama lengkap di baris match, Akhiri di
Beranda, back PWA; 2.7.0 (MINOR) = pemain telat Mixed menyusul (kredit dihapus); 2.8.0 (MINOR) = Best of/Americano berhenti lebih awal;
3.0.0 (MAJOR) = nama Match Addict + pindah alamat web, peringkat dari nilai metode + selisih (peringkat lama berbeda);
3.1.0 (MINOR) = round tambahan Fixed + atur ulang pasangan.

## Arsitektur

- `lib/models/models.dart` — seluruh model domain, immutable. Termasuk `ActiveTournament`
  (turnamen + bye/resting per round); dia ada di sini, bukan di controller, supaya
  `services/storage/` bisa menyerialisasinya tanpa services meng-import features.
- `lib/services/**` — logika murni Dart, **wajib ada test**; tidak boleh diduplikasi di widget.
- `lib/features/<screen>/` — satu folder per layar.
- `lib/core/widgets/` — komponen v2 lintas layar (lihat bagian Redesain v2 → Komponen).
- `lib/core/widgets/court_painter.dart` + `mabar_ball.dart` — lapangan + bola brand. Dipakai banner Beranda **dan** generator icon aplikasi; jangan bikin salinan kedua.
- `lib/features/schedule/widgets/` — komponen jadwal v2 (RoundTabs, RestingList, ScheduleMatchRow), dipakai Fixed dan Mixed.
- `relay/` — relay live score (Cloudflare Worker + Durable Object, JavaScript), di luar app Flutter; lihat bagian Live score.
- State turnamen: Riverpod `tournamentProvider` (`features/schedule/tournament_controller.dart`) — satu-satunya sumber kebenaran sejak layar jadwal. Sebelum itu data dioper lewat `extra` router.

Konvensi: komentar seperlunya dan dalam bahasa Indonesia, menjelaskan *kenapa*. Nama komponen merujuk kelas CSS mockup (mis. `// .info` / `.share-card`) supaya mudah dicocokkan; untuk kode desain v2 pakai kelas di `design/hifi.html` (mis. `// .bug`, `.rest`) dan nama widget di `design/spec/components.md`.

## Status: 11 layar selesai + persistensi lokal

> **Saat merakit layar v2:** logika, provider, persistensi, dan aturan platform di bagian ini tetap berlaku. Detail
> **tampilan** layar lama (ikon Material, gradien, `typeScale`, poster lama, teks versi di bawah Beranda, label
> tombol lama) diganti hi-fi + komponen v2 — kalau bertentangan, hi-fi yang benar. Beranda v2 tidak menampilkan versi
> (Cakupan → Dihapus); versi app hanya di `appVersion` + simpanan.

Alur penuh jalan: Home → Peserta → Konfigurasi → Pasangan (Fixed) / langsung (Mixed) → Jadwal 6a/6b → Input Skor + sheet WO → Peringkat → Detail Pemain → Share. Fixed setelah round-robin: Tambah round (+ Atur pasangan).

Mesin domain yang sudah ada + ter-test (semua `flutter test` lulus, termasuk golden komponen di `test/hifi/`; `flutter analyze` bersih kecuali 2 info lint lama di `models.dart`):
- `pairing/player_name_parser.dart` — parser textarea nama.
- `pairing/pair_generator.dart` — pasangan Fixed (acak/manual), sisa pemain ganjil.
- `schedule/round_robin_generator.dart` — circle method. **Invariant:** satu putaran circle dipotong jadi beberapa round sebesar jumlah court, tidak pernah menggabungkan dua putaran (kalau digabung, satu pair bisa main di dua lapangan bersamaan).
- `schedule/endless_round_generator.dart` — round Mixed. Constraint direlaksasi lewat bobot penalti: ulang match persis 1000, ulang partner 10, ulang lawan 3; ambil terbaik dari 400 percobaan. Invariant: selisih match antar pemain yang hadir sejak awal ≤ 1 (pemain telat: lihat bawah).
  Siapa yang main = `priorityOrder` (jumlah main → paling lama istirahat → undian → id, lalu jeda pemain telat). Undiannya **dikunci
  per round**: `Random(drawSeed + nomor round)` dibagikan ke pemain urut id, `drawSeed` = FNV-1a dari id turnamen
  (`ActiveTournament.drawSeed`, tanpa kunci simpanan baru; perkaliannya dipecah supaya sama di web). Jadi
  `restingAfterLastRound` (baris "Istirahat · Prioritas main di R…" / "Istirahat lagi di R…", dari pemain aktif
  sekarang) selalu sama dengan hasil "Buat R…". **Waktu = jam sungguhan** (keputusan host 2026-10-22): sisa booking
  court = booking − menit sejak `createdAt` (`ActiveTournament.elapsedMinutes(now)`), court ikut round baru kalau sisa
  itu muat satu match (`courtsAvailableAt(now)`); round yang selesai cepat menyisakan waktu. Semua turunannya
  (`canGenerateNextRound`, `canResume`, `isFinal`, `remainingBookingMinutes`, `capacityAhead`, `restingAfterLastRound`)
  menerima `now` dari `clockProvider` — test wajib meng-override jam, kalau tidak hasilnya ikut tanggal mesin. Jadwal
  Mixed ditik ulang tiap menit supaya "Waktu habis" muncul sendiri. Waktu habis (tidak ada court yang muat) → slot dihitung dari semua
  court, sesuai frame 06l. Tes: `test/services/mixed_priority_test.dart`.
- Peserta Mixed bisa berubah di tengah turnamen (sheet "Kelola Peserta", `features/schedule/mixed/manage_players_sheet.dart`; tes di `test/services/mixed_roster_test.dart`). Pemain keluar **tidak dihapus** dari `config.players`, hanya masuk `ActiveTournament.withdrawnPlayerIds`, supaya nama di match lama & peringkatnya tetap ada (tampil di Peringkat/Detail/Share tanpa penanda "keluar" — keputusan host 2026-10-20); generator hanya menerima `activePlayers`. **Pemain telat menyusul** (keputusan host 2026-10-25, `design/spec/logic.md` §5a): pemain baru/kembali = `ActiveTournament.latePlayerIds` (absen di round yang sudah dibuat: tidak main dan tidak ada di daftar istirahat) paling sedikit main jadi diprioritaskan, tapi `priorityOrder` memindahnya ke paling bawah setelah main k round beruntun selama masih di bawah yang paling banyak main; k = max(2, slot ÷ yang istirahat + 1), 12 pemain/2 court → 3. Pemain yang hadir sejak awal tidak kena jeda (undian seri kadang memberi mereka k round beruntun; memotongnya membuat selisih 2). Kredit catch-up lama (`matchCredits`, ≤ 2.6) membuat selisihnya tetap selamanya dan sudah dihapus; kunci `credits` di simpanan diabaikan. Menyusulnya pelan kalau sisa istirahat sedikit (12/2 court ±0,1 match per round) — itu harga jeda stamina yang dipilih host. Hanya untuk prioritas jadwal, tidak ikut ranking (di Total Point pemain telat memang tertinggal; ini keputusan host). Minimal 4, maksimal 30 pemain aktif (`TournamentConfig.minPlayers`/`maxPlayers`, satu batas untuk layar Pemain, parser, dan Kelola pemain, Fixed maupun Mixed — keputusan host 2026-10-23, kebutuhan klub 24–26 orang).
- Mixed: round terakhir yang belum ada satu skor pun bisa **dibatalkan = dihapus** ("Batalkan Rn",
  `TournamentController.cancelLastRound`, syaratnya `ActiveTournament.canCancelLastRound`; tombol di bawah "Buat R…"),
  untuk pemain yang baru datang: host tambah pemain lewat Peserta lalu "Buat Rn" lagi. Tidak dibuat ulang otomatis —
  keputusan host. **R1 tidak bisa dibatalkan** (`roundCount > 1`), karena layar jadwal tanpa round tidak punya isi.
  Setelah dibatalkan layar pindah ke round sebelumnya; pemain yang ditambah setelah round itu dibuat paling sedikit
  main, jadi langsung main di round penggantinya.
- **Round tambahan Fixed** (keputusan host 2026-11-03, dari live TBNE36; `design/spec/logic.md` §12, PRD 3.3a; tes
  `test/services/fixed_extra_rounds_test.dart`, `fixed_add_rounds_test.dart`, golden `test/hifi/screens/tambah_round_test.dart`
  06v–06z/04f–04h, 09g, 10d; fixture `fixed_extra_fixture.dart`). Setelah semua match terisi dan belum diakhiri
  (`ActiveTournament.canAddRounds`) action bar Jadwal Fixed = ikon Klasemen + "Tambah round" → sheet
  `features/schedule/fixed/add_rounds_sheet.dart` (jam booking per court + estimasi dari `schedule/widgets/extend_sheet_parts.dart`,
  dipakai bersama Lanjutkan Mixed). `RoundRobinGenerator.extend`: putaran = tiap pasangan +1 (genap, circle round
  k mod (n−1)) atau +2 (ganjil, siklus Walecki k mod m); jumlah putaran = paling sedikit yang mengisi round yang muat di
  court terpanjang, dibulatkan ke atas, boleh lewat booking; court yang habis berhenti dipakai. `extraPutaran` (kunci
  simpanan opsional) melanjutkan urutan lawan antar tambahan. Atur pasangan (`features/pair_edit/pair_edit_screen.dart`
  di atas `services/pairing/pair_draft.dart`): "Ubah" (label host) memisahkan pasangan, pasangan baru mengisi slot yang
  kosong supaya lawan pasangan lain tetap, pemain pengganti diketik; yang tidak dipasangkan tidak ikut (poin tertinggal).
  Klasemen/Detail/poster memakai `ActiveTournament.standingPairs` (pasangan yang selalu main bersama) — sisanya per
  pemain, jadi baris campuran (09g); poster campuran menulis "+n lainnya" / "Semua n" (`shareRowNoun`). `pairById` juga
  mencari pasangan lama di match. Fixed yang diakhiri tetap tidak bisa dilanjutkan.
- `ranking/ranking_calculator.dart` — dua metode: Win % dan **Total Point** (`gamesWon`, yaitu jumlah game yang dimenangkan lintas match: 6-5, 4-6, 3-6 → 13). Default app = Total Point, sesuai keputusan host bahwa total point dihitung lebih dulu; metode "Kombinasi" sudah dihapus karena isinya identik dengan Win %. Urutan = `RankingCalculator.compare`: nilai metode → selisih (`gameDiff`), lalu nama hanya untuk mengurutkan yang nomornya sama. Keputusan host 2026-11-02: hanya angka yang tampil di Klasemen/poster yang menentukan nomor, jadi head-to-head (di Mixed bisa berputar A > B > C > A) dan Total Point sebagai pemisah Win % dihapus. WO (PRD 4.4, `ScoreFormat.woWinnerScore`): menang/kalah dihitung; pemenang dapat N game di Race to, di Best of/Americano rata-rata skornya sendiri dari match yang dia mainkan (bulat ,5 ke atas) tapi minimal ⌊N÷2⌋+1; yang kalah 0. Nilai itu masuk `woPoints` → `totalPoint`, **tidak** ke `gameDiff`. Format lama tetap: WO tanpa game. `cancelled` & `pending` diabaikan total. Tes dengan data frame 09a–09f/10b: `test/services/ranking_v2_test.dart`.
- `ranking/ranking_calculator.dart` → `standingEntries()` — mengubah klasemen per pemain jadi baris tampilan. Mode Fixed: pasangan yang tidak pernah berganti (`standingPairs`) statistik kedua anggotanya identik, jadi dua baris kembar digabung jadi satu baris "Andi + Budi" yang mengambil posisi anggota terbaiknya. Mode Mixed: satu baris per pemain, urutan `rank()` tidak diubah. Pemain sisa (jumlah ganjil) tetap tampil sendiri. `StandingEntry.position`: `compare` = 0 (nilai metode dan selisih sama) → nomor sama, nomor berikutnya melanjutkan (1, 2, 2, 3 — bukan 1, 2, 2, 4), jadi `standingEntries` butuh `method` yang sama dengan `rank()`; baris yang belum main dipindah ke belakang dengan `position == null` (grup "Belum main"). Peringkat, Detail, Bagikan, dan caption memakai nomor ini — jangan menomori dengan indeks.
- `ActiveTournament.isFinal(now)` — status Final/Sementara: diakhiri, Fixed semua match terisi, Mixed waktu booking habis + round terakhir lengkap (bukan tiap round lengkap). `playedRoundCount` = jumlah round yang punya match selesai/WO ("5 round · 10 match").
- **Format skor** (`TournamentConfig.format` = `ScoreFormat(method, target)`; tes `test/services/score_format_test.dart`):
  Race to N (2–9, default 6 — default kedua olahraga; murni: skor akhir N lawan 0..N−1, tanpa 7–5/7–6), Best of N (1–15, default 5), Americano N (2–99, default 21).
  Semua disimpan sebagai **satu `SetScore`**, jadi ranking/share/codec tidak bercabang. Best of & Americano: total ≤ N
  dan pemenang ≥ `minWinningScore` (⌊N÷2⌋+1) — match boleh berhenti begitu lawan tidak mungkin mengejar (11–5 di
  Americano 21, keputusan host 2026-10-26, pesan "Total poin lebih dari 21" / "Minimal skor pemenang 11"); `N − x`
  hanya mengisi kotak lawan yang kosong atau masih otomatis (`autoSide`), yang sudah diketik/skor tersimpan tidak
  dihitung ulang supaya yang kalah tidak dapat poin gratis; seri hanya dengan total penuh di N genap (`canDraw`, juga
  penentu kolom D). Aturan sah + pesan frame 07d/07n/07o di
  `services/scoring/score_entry.dart` (`ScoreRules.judge`), begitu juga keypad v2 (`ScoreEntry`: batas per kotak
  `maxPerSide`, ketikan pertama setelah kotak dipilih mengganti isi, digit penuh → pindah ke kotak lawan yang kosong,
  tombol tidak melihat isi lawan). Durasi match selalu kelipatan 5 (`TournamentConfig.roundDuration`). Config yang disalin wajib lewat
  `copyWith` supaya `format` tidak hilang.
- `MatchGame.withScore` / `asWalkover` menimpa match sepenuhnya: skor di match WO membuang sisa WO, dan alasan WO yang
  dilepas benar-benar hilang (`copyWith` tidak bisa mengosongkan field).
- **Kelola court** (Mixed, menu ⋯, keputusan host 2026-10-22; `design/spec/logic.md` §10; tes
  `test/services/court_manage_test.dart`, `court_availability_test.dart`, golden `test/hifi/screens/kelola_court_test.dart`):
  `Court.startMinute` = menit sejak `createdAt` saat booking court mulai (Konfigurasi 0; kunci simpanan opsional →
  simpanan 2.1 tetap terbaca), sisa = `endMinute − elapsed`. Sheet `features/schedule/mixed/manage_courts_sheet.dart`:
  daftar court + court baru (`TournamentController.addCourt`), ketuk → detail court (sheet aksi, Simpan →
  `updateCourt`; stepper = panjang booking, court habis mulai 0 dan dipesan ulang dari sekarang lewat
  `withBookingHours`/`extendedBy`, sama dengan Lanjutkan). Kapan court dipakai = `EndlessRoundGenerator.courtUse`:
  round berjalan + court tanpa match + istirahat ≥ 4 → langsung main (`courtMatch`, 4 teratas `priorityOrder(n+1)`);
  court lama yang sudah muat tidak pernah tiba-tiba dipakai (`wasAvailable`). Hapus (`removeCourt`) hanya court bernomor
  terakhir tanpa skor dan bukan satu-satunya — nomor court = urutannya. Fixture `courtTournament` (id `t-court-329705`
  dipilih supaya undian seri sama dengan frame).
- **Nama turnamen** (keputusan host 2026-10-23): `TournamentConfig.name` (null = tanpa nama, maks
  `TournamentConfig.maxNameLength` 40, dipangkas di Konfigurasi; kunci simpanan `name` opsional, jadi simpanan lama
  terbaca). Hanya diisi di Konfigurasi (kotak paling atas, `MabarField` tanpa label), tidak bisa diubah. Menggantikan
  "olahraga · mode · n pemain" di Beranda (`MabarRow.titleOneLine`, banner satu baris) dan baris kecil poster
  (`SharePosterData.eyebrow`, maks dua baris; tanggal pindah ke `summary`); caption "🏆 {nama} · Padel". Tanpa nama
  semua tampilan tetap. Golden bernama: 01a/01e/01h, 03c, 11a/11d/11f.
- `ActiveTournament.capacityAhead` (sheet Lanjutkan) mengembalikan `fewerCourtsFrom` = round tambahan saat court yang
  main di round pertamanya habis; court yang sejak awal tidak dapat tambahan bukan "berkurang" (bug lama).
- `share/result_text_builder.dart` — teks share ringkas/lengkap (tiap baris memuat total point, satuan ikut format, "Peringkat Akhir"/"Sementara" dari `isFinal`).
- `storage/tournament_codec.dart` + `storage/tournament_store.dart` — persistensi lokal (lihat bawah).

Metode peringkat yang dipilih host hidup di `rankingMethodProvider`, klasemennya di `standingsProvider`, dan baris siap tampilnya di `standingEntriesProvider` (semuanya di `features/schedule/tournament_controller.dart`) — layar Peringkat, Detail Pemain, dan Share membaca `standingEntriesProvider` yang sama, jadi nomor urutnya tidak pernah berbeda antar layar. Di layar Detail, nama yang ditampilkan diambil dari `config.players` memakai `playerId`, **bukan** dari `entry.standing.player`: satu baris Fixed memuat dua pemain, dan `standing` itu milik anggota yang peringkatnya lebih tinggi.

Bagikan (`features/share/share_result_screen.dart`) mengirim **gambar**, bukan cuma teks: `SharePoster` (target Feed
1080×1080 dan Story 1080×1920, `SharePosterTarget.exportPixelRatio`) di-render lewat `screenshot` lalu dibagikan
dengan `Share.shareXFiles` lewat share sheet sistem, teks hasil (`ResultTextBuilder`) jadi caption. Gagal share →
caption disalin + toast "Hasil disalin" (selalu 19 pt di atas action bar: `showMabarToast(bottom:)` diisi tinggi
action bar dua tombol). Isi poster dari `sharePosterData()` (`share_content.dart`): Ringkas = 5
teratas + "+n pemain/pasangan lainnya", Lengkap = semua yang bernomor. Tiap baris = nilai metode + selisih
(`SharePosterRow.detail` satuan, `.diff` selisih): "42 poin · +12" / "100% · +12", dua kolom dan Story tanpa satuan
"42 · +12". Data golden poster (`test/hifi/components/share_poster_data.dart`) ditulis `tool/hifi_extract.py`. Lengkap: Mixed > 10 baris di pratinjau/Feed jadi dua kolom, pasangan dan Story selalu
satu kolom; lebih padat dari frame terpadat yang disetujui (10 baris satu kolom, 15 per kolom, 20 baris nama di Story) semua huruf
baris dikecilkan sebanding (`SharePoster._density`, frame 11k/11l). Teks kepala/kaki poster dibungkus `_CssLines`
(tinggi = n baris × ukuran × line-height, ikut skala teks) supaya ruang daftar sama dengan CSS. Golden Feed/Story 11l
bertoleransi 3%: kotaknya sudah sama dengan Chrome, sisa geseran huruf ≤ 1 pt di baris rapat (line-height 1,1) jadi
±1,7% piksel di Mac dan ±0,7 poin lebih tinggi di CI Linux (pernah gagal 3,2% sebelum `_CssLines`). `ShareTheme` punya 10 gradien (6 gelap bertinta putih + 4 lembut bertinta gelap);
semua warna poster diturunkan dari `theme.ink` — jangan menaruh `Colors.white` langsung. Tema & format tidak disimpan.

Cara melihat hasil poster tanpa build web: test sekali pakai yang me-render `SharePoster` di `RepaintBoundary` lalu `toImage(pixelRatio: 3)` di dalam `tester.runAsync`, dan simpan PNG-nya. Wajib `loadHifiFonts()` (`test/hifi/hifi_golden.dart`, memuat Archivo + font ikon `PhosphorBold`) dan tema `MabarTheme.light()` — tanpa itu `flutter test` memakai font Ahem dan proporsinya menyesatkan. `Image.asset` memang tidak ikut ter-render di test.

## Live score (2.5.0)

Keputusan host 2026-10-24 (frame 06c/06d/06i, 12a–12o; PRD §5.11; aturan rinci `design/spec/logic.md` §11). Host
membagikan link `asepsugi.github.io/match-addict/#/live/KODE`; pemain lain melihat Jadwal, Klasemen, Detail di browser, baca
saja, Fixed dan Mixed. **Tanpa database**: `relay/src/index.js` (Cloudflare Worker + satu Durable Object per kode, paket
gratis) hanya memegang salinan JSON `TournamentCodec` terakhir, terhapus 3 hari setelah kiriman terakhir. Deploy relay
dari `relay/`: `npm install`, `npx wrangler login` (akun Cloudflare host), `npm run deploy`. URL produksi
`https://mabar-live.mabar-live.workers.dev` (subdomain workers.dev akun = `mabar-live`) = `LiveRelay.url`
(`lib/services/live/live_relay.dart`, bisa diganti `--dart-define=LIVE_RELAY=…`). Uji relay: `npm run dev` (port 8790;
8787 dipakai proses lain di Mac host) lalu `npm run smoke` (`relay/smoke.sh`; `BASE=<url produksi>` untuk hasil
deploy). Relay tidak ikut `flutter test`/CI.

- `services/live/live_relay.dart` — klien HTTP (`package:http`) + `LiveSession` (kode, token rahasia, `sentAt`). Sesi
  disimpan di box Hive yang sama, kunci `live` (`TournamentStore.loadLive/saveLive`). Token tidak pernah ikut isi.
- `features/live/live_host_controller.dart` — `liveHostProvider`, didengar `MabarApp` supaya hidup sepanjang app. Live
  = sesi milik turnamen aktif; setiap perubahan `tournamentProvider` dikirim utuh, satu kiriman sekaligus (perubahan
  selama itu dikirim sesudahnya), gagal → "Menunggu internet" + coba lagi 30 detik. "Selesai" tidak menghentikan live
  (resume dari Beranda melanjutkan kode yang sama); turnamen dibuang ("Hapus & mulai baru") → DELETE. Relay 404/403 →
  sesi dibuang. **Jangan** memanggil kirim manual dari mutator: sama seperti auto-save, semua lewat `state =`.
- `features/live/live_view_controller.dart` — halaman penonton. `main()` membaca `#/live/KODE` (`LiveRelay.codeIn`);
  kalau ada, `liveCodeProvider` di-override dan `tournamentProvider` = `LiveTournamentController` (salinan relay), Hive
  penonton **tidak dibuka**. Layar memakai `ref.watch(liveCodeProvider) != null` sebagai tanda baca saja (Jadwal Fixed/
  Mixed tanpa ⋯/kembali/Isi skor/Batalkan/Buat, Klasemen tanpa Bagikan); jangan pakai `liveViewProvider` untuk itu
  karena ia berubah tiap pengecekan. Cek tiap 10 detik (1 menit setelah Final), berhenti saat halaman tidak terlihat
  (`AppLifecycleListener`), dua gagal → "Offline", 404 → "Live tidak ditemukan".
- `features/live/live_score.dart` — item menu, dialog mulai, `LiveScoreSheet`, `LiveTag`; `live_screen.dart` — rute
  `/live/:code`; `open_home*.dart` — "Buka Match Addict" memuat ulang web tanpa fragment (mode penonton dipasang sekali di
  `main()`).
- Mixed: mengetuk tab round terakhir menyimpan `null`, jadi penonton yang mengikuti round terakhir ikut pindah saat round
  baru muncul. ⋯ Fixed setelah diakhiri tetap aktif (menunya berisi Live score).
- Test: `test/services/live_score_test.dart` (relay tiruan `FakeRelay` di atas `MockClient`; timer lewat `testWidgets`),
  golden `test/hifi/screens/live_test.dart` (+ 12f/12i di `jadwal_fixed_test.dart`, fixture `live_fixture.dart`).
- Preview link WhatsApp generik "Mabar": GitHub Pages statis, tidak bisa OG tag per turnamen.

## Persistensi lokal

Seluruh MVP PRD sudah jalan, termasuk bagian 5 (Penyimpanan Data).

- `services/storage/tournament_codec.dart` — `ActiveTournament` ↔ JSON, Dart murni, ter-test.
  Sengaja **bukan** TypeAdapter Hive: model domain jadi bebas anotasi/codegen dan tidak perlu
  mengelola nomor `typeId`. `schemaVersion` dinaikkan kalau bentuk JSON berubah tidak kompatibel
  (sekarang 2 = app v2), dan tiap simpanan membawa `appVersion` (`lib/core/app_version.dart`, harus sama dengan
  `version` di pubspec — dijaga test; tampil juga di Beranda). Simpanan app lama (skema 1, tanpa `appVersion`,
  skor per set) sengaja tidak dimuat. Payload beda versi atau rusak (app di-kill di tengah tulis) di-`decode` jadi `null`, bukan
  melempar — turnamennya saja yang hilang, app tetap bisa dibuka.
- `services/storage/tournament_store.dart` — box Hive `tournament` berisi 3 key: `active`,
  `lastFinished`, dan `live` (sesi live score, lihat bagian Live score). `TournamentStore.memory()` dipakai test dan sebagai penyelamat kalau box gagal
  dibuka (disk penuh, browser mode private).
- Auto-save-nya satu `listenSelf` di `TournamentController.build()`. Semua mutasi controller
  berakhir di `state =`, jadi tidak ada call site yang bisa lupa menyimpan — **jangan** menambah
  pemanggilan `saveActive` manual di mutator baru.
- Resume: `build()` mengembalikan `_store.loadActive()`. Kartu "Lanjutkan turnamen" di Home adalah
  satu-satunya jalan masuknya, dan dia mengoper `active.config` apa adanya karena `startIfNeeded`
  membandingkan config dengan `identical` — kalau config-nya disalin, jadwalnya akan diregenerate.
  Karena menambah pemain mengganti `state.config`, controller juga mengingat `_startedFrom` (config
  awal yang masih dipegang layar Konfigurasi di belakang jadwal); dua-duanya dianggap turnamen yang sama.
- `close()` (tombol "Selesai" di layar Share) memindahkan turnamen ke slot `lastFinished`,
  tidak menghapusnya, sesuai PRD. Future-nya dikembalikan supaya test bisa menunggu tulisannya.
- **Lanjutkan Turnamen** (Mixed saja; Fixed sengaja tidak — keputusan host): `TournamentController.resume`
  + sheet `features/schedule/mixed/resume_tournament_sheet.dart`, tes di `test/services/resume_tournament_test.dart`.
  Muncul kalau `ActiveTournament.canResume(now)` (sudah "Akhiri" atau waktu booking semua court habis) di layar Jadwal,
  dan dari kartu "Turnamen terakhir" di Beranda untuk slot `lastFinished` (`lastFinishedProvider`, diset sinkron
  oleh `close()` supaya Beranda tidak menunggu tulisan ke device). Jam ditambah **per court** karena sering cuma
  sebagian court yang bisa diperpanjang, dan dihitung dari sekarang: `max(ujung booking, sekarang) + tambahan`
  (`ActiveTournament.extendedBy`; court yang habis dipesan ulang, `startMinute` = sekarang) — court yang waktunya sudah
  lama habis tetap dapat jam penuh. Match `cancelled` (hanya dibuat oleh "Akhiri")
  kembali `pending`. Estimasi di sheet = `ActiveTournament.capacityAhead` dalam **jumlah match** (bukan round: round jalan
  selama masih ada satu court, jadi cuma mengikuti court terpanjang dan tambahan di court lain tidak kelihatan).
- Slot aktif cuma satu, jadi memilih jenis permainan di Home saat ada turnamen berjalan memunculkan
  konfirmasi dulu ("Buang & Mulai Baru"). Turnamen di slot aktif yang sudah **diakhiri** (belum "Selesai") bukan
  turnamen berjalan: Beranda menampilkannya sebagai turnamen terakhir (baris riwayat Mixed, 01c), dan Mulai turnamen
  memanggil `close()` dulu tanpa dialog (keputusan host 2026-10-25).
- Belum ikut disimpan: `rankingMethodProvider` — setelah resume, metode peringkat kembali ke
  default Total Point.

Wording UI sudah direview host (2026-10-20) dan sengaja menyimpang dari mockup: istilah olahraga tetap
Inggris (court, round, match, set, WO, Win %, Total Point), istilah teknis diganti (generate → buat,
device → HP, Ranking/Share/Home → Klasemen/Bagikan/Beranda — layar Peringkat jadi "Klasemen" 2026-10-22, posisi pemain tetap "Peringkat n" di Detail, "Endless" tidak muncul lagi di UI). Yang
dipertahankan atas permintaan host: "Aturan Fairness", "Selisih match antar pemain ≤ 1", label Estimasi
(Max Round · Match/Pemain · Court Aktif · Total Match), "→ Prioritas main di R…". Pakai "duplikat" (bukan
"dobel") dan "diprioritaskan" (bukan "didahulukan").
Di desain v2 (keputusan host 2026-10-21) frasa itu menjadi judul "Istirahat · Prioritas main di R…", dan "peserta"
tidak dipakai lagi: semua orang disebut "pemain" (layar Pemain, Kelola pemain, Ubah pemain).

## Aset ilustrasi

`assets/images/` — raket tennis/padel (`SportTypeX.assetPath`) dan ilustrasi mode Fixed/Mixed (`PartnerModeX.assetPath`). Semuanya PNG transparan dengan garis berwarna **satu abu yang sama, #6B7280** (token `text3` desain lama; hi-fi v2 memakai raket apa adanya dan menggelapkannya saat terpilih, ilustrasi mode diganti ikon); kalau menambah aset baru, samakan warnanya — beberapa tempat menampilkan aset apa adanya (kartu Home, chip Jadwal) sehingga beda warna langsung kelihatan. Tempat lain mewarnai ulang lewat `ColorFiltered(BlendMode.srcIn)` (watermark share ikut tema, ilustrasi mode ikut status terpilih), dan itu hanya bekerja kalau latar aset benar-benar transparan.

Sumber aslinya JPEG berlatar putih; konversinya: potong bingkai tipis 1-2px di tepi file, putih → transparan dengan alpha bertingkat (biar tepi anti-alias tidak bergerigi), pangkas ke isi, lalu beri padding mengikuti rasio isi:kanvas aset lama supaya ukuran tampilnya tidak bergeser.

## Target platform

`android/`, `ios/`, dan `web/` semuanya ada. Bundle id / applicationId: **`id.matchaddict.app`** (label `Match Addict`; dulu `id.mabar.app`),
minSdk 24, iOS minimum 15. Beranda tanpa header: banner lapangan naik sampai di bawah status bar (gambarnya ikut
`MediaQuery.padding.top`) dengan ikon status bar putih lewat `AnnotatedRegion` (`MabarTheme.statusBarLight`); default
gelap dipasang di `builder` `MaterialApp` supaya gaya putih tidak terbawa ke layar lain. Beranda tidak menampilkan versi
app.
Orientasi dikunci portrait di dua tempat — `SystemChrome` di `lib/main.dart`
dan `UISupportedInterfaceOrientations` di `ios/Runner/Info.plist`; kalau menambah layar landscape,
keduanya harus diubah bareng.

Kode Dart-nya bebas platform (nol `kIsWeb`/`dart:html`/`Platform.*`). Titik sentuh platform cuma empat:

- Share sheet di `features/share/share_result_screen.dart` — `XFile.fromData` in-memory, jadi tidak ada
  permission/Info.plist yang perlu ditambah. Konsekuensinya share **wajib diuji di HP fisik**, bukan simulator.
- Kartu **"Pasang Match Addict di HP"** di Beranda (PWA saja). `features/home/app_install.dart` memilih implementasi
  lewat conditional export: `app_install_web.dart` (`dart:js_interop`) atau stub (native/test → selalu `none`,
  kartu tidak muncul). Logikanya di `window.mabarInstall` (`web/index.html`): `beforeinstallprompt` harus
  ditangkap di sana karena sering datang sebelum Flutter selesai dimuat. Chrome/Edge/Samsung Internet →
  tombolnya langsung memunculkan dialog pasang bawaan (tetap butuh satu ketukan konfirmasi; pasang diam-diam
  memang tidak bisa). iPhone/iPad tidak punya API pasang → tombolnya membuka panduan Bagikan → Tambah ke Layar
  Utama (`ios_install_sheet.dart`). Deteksi "sudah terpasang": dibuka dalam mode standalone, atau Chrome tidak
  lagi mengirim event-nya. Di tab Safari iOS status terpasang **tidak bisa** diketahui, jadi kartunya tetap
  muncul di sana. Closure yang dioper ke `.toJS` harus mengembalikan tipe JS/void — `() => x.value = y`
  gagal compile di web (tidak ketahuan di `flutter test`, jadi cek dengan `tool/build_web.sh`).
- "Buka Match Addict" di halaman live yang tidak ditemukan (`features/live/open_home.dart`, conditional export yang sama):
  web memuat ulang URL tanpa `#/live/…`; stub native kosong karena halaman live hanya ada di web.
- Back browser = back Android di PWA (`core/router/browser_back.dart`, conditional export yang sama). `appRouterConfig`
  (`app_router.dart`) membungkus go_router supaya rute **tidak pernah dilaporkan** ke browser; `web/index.html` menjaga
  riwayat dua entri (dasar + penjaga), menangkap `popstate` sebelum Flutter, memantul ke penjaga dengan
  `history.forward()`, lalu `window.mabarBack` (Dart) menutup sheet/dialog/layar teratas (false di Beranda → back
  berikutnya keluar app). Jangan kembali ke riwayat bawaan go_router: back membangun ulang tumpukan layar dari riwayat
  dan `extra` non-JSON (config turnamen) jadi null → layar abu-abu (bug 2026-10-25). Riwayat satu entri bawaan Flutter
  juga tidak dipakai: ia `pushState` lagi di tiap back tanpa ketukan, dan Chrome melewati entri seperti itu, jadi back
  kedua berturut-turut menutup app. Diuji di Chrome (`navigate back` = tombol back browser), tidak ikut `flutter test`.

Beranda v2 (`features/home/home_screen.dart`): `Column` = banner `Expanded` (menerus 24 pt di bawah sudut panel lewat
`Positioned(bottom: -24)`) + `HomePanel`. Tanpa scroll: panel terpanjang (01a) ±330 pt, jadi banner tetap muat wordmark +
info round di layar 568 pt. Status pasang dibaca lewat `appInstallModeProvider` supaya golden bisa menampilkan baris
pasang. Pilihan olahraga: pilihan host → turnamen berjalan → turnamen terakhir → Tennis; banner mengikuti turnamen
berjalan kalau ada.

Toolchain (per 2026-10-20): Android SDK di `~/Library/Android/sdk` dan Xcode 16.4 sudah terpasang (Mac Intel,
Xcode 27 Apple Silicon saja). `app-release.apk` pernah di-build, tapi release masih ditandatangani **debug key**
(`android/app/build.gradle.kts`) — perlu keystore sendiri sebelum dibagikan rutin / ke Play Store.

App icon Android/iOS/web digenerate dari `CourtPainter` + `MabarBall` (opsi A, frame 01j), bukan digambar terpisah:

```bash
flutter test tool/generate_app_icon.dart   # 3 PNG 1024×1024 ke assets/icon/
dart run flutter_launcher_icons             # sebar ke android/ + ios/ + web/icons + favicon
```

`tool/` sengaja di luar `test/` supaya generator tidak ikut `flutter test` biasa. Ulangi kedua perintah itu setiap kali painter, `CourtLayout.icon`, atau bola berubah. Adaptive icon Android: komposisi ikon utuh dikecilkan ke 72/108 bagian tengah (yang terlihat di mask), lapangan & run-off tetap sampai tepi latar, bola di foreground — jadi mask bulat/squircle memotong gambar yang sama dengan ikon iOS.

## Deploy web

Repo public `github.com/asepsugi/match-addict` (dulu `mabar`); tiap push ke `main` → `.github/workflows/deploy-web.yml`
(flutter test → `tool/build_web.sh --base-href /match-addict/` → GitHub Pages) → **https://asepsugi.github.io/match-addict/**.
`base-href` harus sama dengan nama repo: push dengan nama repo lain membuat semua aset 404. Sub-path itu
alasan `sw.js` didaftarkan relatif dan `start_url: "."` — jangan diganti jadi path absolut `/...`. Pages memberi
`max-age=600` yang tidak bisa diatur, jadi update baru terlihat paling lambat ~10 menit + reload kedua (lihat SW di bawah).
Versi Flutter di workflow dipatok (3.47.4); naikkan bareng kalau toolchain lokal naik.

## Cara menjalankan & verifikasi visual

`flutter run` biasa untuk device. Untuk cek cepat di browser (dipakai selama ini):

```bash
tool/build_web.sh
cd build/web && python3 -m http.server 8897 --bind 127.0.0.1
```

PWA/offline: **jangan** `flutter build web` langsung. Di Flutter 3.47 `flutter_service_worker.js` cuma
meng-unregister dirinya, jadi offline ditangani `web/sw.js` sendiri (cache-first, didaftarkan di `index.html`).
`tool/build_web.sh` membangun dengan `--no-web-resources-cdn` (CanvasKit dari server sendiri, bukan gstatic) lalu
mengisi daftar precache + versi di `sw.js`; `canvaskit/` sengaja tidak di-precache (beberapa varian ~5MB) dan
ter-cache saat dipakai. Daftar precache berisi URL: nama aset yang di-encode Flutter di disk (`Archivo%5Bwdth,wght%5D.ttf`)
ditulis dengan `%25`; satu URL 404 saja menggagalkan `cache.addAll` dan service worker tidak pernah ter-install. Precache
diambil dengan `cache: 'reload'`: tanpa itu cache versi baru bisa berisi file lama dari HTTP cache browser (pernah
terjadi 2026-10-23: app lokal tertahan di build sebelum Race to murni). Setelah
build, cek semua URL di `PRECACHE` mengembalikan 200. `web/flutter_bootstrap.js` memanggil `load()` tanpa `serviceWorkerSettings` — kalau
SW Flutter didaftarkan, scope-nya sama dan ia mencopot `sw.js`. Offline sudah diuji: server dimatikan, reload, app tetap jalan.
Update: `sw.js` baru terunduh di background saat app dibuka; pada pembukaan **berikutnya** `index.html` mengaktifkannya
(`skipWaiting` via pesan) lalu reload sekali. Jadi setelah rebuild, versi baru baru terlihat di reload ke-2 —
ini pernah bikin fitur baru "tidak muncul". Saat testing lokal pakai DevTools → Application → "Update on reload".

Catatan penting:
- Setelah rebuild, **restart server**-nya — `flutter build web` mengganti direktori, server lama menyajikan isi lama.
- Di browser harus **hard reload** (⇧⌘R); Chrome meng-cache `main.dart.js`.
- `flutter run -d web-server` sempat dipakai tapi koneksi debug-nya putus tiap reload; build statis lebih stabil.
- Bandingkan dengan hi-fi v2: `python3 -m http.server 8898` di root proyek lalu buka `design/hifi.html`
  (atau lihat PNG di `design/frames/`).
