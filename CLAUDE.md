# Match Addict (dulu Mabar) — konteks proyek

App Flutter untuk host turnamen mabar tennis/padel (klub, 4–30 pemain, 1 device host, offline).

**Nama app = Match Addict** sejak 3.0.0 (keputusan host 2026-11-02): wordmark "Match Addict" (bukan huruf kecil), label
ikon, judul web, repo `asepsugi/match-addict`, web `asepsugi.github.io/match-addict/`, bundle id `id.matchaddict.app`,
paket Dart `match_addict`. Yang sengaja **tetap** "mabar": nama kelas/berkas internal (`MabarColors`, `MabarButton`,
`mabar_ball.dart`, `window.mabarInstall`, …), box Hive `tournament`, worker relay `mabar-live` (URL relay tidak berubah),
dan kata "mabar" sebagai istilah (main bareng) di teks maupun contoh nama turnamen ("Mabar Jumat PB Garuda").

**Sumber kebenaran, baca sebelum mengubah UI/logika:**
- `PRD.md` — produk, algoritma, aturan skor & ranking; sejalan dengan hi-fi v2 (diselaraskan 2026-10-22); §13
  Sparing disetujui host 2026-11-04 (keputusan 19–20), hi-fi 13a–13w, 14a–14y, 15a–15y; §14
  Mexicano (keputusan 23–47, 2026-11-11…12), hi-fi 03a–03q, 16a–16g; §15 Tukar pemain Mixed (keputusan 48–59,
  2026-11-12), hi-fi 17a–17r; §5.9 Poster podium Bagikan (keputusan 60–74, 2026-11-12…13), hi-fi 18a–18t.
- `design/hifi.html` — **hi-fi v2 final** (disetujui host 2026-10-21): Fondasi, Komponen, 247 frame layar 390×844 +
  12 lembar gambar (per 2026-11-12) + catatan perilaku, Cakupan. Acuan visual dan perilaku untuk semua pekerjaan UI. File ±1,1 MB (per
  2026-11-12): **jangan dibaca utuh**, baca per bagian (`<section class="flow" id="beranda">`, dst.); untuk satu layar
  lebih ringkas baca `design/spec/screens/<alur>.md` + PNG frame-nya.
- `design/spec/` — paket implementasi v2. **Mulai dari `design/spec/README.md`** (urutan kerja, aturan golden), lalu
  `tokens.json`, `components.md`, `logic.md` (aturan logika yang berubah + data test), `screens/*.md` (per alur).

## Aturan setiap perubahan

- Keputusan host yang mengubah perilaku: perbarui PRD + hi-fi (`design/hifi.html` dan artifact online
  `H9ZVDUfYvEBXsoBqih4iov`, publish file yang sama) dalam perubahan yang sama. Hi-fi diubah hanya untuk keputusan host,
  bukan untuk menyamakan kode; catat di hi-fi → Cakupan → "Sudah disetujui" (alur render ulang: `docs/ui-v2.md`).
- Semua keputusan redesain v2 sudah disetujui host; daftar lengkapnya di hi-fi → Cakupan. Jangan buka ulang.
- Frame yang bertentangan dengan catatannya: berhenti dan tanya host, jangan memilih sendiri.
- Jangan klaim layar sudah sesuai tanpa golden lolos (`expectMatchesHifi`, `docs/ui-v2.md`).
- Logika domain hanya di `lib/services/**` (wajib test), tidak diduplikasi di widget.
- **Jangan** menambah pemanggilan `saveActive` manual di mutator baru, dan **jangan** memanggil kirim live manual: semua
  mutasi berakhir di `state =`, auto-save dan live ikut dari situ.
- Format: `dart format` memakai lebar 120 dari `analysis_options.yaml`. Kode lama belum seluruhnya terformat, jadi format
  hanya file baru atau hunk sendiri, jangan seluruh repo/file lama (bikin diff liar dan bentrok antar branch).
- Konvensi: komentar seperlunya dan dalam bahasa Indonesia, menjelaskan *kenapa*. Nama komponen merujuk kelas CSS
  mockup (mis. `// .info` / `.share-card`) supaya mudah dicocokkan; untuk kode desain v2 pakai kelas di
  `design/hifi.html` (mis. `// .bug`, `.rest`) dan nama widget di `design/spec/components.md`.
- **Wording UI** (direview host 2026-10-20, sengaja menyimpang dari mockup): istilah olahraga tetap Inggris (court,
  round, match, set, WO, Win %, Total Point), istilah teknis diganti (generate → buat, device → HP,
  Ranking/Share/Home → Klasemen/Bagikan/Beranda — layar Peringkat jadi "Klasemen" 2026-10-22, posisi pemain tetap
  "Peringkat n" di Detail, "Endless" tidak muncul lagi di UI). Dipertahankan atas permintaan host: "Aturan Fairness",
  "Selisih match antar pemain ≤ 1", label Estimasi (Max Round · Match/Pemain · Court Aktif · Total Match),
  "→ Prioritas main di R…". Pakai "duplikat" (bukan "dobel") dan "diprioritaskan" (bukan "didahulukan"). Di desain v2
  (keputusan host 2026-10-21) frasa itu menjadi judul "Istirahat · Prioritas main di R…", dan "peserta" tidak dipakai
  lagi: semua orang disebut "pemain" (layar Pemain, Kelola pemain, Ubah pemain).

## Skill & tools

| Peran | Skill / MCP | Kapan |
|---|---|---|
| — | Belum ada skill/MCP eksternal yang dipakai proyek ini | — |

## Arsitektur

- `lib/models/models.dart` — seluruh model domain, immutable. Termasuk `ActiveTournament` (turnamen + bye/resting per
  round); dia ada di sini, bukan di controller, supaya `services/storage/` bisa menyerialisasinya tanpa services
  meng-import features.
- `lib/services/**` — logika murni Dart, **wajib ada test**; tidak boleh diduplikasi di widget.
- `lib/features/<screen>/` — satu folder per layar. `lib/core/theme/` — fondasi v2; `lib/core/widgets/` — komponen v2
  lintas layar.
- `lib/core/widgets/court_painter.dart` + `mabar_ball.dart` — lapangan + bola brand. Dipakai banner Beranda **dan**
  generator icon aplikasi; jangan bikin salinan kedua.
- `relay/` — relay live score (Cloudflare Worker + Durable Object, JavaScript), di luar app Flutter.
- State turnamen: Riverpod `tournamentProvider` (`features/schedule/tournament_controller.dart`) — satu-satunya sumber
  kebenaran sejak layar jadwal. Sebelum itu data dioper lewat `extra` router.
- Mesin per engine, provider, dan invariant: `docs/architecture.md`.

## Versioning app (PRD §12)

Semver `MAJOR.MINOR.PATCH+BUILD` di `pubspec.yaml`; `lib/core/app_version.dart` (`appVersion`) = `MAJOR.MINOR.PATCH`
(dijaga test) dan ikut tertulis di tiap simpanan turnamen. **Setiap perubahan dikategorikan:** MAJOR = perubahan besar
logika/desain atau data lama tidak kompatibel (`schemaVersion` naik → selalu MAJOR); MINOR = fitur/perilaku baru yang
kompatibel; PATCH = perbaikan bug/teks/visual kecil tanpa mengubah perilaku yang disepakati. Versi + `appVersion`
dinaikkan di commit yang membawa perubahan ke `main` (tiap push = deploy web), kategori tertinggi yang menang, `BUILD`
naik tiap rilis. Sebut kategorinya di pesan commit/PR (`[minor]`). Riwayat: branch `redesain-v2-spec` = 2.0.0 (MAJOR:
redesain + format skor + data app lama tidak dimuat); 2.2.0 Kelola court; 2.3.0 nama turnamen; 2.4.0 batas 30 pemain;
2.5.0 live score; 2.6.0 nama lengkap di baris match, Akhiri di Beranda, back PWA; 2.7.0 pemain telat Mixed menyusul
(kredit dihapus); 2.8.0 Best of/Americano berhenti lebih awal (semuanya MINOR); 3.0.0 (MAJOR) = nama Match Addict +
pindah alamat web, peringkat dari nilai metode + selisih (peringkat lama berbeda); 3.1.0 (MINOR) = round tambahan Fixed
+ atur ulang pasangan; 3.2.0 (MINOR) = Sparing (dua klub, Fixed & Mixed) + versi app di Beranda; 3.3.0 (MINOR) = default metode
Klasemen ikut format skor (Race to/Best of → Win %, Americano → Total Point); 3.3.1 (PATCH) = back di Jadwal ke Beranda;
3.3.2 (PATCH) = temuan security #1/#4 (simpanan tak terbaca dilewati, batas `roundNumber`); 3.4.0 (MINOR) = Mexicano +
Konfigurasi diringkas (pengaturan terakhir per olahraga); 3.5.0 (MINOR) = tukar pemain Mixed (ikon di baris match); 3.6.0 (MINOR) = poster podium Bagikan Ringkas.

## Status

Seluruh MVP PRD jalan. Alur penuh: Home → Peserta → Konfigurasi → Pasangan (Fixed) / langsung (Mixed) → Jadwal 6a/6b →
Input Skor + sheet WO → Peringkat → Detail Pemain → Share. Fixed setelah round-robin: Tambah round (+ Atur pasangan).
Logika, provider, persistensi, dan platform di `docs/` berlaku; tampilan mengikuti hi-fi v2.
- Redesain v2: langkah 1–5 (fondasi, logika, komponen, painter lapangan, semua layar 01–11) selesai, golden per frame
  di `test/hifi/` — `docs/ui-v2.md`.
- Format skor Race to / Best of / Americano + berhenti lebih awal, WO per format — `docs/architecture.md`.
- Klasemen Win % / Total Point (default ikut format skor, keputusan 21), nomor rapat dari nilai metode + selisih —
  `docs/architecture.md`.
- Mixed: prioritas main, pemain telat menyusul, Kelola pemain, Batalkan round, Kelola court — `docs/architecture.md`.
- Fixed: round tambahan + atur ulang pasangan — `docs/architecture.md`.
- Nama turnamen, Bagikan (poster gambar + caption) — `docs/architecture.md`, `docs/ui-v2.md`.
- Persistensi lokal, resume, Lanjutkan turnamen (Mixed) — `docs/data.md`.
- Live score (relay tanpa database) — `docs/live.md`.
- Android/iOS/web, PWA offline, deploy GitHub Pages — `docs/infra.md`. Release Android masih debug key.
- Sparing 3.2.0 (2 klub, partner sesama klub, lawan klub lain; Fixed & Mixed) — PRD §13, `docs/architecture.md` →
  Sparing, `docs/data.md` → Sparing. Rilis 3.2.0+14 live 2026-11-11 (564ea67). 3.3.0–3.3.2 sudah di `main` dan live (8af509b).
- Mexicano + Konfigurasi diringkas 3.4.0 (MINOR): rilis 3.4.0+18 live 2026-11-12 (61bbaba): PRD §14 + keputusan 23–47, hi-fi
  03a–03q dan 16a–16g (artifact v77), spec `design/spec/logic.md` §14, task MX-n/KF-n di `docs/tasks.md`; kode selesai. Semua usulan PM disetujui (keputusan 44–47).
- Tukar pemain Mixed 3.5.0 (MINOR): PRD §15 + keputusan 48–59, hi-fi 17a–17r (ikon di kolom bola baris match), spec
  `logic.md` §15, task TP-n; rilis 3.5.0+19 live 2026-11-12 (dcff87f).
- Poster podium Bagikan 3.6.0 (MINOR), branch `poster-podium`: Ringkas = ilustrasi podium sudut lapangan, PRD §5.9 +
  keputusan 60–74, hi-fi 11a/11c/11d/13q/13r + 18a–18t (artifact v85), spec `logic.md` §16, task PP-n. Kode + golden
  selesai (3.6.0+20), belum di-merge ke `main`; sisa QA Chrome + uji share di HP. Eksplorasi A/B/C: `design/explore/`.

## Area docs

| File | Baca kalau… | Pemilik |
|---|---|---|
| `docs/architecture.md` | mengubah `lib/services/**`, model, provider, aturan jadwal/skor/ranking | tech-lead |
| `docs/ui-v2.md` | mengubah layar, komponen, tema, painter, poster, golden, atau render ulang frame | tech-lead |
| `docs/data.md` | mengubah simpanan/codec, `schemaVersion`, resume, Lanjutkan turnamen, slot aktif | dba |
| `docs/live.md` | menyentuh live score: `relay/`, `services/live/`, `features/live/` | tech-lead (deploy relay: tech-infra) |
| `docs/infra.md` | platform, build web, service worker, deploy, ikon app, toolchain | tech-infra |
| `docs/security.md` | menyentuh decode simpanan/payload, live/relay, atau menambah dependensi | security (ditulis main session) |
| `docs/tasks.md` | mengerjakan atau mereview task fitur (sekarang: Poster podium PP-n) | tech-lead |

## Pitfalls (lintas area)

- Semua turunan waktu (`canGenerateNextRound`, `isFinal`, `capacityAhead`, …) menerima `now` dari `clockProvider`: test
  wajib meng-override jam, kalau tidak hasilnya ikut tanggal mesin.
- `startIfNeeded` membandingkan config dengan `identical` (`docs/data.md`): oper config apa adanya (resume, golden),
  kalau disalin jadwalnya diregenerate. Config yang memang disalin wajib lewat `copyWith` supaya `format` tidak hilang.
- Nomor peringkat selalu dari `standingEntriesProvider` / `StandingEntry.position`, jangan menomori dengan indeks.
- Render di `flutter test` memakai font Ahem kecuali `loadHifiFonts()` + `MabarTheme.light()`: jangan menilai tata
  letak dari render tanpa itu.
- Kode web (`.toJS`, `web/index.html`, back browser, service worker) tidak teruji `flutter test`: cek dengan
  `tool/build_web.sh` + Chrome (`docs/infra.md`).
