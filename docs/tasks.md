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
- Fixture bersama `test/hifi/screens/sparing_fixture.dart` dibuat SP-5. Task layar menambah varian di file test-nya
  sendiri, tidak mengubah fixture bersama (supaya task paralel tidak bentrok).
- Kategori semua task: MINOR (bagian dari 3.2.0); versi baru dinaikkan di SP-19 saja.
- **Model**: "kuat" = fondasi/algoritma/lintas modul; sisanya engineer default.

## Peta urutan

| Gelombang | Task (paralel di dalam gelombang kecuali ditulis) |
|---|---|
| 0 — sekarang | SP-0 (DBA), SP-2, SP-6, SP-7 |
| 1 | SP-1 (setelah SP-0) |
| 2 | SP-3, SP-4, SP-5 (SP-5 juga butuh SP-2), SP-8 |
| 3 | SP-9, SP-10, SP-11, SP-12, SP-13, SP-14, SP-15, SP-17; SP-16 setelah SP-11 |
| 4 | SP-18 (menunggu hi-fi Mixed + SP-3), lalu SP-19 |

Bentrok berkas yang diketahui: SP-3 dan SP-5 sama-sama menyentuh `tournament_controller.dart` dan `models.dart`
(method berbeda) → boleh paralel di worktree, gabungkan SP-5 dulu (layar Fixed menunggunya), SP-3 rebase. SP-16 dan
SP-11 sama-sama di `schedule_fixed_screen.dart` → berurutan. SP-17 setelah SP-7 (sama-sama Beranda).

---

## SP-0 · Finalkan bentuk simpanan sparing (DBA)
- **Goal:** memfinalkan draf `logic.md` §13.10 dan menuliskannya di `docs/data.md`.
- **Baca:** `logic.md` §13.1 + §13.10, `docs/data.md`, `lib/services/storage/tournament_codec.dart`, PRD §13.8.
- **Ubah:** `docs/data.md` (bagian Sparing), koreksi §13.10 kalau ada yang diubah.
- **Acceptance:** keputusan tertulis untuk `config.clubs`, `players[].club`, `restingPairs`, pemakaian ulang
  `extraPutaran`, perlakuan payload sparing yang tidak lengkap, dan risiko app 3.1.0 ter-cache. `schemaVersion` tetap 2.
- **Dependensi:** tidak ada. **Paralel:** ya. **Model:** DBA.

## SP-1 · Model + codec sparing — kuat
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
- **Baca:** `logic.md` §13.2–13.4; prototipe `tool/sparing_proto/lib/sparing_fixed.dart` + `test/fixed_property_test.dart`,
  `test/examples_test.dart`, `test/frames_test.dart`; `round_robin_generator.dart` (`extend`, `_Packer`).
- **Ubah:** file generator baru; `test/services/sparing_fixed_test.dart` (port test properti + contoh). Input generator
  hanya daftar pasangan per klub + court, jadi tidak menunggu SP-1.
- **Acceptance:** AC-S5, AC-S6, AC-S7a (estimasi), AC-S18; tabel 13.11 persis (13A, 8/4, round tambahan R7–R12).
  Test properti §13.12 Fixed (jadwal awal 2250 ukuran + 8 tambahan berantai) lulus.
- **Dependensi:** tidak ada. **Paralel:** ya. **Model:** kuat (algoritma; jebakan `K mod g` di §13.2).
- **Penutup:** kalau SP-3 sudah selesai, hapus `tool/sparing_proto/` dan baris exclude-nya di `analysis_options.yaml`.

## SP-3 · Mixed sparing per klub (`C'` lintas modul) — kuat
- **Goal:** semua aturan `logic.md` §13.6 di service/model: satu fungsi court aktif sparing yang menggantikan
  `slotsFor` di `generateRound`, `_nextRoundSlots`/`restingAfterLastRound` (hasil per klub), `courtUse`/`courtMatch`
  (2 + 2), `capacityAhead.matchesPerRound`; `priorityOrder` per klub; susunan pasangan sesama klub; Kelola pemain
  (tambah wajib klub, Keluarkan mati kalau klub tinggal 2, Kembalikan ke klubnya); estimasi Mixed sparing sebagai
  fungsi murni untuk Konfigurasi dan sheet Cara kerja.
- **Baca:** `logic.md` §5, §5a, §6, §10, §13.6; `endless_round_generator.dart`; `ActiveTournament.capacityAhead`,
  `latePlayerIds`; `TournamentController` (`generateNextRound`, `addPlayer`, `withdrawPlayer`, `reinstatePlayer`,
  `_placeCourt`); prototipe `tool/sparing_proto/lib/sparing_mixed.dart`, `test/mixed_*_test.dart`.
- **Ubah:** `endless_round_generator.dart`, `models.dart` (ActiveTournament), `tournament_controller.dart` (cabang
  sparing di method di atas), test baru `test/services/sparing_mixed_test.dart`.
- **Acceptance:** AC-S8, AC-S9, AC-S10, AC-S11, AC-S12, AC-S13; contoh Oki/Nanda §13.11; tabel 8 round PRD 13.4.
  Turnamen biasa: `mixed_priority_test`, `mixed_roster_test`, `court_manage_test`, `court_availability_test`,
  `resume_tournament_test` lulus tanpa diubah.
- **Simpanan (review SP-1):** setiap mutator sparing (`addPlayer` dengan klub, Kembalikan, pasangan per round) wajib
  menjaga S1/S2/S4; tiap test mutator sparing memeriksa `TournamentCodec.decode(encode(state)) != null`. `addPlayer`
  (`tournament_controller.dart:126`) sekarang membuat `Player` tanpa `clubId`: itu harus diisi.
- **Test properti:** §13.12 Mixed. Versi ringkas di suite biasa; sweep penuh (±90 detik) bertag `slow`.
- **Dependensi:** SP-1. **Paralel:** dengan SP-4, SP-5 (lihat bentrok), SP-8. **Model:** kuat (lintas modul).
- **Penutup:** kalau SP-2 sudah selesai, hapus `tool/sparing_proto/` + exclude-nya.

## SP-4 · Skor klub + klasemen per klub
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
- **Goal:** "v{appVersion}" di kanan atas banner, semua kondisi Beranda.
- **Baca:** `screens/01-beranda.md` (catatan 01a), `court_banner.dart`, `home_screen.dart`, `test/hifi/screens/` Beranda.
- **Ubah:** `features/home/widgets/court_banner.dart` (atau panel, ikut hi-fi), test Beranda.
- **Acceptance:** golden 01a–01f, 01h, 01i lolos + `find.text('v$appVersion')`; 01g/01j tanpa versi; tidak bisa diketuk.
- **Dependensi:** tidak ada. **Paralel:** ya. **Model:** default.

## SP-8 · Layar Pemain: Mabar / Sparing
- **Goal:** pilihan Mabar / Sparing, dua blok klub (nama klub + kotak nama + daftar), validasi K6/K8, isi tiap pilihan
  disimpan selama layar terbuka, kirim olahraga + dua klub + anggotanya ke Atur turnamen.
- **Baca:** `screens/02-pemain.md`, `13-sparing.md` 13a–13g, `player_name_parser.dart`, `setup_peserta_screen.dart`.
- **Ubah:** `features/setup_peserta/**`, aturan validasi sparing sebagai fungsi murni di `services/pairing/`
  (mis. `club_roster.dart`, dengan test), router extra.
- **Acceptance:** AC-S1, AC-S2; golden 02a, 02b, 02c (sekarang merah di `main`), 13a–13g; pesan "Andi, Budi, Citra +2
  ada di dua klub"; nama klub maks 20, dipangkas.
- **Dependensi:** SP-1. **Paralel:** ya. **Model:** default.

## SP-9 · Atur turnamen sparing
- **Goal:** subjudul "olahraga · klub1 n · klub2 n"; estimasi tombol Fixed sparing K10 (dari SP-2) dan Mixed sparing
  (dari SP-3); config yang dibuat membawa klub.
- **Baca:** `screens/13-sparing.md` 13h–13j, `14-sparing-fixed.md` 14f–14g, `logic.md` §13.4, §13.6,
  `konfigurasi_screen.dart`.
- **Ubah:** `features/konfigurasi/**`.
- **Acceptance:** AC-S7a, AC-S10 (estimasi); golden 13h, 14f, 14g; 13i, 13j setelah SP-3.
- **Dependensi:** SP-2, SP-5 (navigasi ke Pasangan), SP-3 untuk 13i/13j. **Paralel:** ya. **Model:** default.

## SP-10 · Pasangan sparing
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
- **Goal:** `ClubScore` di atas daftar (ikut tergulir), Istirahat dua kolom per klub (`.rest .names.clubs`, "–"
  kalau kosong), court tidak aktif tidak tampil, sisanya sama dengan Jadwal Fixed; mode penonton Live ikut.
- **Baca:** `13-sparing.md` 13k–13l, `14-sparing-fixed.md` 14h–14m, `components.md` (`.rest`), `schedule_fixed_screen.dart`,
  `features/schedule/widgets/resting_list.dart`.
- **Ubah:** `schedule_fixed_screen.dart`, `RestingList` (varian klub), test layar.
- **Acceptance:** AC-S6 (Court 3 tidak tampil), AC-S7 (sisi atas = klub pertama), AC-S14 (6 – 4 / 7 – 5); golden 13k,
  13l, 14h, 14i, 14j, 14k, 14l, 14m; hitung mundur 00:45 dengan `find.text`; penonton Live: skor klub tampil, tanpa ⋯.
- **Dependensi:** SP-4, SP-5, SP-6. **Paralel:** ya. **Model:** default.

## SP-12 · Input Skor + WO sparing
- **Goal:** pastikan papan dan sheet WO mengikuti S4 (klub pertama atas, urutan pilihan WO = papan) dan skor klub
  dihitung ulang setelah simpan.
- **Baca:** `14-sparing-fixed.md` 14q–14r, `score_input_screen.dart`, `walkover_sheet.dart`.
- **Ubah:** `features/score_input/**` hanya kalau perlu; test layar.
- **Acceptance:** AC-S7, AC-S15; golden 14q, 14r.
- **Dependensi:** SP-5. **Paralel:** ya. **Model:** default.

## SP-13 · Klasemen sparing
- **Goal:** `ClubScore` tetap di atas tab metode, tabel per klub bernomor sendiri, "Belum main" per klub, baris campuran
  setelah Atur pasangan, "1 match WO" di bawah tabel terakhir; Live penonton memakai angka yang sama.
- **Baca:** `13-sparing.md` 13n–13p, `14-sparing-fixed.md` 14p, 14s–14u, `leaderboard_screen.dart`, `logic.md` §13.8.
- **Ubah:** `features/leaderboard/**`.
- **Acceptance:** AC-S14, AC-S16, AC-S17; golden 13n, 13o (digulir), 13p (Win %), 14p, 14s, 14t, 14u.
- **Dependensi:** SP-4, SP-5, SP-6. **Paralel:** ya. **Model:** default.

## SP-14 · Detail sparing
- **Goal:** subjudul "Peringkat n · klub · …", tim sendiri di atas (K9), Beda lawan ÷ pemain klub lain.
- **Baca:** `14-sparing-fixed.md` 14v–14w, `detail_player_screen.dart`, `logic.md` §13.8.
- **Ubah:** `features/detail_player/**`.
- **Acceptance:** AC-S7 (Detail Maya), AC-S17; golden 14v, 14w.
- **Dependensi:** SP-4, SP-5. **Paralel:** ya. **Model:** default.

## SP-15 · Bagikan sparing: Ringkas + caption
- **Goal:** `sharePosterData` sparing (`.pscore`, label `.pclub`, 3 teratas tiap klub, "+n pasangan lainnya"),
  `SharePoster` pratinjau Ringkas, caption 13q (termasuk Seri dan sparing bernama), Lengkap pratinjau per aturan
  `logic.md` §13.9.
- **Baca:** `13-sparing.md` 13q, `11-bagikan.md`, `share_content.dart`, `share_poster.dart`, `result_text_builder.dart`,
  `docs/ui-v2.md` Bagikan.
- **Ubah:** `features/share/**`, `services/share/result_text_builder.dart` (+ test).
- **Acceptance:** AC-S17 (nomor sama), K7; golden 13q; test caption = teks 13q persis; caption Seri "… 6–6 … · Seri ·
  Padel" dan "6½–5½".
- **Feed/Story/Lengkap:** host setuju (2026-11-07) designer menambah frame poster sparing Feed, Story, dan Lengkap,
  persis gaya poster yang ada (bukan rombak Bagikan). Sedang digambar; ukuran `.pscore`/`.pclub` dan aturan kepadatan
  dengan label klub ada di catatan frame itu. Jangan mengarang ukuran sebelum frame-nya di-commit.
- **Dependensi:** SP-4, SP-5. **Paralel:** ya. **Model:** default.

## SP-16 · Tambah round + Atur pasangan sparing
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
- **Goal:** baris "PB Garuda 6 – 4 Matcha Club" (tanpa nama turnamen), dialog mulai baru 14y.
- **Baca:** `14-sparing-fixed.md` 14x–14y, `home_screen.dart`, `logic.md` §13.9.
- **Ubah:** `features/home/**`.
- **Acceptance:** golden 14x, 14y; "0 – 0" sebelum ada hasil. Sparing **bernama** 15w/15y dan turnamen terakhir Mixed
  sparing 15x (hi-fi Mixed disetujui host 2026-11-07) boleh ikut task ini atau SP-18.
- **Dependensi:** SP-4, SP-7. **Paralel:** ya. **Model:** default.

## SP-18 · Layar Mixed sparing — menunggu hi-fi Mixed
- Hi-fi Mixed **disetujui host 2026-11-07** (`design/spec/screens/15-sparing-mixed.md`, 15a–15y); tech-lead memecahnya
  jadi task setelah SP-3. Undian di frame dipanggil langsung dengan `seed: 0x5eed` (bukan FNV-1a id turnamen) dan
  seed `Random` per frame tertulis di pembuka section Mixed. Cakupan perkiraan:
  Jadwal Mixed sparing (13m + 15*), Istirahat per klub dengan Prioritas /
  Istirahat lagi, Kelola pemain per klub, Kelola court, sheet Cara kerja Mixed sparing, Klasemen/Detail per pemain,
  Bagikan Mixed, Live. Dipecah jadi task setelah hi-fi alur Mixed disetujui host. Logikanya sudah di SP-3.
- Catatan fixture: designer menulis susunan 13m/15a–15y sebagai "hasil generator". Undian prioritas berseed id
  turnamen (seperti `t-06o-30`) dan susunan pasangan memakai `Random`, jadi task ini butuh id turnamen + seed + versi
  prototipe yang dipakai designer, dan generator produksi harus memberi hasil yang sama dengan prototipe
  `tool/sparing_proto` untuk input itu (atau fixture menulis match secara eksplisit dan hanya daftar prioritas yang
  dicek dari generator).
- **Dependensi:** hi-fi Mixed, SP-3, SP-6, SP-11. **Model:** default (kecuali ada logika baru dari hi-fi).

## SP-19 · Rilis 3.2.0
- **Goal:** `pubspec.yaml` 3.2.0+14 + `appVersion`; `docs/architecture.md`, `docs/ui-v2.md`, CLAUDE.md (tech-lead) dan
  `docs/data.md` (DBA) diperbarui; `logic.md` §13 status "sudah diimplementasi".
- **Acceptance:** `flutter analyze` tanpa peringatan baru, `flutter test` lulus (termasuk golden semua frame 01–14),
  test `slow` lulus, `tool/build_web.sh` sukses dan semua URL precache 200 (tech-infra kalau ada masalah build), AC-S21
  dicek offline. Merge `sparing` → `main` hanya atas perintah main session.
- **Catatan review SP-7:** hapus frasa "sementara 3.1.0" di komentar `beranda_test.dart` saat `appVersion` naik.
  Versi dan wordmark tidak punya ruang cadangan: aman di 390 pt, belum dicek di skala teks besar (opsional: test text
  scale 1,5 dengan `loadHifiFonts`).
- **Dependensi:** semua. **Model:** default.
