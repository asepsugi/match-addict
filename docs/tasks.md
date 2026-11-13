# Task — Poster Lengkap arah B "Podium mini" (rencana 3.7.0, MINOR)

Pemilik: tech-lead. Daftar task sebelumnya (Poster podium PP-n, selesai, rilis 3.6.0) ada di riwayat git:
`git show 3a95d55:docs/tasks.md`.

## Serah terima (2026-11-13) — fase desain selesai, fase kode belum mulai

- **Keputusan host:** PRD §10 keputusan 76–88 (76–85 di-commit, 86–88 di commit serah terima ini).
- **Hi-fi final:** commit 3a95d55, artifact v87. Frame: 11b, 11e–11m (11m baru: >4 di #1 dan belum ada match), 13s–13w.
  Komponen → panel `.lk` (rumus kepadatan 80, tabel ukuran, kolom 81, podium mini, `.lclub`).
  `tokens.json` → `posterLengkap`. `design/spec/screens/11-bagikan.md` + `13-sparing.md` sudah di-generate ulang.
  `test/hifi/components/share_poster_data.dart` juga sudah di-generate ulang, termasuk poster '11m'.
- **Eksplorasi:** `design/explore/bagikan-lengkap.html`, arah B = LB1–LB13.
- **Belum diperbarui, jadi tugas tech-lead di awal fase kode:**
  - teks PRD §5.9: masih menulis ambang baris lama dan "Story selalu satu kolom";
  - `design/spec/logic.md` §9 dan §16.3: masih ambang lama dan keputusan 70;
  - `docs/ui-v2.md` bagian Bagikan.
- **Golden:** golden 11b, 11e–11l, 13s–13w dan poster SharePoster saat ini gagal sampai kode menyusul. Ini wajar.
- **Versi:** 3.6.1 (0336826) belum di-push. Rilis berikutnya 3.7.0 (MINOR). Kalau 3.6.1 belum di-push, ikut dalam
  rilis itu.

## Langkah berikutnya (sesi baru)

1. Spawn `tech-lead` (opus/high): spec di `logic.md` (§16 baru untuk Lengkap atau §17) dan task PL-n di file ini.
   Isinya: painter podium mini, memakai ulang `PodiumScenePainter` dan `services/share/podium.dart`, jangan menyalin;
   panel `.lk`; kepadatan; kolom; sparing `.lclub`; deret 11 tema di tab Lengkap; golden.
   Batas ~150k context.
2. Engineer dikelompokkan per batch (sonnet/medium, atau opus kalau ditandai), di branch `poster-lengkap`, bukan
   `main`.
3. Reviewer `tech-lead` baru hanya untuk logika/painter. Layar dicek main session.
