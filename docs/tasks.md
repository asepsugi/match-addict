# Task — Poster podium Bagikan (rencana 3.6.0)

Pemilik: tech-lead. Sumber: PRD §5.9 + keputusan 60–71 (§10), `design/spec/logic.md` §16 (siapa naik, panel, fakta,
tema, API, data test, tata letak, jebakan, pertanyaan terbuka 16.8), `design/spec/screens/18-poster-podium.md` + frame
18a–18t, `screens/11-bagikan.md` (11a, 11c, 11d), `screens/13-sparing.md` (13q, 13r), `components.md` →
`PodiumPoster (PodiumScenePainter)` dan `SharePoster` (`.themes.fit`), `tokens.json` → `posterPodium`.
Daftar task sebelumnya (Tukar pemain TP-n, selesai) ada di riwayat git: `git show 7875ce8:docs/tasks.md`.

Aturan untuk semua task:
- Kerja di branch `poster-podium` (worktree per agen), **bukan** `main`: tiap push ke `main` = deploy. Rilis 3.6.0 =
  satu merge (PP-4) atas perintah host.
- Poster Lengkap, caption, Klasemen, simpanan tidak berubah. Golden yang boleh berubah/baru **hanya**: 11a, 11c, 11d,
  13q, 13r (digambar ulang di 059e61c) dan 18a–18t. Golden Lengkap 11b, 11e–11l, 13s–13w dan test caption lolos
  **tanpa diubah**. Kalau frame dan aturan berbeda: berhenti dan laporkan (`CLAUDE.md`), jangan mengubah fixture supaya
  cocok.
- Logika siapa naik, level/emas, dan baris fakta hanya di `lib/services/share/podium.dart` dengan test; widget tidak
  menghitung nomor, tidak memangkas, tidak membaca `ClubResult.lead` sendiri. Jebakan wajib dibaca: `logic.md` §16.7.
- Nama test memakai id frame + nomor keputusan (`18i K65 …`). Render poster di test wajib `loadHifiFonts()` +
  `MabarTheme.light()`; `clockProvider` di-override.
- `dart format` lebar 120 hanya untuk berkas baru dan hunk sendiri.
- Engineer dan reviewer hanya menjalankan test yang disentuh perubahannya; `flutter test` penuh sekali per merge di
  main session. Kategori semua task: MINOR (bagian dari 3.6.0); versi dinaikkan di PP-4 saja.
- Tidak ada perubahan simpanan, payload live, atau dependensi: DBA dan security tidak perlu task. Kalau engineer merasa
  perlu menyentuh `lib/services/storage/`, `lib/models/`, `relay/`, atau `pubspec.yaml`, berhenti dan laporkan.

## Peta urutan

| Gelombang | Task | Agen |
|---|---|---|
| 1 | PP-1 (logika podium + fakta) **paralel dengan** PP-2 (painter, panel, tema, golden gambar) | 2 |
| 2 | setelah PP-1 dan PP-2 di-merge ke branch: PP-3 (layar Bagikan Ringkas, ekspor, golden layar) | 1 |
| 3 | PP-4 rilis (main session + QA) | 1 |

PP-1 ↔ PP-2 tidak berbagi berkas: PP-1 hanya `lib/services/share/podium.dart` + test service; PP-2 hanya berkas baru di
`lib/features/share/` (+ satu helper publik di `mabar_ball.dart`) dan test komponen. PP-2 memakai view-model datanya
sendiri (data literal dari frame), jadi tidak menunggu tipe PP-1; PP-3 yang menyambungkan `Podium` → view-model.

---

## PP-1 · Logika podium + baris fakta (service)
- **Goal:** `logic.md` §16.1, §16.2 (fakta), §16.4: `Podium.of` (Empty / Steps / Crowd / Clubs, level, muka, bola,
  urutan slot, `pairSize`), `rowNoun` (pindahan `shareRowNoun`, isi sama), `podiumFacts`.
- **Baca:** `logic.md` §4 (nomor rapat), §13.7 (skor klub), §16; `ranking_calculator.dart` (`StandingEntry`,
  `standingEntries`, `compare`), `club_score.dart` (`ClubResult.lead`, `ClubTally.winsLabel`, `leads`),
  `features/share/share_content.dart` (`shareRowNoun`, pola teks), `models.dart` (`playedRoundCount`,
  `playedMatchCount`, `currentRound`, `MatchStatus.wo`), `leaderboard_screen.dart:23` (pola Sementara). Fixture:
  data set 1 di `test/hifi/screens/bagikan_test.dart`, `sparingFull` di `sparing_bagikan_test.dart`, 09g.
- **Ubah:** `lib/services/share/podium.dart` (baru). **Tidak** menyentuh `share_content.dart` (PP-3 yang menghapus
  `shareRowNoun` dan memakai `rowNoun`), widget, model.
- **Test baru:** `test/services/podium_test.dart`: semua baris tabel §16.5 (siapa naik + fakta), termasuk batas #1 ×4
  vs ×5, dua baris saja, satu baris, Sparing 0 – 0 (asumsi 16.8 #1); invariant I1–I4 sebagai test properti kecil atas
  semua kombinasi nomor rapat panjang 1–8 (enumerasi, bukan acak; < 2 detik).
- **Acceptance:** tabel §16.5 hijau; `podiumFacts` = teks frame persis; `git diff` hanya berkas di atas; `flutter
  analyze` tanpa peringatan baru.
- **Dependensi:** tidak ada. **Model:** default engineer, sonnet / medium (aturan kecil, sudah dirinci dengan data).
- **Review:** tech-lead, diff saja, daftar periksa §16.1 invariant + §16.7 #1–#6, #8 (sonnet / medium cukup).

## PP-2 · `PodiumPoster` + `PodiumScenePainter` + tema podium + golden gambar
- **Goal:** gambar podium Feed/Story/kartu sesuai §16.2 (teks panel), §16.3 (tema), §16.6 (tata letak), dari
  view-model sederhana; golden gambar 11d, 13r, 18c–18t.
- **Baca:** `logic.md` §16.2, §16.3, §16.6, §16.7 #9–#12; `components.md` → `PodiumPoster (PodiumScenePainter)` (CSS
  `.podium`) dan `SharePoster` (`.themes.fit`); `tokens.json` → `posterPodium`; `screens/18-poster-podium.md` + PNG
  18c–18t, 11d, 13r; satu SVG contoh di `design/hifi.html` (cari `<b>18c</b>`, baca hanya blok itu, jangan file utuh);
  `share_theme.dart`, `widgets/share_poster.dart` (`_CssLines`, pola target/ekspor), `core/widgets/mabar_ball.dart`,
  `core/theme/mabar_theme.dart` (`numVariations`, warna `court`, `courtDeep`, `padel`); test
  `test/hifi/components/share_poster_test.dart` (pola `expectRegionMatchesHifi` + `hifiStage`), `docs/ui-v2.md` →
  Golden.
- **Ubah (semua baru kecuali satu):** `lib/features/share/podium_theme.dart` (`PodiumTheme`: dua tema lapangan per
  olahraga + turunan 10 `ShareTheme` dari token, `goldBlock`, panel 0,86), `lib/features/share/widgets/podium_poster.dart`
  (`PodiumPosterTarget` card/feed/story dengan `designSize` dan `exportPixelRatio` = 3 untuk feed/story;
  `PodiumPosterData` view-model: judul, baris kecil, blok `{level, face, balls}` kiri → kanan, `wide` untuk Kerumunan,
  baris panel `{badge, hash, gold, names, value, detail}`, `pairSize`, fakta, olahraga; widget `PodiumPoster`;
  `PodiumScenePainter`; hitung tata letak sebagai fungsi murni `podiumLayout(...)` di berkas yang sama),
  `lib/core/widgets/mabar_ball.dart` (hanya: buka cara menggambar bola di `Canvas` untuk painter, mis. static
  `MabarBall.paint(canvas, rect)`; jangan menyalin painter bola).
- **Test baru:** `test/hifi/components/podium_poster_test.dart`: golden region 11d (Feed, Story), 13r (Feed, Story),
  18c–18p dan 18s–18t (Feed + Story), 18q (lima Feed), 18r (12 Feed: lapangan padel, lapangan tennis, 10 gradien);
  data literal dari teks frame (`screens/18-poster-podium.md` + panel di hi-fi), posisi region diukur dari PNG frame
  (Feed x 0, Story x 374 seperti 11d; 18q/18r membungkus baris, ukur dari PNG). Assert jumlah `MabarBall`/bola dan
  lencana per frame (§16.7 #12). Unit test `podiumLayout`: angka §16.6 (x0 55/71/121/54; tinggi Story 18h
  139/100/67, 11d 160/115/77, 18m 128/92/62; garis belakang 174 / 288 / 200 / 148 / 226).
- **Acceptance:** semua golden di atas lolos 2% (kalau perlu toleransi lebih, sebut frame dan alasannya di laporan,
  seperti 11l); golden lain tidak berubah; `flutter analyze` tanpa peringatan baru. Tidak mengubah `SharePoster`,
  `SharePosterTarget`, `ShareTheme`.
- **Dependensi:** tidak ada (paralel dengan PP-1). **Model:** default engineer, sonnet / high (banyak aturan tata letak,
  tapi oracle-nya golden + angka §16.6; naikkan ke opus hanya kalau 18h/18m/11d Story gagal setelah satu putaran).
- **Review:** main session (diff + golden terkait), tech-lead hanya kalau diff menyentuh `lib/services/**`.

## PP-3 · Layar Bagikan Ringkas = podium, deret 11 tema, ekspor Story ×3, golden layar
- **Goal:** keputusan 60, 62, 66, 69, 70 di layar: tab Ringkas memakai `PodiumPoster` (kartu 358 × 372) dari
  `Podium.of` + `podiumFacts`; deret 11 lingkaran 27 pt (lapangan + 10 gradien) di Ringkas, 10 lingkaran 30 pt di
  Lengkap dengan lapangan → biru; keterangan Ringkas "Podium · gambar Feed 1:1 & Story 9:16" (juga Sparing); Bagikan
  Ringkas mengekspor `PodiumPoster` Feed 360 × 360 dan Story 360 × 640 ×3 dengan nama berkas lama; 18t tombol tetap
  aktif.
- **Baca:** `logic.md` §16 (terutama 16.2–16.4, 16.7); `screens/11-bagikan.md` 11a/11c, `screens/13-sparing.md` 13q,
  `screens/18-poster-podium.md` 18a/18b/18t; `share_result_screen.dart`, `share_content.dart`, test
  `bagikan_test.dart`, `sparing_bagikan_test.dart`, `share_poster_test.dart`; API PP-1 dan PP-2.
- **Ubah:** `lib/features/share/share_content.dart` (`podiumPosterData(...)`: `Podium` → `PodiumPosterData`, teks
  lencana/nilai/kepala per §16.2; hapus `shareSummaryCount`, `shareClubSummaryCount`, cabang Ringkas di
  `sharePosterData`; ganti `shareRowNoun` dengan `rowNoun` dari service), `lib/features/share/share_result_screen.dart`
  (state tema = lapangan atau `ShareTheme`; dua deret; render/ekspor per format; precache watermark hanya untuk
  Lengkap). Tidak menyentuh `ResultTextBuilder`, `SharePoster`, painter PP-2 (kalau perlu ubah, laporkan).
- **Test:** di `bagikan_test.dart` golden 11a (data set 1, bernama, lapangan) dan 11c (tanpa nama + toast) menggantikan
  versi lama; di `sparing_bagikan_test.dart` golden 13q dan gambar 13r lewat `sparingFull` + `podiumPosterData`
  (menggantikan assert "+1 pasangan lainnya" / "3 baris per klub" Ringkas yang dicabut keputusan 62); golden 18a dan
  18b kalau datanya bisa dibuat tanpa kode produksi baru (boleh override `standingEntriesProvider` dengan baris literal
  di atas turnamen yang jumlah round/match-nya sama; kalau tidak bisa, laporkan dan cukup assert finder deret 11 + cincin
  lapangan). Widget test: deret Ringkas 11 / Lengkap 10; lapangan dipilih lalu pindah Lengkap → biru bercincin (11e);
  nude dipilih di Ringkas tetap nude di Lengkap (18b → 11b); 18t (semua belum main) tombol "Bagikan hasil" aktif;
  ekspor Ringkas memanggil render dengan `Size(360, 640)` dan rasio 3 untuk Story (uji lewat fungsi kecil yang bisa
  dipanggil test, bukan share sheet). Hapus test lama 11d Ringkas di `share_poster_test.dart` (sudah crash null-check;
  penggantinya di PP-2).
- **Acceptance:** golden 11a, 11c, 13q, 13r (+18a, 18b bila dibuat) lolos; golden Lengkap 11b, 11e–11l, 13s–13w dan test
  caption 11a/13q lolos tanpa diubah; tidak ada sisa referensi `shareSummaryCount`/`shareClubSummaryCount`;
  `flutter analyze` tanpa peringatan baru.
- **Dependensi:** PP-1 dan PP-2 di-merge ke branch. **Model:** default engineer, sonnet / medium.
- **Review:** tech-lead, diff saja (menyentuh pemetaan service → layar; daftar periksa §16.7 #6–#10, #13), sonnet /
  medium. Re-review diff perbaikan: main session.

## PP-4 · Rilis 3.6.0 (main session)
- **Goal:** `pubspec.yaml` 3.6.0+20 (BUILD = terakhir + 1), `appVersion` 3.6.0. Docs: `docs/ui-v2.md` → Bagikan (podium:
  `PodiumPoster`, `PodiumPosterTarget` ×3, tema lapangan, golden 18a–18t), `docs/architecture.md` → "Nama turnamen &
  teks share" (butir `services/share/podium.dart`: aturan pangkas + invariant I1–I3 ringkas), `logic.md` status baris
  7 (§16 diimplementasi), `CLAUDE.md` (status, riwayat versi 3.6.0, baris `docs/tasks.md` di Area docs: "sekarang:
  Poster podium PP-n"), header PRD §5.9 (PM) kalau perlu. Jawaban host atas `logic.md` §16.8 dicatat di PRD (PM) bila
  berbeda dari asumsi.
- **Acceptance:** `flutter analyze` tanpa peringatan baru; `flutter test` penuh lulus; `tool/build_web.sh` sukses. QA
  (sonnet / medium): Bagikan Ringkas di Chrome (build lokal) → dua PNG 1080 × 1080 dan 1080 × 1920 (cek ukuran berkas
  hasil unduh/share), Story tidak gepeng, teks di luar 250 px atas/bawah; 18t (turnamen baru tanpa skor) tombol aktif;
  share di HP Android/iOS oleh host (tidak bisa diuji agen). Merge `poster-podium` → `main` hanya atas perintah host.
- **Security:** tidak perlu agen terpisah: tidak ada jalur input, decode, atau dependensi baru.
- **Dependensi:** semua.
