# Task — Sparing 3.2.0

Pemilik: tech-lead. Sumber: PRD §13 (K1–K12) + keputusan 20, `design/spec/logic.md` §13 (aturan + data test),
`design/spec/screens/13-sparing.md`, `14-sparing-fixed.md`, `01-beranda.md`, `02-pemain.md`, `components.md`.
Urutan ringkas juga di `design/spec/README.md` langkah 6.

Aturan untuk semua task:
- Kerja di branch `sparing` (worktree per task boleh), **bukan** `main`: tiap push ke `main` = deploy, dan alur Mixed
  sparing baru lengkap setelah SP-18. Rilis 3.2.0 = satu merge (SP-19).
- Turnamen biasa tidak berubah: semua test dan golden yang ada tetap lolos tanpa diubah (AC-S19), kecuali golden
  frame yang memang diubah hi-fi 3.2.0 (01a–01i, 02a–02c). Catatan: di `main` sekarang 02b dan 02c sudah merah karena
  frame-nya baru (pilihan Mabar / Sparing); SP-8 yang menghijaukannya.
- Logika hanya di `lib/services/**` / model, dengan test; widget tidak menghitung skor klub, slot, atau nomor.
- Data test = angka di `logic.md` §13.11 (= PRD = frame). Nama test memakai ID AC (`AC-S5 …`) dan id frame golden.
- Golden: `test/hifi/screens/sparing_<alur>_test.dart`, data persis frame, `clockProvider` di-override. Teks kecil yang
  lolos toleransi 2% walau salah (versi app, angka skor klub, hitung mundur) dicek juga dengan `find.text`.
- Fixture bersama `test/hifi/screens/sparing_fixture.dart` (Fixed) dibuat SP-5, `sparing_mixed_fixture.dart` (Mixed)
  dibuat SP-18a. Task layar menambah varian di file test-nya sendiri, tidak mengubah fixture bersama (supaya task
  paralel tidak bentrok).
- Kategori semua task: MINOR (bagian dari 3.2.0); versi baru dinaikkan di SP-19 saja.
- **Model**: "kuat" = fondasi/algoritma/lintas modul; sisanya engineer default.

## Peta urutan

| Gelombang | Task (paralel di dalam gelombang kecuali ditulis) |
|---|---|
| 0–2 (selesai) | SP-0, SP-1, SP-2, SP-3, SP-4, SP-5, SP-6, SP-7, SP-8 |
| 3 | selesai: SP-9…SP-14, SP-17 · berjalan: SP-16 · menunggu frame poster: SP-15 |
| 4 — sekarang | SP-18a (fondasi Mixed, kuat), SP-18b (Atur turnamen) |
| 5 | setelah SP-18a: SP-18c, SP-18f, SP-18g, SP-18h; SP-18d dan SP-18e mulai bersamaan, golden + merge setelah SP-18c |
| 6 | SP-19 (setelah semua, termasuk SP-15 dan SP-16) |

Bentrok berkas yang diketahui:
- Selesai: SP-3/SP-5 (`tournament_controller.dart`, `models.dart`), SP-11/SP-16 (berurutan), SP-17 setelah SP-7.
- SP-18a ↔ SP-16: `models.dart` (`ActiveTournament`, method berbeda; SP-16 mungkin menambah helper `roundsLeft` dekat
  `capacityAhead`) dan `schedule_fixed_screen.dart` (SP-18a hanya `_restingByClub`). Boleh paralel di worktree; yang
  selesai belakangan rebase. Kalau SP-16 sudah siap merge, gabungkan SP-16 dulu.
- SP-18e ↔ SP-16: `widgets/extend_sheet_parts.dart` (Lanjutkan dan Tambah round) — SP-18e tidak mengubahnya; kalau
  ternyata perlu, tunggu SP-16 di-merge.
- SP-18c/18d/18e sama-sama di `features/schedule/`, berkas terpisah: hanya SP-18c yang mengubah
  `schedule_mixed_screen.dart`; SP-18d hanya `mixed/manage_players_sheet.dart`; SP-18e hanya `mixed/manage_courts_sheet.dart`,
  `mixed/resume_tournament_sheet.dart`, `mixed/mixed_guide_sheet.dart`. `resting_list.dart`, `models.dart`, dan
  `sparing_mixed_fixture.dart` hanya diubah SP-18a.
- Urutan merge SP-18: SP-18a → SP-18c → SP-18d/18e/18f/18g/18h bebas; SP-18b kapan saja (sebaiknya setelah SP-18c).

---

## SP-0 · Finalkan bentuk simpanan sparing (DBA)
- **Status:** selesai (cbb964f, dc90462).
- **Goal:** memfinalkan draf `logic.md` §13.10 dan menuliskannya di `docs/data.md`.
- **Baca:** `logic.md` §13.1 + §13.10, `docs/data.md`, `lib/services/storage/tournament_codec.dart`, PRD §13.8.
- **Ubah:** `docs/data.md` (bagian Sparing), koreksi §13.10 kalau ada yang diubah.
- **Acceptance:** keputusan tertulis untuk `config.clubs`, `players[].club`, `restingPairs`, pemakaian ulang
  `extraPutaran`, perlakuan payload sparing yang tidak lengkap, dan risiko app 3.1.0 ter-cache. `schemaVersion` tetap 2.
- **Dependensi:** tidak ada. **Paralel:** ya. **Model:** DBA.

## SP-1 · Model + codec sparing — kuat
- **Status:** selesai, di-approve (f2e1392 + 94f1f7f di `sparing`).
- **Goal:** `Club`, `TournamentConfig.clubs` / `isSparing`, `Player.clubId`, `ActiveTournament.restingPairIdsByRound`,
  helper klub (pemain/pasangan/klub per id, pemain aktif per klub), dan codec sesuai SP-0.
- **Baca:** `logic.md` §13.1, §13.10; `docs/data.md`; `lib/models/models.dart`; `tournament_codec.dart`.
- **Ubah:** `lib/models/models.dart`, `lib/services/storage/tournament_codec.dart`; `copyWith` config/pemain
  membawa klub (Pitfall `copyWith`).
- **Acceptance:** AC-S19 (simpanan 3.1.0 = turnamen biasa, semua test lama lolos tanpa diubah), AC-S20 (sparing
  encode → decode identik: klub, anggota, istirahat per round, `extraPutaran`), payload sparing yang rusak → null.
- **Test:** `test/services/sparing_codec_test.dart`: data 13A setelah R3 + R6 diakhiri; simpanan 3.1.0 dari test
  codec yang ada; pemain pengganti dengan klub.
- **Dependensi:** SP-0. **Paralel:** dengan SP-2, SP-6, SP-7. **Model:** kuat (semua task membangun di atasnya).

## SP-2 · Generator Fixed sparing — kuat
- **Status:** selesai, di-approve (2680bbd + 918f881 di `sparing`, 2026-11-08).
- **Goal:** `lib/services/schedule/sparing_fixed_generator.dart`: `generate`, `extend`, `extraRounds`, `activeCourts`,
  `unitMatches`, dan estimasi Konfigurasi K10 (round, match, court aktif, menit lewat booking).
- **API jadi (dipakai SP-5/SP-9/SP-16):** `extraRounds(active, now, {required club1, required club2, extraMinutes})`
  dengan daftar pasangan per klub yang **urutannya = indeks generator** (urutan `config.fixedPairs`), hasil
  `{schedule, units, perPair: (club1, club2), fitRounds, roundsLeft, overMinutes}`. `estimate` mengembalikan angka
  `(rounds, matches, activeCourts, overMinutes)`; teks "Lanjut · …" dirangkai layar. `unitMatches(p1, 0) == 0`.
- **Baca:** `logic.md` §13.2–13.4; prototipe (sudah dihapus, `git show 13646f4:tool/sparing_proto/…`)
  `lib/sparing_fixed.dart` + `test/fixed_property_test.dart`, `test/examples_test.dart`, `test/frames_test.dart`;
  `round_robin_generator.dart` (`extend`, `_Packer`).
- **Ubah:** file generator baru; `test/services/sparing_fixed_test.dart` (port test properti + contoh). Input generator
  hanya daftar pasangan per klub + court, jadi tidak menunggu SP-1.
- **Acceptance:** AC-S5, AC-S6, AC-S7a (estimasi), AC-S18; tabel 13.11 persis (13A, 8/4, round tambahan R7–R12).
  Test properti §13.12 Fixed (jadwal awal 2250 ukuran + 8 tambahan berantai) lulus.
- **Dependensi:** tidak ada. **Paralel:** ya. **Model:** kuat (algoritma; jebakan `K mod g` di §13.2).
- **Penutup:** selesai — `tool/sparing_proto/` dan exclude-nya dihapus bersama SP-3.

## SP-3 · Mixed sparing per klub (`C'` lintas modul) — kuat
- **Status:** selesai, di-approve (804ad7f + 7364841 di `sparing`, 2026-11-08). API untuk SP-9/SP-18:
  `EndlessRoundGenerator.generateSparingRound`, `restingByClubAfterLastRound`, `sparingEstimate`;
  `ActiveTournament.sparingActiveCourts`, `activePlayersByClub`, `canWithdraw`; `addPlayer(name, clubId:)`.
- **Goal:** semua aturan `logic.md` §13.6 di service/model: satu fungsi court aktif sparing yang menggantikan
  `slotsFor` di `generateRound`, `_nextRoundSlots`/`restingAfterLastRound` (hasil per klub), `courtUse`/`courtMatch`
  (2 + 2), `capacityAhead.matchesPerRound`; `priorityOrder` per klub; susunan pasangan sesama klub; Kelola pemain
  (tambah wajib klub, Keluarkan mati kalau klub tinggal 2, Kembalikan ke klubnya); estimasi Mixed sparing sebagai
  fungsi murni untuk Konfigurasi dan sheet Cara kerja.
- **Baca:** `logic.md` §5, §5a, §6, §10, §13.6; `endless_round_generator.dart`; `ActiveTournament.capacityAhead`,
  `latePlayerIds`; `TournamentController` (`generateNextRound`, `addPlayer`, `withdrawPlayer`, `reinstatePlayer`,
  `_placeCourt`); prototipe (sudah dihapus, `git show 13646f4:tool/sparing_proto/…`) `lib/sparing_mixed.dart`,
  `test/mixed_*_test.dart`.
- **Ubah:** `endless_round_generator.dart`, `models.dart` (ActiveTournament), `tournament_controller.dart` (cabang
  sparing di method di atas), test baru `test/services/sparing_mixed_test.dart`.
- **Acceptance:** AC-S8, AC-S9, AC-S10, AC-S11, AC-S12, AC-S13; contoh Oki/Nanda §13.11; tabel 8 round PRD 13.4.
  Turnamen biasa: `mixed_priority_test`, `mixed_roster_test`, `court_manage_test`, `court_availability_test`,
  `resume_tournament_test` lulus tanpa diubah.
- **Simpanan (review SP-1):** setiap mutator sparing (`addPlayer` dengan klub, Kembalikan, pasangan per round) wajib
  menjaga S1/S2/S4; tiap test mutator sparing memeriksa `TournamentCodec.decode(encode(state)) != null`. `addPlayer`
  (`tournament_controller.dart:126`) sekarang membuat `Player` tanpa `clubId`: itu harus diisi.
- **Test properti:** §13.12 Mixed. Versi ringkas di suite biasa; sweep penuh bertag `slow` (±11–17 menit,
  `flutter test --tags slow --run-skipped`).
- **Dependensi:** SP-1. **Paralel:** dengan SP-4, SP-5 (lihat bentrok), SP-8. **Model:** kuat (lintas modul).
- **Penutup:** selesai — `tool/sparing_proto/` + exclude-nya dihapus.

## SP-4 · Skor klub + klasemen per klub
- **Status:** selesai, di-approve (51b84a5 + 9b35c1b di `sparing`, 2026-11-08). Sisa untuk QA: helper `mixed()` di
  `sparing_score_test.dart:293-294` memberi skor tidak sah untuk Americano 21 (7–3) dan menaruh Matcha di `pair1` (langgar
  S4); hitungannya tetap benar, tapi datanya sebaiknya disamakan dengan frame.
- **Goal:** fungsi murni skor klub (`logic.md` §13.7: `halfWins`, Total Point klub, selisih, unggul/Seri, nilai WO
  klub K11) dan klasemen per klub (§13.8) + provider di file baru (mis.
  `lib/features/schedule/sparing_providers.dart`: skor klub, baris klasemen per klub, nomor per klub).
- **Baca:** `logic.md` §4, §13.7, §13.8, §13.11; `ranking_calculator.dart`; provider di `tournament_controller.dart`.
- **Ubah:** `lib/services/ranking/club_score.dart` (baru), helper per klub di `ranking_calculator.dart` kalau perlu
  (tanpa mengubah perilaku biasa), file provider baru; `test/services/sparing_score_test.dart`.
- **Acceptance:** AC-S14, AC-S15, AC-S15a, AC-S16, AC-S17 (data 13C + 13n setelah R5 + 14s/14t/14u persis §13.11);
  skor sama + Total Point beda → klub Total Point lebih besar unggul; semua sama → Seri.
- **Dependensi:** SP-1. **Paralel:** ya (file baru). **Model:** default.

## SP-5 · Controller Fixed sparing, pasangan per klub, fixture golden — kuat
- **Status:** selesai, di-approve (e3750fb + 086f007 di `sparing`, 2026-11-08).
- **Goal:** `startIfNeeded` sparing (SP-2 generator, `restingPairIdsByRound`), `addRounds` sparing (satuan,
  `extraPutaran`, Atur pasangan per klub dengan pemain baru berklub), `PairGenerator` acak per klub + manual sesama klub
  (layanan yang dipakai Pasangan), `PairDraft` per klub (pengganti mengisi slot, unik terhadap kedua klub, "minimal 1
  pasangan tiap klub"), dan fixture golden bersama.
- **Baca:** `logic.md` §12, §13.1–13.5; `tournament_controller.dart` (`startIfNeeded`, `addRounds`); `pair_generator.dart`,
  `pair_draft.dart`; `test/services/fixed_add_rounds_test.dart`; `test/hifi/screens/fixed_extra_fixture.dart`.
- **Ubah:** `tournament_controller.dart`, `pair_generator.dart`, `pair_draft.dart`; test
  `test/services/sparing_fixed_flow_test.dart`; fixture `test/hifi/screens/sparing_fixture.dart` (13A: R3 berjalan,
  setelah R5, R6 terisi, diakhiri di R6; 8/4 di 3 court; skor 14s/14t/14u; setelah Atur pasangan 14o/14p dengan Gilang
  dan Oki).
- **Simpanan (review SP-1):** `PairDraft.add` (`pair_draft.dart:98`) membuat `Player` tanpa `clubId`: pemain
  pengganti sparing wajib berklub. Tiap test mutator sparing memeriksa `decode(encode(state)) != null`.
- **Acceptance:** AC-S3, AC-S4, AC-S5, AC-S18; Fixed biasa (`fixed_extra_rounds_test`, `fixed_add_rounds_test`) tetap
  lulus; config `identical` tetap mencegah regenerate (Pitfall `startIfNeeded`).
- **Dependensi:** SP-1, SP-2. **Paralel:** dengan SP-3, SP-4, SP-8. **Model:** kuat (semua layar Fixed bergantung).

## SP-6 · Komponen `ClubScore` + `.clubscore` di extractor
- **Status:** selesai, di-approve (4814813 + d88d1b7 (adaptor ClubResult e340b4d) di `sparing`, 2026-11-08).
- **Goal:** tambah `('ClubScore', ['.clubscore'], …)` ke `COMPONENTS` di `tool/hifi_extract.py`, jalankan extractor
  supaya `components.md` dan `rects.json` memuat `.clubscore`, lalu widget `ClubScore` (angka sudah jadi: nama, Total
  Point · selisih + satuan, menang dengan "½", bola per baris) + golden per wilayah.
- **Baca:** `components.md` (catatan `.clubscore` di hi-fi → Komponen), `docs/ui-v2.md` (Hi-fi → frame, jangan
  `pgrep` loop), contoh golden komponen di `test/hifi/components/`.
- **Ubah:** `tool/hifi_extract.py`, hasil extractor di `design/` (frame/`screens`/`components.md`/`rects.json`),
  `lib/core/widgets/club_score.dart` (dipakai Jadwal dan Klasemen), `test/hifi/components/club_score_test.dart`.
- **Acceptance:** golden wilayah `.clubscore` di 13k (unggul klub pertama), 14s (klub kedua), 14t (Seri, bola dua),
  14u ("6½ – 5½", poin), 14m (0 – 0 tanpa bola).
- **Koordinasi:** extractor menulis ulang `design/` — jalankan hanya saat designer tidak sedang mengubah `hifi.html`
  (minta izin main session); frame yang berubah tanpa alasan = noise, jalankan ulang.
- **Dependensi:** tidak ada (widget menerima nilai jadi). **Paralel:** ya. **Model:** default.

## SP-7 · Versi app di Beranda (keputusan 20)
- **Status:** selesai, di-approve (22a5f59 + 34f11c8 di `sparing`).
- **Goal:** "v{appVersion}" di kanan atas banner, semua kondisi Beranda.
- **Baca:** `screens/01-beranda.md` (catatan 01a), `court_banner.dart`, `home_screen.dart`, `test/hifi/screens/` Beranda.
- **Ubah:** `features/home/widgets/court_banner.dart` (atau panel, ikut hi-fi), test Beranda.
- **Acceptance:** golden 01a–01f, 01h, 01i lolos + `find.text('v$appVersion')`; 01g/01j tanpa versi; tidak bisa diketuk.
- **Dependensi:** tidak ada. **Paralel:** ya. **Model:** default.

## SP-8 · Layar Pemain: Mabar / Sparing
- **Status:** selesai, di-approve (f6a31da + e61f4c5 di `sparing`, 2026-11-08).
- **Goal:** pilihan Mabar / Sparing, dua blok klub (nama klub + kotak nama + daftar), validasi K6/K8, isi tiap pilihan
  disimpan selama layar terbuka, kirim olahraga + dua klub + anggotanya ke Atur turnamen.
- **Baca:** `screens/02-pemain.md`, `13-sparing.md` 13a–13g, `player_name_parser.dart`, `setup_peserta_screen.dart`.
- **Ubah:** `features/setup_peserta/**`, aturan validasi sparing sebagai fungsi murni di `services/pairing/`
  (mis. `club_roster.dart`, dengan test), router extra.
- **Acceptance:** AC-S1, AC-S2; golden 02a, 02b, 02c (sekarang merah di `main`), 13a–13g; pesan "Andi, Budi, Citra +2
  ada di dua klub"; nama klub maks 20, dipangkas.
- **Dependensi:** SP-1. **Paralel:** ya. **Model:** default.

## SP-9 · Atur turnamen sparing
- **Status:** selesai, di-approve (f08e2d5 + ee6ac20 (bagian Fixed; Mixed 13i/13j di SP-18b) di `sparing`, 2026-11-08).
- **Goal:** subjudul "olahraga · klub1 n · klub2 n"; estimasi tombol Fixed sparing K10 (dari SP-2) dan Mixed sparing
  (dari SP-3); config yang dibuat membawa klub.
- **Baca:** `screens/13-sparing.md` 13h–13j, `14-sparing-fixed.md` 14f–14g, `logic.md` §13.4, §13.6,
  `konfigurasi_screen.dart`.
- **Ubah:** `features/konfigurasi/**`.
- **Acceptance:** AC-S7a, AC-S10 (estimasi); golden 13h, 14f, 14g; 13i, 13j setelah SP-3.
- **Dependensi:** SP-2, SP-5 (navigasi ke Pasangan), SP-3 untuk 13i/13j (→ SP-18b). **Paralel:** ya. **Model:** default.

## SP-10 · Pasangan sparing
- **Status:** selesai, di-approve (86924cc + 538b526 di `sparing`, 2026-11-08).
- **Goal:** daftar pasangan per klub, Acak ulang satu, Manual sesama klub, sisa ganjil per klub menahan Buat jadwal,
  dialog 14d.
- **Baca:** `14-sparing-fixed.md` 14a–14e, `pair_setup_screen.dart`, `logic.md` §13.5.
- **Ubah:** `features/pair_setup/**`.
- **Acceptance:** AC-S3, AC-S4; golden 14a–14e (acak berskrip lewat `PairSetupScreen.random` supaya = G1–G4/M1–M3).
- **Dependensi:** SP-5. **Paralel:** ya. **Model:** default.

- **Catatan review SP-5:** pakai `PairGenerator.randomByClub(…, random: widget.random)` (urutan per klub = 14a) dan
  `PairGenerator.manual` / `PairDraft.canPair`, jangan menyusun `Pair(id: …)` sendiri seperti `pair_setup_screen.dart:64`.
  Mengetuk chip klub lain memindah pilihan (cek `canPair` dulu), tidak membentuk pasangan.
## SP-11 · Jadwal Fixed sparing
- **Status:** selesai, di-approve (aaa679a di `sparing`, 2026-11-08).
- **Goal:** `ClubScore` di atas daftar (ikut tergulir), Istirahat dua kolom per klub (`.rest .names.clubs`, "–"
  kalau kosong), court tidak aktif tidak tampil, sisanya sama dengan Jadwal Fixed; mode penonton Live ikut.
- **Baca:** `13-sparing.md` 13k–13l, `14-sparing-fixed.md` 14h–14m, `components.md` (`.rest`), `schedule_fixed_screen.dart`,
  `features/schedule/widgets/resting_list.dart`.
- **Ubah:** `schedule_fixed_screen.dart`, `RestingList` (varian klub), test layar.
- **Acceptance:** AC-S6 (Court 3 tidak tampil), AC-S7 (sisi atas = klub pertama), AC-S14 (6 – 4 / 7 – 5); golden 13k,
  13l, 14h, 14i, 14j, 14k, 14l, 14m; hitung mundur 00:45 dengan `find.text`; penonton Live: skor klub tampil, tanpa ⋯.
- **Dependensi:** SP-4, SP-5, SP-6. **Paralel:** ya. **Model:** default.

- **Catatan review SP-6:** widget `ClubScore`/`ClubScoreRow` (lib/core/widgets) menerima string jadi. Adaptor sudah ada
  di `ClubResult` (commit setelah d88d1b7): `detailLabel(t)` ("56 game · +13") dan `leads(t)` (unggul/seri, tanpa bola
  sebelum ada hasil), dengan test. Jadwal, Klasemen,
  Beranda, poster, dan Live memakai adaptor yang sama; jangan merangkai di tiap layar. Data skor klub = `ClubResult`
  (dulu `ClubScore`, diganti 1d04930 supaya tidak bentrok dengan widget).
## SP-12 · Input Skor + WO sparing
- **Status:** selesai, di-approve (c7e7e4a di `sparing`, 2026-11-08).
- **Goal:** pastikan papan dan sheet WO mengikuti S4 (klub pertama atas, urutan pilihan WO = papan) dan skor klub
  dihitung ulang setelah simpan.
- **Baca:** `14-sparing-fixed.md` 14q–14r, `score_input_screen.dart`, `walkover_sheet.dart`.
- **Ubah:** `features/score_input/**` hanya kalau perlu; test layar.
- **Acceptance:** AC-S7, AC-S15; golden 14q, 14r.
- **Dependensi:** SP-5. **Paralel:** ya. **Model:** default.

## SP-13 · Klasemen sparing
- **Status:** selesai, di-approve (2040a7e + 7866fb4 + 62311b3 di `sparing`, 2026-11-08). Garis app bar saat digulir
  berlaku juga untuk Klasemen biasa.
- **Goal:** `ClubScore` tetap di atas tab metode, tabel per klub bernomor sendiri, "Belum main" per klub, baris campuran
  setelah Atur pasangan, "1 match WO" di bawah tabel terakhir; Live penonton memakai angka yang sama.
- **Baca:** `13-sparing.md` 13n–13p, `14-sparing-fixed.md` 14p, 14s–14u, `leaderboard_screen.dart`, `logic.md` §13.8.
- **Ubah:** `features/leaderboard/**`.
- **Acceptance:** AC-S14, AC-S16, AC-S17; golden 13n, 13o (digulir), 13p (Win %), 14p, 14s, 14t, 14u.
- **Dependensi:** SP-4, SP-5, SP-6. **Paralel:** ya. **Model:** default.

## SP-14 · Detail sparing
- **Status:** selesai, di-approve (ff39fd2 di `sparing`, 2026-11-08).
- **Goal:** subjudul "Peringkat n · klub · …", tim sendiri di atas (K9), Beda lawan ÷ pemain klub lain.
- **Baca:** `14-sparing-fixed.md` 14v–14w, `detail_player_screen.dart`, `logic.md` §13.8.
- **Ubah:** `features/detail_player/**`.
- **Acceptance:** AC-S7 (Detail Maya), AC-S17; golden 14v, 14w.
- **Dependensi:** SP-4, SP-5. **Paralel:** ya. **Model:** default.

## SP-15 · Bagikan sparing: Ringkas + caption
- **Status:** selesai, di-approve (7222885 + cb3c0b7 di `sparing`, 2026-11-11). Saran review yang belum dikerjakan
  (opsional): test poster nama klub panjang, tanpa hasil "0 – 0", skor ½.
- **Goal:** `sharePosterData` sparing (`.pscore`, label `.pclub`, 3 teratas tiap klub, "+n pasangan lainnya"),
  `SharePoster` pratinjau Ringkas, caption 13q (termasuk Seri dan sparing bernama), Lengkap pratinjau per aturan
  `logic.md` §13.9.
- **Baca:** `13-sparing.md` 13q, `11-bagikan.md`, `share_content.dart`, `share_poster.dart`, `result_text_builder.dart`,
  `docs/ui-v2.md` Bagikan.
- **Ubah:** `features/share/**`, `services/share/result_text_builder.dart` (+ test).
- **Acceptance:** AC-S17 (nomor sama), K7; golden 13q; test caption = teks 13q persis; caption Seri "… 6–6 … · Seri ·
  Padel" dan "6½–5½".
- **Feed/Story/Lengkap:** host setuju (2026-11-07) designer menambah frame poster sparing Feed, Story, dan Lengkap,
  persis gaya poster yang ada (bukan rombak Bagikan). Frame 13r–13w **disetujui host 2026-11-08**; ukuran
  `.pscore`/`.pclub` per target dan aturan kepadatan dengan label klub ada di catatan frame (`13-sparing.md`).
- **Dependensi:** SP-4, SP-5. **Paralel:** ya. **Model:** default.

## SP-16 · Tambah round + Atur pasangan sparing
- **Status:** selesai, di-approve (2026-11-08).
- **Goal:** sheet Tambah round dengan ringkasan per klub (+3 / +4, satu baris kalau jumlah pasangan sama), baris
  "4 + 3 pasangan", "Buat R7–R12"; Atur pasangan satu bagian per klub.
- **Baca:** `14-sparing-fixed.md` 14n–14o, `logic.md` §12, §13.3, §13.5, `add_rounds_sheet.dart`,
  `extend_sheet_parts.dart`, `pair_edit_screen.dart`.
- **Ubah:** `features/schedule/fixed/**`, `features/pair_edit/**`.
- **Acceptance:** AC-S18; golden 14n, 14o; jam ditambah 1 jam di kedua court → tetap 1 satuan tanpa "lewat booking".
- **Catatan review SP-2:** "lewat booking" pakai `extraRounds(...).overMinutes`, jangan dihitung di sheet.
  `add_rounds_sheet.dart:92` menghitung "n court" dari `roundsLeft.where(k >= 1)` tanpa C': untuk sparing pakai
  `SparingFixedGenerator.activeCourts` (4 / 2 pasangan di 3 court = 2 court). Hitungan `roundsLeft` di generator sparing
  menyalin `round_robin_generator.dart:65-77, 102-105`; kalau task ini menyentuhnya, satukan ke satu helper (mis. di
  `ActiveTournament` dekat `capacityAhead`).
- **Dependensi:** SP-5, SP-11. **Paralel:** setelah SP-11. **Model:** default.

## SP-17 · Beranda sparing
- **Status:** selesai, di-approve (6b6b41d + 898e238 (14x/14y; 15w/15x/15y di SP-18h) di `sparing`, 2026-11-08).
- **Goal:** baris "PB Garuda 6 – 4 Matcha Club" (tanpa nama turnamen), dialog mulai baru 14y.
- **Baca:** `14-sparing-fixed.md` 14x–14y, `home_screen.dart`, `logic.md` §13.9.
- **Ubah:** `features/home/**`.
- **Acceptance:** golden 14x, 14y; "0 – 0" sebelum ada hasil. Sparing **bernama** 15w/15y dan turnamen terakhir Mixed
  sparing 15x pindah ke SP-18h.
- **Dependensi:** SP-4, SP-7. **Paralel:** ya. **Model:** default.

## SP-18 · Layar Mixed sparing (dipecah SP-18a…SP-18h)
Hi-fi Mixed **disetujui host 2026-11-07** (`design/spec/screens/15-sparing-mixed.md` 15a–15y, `13-sparing.md` 13i, 13j,
13m). Logikanya sudah ada di SP-3/SP-4 (`docs/architecture.md` → Sparing); task di bawah hanya layar, kecuali getter
kecil di SP-18a. **Bagikan Mixed (poster, caption) tetap di SP-15**, tidak di sini.

Aturan bersama SP-18:
- Data frame = fixture bersama `test/hifi/screens/sparing_mixed_fixture.dart` (SP-18a). Task lain menambah varian di
  file test-nya sendiri dan **tidak mengubah** fixture itu, `resting_list.dart`, atau `models.dart`; kalau butuh
  keadaan baru di model, laporkan ke tech-lead.
- Undian frame dipanggil dengan `seed: 0x5eed` (bukan FNV-1a id turnamen) dan `Random` per frame dari pembuka
  `15-sparing-mixed.md` (path prototipe di sana dibaca sebagai `generateSparingRound`, `courtUse`/`courtMatch`,
  `priorityOrder`). Layar memakai `drawSeed`, jadi fixture memakai id turnamen yang `drawSeed`-nya `0x5eed`.
- Golden sheet berlatar Jadwal Mixed sparing (15c, 15g, 15h, 15j, 15l, 15m, 15o) baru bisa lolos setelah SP-18c
  di-merge: task sheet boleh mulai bersamaan, tapi golden dan merge setelah SP-18c.
- Hanya `schedule_mixed_screen.dart` (SP-18c) yang mengubah layar Jadwal Mixed; tanda tangan `show…Sheet` tetap.
- Skor klub lewat adaptor `club_score_view.dart` (`clubScoreOf`, `clubScoreRowOf`) / `ClubResult`, nomor lewat
  `clubStandingEntriesProvider`; tidak merangkai atau menghitung di widget (catatan review SP-6).
- Turnamen biasa: golden 03*, 06*, 07*, 08*, 09*, 10*, 12* dan Fixed sparing 13k–14y tetap lolos tanpa diubah (AC-S19).

## SP-18a · Fondasi Mixed sparing: fixture bersama, istirahat per klub di model, `RestingList.clubs` — kuat
- **Status:** selesai, di-approve (2026-11-08). Getter baru dan urutan daftar pemain untuk tab round lewat: catat di
  `docs/architecture.md` saat SP-19.
- **Goal:** (1) fixture golden Mixed sparing bersama, semua susunan dari generator dengan seed frame; (2) pengelompokan
  istirahat per klub pindah dari widget ke `ActiveTournament` dan dipakai Jadwal Fixed (catatan review SP-11);
  (3) `RestingList.clubs` mendukung judul Prioritas / "Istirahat lagi" / judul lain; (4) klub yang membatasi match per
  round untuk kalimat Lanjutkan 15j.
- **Baca:** `15-sparing-mixed.md` (pembuka + catatan semua frame), `13-sparing.md` 13m;
  `test/services/sparing_mixed_test.dart` grup "frame 13m / 15*" (`_run`, `_frameSeed`, cara memanggil generator);
  `sparing_fixture.dart` dan `schedule_fixture.dart` (`LoadedTournament`, pola fixture); `sparing_pasangan_test.dart:49-51`
  (daftar 16 + 14 dari 14e, dipakai 15d); `resting_list.dart`; `schedule_fixed_screen.dart:97-110` (`_restingByClub`);
  `models.dart` (`ActiveTournament`, `drawSeed`, `capacityAhead`, `sparingActiveCourts`); controller
  `generateNextRound` (cara `restingPlayerIdsByRound` diisi).
- **Ubah:**
  - `test/hifi/screens/sparing_mixed_fixture.dart` (baru):
    - Klub dan pemain: Garuda g01–g08, Matcha m01–m06, Oki m07, urut daftar. 15d: 16 + 14 dengan nama dan urutan 14e
      (g01–g16, m01–m14; Oki tetap m07).
    - Id turnamen yang `drawSeed == 0x5eed`: cari sekali dengan skrip di scratchpad (FNV-1a bisa dibalik karena
      pengalinya prima ganjil; meet-in-the-middle 3 + 3 karakter cukup), lalu dikunci `expect(active.drawSeed, 0x5eed)`.
      Tanpa ini daftar Prioritas di layar (memakai `drawSeed`) berbeda dengan frame.
    - Round dari `generateSparingRound(seed: 0x5eed, random: …)`: `Random(1)` bersambung R1–R8; 8 / 3 (15e) dan 16 / 14
      (15d) masing-masing `Random(1)` baru; Court 3 (15o/15p) = `courtMatch(…, random: Random(2))` saat R4 berjalan;
      15n: R1–R3 `Random(1)`, Oki ditambah setelah R3, R4–R6 `Random(3)` dengan `late: {m07}`.
      `restingPlayerIdsByRound` diisi seperti controller. Tidak ada match yang ditulis tangan.
    - Satu keadaan per frame/latar (nama bebas): 15k (R1 baru), 13m (R3 berjalan, Court 2 belum), 15a (R3 lengkap),
      15b (R4 baru; latar 15c, 15g, 15h, 15o), 15d, 15e (8 / 3), 15f (R8 lengkap, waktu habis; latar 15j, 15s, 15u,
      15v, 15x), 15i (diakhiri saat R4), 15l → 15n (Oki), 15m (8 / 3, Kiki keluar), 15p (Court 3 ditambah 19.47),
      15r/15t (Americano 21, WO R3 Court 2 Citra · Gita absen), 15w/15y (sparing bernama berjalan, data dari frame),
      dan jam per keadaan (`mixedSparingAt(…)`).
    - Skor: yang tertulis di catatan dipakai persis (13m, 15a, 15r). Skor yang tidak tertulis (R1–R2 di 15d, R4–R8 di
      15f) dipilih supaya **semua** angka yang tampil di 15d, 15f, 15s, 15u, 15v cocok (skor klub, Total Point,
      selisih per pemain, riwayat Detail). Kalau tidak ada susunan yang cocok: berhenti dan laporkan, jangan memilih.
  - `test/hifi/screens/sparing_mixed_fixture_test.dart` (baru): susunan tiap keadaan = catatan frame; skor klub 13m
    4 – 1 · 27 – 21, 15a 4 – 2 · 32 – 27, 15d 4 – 1 · 28 – 20, 15f 10 – 6 · 83 – 69, 15t 4 – 2 · Matcha 58; jumlah
    main 15f; `TournamentCodec.decode(encode(state)) != null` untuk tiap keadaan.
  - `models.dart` (`ActiveTournament`, total, tidak melempar, kosong di turnamen biasa, urut `config.clubs`):
    `restingPairsByClub(round)` (Fixed, dari `restingPairIdsByRound`) dan `restingPlayersByClub(round)` (Mixed, round
    lewat, dari `restingPlayerIdsByRound`); `sparingLimitingClub` = klub dengan ⌊aktif ÷ 2⌋ terkecil (sama → yang
    pemainnya lebih sedikit, masih sama → klub pertama; asumsi tech-lead, frame hanya memberi contoh 8 / 3). Test
    `test/services/sparing_resting_test.dart` dengan data 13A (Fixed setelah R5) dan 13B (Mixed R3, 8 / 3).
  - `schedule_fixed_screen.dart`: `_restingByClub` hanya memetakan nama dari `restingPairsByClub` (perilaku tetap).
  - `widgets/resting_list.dart`: `RestingList.clubs` menerima `priorityRound`, `later`, `title` dengan judul yang sama
    dengan daftar biasa (06o: "Istirahat lagi" pudar), kolom kosong "–"; `assert(clubs.length == 2)`. Test widget di
    file baru `test/hifi/components/resting_clubs_test.dart` (judul, dua kolom, "–", `find.text`).
- **Acceptance:** AC-S8 (main setelah R8: Garuda 4, Matcha Lina/Nanda 6, lainnya 5), AC-S10 (8 / 3 hanya Court 1),
  AC-S11 (Prioritas per klub keadaan 13m, 15a, 15b, 15d = `restingByClubAfterLastRound` pada id fixture = isi round
  berikutnya), AC-S13 (Court 3 15p), K11 (15t Matcha 58), AC-S20 (simpanan); golden 13k, 13l, 14h–14m tetap lolos
  tanpa diubah.
- **Dependensi:** SP-3, SP-11 (selesai). **Paralel:** dengan SP-18b; bentrok kecil dengan SP-16 (lihat Peta urutan).
  **Model:** kuat (semua task SP-18 membangun di atasnya; pencarian seed dan skor yang konsisten).

## SP-18b · Atur turnamen Mixed sparing (13i, 13j)
- **Status:** selesai, di-approve, digabung setelah SP-18c (2026-11-08).
- **Goal:** cabut `_mixedSparingBlocked` (catatan review SP-9); tombol "Mulai Round 1 · ±R round", ditambah " · C' court"
  kalau C' < court dipesan, angka dari `EndlessRoundGenerator.sparingEstimate` (tidak dihitung di layar).
- **Baca:** `13-sparing.md` 13h–13j, `logic.md` §13.6 (Estimasi Konfigurasi), `konfigurasi_screen.dart`
  (`_mixedSparingBlocked`, `_sparingMeta`), `test/hifi/screens/sparing_konfigurasi_test.dart`.
- **Ubah:** `features/konfigurasi/**`; `sparing_konfigurasi_test.dart`.
- **Acceptance:** AC-S10 (13j "· 1 court"); golden 13i, 13j + `find.text` label tombol; Mulai Round 1 aktif untuk Mixed
  sparing, config yang dikirim ke `/schedule` membawa `clubs`; 03*, 13h, 14f, 14g tetap lolos.
- **Dependensi:** SP-3, SP-9 (selesai); tidak butuh SP-18a (data 13B cukup dari `sparing_fixture.dart`).
  **Paralel:** ya, mulai sekarang. Merge sebaiknya setelah SP-18c (supaya branch tidak membuka Jadwal Mixed sparing
  tanpa tampilan klub), tidak wajib. **Model:** default.

## SP-18c · Jadwal Mixed sparing (13m, 15a–15i, 15n, 15p) + penonton Live
- **Status:** selesai, di-approve (2026-11-08).
- **Goal:** `schedule_mixed_screen.dart` untuk sparing: `ClubScore` di atas daftar (ikut tergulir, seperti 13k);
  Istirahat round terakhir per klub dari `EndlessRoundGenerator.restingByClubAfterLastRound` (bukan gabungan
  `restingAfterLastRound`, catatan review SP-3): "Istirahat · Prioritas main di R(n+1)" lalu "Istirahat lagi di
  R(n+1)" hanya kalau ada klub yang punya, kolom klub yang kosong "–"; tab round lewat dari `restingPlayersByClub`;
  meta Buat "· n court" memakai C' (`sparingActiveCourts` dengan court yang masih muat), bukan jumlah court tersedia;
  Buat/Batalkan/menu ⋯/Akhiri/diakhiri/waktu habis sama dengan Mixed biasa. Penonton Live (`live_screen.dart` memakai
  layar yang sama) ikut tanpa perubahan di `features/live/**`.
- **Baca:** `13-sparing.md` 13m, `15-sparing-mixed.md` 15a–15i, 15n, 15p; `06-jadwal-mixed.md` 06f–06o;
  `schedule_mixed_screen.dart`; `schedule_fixed_screen.dart` (pola sparing SP-11: `clubScoreOf`, `RestingList.clubs`);
  `test/hifi/screens/jadwal_fixed_sparing_test.dart` (pola golden + penonton Live).
- **Ubah:** `schedule_mixed_screen.dart` (+ `schedule_widgets.dart` kalau perlu); test baru
  `test/hifi/screens/jadwal_mixed_sparing_test.dart`.
- **Acceptance:** AC-S7 (klub pertama baris atas), AC-S10 (15e: Court 2 tidak tampil), AC-S11 (keadaan 15a → ketuk Buat
  R4 → pemain R4 tiap klub = daftar Prioritas yang tampil), AC-S14 (skor klub `find.text`); golden 13m, 15a, 15b, 15c,
  15d, 15e, 15f, 15g, 15h, 15i, 15n, 15p; hitung mundur 15p "02:00" dengan `find.text`; tombol Pemain (15) di 15n;
  penonton Live (`liveViewProvider` di-override): skor klub dan Istirahat per klub tampil, tanpa ⋯ dan Batalkan;
  golden 06f–06u tetap.
- **Dependensi:** SP-18a. **Paralel:** dengan SP-18d–SP-18h. **Model:** default.

## SP-18d · Kelola pemain sparing (15l, 15m)
- **Status:** selesai (satu engineer untuk 18d/e/f; layar dicek main session) — 720c5da + 81798d2 di `sparing`, 2026-11-11.
- **Rencana lanjut (2026-11-08):** SP-18d, SP-18e, dan SP-18f dikerjakan **satu engineer (Sonnet)** dalam satu worktree,
  supaya konteks dibaca sekali (aturan "Token budget" di playbook). Review hanya dicek main session (layar), kecuali
  ada perubahan logika di `lib/services/**`/model.
- **Goal:** sheet 08a versi sparing: dua chip klub di bawah kotak nama tanpa pilihan awal, Tambah mati sampai nama terisi
  dan klub dipilih, `addPlayer(name, clubId:)`; daftar per klub berlabel "{klub} · n aktif" (· n keluar); Keluarkan
  memakai `active.canWithdraw(p.id)` — ganti `activeCount > 4` di `manage_players_sheet.dart:56` (catatan review SP-3;
  hasil sama untuk turnamen biasa); alasan "Butuh minimal 2 pemain per klub" di bawah daftar klub yang Keluarkan-nya mati
  karena klub (total aktif > 4), "Butuh minimal 4 pemain" tetap untuk batas total; Kembalikan ke klubnya sendiri.
  Turnamen biasa tidak berubah.
- **Baca:** `15-sparing-mixed.md` 15l, 15m; `07-pemain-court-dan-lanjutkan-mixed.md` 08a, 08b;
  `manage_players_sheet.dart`; controller `addPlayer`, `withdrawPlayer`, `reinstatePlayer`;
  `kelola_lanjutkan_test.dart` (pola golden sheet).
- **Ubah:** `features/schedule/mixed/manage_players_sheet.dart`; test baru `test/hifi/screens/sparing_kelola_pemain_test.dart`.
- **Acceptance:** AC-S12 (tanpa klub tidak bisa ditambah; Keluarkan mati di Matcha 15m, Garuda tetap bisa; Kembalikan
  Kiki ke Matcha); golden 15l (latar 13m, "Oki" + Matcha Club dipilih), 15m; `find.text('Andi sudah ada di PB Garuda')`;
  setelah Tambah Oki simpanan terbaca (`decode(encode) != null`); golden 08a, 08b tetap.
- **Dependensi:** SP-18a; golden dan merge setelah SP-18c (latar). **Paralel:** dengan SP-18c, SP-18e–SP-18h (berkas
  sendiri). **Model:** default.

## SP-18e · Kelola court, Lanjutkan, Cara kerja sparing (15j, 15k, 15o)
- **Status:** selesai (satu engineer untuk 18d/e/f; layar dicek main session) — 29e091e di `sparing`, 2026-11-11.
- **Goal:** 15o: "Langsung main di R4" dengan kolom klub (`RestingList.clubs(title: …)`), pemain dari
  `EndlessRoundGenerator.courtUse(…).players` dikelompokkan per klub lewat `config.clubOfPlayer` (bukan indeks); "Tambah court
  · mulai R5" tetap. 15j: angka dari `capacityAhead` (sudah C'); kalimat batas pemain sparing "maks n match per round
  ({klub} n pemain)" dari `sparingLimitingClub`. 15k: Max Round, Court Aktif, Total Match, Match/Pemain per klub dari
  `sparingEstimate` dengan pemain aktif per klub; aturan Fairness ketiga per klub (teks frame). Muncul sekali saat R1
  dibuat (alur yang ada).
- **Baca:** `15-sparing-mixed.md` 15j, 15k, 15o; `06-jadwal-mixed.md` 06k; `07-pemain-court-dan-lanjutkan-mixed.md`
  08c–08k; `manage_courts_sheet.dart`, `resume_tournament_sheet.dart`, `mixed_guide_sheet.dart`;
  `kelola_court_test.dart`, `kelola_lanjutkan_test.dart`.
- **Ubah:** tiga sheet itu saja; test baru `test/hifi/screens/sparing_mixed_sheets_test.dart`. **Jangan** mengubah
  `widgets/extend_sheet_parts.dart` (dipakai SP-16); kalau perlu, tunggu SP-16 di-merge.
- **Acceptance:** AC-S10 (keadaan 15e: `find.text` "maks 1 match per round (Matcha Club 3 pemain)"), AC-S13 (15o:
  Fajar, Gita · Joko, Maya; Simpan → match Court 3 berisi keempatnya), golden 15j, 15k, 15o; alur 13i → Mulai Round 1
  → sheet 15k muncul sekali (setelah SP-18b); golden 06k, 08c–08k tetap.
- **Dependensi:** SP-18a; golden dan merge setelah SP-18c (latar); test alur 13i → 15k setelah SP-18b.
  **Paralel:** dengan SP-18c, SP-18d, SP-18f–SP-18h.
  **Model:** default.

## SP-18f · Input Skor + WO Mixed sparing (15q, 15r)
- **Status:** selesai (satu engineer untuk 18d/e/f; layar dicek main session) — 9c91501 di `sparing`, 2026-11-11.
- **Goal:** pastikan papan dan sheet WO Mixed sparing sama dengan Fixed sparing (SP-12): dua pemain klub pertama di
  atas, tanpa label klub; nilai WO pemain 4.4 dan klub K11 setelah simpan.
- **Baca:** `15-sparing-mixed.md` 15q, 15r; `score_input_screen.dart`, `walkover_sheet.dart`;
  `sparing_input_skor_test.dart`.
- **Ubah:** `features/score_input/**` hanya kalau perlu; tambah test di `sparing_input_skor_test.dart`.
- **Acceptance:** AC-S7; K11 (15r → simpan: Matcha +1 menang, +12 Total Point klub, selisih tetap; Lina 7 + 11,
  Maya 12 + 12 di klasemen pemain); golden 15q (dari 13m Court 2 R3), 15r.
- **Dependensi:** SP-18a. **Paralel:** ya. **Model:** default.

## SP-18g · Klasemen + Detail Mixed sparing (15s–15v)
- **Status:** selesai (2026-11-08): layar sudah benar untuk Mixed sparing, hanya golden + test (tanpa `lib/`; dicek
  main session, tanpa review terpisah karena hanya test).
- **Goal:** pastikan Klasemen (tabel pemain per klub, nomor mulai #1 di tiap klub) dan Detail (K9) berlaku untuk Mixed
  sparing; tutup catatan review SP-14.
- **Baca:** `15-sparing-mixed.md` 15s–15v; `leaderboard_screen.dart`, `detail_player_screen.dart`;
  `sparing_klasemen_test.dart`, `sparing_detail_test.dart`.
- **Ubah:** `features/leaderboard/**`, `features/detail_player/**` hanya kalau perlu; test di dua file test itu.
- **Acceptance:** AC-S17 (15s: Fajar 21 (+7) di atas Budi 21 (+2), Joko 26 (+5) di atas Nanda 26 (−4)); K11 (15t: Maya
  24, Lina 18, Matcha 58); Detail Mixed: Beda partner = dari klub sendiri − 1, Beda lawan = dari klub lain (catatan
  review SP-14): 15u Andi "3 / 7" dan "6 / 6", 15v Lina "5 / 5" dan "7 / 8" (`find.text` keduanya); `find.text` subjudul "Belum main · {klub} · …" untuk pemain sparing yang belum
  main (Oki setelah ditambah, keadaan 15l); golden 15s (+ digulir), 15t (digulir sampai bawah), 15u, 15v; penonton
  Live Klasemen memakai angka yang sama (`find.text`).
- **Dependensi:** SP-18a. **Paralel:** ya. **Model:** default.

## SP-18h · Beranda Mixed sparing (15w, 15x, 15y)
- **Status:** selesai, di-approve (f525fcd + perbaikan review 9d209e1 di `sparing`, 2026-11-11).
- **Goal:** sisa SP-17. 15w: sparing bernama berjalan, nama tetap di baris kecil, skor klub dua baris rata kanan di
  samping "Round n" (klub pertama atas), nama klub panjang elipsis, angka utuh, tinggi info round tidak bertambah.
  15x: turnamen terakhir Mixed sparing tanpa nama → judul "{klub1} · skor · {klub2}", bernama → nama turnamen; ketuk →
  Lanjutkan (archived). 15y: dialog mulai baru menyebut nama turnamen. Fixed sparing selesai tetap tidak tampil.
- **Baca:** `15-sparing-mixed.md` 15w–15y; `14-sparing-fixed.md` 14x, 14y; `01-beranda.md` 01a, 01c, 01e, 01h;
  `home_screen.dart`, `widgets/court_banner.dart` (`CourtBannerClubs`), `widgets/home_panel.dart`;
  `sparing_beranda_test.dart`.
- **Ubah:** `features/home/**`; `sparing_beranda_test.dart`.
- **Acceptance:** golden 15w, 15x, 15y + `find.text` skor klub dan `v$appVersion`; 01a–01j, 14x, 14y tetap; teks skor
  dari `ClubResult.scoreLabel`.
- **Dependensi:** SP-18a (keadaan 15f dan bernama). **Paralel:** ya. **Model:** default.

## SP-19 · Rilis 3.2.0
- **Goal:** `pubspec.yaml` 3.2.0+14 + `appVersion`; `docs/architecture.md`, `docs/ui-v2.md`, CLAUDE.md (tech-lead) dan
  `docs/data.md` (DBA) diperbarui; `logic.md` §13 status "sudah diimplementasi".
- **Acceptance:** `flutter analyze` tanpa peringatan baru, `flutter test` lulus (termasuk golden semua frame 01–15),
  test `slow` lulus (`flutter test --tags slow --run-skipped`, ±11–17 menit), `tool/build_web.sh` sukses dan semua URL
  precache 200 (tech-infra kalau ada masalah build), AC-S21 dicek offline. Merge `sparing` → `main` hanya atas perintah main session.
- **Catatan review SP-16:** satukan hitungan `roundsLeft` (tiga salinan: `RoundRobinGenerator.extraRounds`,
  `SparingFixedGenerator.extraRounds`, `capacityAhead`) jadi satu helper di `ActiveTournament` sebelum merge ke `main`,
  dengan test lama sebagai bukti refactor murni; "court berkurang mulai R…" di sheet ikut pindah ke rencana service.
  Kasus langka dicatat: tambahan dua digit (13 + 2 pasangan → +13) menggeser label baris klub 14n.
- **Catatan review SP-7:** hapus frasa "sementara 3.1.0" di komentar `beranda_test.dart` saat `appVersion` naik.
  Versi dan wordmark tidak punya ruang cadangan: aman di 390 pt, belum dicek di skala teks besar (opsional: test text
  scale 1,5 dengan `loadHifiFonts`).
- **Dependensi:** semua. **Model:** default.
