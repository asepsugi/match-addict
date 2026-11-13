# Task — Poster Lengkap arah B "Podium mini" (rencana 3.7.0, MINOR)

Pemilik: tech-lead. Daftar task sebelumnya (Poster podium PP-n, selesai, rilis 3.6.0) ada di riwayat git:
`git show 3a95d55:docs/tasks.md`.

## PATCH 3.7.1 · ukuran & perataan poster (umpan balik host uji HP 2026-11-13) — SEDANG JALAN

Branch `poster-patch-3-7-1` (dari `5684c9e`), Level 1 Presentation, PATCH. Kode Flutter **sudah** diubah (commit WIP);
golden poster **pasti merah** sampai hi-fi menyusul. Host minta push digabung dengan update berikutnya (belum disebut).
- Permintaan host: (a) nama tabel Ringkas Feed/Story terlalu besar → seukuran sub judul "Tennis · Mixed …";
  (b) kaki Lengkap Feed ("Match Addict", "n pemain …") turun 1 tingkat; (c) poin & selisih berantakan kalau digit
  selisih beda; (d) celah lebar antara panel dan kepala di Lengkap Feed (14 pemain, dua kolom); (e) Lengkap Story:
  nama terlalu besar + kolom poin berantakan.
- Sudah di kode: `posterNameMax` (nama ≤ subSize 12,5/15, Ringkas & Lengkap), `posterValueColumns` + `PosterValue`
  (nilai rata kanan, keterangan rata kiri, lebar = terpanjang se-poster), `PodiumSignature` wordmark 11,5→10,5, bola
  13→12, fakta 10,5→9,5 (semua poster), `lengkap.dart` feed2 `maxRow` 26→40 (baris mengisi ruang, huruf tetap).
- **Belum dikonfirmasi host:** pratinjau render sudah ditunjukkan, host belum bilang oke. Tiga pilihan main session
  yang perlu dicek: kaki mengecil di semua poster; perataan juga di Ringkas; celah ditutup dengan baris lebih tinggi
  (alternatif: tinggi baris tetap, panel menempel di bawah kepala).
- Sisa: keputusan 91 di PRD §5.9; CSS hi-fi (`.psig`/`.wmk`, nama `.prow`, kolom nilai, kepadatan feed2 di JS/tokens
  `posterLengkap.density`) → `python3 tool/hifi_extract.py` → frame 11a–11m, 13q–13w, 18a–18t; golden + test
  `test/services/lengkap_test.dart`; satu run penuh; versi 3.7.1 + `appVersion`; publish ulang artifact hi-fi; catat
  di Cakupan. Pratinjau: test sekali pakai seperti `docs/ui-v2.md` (data 14 pemain dari screenshot host).
- **Digabung (host 2026-11-13): garis lapangan di poster.** Lantai poster hanya garis belakang + satu garis samping →
  di Story tidak terbaca sebagai lapangan. Tambah garis geometri tennis/padel yang tampak dari sudut itu, sejajar
  sumbu podium (horizontal + kemiringan depth). Designer boleh Fable **hanya** untuk eksplorasi gambar sudut lapangan
  (`design/explore/bagikan-garis.html`, lembar `frames/garis-sheet.png`); hi-fi final kembali ke Opus. Pratinjau
  + render ulang hi-fi ditunda host sampai gabungan ini siap.
  - Putaran 1 (G0–G4, `bagikan-garis.html`) ditolak host. Putaran 2 disetujui: **L1 + panel tetap 86%** = keputusan
    91 (ukuran/perataan 3.7.1 jadi keputusan 92). Rumus + aturan garis/dinding: laporan di
    `design/explore/bagikan-lapangan.html` (mode `?check=1`), ringkas: titik (u, v, t m) → x = ax + S·u − k·g·v,
    y = ay + g·v − S·t; k = dx ÷ |dy| depth podium poster itu; L1: sudut (cornerX, backLine), sideline kanan
    memotong tepi bawah di x = W − cornerX, net 10 px di bawah tepi bawah. Net tidak digambar; dinding kanan tidak.
  - Berikutnya: hi-fi final (Opus, per grup frame, maks 3 paralel) untuk 11a–11m, 13q–13w, 18a–18t → golden →
    `PodiumScenePainter` (perlu rumus lapangan + kisi kawat padel). Spec `logic.md` §16/§17.6 ikut diperbarui.

## Serah terima (2026-11-13)

- **Progres (sesi 2026-11-13, branch `poster-lengkap`):** B1 selesai dan Approve oleh tech-lead baru — PL-1
  `4cc9e4a`, PL-2 `b13dcd6`, merge `214a859`. 54 test baru lolos; golden Ringkas lolos tanpa diubah; 13 golden Lengkap
  (11b/e/h/i, 13s–13w) masih gagal, menunggu PL-3. **Berikutnya (sesi baru):** PL-3 (engineer opus/high, base =
  HEAD `poster-lengkap`), review tech-lead baru, lalu PL-4 (sonnet/low–medium, dicek main session), satu full test,
  bump 3.7.0, merge `main` setelah host bilang go.
- **Progres B2 (2026-11-13):** PL-3 selesai + Approve — `e66971d` (feat) + `ff8a144` (review: panel/pengukur satu
  sumber, `lengkapPanel`, `posterStyle`/`posterWidth`). Golden komponen Lengkap + 13t/13v/13w + Ringkas lolos; tinggal
  golden layar 11b/11e/11h/11i/13s/13u (PL-4). `docs/ui-v2.md` → Bagikan sudah memakai nama akhir. **Berikutnya:** PL-4.
- **Progres B3 (2026-11-13):** PL-4 selesai — `8514295`, dicek main session. Full `flutter test` hijau (1173 lolos,
  1 skip), analyze bersih (2 info lama). Versi 3.7.0+22. Rilis 3.7.0+22 live 2026-11-13 (merge 1ef8031, fix test CI
  b8d39bc). **Sisa:** uji share di HP (host); hi-fi 11j diperbaiki (32d7a86, artifact v90).
- **Catatan untuk PL-4 (sudah dikerjakan):** (1) layar Lengkap dengan tema null sudah menggambar lapangan tapi deret
  masih menandai biru (`share_result_screen.dart:43,87`) — beres di PL-4, test lama "Lengkap memakai dan menandai biru"
  diganti "11e K76 …". (2) Komentar `_theme` di `share_result_screen.dart:38` basi. (3) Nama test
  `sparing_bagikan_test.dart:105` "13s … ×8/9" merujuk kepadatan lama. (4) Turunan `ShareTheme.ink` dkk tak terpakai
  poster lagi → bersihkan. (5) Golden layar 11e/11h gagal juga karena setup test belum memakai nama turnamen + tema
  frame.
- **Catatan hi-fi (bawa ke host, bukan kode):** frame 11j `.mini b { color: var(--fg) }` membuat nomor/nilai kartu
  gelap; golden tetap lolos (≤ 0,62%).
- **Catatan review B1 untuk PL-3 (sudah dikerjakan):** (1) Sparing: kalau `Podium.of` = `PodiumEmpty`, oper
  `rowCounts` 0 ke `lengkapGrid` (bukan jumlah baris Klasemen klub), kalau tidak kepala klub muncul dan melanggar
  keputusan 89 — test "K89 Sparing 0–0 tanpa kepala klub" di tingkat `sharePosterData`. (2) `lengkapHead` dipanggil di
  build/jalur ekspor seperti Ringkas, jangan di-cache di provider. (3) `rankCol`/`gap` dari tokens ditambahkan di PL-3
  (bagian widget). API B1: `miniPodiumLayout`, `lengkapHead` → `LengkapHead`, widget bersama `PodiumHead`,
  `PodiumRank`, `PodiumSignature`; `PodiumLayout.panel` kini nullable.
- **Backlog PATCH (sesudah 3.7.0):** Ringkas `podium_poster.dart:325` menghitung bawah kepala dengan ukuran 22/27 untuk
  judul yang mengecil tapi tetap satu baris (menyimpang dari §16.6 `.ptitle.two`, sejak 3.6.0). Probe reviewer: tidak
  ada fixture yang kena, jadi golden tidak berubah; kalau ternyata berubah, bawa ke host.
- **Keputusan host:** PRD §10 keputusan 76–90. **Hi-fi final:** 3a95d55 / cbcf0d4, artifact v89 (f53cebe). Frame 11b, 11e–11m,
  13s–13w; Komponen → `.lk`; `tokens.json` → `posterLengkap`; fixture `test/hifi/components/share_poster_data.dart`
  (termasuk '11m') sudah di-generate ulang.
- **Spec:** `design/spec/logic.md` §17 (aturan, rumus, data test = frame, golden, jebakan). PRD §5.9, logic §9, §13.9,
  §16.3, `docs/ui-v2.md` → Bagikan, dan `docs/architecture.md` sudah diselaraskan (2026-11-13).
- **Golden:** 11b, 11e–11l, 13s–13w dan poster `SharePoster` saat ini gagal sampai kode menyusul. Wajar.
- **Versi:** 3.6.1 (0336826) belum di-push. Rilis berikutnya 3.7.0 (MINOR), dinaikkan main session saat merge ke
  `main`, bukan oleh engineer.
- **Tanpa** `schemaVersion`, DBA, tech-infra, atau dependensi baru. Caption dan simpanan tidak berubah.
- Pertanyaan terbuka `logic.md` §17.13: kedua asumsi disetujui host 2026-11-13 (keputusan 89–90).

## Urutan batch

| Batch | Task | Model / effort | Paralel | Dicek oleh |
|---|---|---|---|---|
| 1 | PL-1 aturan kolom + kepadatan (service) | sonnet / medium | ya, dengan PL-2 (file berbeda) | tech-lead baru |
| 1 | PL-2 podium mini + kepala (geometri, refaktor podium) | **opus / high** | ya, dengan PL-1 | tech-lead baru |
| 2 | PL-3 `SharePoster` `.lk` + isi + ekspor + golden komponen | **opus / high** | tidak (butuh PL-1, PL-2) | tech-lead baru |
| 3 | PL-4 layar Bagikan: deret 11 tema, golden layar, bersih-bersih | sonnet / medium | tidak (butuh PL-3) | main session |

Semua di branch `poster-lengkap`, bukan `main`. Tiap task: `dart format` hanya file baru/hunk sendiri (lebar 120),
`flutter analyze` bersih, `flutter test` untuk berkas yang disentuh + golden Ringkas (11a, 11c, 11d, 13q, 13r, 18a–18t)
tetap lolos tanpa diubah.

## PL-1 · `services/share/lengkap.dart` — kolom dan kepadatan (keputusan 80, 81, 86, 88)

- **Tujuan:** aturan murni Dart 17.3 + 17.4: `LengkapSizing`, `LengkapCell` (baris / kepala klub), `LengkapGrid`,
  `lengkapGrid(...)`, `LengkapDensity`, `lengkapDensity(...)` (API 17.9; nama boleh disesuaikan, bentuk jangan).
  Angka acuan/batas baris/batas skala per susunan dari `tokens.json → posterLengkap.density` sebagai konstanta di file
  ini (ukuran huruf tidak, itu milik widget).
- **Baca:** `logic.md` §17.3, 17.4, 17.9, 17.10 (tabel pertama); `lib/services/share/podium.dart` (pola).
- **Sentuh:** `lib/services/share/lengkap.dart` (baru), `test/services/lengkap_test.dart` (baru).
- **Kriteria terima:** semua baris tabel 17.10 pertama + kasus batas (Mixed 10/11 Feed, 20/21 Story, Fixed 15 pasangan
  Story, Sparing Mixed 3 + 3 Feed, Sparing Mixed 20/21 Story, Mexicano = Mixed, Kosong = 0 satuan) lolos; nama test
  memakai id frame + keputusan (`11k K88 …`, `13w K86 …`). Invariant L1–L4 diuji sebagai properti atas n 0–30 dan
  semua kombinasi target × mode × Sparing. Tidak meng-import `package:flutter`.
- **Bergantung:** tidak ada.

## PL-2 · Podium mini + kepala Lengkap (`widgets/podium_poster.dart`) — opus

- **Tujuan:** geometri 17.5 + 17.6 tanpa menyalin podium. (a) Satu fungsi penempatan blok + bola dipakai
  `podiumLayout` dan `miniPodiumLayout` (parameter: dasar, tinggi tetap atau batas tinggi, lebar slot, kedalaman, ukuran
  bola, jarak bola 2/1, angkat bola +2/+1); keduanya menghasilkan `PodiumLayout` untuk `PodiumScenePainter` yang
  sama. (b) Fungsi kepala Lengkap: ukuran judul + jumlah baris, ukuran baris kecil (turun 0,5 sampai 11), bawahKepala
  (line-height CSS), garis belakang, kanan kepala dari slot (Kerumunan/Kosong 3, Klub 2). (c) Lencana emas dan kaki
  `.psig` jadi widget bersama berparameter ukuran (dipakai `PodiumPoster` sekarang, `SharePoster` di PL-3).
- **Baca:** `logic.md` §16.6, 17.5, 17.6, 17.7 (lencana, kaki), 17.10 (tabel kepala dan podium mini), 17.12 #1–#4;
  `tokens.json → posterLengkap.head/court/miniPodium`; `lib/features/share/widgets/podium_poster.dart`.
- **Sentuh:** `lib/features/share/widgets/podium_poster.dart`, `test/features/lengkap_layout_test.dart` (baru).
- **Kriteria terima:** tabel kepala (garis belakang 79/75/191/170/96/188, kanan 74–130) dan tabel podium mini 17.10
  (rect blok, ukuran angka, posisi/jumlah bola) lolos dengan `loadHifiFonts()`; golden Ringkas 11a, 11c, 11d, 13q, 13r,
  18a–18t lolos **tanpa** mengubah test atau toleransinya; tidak ada konstanta/rumus podium yang tertulis dua kali.
- **Bergantung:** tidak ada (paralel dengan PL-1).

## PL-3 · `SharePoster` arah B + isi + ekspor + golden komponen — opus

- **Tujuan:** tulis ulang `SharePoster` sebagai `.lk` (17.1, 17.7): scene dari `miniPodiumLayout` + `PodiumScenePainter`,
  kepala dari PL-2, panel dengan `lengkapGrid`/`lengkapDensity` (PL-1), baris `.prow` (satu/dua kolom, `.duo`,
  `.lclub`), nama dikecilkan bersama per target (kn, langkah 0,02, min 0,82, lalu elipsis), kaki bersama. Target
  `PodiumPosterTarget`, tema `PodiumTheme`. `SharePosterData` baru (17.9); `sharePosterData()` memetakan `Podium.of` +
  kepala + `podiumFacts` lewat helper yang sama dengan `podiumPosterData`. `lengkapImages(data, PodiumTheme)` Feed
  360×360 / Story 360×640 ×3. Sambungan minimal di `share_result_screen.dart` supaya Lengkap menerima `PodiumTheme`
  yang sama dengan Ringkas (deret tetap urusan PL-4). Hapus yang diganti (17.9 "Dihapus", 17.12 #8–#9).
- **Baca:** `logic.md` §17 seluruhnya; `screens/11-bagikan.md` 11b, 11e–11m; `screens/13-sparing.md` 13s–13w; hi-fi
  Komponen → `.lk` (hanya panel itu); `share_poster.dart`, `share_content.dart`, `share_exports.dart`.
- **Sentuh:** `lib/features/share/widgets/share_poster.dart`, `lib/features/share/share_content.dart`,
  `lib/features/share/share_exports.dart`, `lib/features/share/share_result_screen.dart` (sambungan tema saja);
  test: `test/hifi/components/share_poster_test.dart`, gambar 13t/13v/13w di `test/hifi/screens/sparing_bagikan_test.dart`,
  `test/features/share_poster_test.dart`, `test/features/sparing_share_test.dart` (grup `sparingPosterDensity` dihapus,
  caption tetap), `test/features/sparing_poster_edge_test.dart` (kasus ditulis ulang untuk `.lclub` dan blok: nama klub
  panjang elipsis, "6½"/"5½" di blok 34, 6 – 6 dua emas, 0 – 0 panel hanya kaki).
- **Kriteria terima:** golden komponen 11b, 11e, 11f, 11g, 11h, 11i, 11j (baru), 11k, 11l, 11m (baru) dan gambar 13t,
  13v, 13w lolos dengan toleransi 17.11; assert jumlah bola, lencana emas, fakta, judul per frame (17.11); test
  pemetaan isi 17.10 (11m Feed/Story, 13s, 13u, 13w, Sparing 0 – 0); ekspor 1080×1080 dan 1080×1920; tes caption lama
  lolos tanpa diubah; golden Ringkas tetap lolos; `grep` tidak menemukan `SharePosterTarget`, `sparingPosterDensity`,
  `SharePosterClubScore`.
- **Bergantung:** PL-1, PL-2.

## PL-4 · Layar Bagikan: deret tema + golden layar + bersih-bersih — dicek main session

- **Tujuan:** deret tema Lengkap = Ringkas, 11 lingkaran 27 pt satu baris (17.8, keputusan 76); cabang 10 × 30 pt dan
  pemetaan lapangan → biru dihapus. Keterangan tab dan caption tidak berubah.
- **Baca:** `logic.md` §17.8, 17.11, 17.12 #13 #15; `screens/11-bagikan.md` 11b, 11e; `docs/ui-v2.md` → Bagikan.
- **Sentuh:** `lib/features/share/share_result_screen.dart`, `test/hifi/screens/bagikan_test.dart`, layar 13s/13u di
  `test/hifi/screens/sparing_bagikan_test.dart`.
- **Kriteria terima:** golden layar 11b, 11e, 11h, 11i, 18b, 13s, 13u lolos; test baru "11e K76 lapangan tetap lapangan
  di Lengkap" (tidak dipetakan ke biru); seluruh `flutter test` hijau; `docs/ui-v2.md` → Bagikan masih cocok dengan
  nama kelas/fungsi akhir (laporkan kalau tidak, tech-lead yang mengubah).
- **Bergantung:** PL-3.
