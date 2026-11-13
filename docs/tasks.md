# Task — Poster Lengkap arah B "Podium mini" (rencana 3.7.0, MINOR)

Pemilik: tech-lead. Daftar task sebelumnya (Poster podium PP-n, selesai, rilis 3.6.0) ada di riwayat git:
`git show 3a95d55:docs/tasks.md`.

## Serah terima (2026-11-13)

- **Keputusan host:** PRD §10 keputusan 76–88. **Hi-fi final:** 3a95d55 / cbcf0d4, artifact v88. Frame 11b, 11e–11m,
  13s–13w; Komponen → `.lk`; `tokens.json` → `posterLengkap`; fixture `test/hifi/components/share_poster_data.dart`
  (termasuk '11m') sudah di-generate ulang.
- **Spec:** `design/spec/logic.md` §17 (aturan, rumus, data test = frame, golden, jebakan). PRD §5.9, logic §9, §13.9,
  §16.3, `docs/ui-v2.md` → Bagikan, dan `docs/architecture.md` sudah diselaraskan (2026-11-13).
- **Golden:** 11b, 11e–11l, 13s–13w dan poster `SharePoster` saat ini gagal sampai kode menyusul. Wajar.
- **Versi:** 3.6.1 (0336826) belum di-push. Rilis berikutnya 3.7.0 (MINOR), dinaikkan main session saat merge ke
  `main`, bukan oleh engineer.
- **Tanpa** `schemaVersion`, DBA, tech-infra, atau dependensi baru. Caption dan simpanan tidak berubah.
- Pertanyaan terbuka untuk host: `logic.md` §17.13 (dua asumsi, kode ditulis sesuai asumsi; kalau host memilih lain,
  perubahannya satu konstanta/cabang).

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
