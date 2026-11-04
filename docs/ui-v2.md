# UI v2 — catatan implementasi redesain

Pemilik: tech-lead. Baca kalau mengubah layar, komponen, tema, painter, poster, golden, atau `design/` →
`design/frames/`. Urutan kerja, satu tugas layar, dan aturan golden dasar (390×844 rasio 2, kanal > 32/255, ≤ 2% piksel,
safe area 47/34, `font-stretch` → `FontVariation('wdth', n)`): `design/spec/README.md`.

Tujuannya tampilan yang tidak terkesan AI-generated: arah "papan skor pinggir lapangan" — biru court + tinta + kuning
bola, Archivo variabel (`assets/fonts/Archivo[wdth,wght].ttf`, sumbu `wdth` untuk angka condensed), ikon Phosphor Bold,
banner Beranda berupa sudut lapangan tampak atas (padel terracotta), ikon app dari painter yang sama. Hi-fi lama
(11 layar, Inter, hijau) ada di git: `git show dae32c9:hifi.html`.

Saat merakit layar v2: logika, provider, persistensi, dan aturan platform (`docs/architecture.md`, `docs/data.md`,
`docs/infra.md`) tetap berlaku. Detail **tampilan** layar lama (ikon Material, gradien, `typeScale`, poster lama, teks
versi di bawah Beranda, label tombol lama) diganti hi-fi + komponen v2 — kalau bertentangan, hi-fi yang benar. Beranda
v2 belum menampilkan versi (Cakupan → Dihapus); keputusan 20 (2026-11-04) memunculkannya lagi di 3.2.0, gayanya ikut
hi-fi baru, bukan teks versi lama.

## Fondasi (langkah 1, `lib/core/theme/`)

- `mabar_theme.dart` — `MabarColors` (token v2 saja; token lama sudah dipetakan lewat tabel "Token lama → baru" di
  hi-fi dan dihapus), `MabarSpacing`, `MabarRadius`, `MabarSize` (tinggi sentuh, ukuran ikon), `MabarShadows` (hanya
  panel Beranda & menu ⋯; blur CSS dikonversi ke sigma Flutter), `MabarType` (skala huruf; angka besar =
  `numVariations` wdth 72 + `tabular`), dan `MabarTheme.light()`.
- Setiap `MabarType` membawa `fontFamily` sendiri: `ButtonStyle.textStyle`, judul dialog, dan isi snackbar **mengganti**
  gaya tema (tidak di-merge), jadi `TextStyle` tanpa keluarga di situ jatuh ke Roboto/SF. Semua slot `TextTheme`
  menulis `letterSpacing: 0` + `height`, kalau tidak geometri Material 3 ikut masuk.
- `mabar_icons.dart` — `MabarIcons`, 32 ikon Phosphor Bold hi-fi sebagai `IconData` konstan dari
  `assets/fonts/Phosphor-Bold.ttf` (`@phosphor-icons/web@2.1.1`, MIT; codepoint dari `style.css`-nya). Paket
  `phosphor_flutter` **tidak** dipakai: tidak dirawat sejak 2024 dan gagal dikompilasi karena `IconData` sekarang
  `final class`. Jangan menambah `Icons.*` Material; ikon baru = konstanta baru di sini.
- Inter dan `design-tokens.json` lama sudah dihapus.

## Komponen (langkah 3)

60+ golden per wilayah frame di `test/hifi/components/`.

- Generik di `lib/core/widgets/`: `mabar_controls` (MabarButton, MabarTextButton, MabarIconButton, MabarRowAction,
  MabarActionBar, MabarAppBar), `mabar_group` (MabarGroup/MabarRow, MabarSection, MabarGroupLabel/Note/Header),
  `mabar_inputs` (MabarSegmented, MabarStepper, MabarField, MabarChip/Wrap/Grid), `mabar_layers` (showMabarSheet,
  MabarOption, showMabarConfirm, showMabarMenu, showMabarToast), `match_score_row`, `numbered_lists` (RosterPreview,
  PairList), `mabar_ball`.
- Khusus layar di `features/<layar>/widgets/`: RoundTabs, RestingList, ScoreBoard/ScoreKeypad (di atas `ScoreEntry`),
  StandingTable, StatLine, NameListField, ModePicker/CourtSwatch/CourtColorGrid, HomePanel/HomeRowIcon/InstallStep,
  SharePoster (`share/widgets/`, preset pratinjau/Feed/Story, diekspor lewat `SharePosterTarget.exportPixelRatio`).
- Komponen jadwal v2 di `lib/features/schedule/widgets/` (RoundTabs, RestingList, ScheduleMatchRow), dipakai Fixed dan
  Mixed.
- `MabarRowAction` tata letaknya 36 (seperti CSS) dengan area sentuh 44 lewat hit-test yang diperluas.
- Tata letak lama sudah habis (`mabar_widgets.dart` dihapus).

## Golden

- Layar: `expectMatchesHifi(tester, layar, '<id frame>')` di `test/hifi/hifi_golden.dart` membandingkan render Flutter
  dengan `design/frames/<id>.png` (2x, Archivo dimuat; gagal → `build/hifi_diff/`). Golden semua frame + perilaku per
  alur di `test/hifi/screens/<alur>_test.dart`.
- Pembungkus layar `hifiScreen(...)` di `test/hifi/screens/screen_harness.dart` (tema, safe area 47/34, override
  provider). Golden dialog/sheet/ketikan/gulir memakai `expectMatchesHifi(..., act: (tester) async {...})`.
- Golden yang butuh turnamen berjalan meng-override `tournamentProvider` dengan controller yang `build()`-nya
  mengembalikan turnamen itu (config `identical`, jadi `startIfNeeded` tidak membuat jadwal baru).
- Golden bertoleransi 2% piksel, jadi teks hitung mundur dicek dengan `find.text` terpisah, dan test layar yang
  menampilkan sisa wajib meng-override `clockProvider`.
- Komponen: `hifiRect(frame, kelas, text:)` membaca `design/spec/rects.json` (posisi elemen yang diukur Chrome, ditulis
  `tool/hifi_extract.py`), `hifiStage` menaruh widget di posisi itu, `expectRegionMatchesHifi` membandingkan
  wilayahnya saja. Pembanding menyerap geseran 1 piksel perangkat (Chrome men-snap baseline, Flutter tidak); geseran
  2 pt tetap gagal — sudah dibuktikan di `hifi_harness_test`. Gambar aset: `precacheHifiAssets`.
- Fixture: Mixed `test/hifi/screens/schedule_fixture.dart` (`mixedTournament`, `LoadedTournament`); Klasemen
  `test/hifi/screens/ranking_fixture.dart` (data `ranking_v2_test.dart`); 06o (30 pemain, R1–R3 hasil generator) memakai
  id turnamen `t-06o-30` karena undian prioritas berseed id turnamen, `fixtureNames` berisi 30 nama berawalan unik;
  fixture match boleh menulis nama lengkap kalau nama depannya kembar (06u). Data golden poster
  (`test/hifi/components/share_poster_data.dart`) ditulis `tool/hifi_extract.py`.

## Hi-fi → frame

- Kalau hi-fi diubah: `python3 tool/hifi_extract.py` me-render ulang `design/frames/` dan menulis ulang
  `design/spec/screens/` + `components.md` (butuh Google Chrome + internet untuk font). Jangan edit hasilnya dengan
  tangan. Setiap keputusan dicatat juga di hi-fi → Cakupan → "Sudah disetujui", lalu artifact online dipublish ulang
  dari file yang sama.
- Kalau `hifi_extract.py` mengubah banyak frame yang isinya tidak tersentuh sementara `rects.json` tetap sama, itu noise
  rasterisasi font sesaat (pernah terjadi 2026-10-22, ~60 golden gagal): jalankan ulang, jangan commit frame itu.
- Frame yang dulu tidak konsisten dengan aturannya sudah dibetulkan di hi-fi atas keputusan host (2026-10-22), jadi
  golden layar tidak perlu pengecualian: keypad 07a–07g/07i menggambar tombol mati sesuai aturan, Lanjutkan di banner
  46 pt dan Tambah di 08a/08b 48 pt (dulu kalah oleh `min-height: 52px` `.btn`), keyframe 200 ms 01g digambar dari
  aturan, gambar Feed/Story line-height 1,4.

## Layar (langkah 5, semua selesai)

01 Beranda, 02 Pemain, 03 Konfigurasi, 04 Pasangan, 05 Jadwal Fixed, 06 Jadwal Mixed, 07 Pemain, court & lanjutkan,
08 Input Skor, 09 Peringkat, 10 Detail, 11 Bagikan. Batas yang tidak tergambar di frame: durasi match maks 180 mnt,
booking 1–12 jam per court.

### Umum

- Nama pemain di baris match, Input Skor, WO, riwayat Detail, Istirahat Fixed, dan caption = nama lengkap (keputusan
  host 2026-10-25; dulu nama depan). `MatchScoreSide.names` (+ `prefix` "vs " di Detail); tidak muat → `_TeamNames` di
  `match_score_row.dart` memotong tiap nama sendiri, nama yang muat di separuh lebar tetap utuh (`.nm.split`/`.keep` di
  CSS, frame 06u). `pairNames` mengembalikan daftar nama.
- Dialog konfirmasi dipusatkan di layar penuh (`useSafeArea: false`, sesuai `.dialog { top: 50% }`).

### Beranda

- `features/home/home_screen.dart`: `Column` = banner `Expanded` (menerus 24 pt di bawah sudut panel lewat
  `Positioned(bottom: -24)`) + `HomePanel`. Tanpa scroll: panel terpanjang (01a) ±330 pt, jadi banner tetap muat
  wordmark + info round di layar 568 pt.
- Status pasang dibaca lewat `appInstallModeProvider` supaya golden bisa menampilkan baris pasang.
- Pilihan olahraga: pilihan host → turnamen berjalan → turnamen terakhir → Tennis; banner mengikuti turnamen berjalan
  kalau ada.

### Konfigurasi & Pasangan

- Layar "Cara Kerja Mixed" sudah dihapus: Konfigurasi Mixed ("Mulai Round 1") langsung push `/schedule`.
- Pasangan: hasil acak bisa disuntik lewat `PairSetupScreen.random` (test memakai `Random` berskrip supaya sama dengan
  frame); "Ubah pemain" mem-pop dua layar (Pasangan + Konfigurasi) kembali ke Pemain yang masih terisi.

### Jadwal

- Baris match + subjudul bersama di `features/schedule/widgets/schedule_match_row.dart` (`ScheduleMatchRow`,
  `scheduleSubtitle`, `pairNames`) untuk Fixed dan Mixed. Subjudul tanpa waktu; strip court 42 pt
  (`MatchScoreRow.badgeWidth`, Detail tetap 34) dan di round berjalan (`ActiveTournament.runningRound`) membawa kotak
  jam sisa booking court itu (`countdown`, "01:15", `core/time_text.dart`: ":" durasi, "20.02" jam dinding).
- Layar Jadwal dan Input Skor ditik lewat `core/minute_ticker.dart` di pergantian menit sejak `createdAt` (bukan
  `Timer.periodic`, yang bisa tertinggal 59 detik dari hasil Buat R…).
- Dialog Akhiri = `confirmFinishTournament` → `showMabarConfirm`; `schedule_widgets.dart` tinggal
  `confirmFinishTournament`. Fixed setelah diakhiri: ⋯ tetap aktif, menunya tinggal Live score
  (12f, lihat `docs/live.md`; sebelum 2.5.0 pudar dan mati, 06c).
- Kedua layar jadwal memanggil `startIfNeeded` lewat `Future.microtask` (Riverpod melarang mengubah provider di
  `initState`); Mixed memunculkan sheet "Cara kerja Mixed" (`mixed/mixed_guide_sheet.dart`) sekali saat R1 baru dibuat.
- Sheet Kelola pemain / Lanjutkan turnamen di `schedule/mixed/`.

### Input Skor

- `ScoreBoard` + `ScoreKeypad` di atas `ScoreEntry` (skor tersimpan → `ScoreEntry.edit`, "Perbarui skor"); feedback
  Americano menulis selisih ("menang +5"), format lain skornya.
- Jebakan CSS: dua tombol `flex: 1` / `flex: 2` membagi sisa lebar **setelah** padding tombol (Batal 129, Simpan WO
  219), bukan 1:2 murni.

### Klasemen & Detail

- Klasemen (dulu Peringkat, folder `leaderboard/`): kolom Main = `PlayerStanding.matchesPlayed` (WO ikut). Status
  subjudul dari `rankingStatus()` (`leaderboard_screen.dart`, "Sementara · R3 · 6 dari 6 match" / "Final · 4 round ·
  7 match"); golden Fixed 09c dengan jadwal yang cocok 10b.
- Detail: riwayat terbaru di atas, baris atas = tim sendiri (Mixed: nama sendiri dulu), menang WO "+n" pudar =
  `woPoints` ÷ jumlah menang WO. `MatchScoreRow` mematok tinggi baris tim 22,4 supaya riwayat (tanpa tinggi minimal)
  tidak bergeser 0,8 pt per baris.

### Bagikan (`features/share/share_result_screen.dart`)

- Mengirim **gambar**, bukan cuma teks: `SharePoster` (target Feed 1080×1080 dan Story 1080×1920,
  `SharePosterTarget.exportPixelRatio`) di-render lewat `screenshot` lalu dibagikan dengan `Share.shareXFiles` lewat
  share sheet sistem, teks hasil (`ResultTextBuilder`) jadi caption. Gagal share → caption disalin + toast "Hasil
  disalin" (selalu 19 pt di atas action bar: `showMabarToast(bottom:)` diisi tinggi action bar dua tombol).
- Isi poster dari `sharePosterData()` (`share_content.dart`): Ringkas = 5 teratas + "+n pemain/pasangan lainnya",
  Lengkap = semua yang bernomor. Tiap baris = nilai metode + selisih (`SharePosterRow.detail` satuan, `.diff` selisih):
  "42 poin · +12" / "100% · +12", dua kolom dan Story tanpa satuan "42 · +12".
- Lengkap: Mixed > 10 baris di pratinjau/Feed jadi dua kolom, pasangan dan Story selalu satu kolom; lebih padat dari
  frame terpadat yang disetujui (10 baris satu kolom, 15 per kolom, 20 baris nama di Story) semua huruf baris
  dikecilkan sebanding (`SharePoster._density`, frame 11k/11l).
- Teks kepala/kaki poster dibungkus `_CssLines` (tinggi = n baris × ukuran × line-height, ikut skala teks) supaya ruang
  daftar sama dengan CSS. Golden Feed/Story 11l bertoleransi 3%: kotaknya sudah sama dengan Chrome, sisa geseran huruf
  ≤ 1 pt di baris rapat (line-height 1,1) jadi ±1,7% piksel di Mac dan ±0,7 poin lebih tinggi di CI Linux (pernah gagal
  3,2% sebelum `_CssLines`).
- `ShareTheme` punya 10 gradien (6 gelap bertinta putih + 4 lembut bertinta gelap); semua warna poster diturunkan dari
  `theme.ink` — jangan menaruh `Colors.white` langsung. Tema & format tidak disimpan.
- Melihat hasil poster tanpa build web: test sekali pakai yang me-render `SharePoster` di `RepaintBoundary` lalu
  `toImage(pixelRatio: 3)` di dalam `tester.runAsync`, dan simpan PNG-nya. Wajib `loadHifiFonts()`
  (`test/hifi/hifi_golden.dart`, memuat Archivo + font ikon `PhosphorBold`) dan tema `MabarTheme.light()` (Pitfalls `CLAUDE.md`).
  `Image.asset` memang tidak ikut ter-render di test.

## Painter lapangan (langkah 4)

- `core/widgets/court_painter.dart` — `CourtPainter(t, toward, layout)`, satu gambar sudut lapangan untuk banner Beranda
  **dan** ikon app (generatornya: `docs/infra.md`). `t` = posisi garis tennis (0) → padel (1); warna `toward` menyapu
  dari dinding belakang dengan tepi tegas, tidak dicampur. `CourtLayout.banner` (60 pt/m, garis dipudarkan 35% lewat
  satu `saveLayer`) dan `CourtLayout.icon` (kanvas 1024, garis penuh).
- `features/home/widgets/court_banner.dart` — `CourtBanner(sport, live)`: wordmark, nama olahraga / `.liveblock`,
  animasi 01g (controller = posisi garis + `animateTo`, jadi berbalik di tengah jalan tidak meloncat; kurva
  `easeInOutCubic` Flutter tidak simetris). Gambarnya ikut safe area (frame: status bar 47 → baseline y 104).
- Golden 01b/01c/01e/01f di `test/hifi/components/court_banner_test.dart`.

## Jebakan CSS → Flutter (sudah makan korban)

- Border CSS memakan tempat (border-box), `inset box-shadow` tidak; `Container` dengan border dekorasi otomatis
  menambah tebal border ke padding.
- Mesin teks membulatkan tinggi tiap baris ke pt bulat (22,4 → 22, 25,6 → 26), jadi kotak yang tingginya dari jumlah
  baris perlu dikompensasi (NameListField, baris poster).
- `OutlineInputBorder` menggeser isi 4 pt kecuali `gapPadding: 0`.
- `flex: 1` (basis 0) membagi sisa ruang ke isi baris dan garis atas ada di luar bagian itu, jadi baris pertama tanpa
  garis 1 pt lebih pendek (poster `.rows`).
- `ButtonStyle.textStyle` mengganti gaya tema (makanya `MabarType` membawa `fontFamily`); `ThemeData` mengunci platform
  saat dibuat.

## Aset ilustrasi

`assets/images/` — raket tennis/padel (`SportTypeX.assetPath`) dan ilustrasi mode Fixed/Mixed (`PartnerModeX.assetPath`).
Semuanya PNG transparan dengan garis berwarna **satu abu yang sama, #6B7280** (token `text3` desain lama; hi-fi v2
memakai raket apa adanya dan menggelapkannya saat terpilih, ilustrasi mode diganti ikon); kalau menambah aset baru,
samakan warnanya — beberapa tempat menampilkan aset apa adanya (kartu Home, chip Jadwal) sehingga beda warna langsung
kelihatan. Tempat lain mewarnai ulang lewat `ColorFiltered(BlendMode.srcIn)` (watermark share ikut tema, ilustrasi mode
ikut status terpilih), dan itu hanya bekerja kalau latar aset benar-benar transparan.

Sumber aslinya JPEG berlatar putih; konversinya: potong bingkai tipis 1-2px di tepi file, putih → transparan dengan
alpha bertingkat (biar tepi anti-alias tidak bergerigi), pangkas ke isi, lalu beri padding mengikuti rasio isi:kanvas
aset lama supaya ukuran tampilnya tidak bergeser.
