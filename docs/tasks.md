# Task — PATCH 3.8.1 review UX hi-fi (P1 kontras · P2 sentuh + Semantics · P3 teks)

Pemilik: main session. Branch `ux-patch-3-8-1` (dari `main` 559d69f). Produk: PRD keputusan 110–112. Sumber temuan:
`design/review/ux-review.md` (paket) + `ux-review-A.md` / `-B.md` / `-C.md` (id, fakta, baris hi-fi, usulan persis).
Dikerjakan **sesuai usulan reviewer**; P4–P7 di luar lingkup (jangan ikut dikerjakan). Lembar kontak
`design/review/sheets/` tidak di-commit (6,5 MB).

Aturan semua task: hi-fi dulu, lalu kode; golden `expectMatchesHifi` setelah `python3 tool/hifi_extract.py`
(`docs/ui-v2.md`); logika tidak berubah (PATCH); `dart format` hanya hunk sendiri; tanpa dependensi baru; tanpa naik
versi sampai UX-5. Ikon tukar tetap 44 × 42 (keputusan 48–57). Wording UI dan aturan "tanpa kalimat penjelas" berlaku.

## Urutan

| Task | Isi | Siapa | Dicek |
|---|---|---|---|
| UX-0 | Hi-fi bagian bersama: CSS/Fondasi/Komponen untuk P1 (A-1, A-3=B-3, A-4=C-8 + gembok, A-5, A-6 aturan "faint = placeholder" diganti, B-19, C-16), aturan area ketuk ≥ 48 di Fondasi + chip grup 40/gap 8 (A-7, B-5, C-6), tabel Semantics di hi-fi Komponen + `design/spec/components.md` (A-11, B-4, C-5), B-11 jarak Simpan 24, B-12 ⌫ mati, B-17 "Offline · 19.48"; Cakupan "Sudah disetujui" | ui-ux-designer opus/high | main session |
| UX-1 | Hi-fi teks P3 + K3: A-2/C-1 dialog Akhiri per mode (+ frame dialog Grup + Gugur fase grup dan gugur sebelum Final), A-10/K3 hapus paragraf 08a/15l/15m, A-12, A-16, A-17, B-6, B-13, B-14, B-15, B-20, C-13, C-14; catatan + `design/spec/screens/*.md` ikut | ui-ux-designer opus/high (setelah UX-0, file sama) | main session |
| UX-2 | Render ulang frame (`tool/hifi_extract.py`), cek noise rects | main session | — |
| UX-3 | Kode P1 + P2: token/warna, `MabarButton` wait meta, `RoundTabs` terkunci, court swatch, field, tema, bagan, area ketuk, Semantics, keypad; golden diperbarui | engineer sonnet/medium | main session (diff + test terkait) |
| UX-4 | Kode P3 + K3: teks + dialog Akhiri per mode (`confirmFinishTournament`), golden | engineer sonnet/low (bisa digabung UX-3 kalau konteks cukup) | main session |
| UX-5 | Audit PRD ↔ catatan hi-fi (permintaan host): bandingkan per bagian, kode = kebenaran bila keduanya beda; konflik yang kodenya tidak jelas → tanya host | product-manager opus/high, per bagian PRD, maks 3 paralel | main session |
| UX-6 | Rilis: 3.8.1+25 + `appVersion`, full test sekali, merge ke `main`, push (deploy), publish ulang hi-fi, status CLAUDE.md + memory | main session | — |

### Status (2026-11-18, akhir sesi UX-0)

- **UX-0 selesai** (hi-fi CSS/Fondasi/Komponen/Cakupan, `tokens.json`, `components.md`), di-commit di branch ini.
  Frame terdampak praktis semua (226) → UX-2 render ulang semua.
- Keputusan host 2026-11-18 atas pertanyaan UX-0 (semua usulan disetujui):
  1. A-6: tepi `edge` #7D8A96 untuk **semua isian yang tidak fokus** (terisi maupun kosong), bukan hanya yang kosong →
     belum diterapkan di hi-fi; kerjakan bersama UX-1 (Fondasi isian + catatan), di kode = `enabledBorder`.
  2. B-17: tag "Offline · 19.48" di 12m diterima; subjudul terpotong elipsis tidak apa-apa.
  3. B-19: tepi tema lembut tinta 20% tetap sesuai usulan reviewer (dekoratif, < 3:1 diterima).
  4. C-6 usulan kedua (baris tidak pindah saat grup dipilih): ditunda, bahas bersama GU9 (3.8.x).
- **Jebakan UX-2:** `tool/hifi_extract.py` menulis ulang `components.md` utuh → bagian Semantics baru hilang. Ubah
  extractor supaya menyalin tabel dari panel `#semantics` hi-fi, lalu cek diff `components.md`.
- Berikutnya: UX-1 dengan agen **baru** (agen UX-0 sudah 208k konteks), brief menyebut keputusan 1 di atas.

---

# Task — Grup + Gugur (rencana 3.8.0, MINOR)

Pemilik: tech-lead. Branch `grup-gugur`. Produk: PRD §16 (keputusan 93–103). Spec: `design/spec/logic.md` §18 (aturan,
data test, invariant I1–I12, jebakan 18.12). Layar: `design/spec/screens/19-…`–`22-…` + PNG frame. ID test = ID PRD
(`AC-G9 16E …`) + id frame (`20o …`), tanpa tabel pemetaan.

Aturan semua task: logika hanya di `lib/services/**` (wajib test), widget tidak menghitung ulang; `dart format` hanya
file baru/hunk sendiri (lebar 120); `flutter analyze` tidak menambah peringatan; test berkas yang disentuh lulus dan
**semua test + golden lama lolos tanpa diubah** (AC-G16 — jalur round-robin/sparing/Mixed/Mexicano byte-sama). Golden
layar = `expectMatchesHifi` per frame dengan data persis frame (`design/spec/README.md` → Aturan golden; jam dari
`clockProvider`). Tanpa dependensi baru, tanpa naik versi (main session di GG-11), tanpa `saveActive`/kirim live manual.
**DBA wajib** (GG-0: bentuk simpanan + penanda GU15). `schemaVersion` tetap 2 (§18.11); kalau dba menyimpulkan harus
naik → berhenti, itu MAJOR dan kembali ke host. Tidak ada perubahan build/deploy (tanpa tech-infra); relay tidak berubah.

## Urutan batch

| Batch | Task | Model / effort | Paralel | Dicek oleh |
|---|---|---|---|---|
| 1 | GG-0 bentuk simpanan + aturan baca + penanda GU15 (docs) | dba | ya, dengan GG-1 | tech-lead |
| 1 | GG-1 model + jadwal fase grup + estimasi | **opus / high** | ya, dengan GG-0 | tech-lead |
| 2 | GG-2 bagan, lolos, peringkat akhir, label round | **opus / high** | ya, dengan GG-5 | tech-lead |
| 2 | GG-5 Konfigurasi 19a–19l (+ pengaturan terakhir) | sonnet / medium | ya, dengan GG-2 | tech-lead |
| 3 | GG-3 codec + aturan baca (bentuk GG-0) | sonnet / medium | ya, dengan GG-4 (merge GG-3 dulu) | tech-lead |
| 3 | GG-4 controller + provider + fixture golden bersama | **opus / medium** | ya, dengan GG-3 | tech-lead |
| 4 | GG-6 Pasangan Manual + layar Grup 19m–19y | sonnet / medium | ya (maks 3) | main session |
| 4 | GG-7 Jadwal fase grup + Buat bagan + baris gugur | sonnet / high | ya (maks 3) | tech-lead |
| 4 | GG-8 Klasemen grup + Peringkat akhir + Detail | sonnet / medium | ya (maks 3) | main session |
| 5 | GG-9 Bagan + Input Skor/WO gugur | **opus / high** | ya, dengan GG-10 | tech-lead |
| 5 | GG-10 Bagikan + caption + live | sonnet / medium | ya, dengan GG-9 | main session |
| 6 | GG-11 rilis: versi, docs, full test, build web | main session + tech-lead | — | — |

Tidak masuk batch: ubah format babak / juara 3 setelah jadwal dibuat (GU9) — belum ada frame (`logic.md` 18.13 #1).

### Status (2026-11-17, GG-11)

- Rilis siap di `grup-gugur`: versi 3.8.0+24, docs (`architecture.md`, `ui-v2.md`, `logic.md` §18.10, `security.md`,
  `CLAUDE.md`), suite penuh 1753 lolos (1 skip), `tool/build_web.sh` OK, smoke Chrome (v3.8.0, konsol bersih; branch
  tidak menyentuh kode web). Merge ke `main` + live 2026-11-17 (90ebba2, Deploy web lolos). Sisa: uji HP alur 16A (AC-G19, host).

### Status (2026-11-17, akhir sesi B5)

- GG-9 + GG-10 selesai di `grup-gugur` (HEAD setelah merge a2e4564): review fresh tech-lead → test tambahan (69a0e53)
  + saran rapikan (a2e4564: `ActiveTournament.canOpenScore`, `MatchGame.isScorable`, `KnockoutBracket.sourcesOf` /
  `advancesTo`, test caption di `test/services`). Keputusan 109: frame 22q/22r Story ikut §17.12 #3 (763fd4b, hi-fi
  v95). Suite penuh 1753 lolos, 1 skip.
- Diterima host: WO yang membalik pemenang ditolak di sheet kalau babak berikut sudah berskor; Simpan mati saat seri
  di gugur (pengaman, tidak terjadi). Mixed tetap hanya `isScorable` (tanpa kunci round), sengaja.
- Berikutnya: GG-11 (sesi baru): versi 3.8.0, docs, build web + Chrome, lalu merge ke `main` setelah host bilang go.

### Status (2026-11-17, akhir sesi B1–B4)

- Selesai di branch `grup-gugur` (90485e8): GG-0…GG-8. Review fresh tech-lead: GG-1, GG-2, GG-3, GG-4 (temuan sudah
  diperbaiki); layar GG-5…GG-8 dicek main session. `flutter test` penuh: 1692 lolos, 1 skip.
- Berikutnya B5: GG-9 (Bagan + Input Skor/WO gugur; opus/high; isi `BaganView(active, onOpenMatch)` di
  `lib/features/schedule/group_knockout/bagan_view.dart`, dialog 21k/21l via `KnockoutBracket.flipCheck`) paralel
  GG-10 (Bagikan, caption, live). Lalu review layar oleh main session, GG-11 rilis.
- `MatchScoreRow.label`: Jadwal (non-compact) 12/14 + `labelOverlap`, Detail (compact) 13 pt — jangan disatukan.
- Pertanyaan host dijawab 2026-11-17 (semua rekomendasi disetujui, PRD keputusan 104–108): GU9 ubah format babak
  setelah jadwal **ditunda ke 3.8.x** (tidak dikerjakan); "Belum main" tanpa nomor; caption "Pemenang SF2"; frame 19s
  benar (catatan diperbaiki); pseudocode PRD 3.3 diperbaiki.
- Asumsi tanpa frame (laporkan ke host saat review): WO gugur tanpa "+n"; subjudul Detail sebelum bagan; sheet pilih
  slot beberapa grup ("Pilih A2 dan C2"); subjudul round gugur "· diakhiri"; setelah finishNow SF masih bisa diubah.

## GG-0 · dba — bentuk simpanan Grup + Gugur

- **Tujuan:** putuskan bentuk JSON kebutuhan `logic.md` §18.11 (config `groupKnockout`, `phase` per match, sisi tbd),
  penanda GU15 supaya app ≤ 3.7.x menolak (usulan `bye.gg`, pola `bye.sparing`), daftar aturan baca (semua = `decode`
  null), apakah hasil Buat bagan cukup dari sisi babak pertama, dan kunci opsional pengaturan terakhir (19i).
- **Baca:** `logic.md` §18.1, 18.8, 18.11; `docs/data.md` (Riwayat bentuk, Sparing → Risiko app lama, Mexicano);
  `lib/services/storage/tournament_codec.dart`, `last_settings.dart`.
- **Sentuh:** `docs/data.md` (bagian baru "Grup + Gugur (3.8.0, MINOR)" + baris Riwayat), `logic.md` §18.11 (tandai
  "Final (dba)"). Tanpa kode.
- **Kriteria terima:** tiap aturan baca punya contoh payload yang ditolak; bukti (baris kode 3.7.1) bahwa decoder lama
  menolak payload dengan penanda; encode turnamen lain byte-sama; daftar test wajib untuk GG-3. Butir untuk
  `docs/security.md` dilaporkan ke main session (bukan ditulis dba).
- **Bergantung:** tidak ada.

## GG-1 · Model + jadwal fase grup + estimasi — opus

- **Tujuan:** §18.1 (semua tipe/field/helper model, termasuk `copyWith` yang membawa `phase`/`groupKnockout`,
  `formatFor`, `forKnockout`, `isValidKnockout`, `Pair.tbd`, `StandingEntry.stage`, `hasBracket`), §18.2–18.5
  (`GroupStage.sizes`, `groupCountsFor`, `courtsOfGroups`, `schedule`, `estimate`). Circle method dan `_Packer` dipakai
  ulang dari `round_robin_generator.dart` (refaktor tanpa ubah perilaku), bukan disalin.
- **Baca:** `logic.md` §18.1–18.5, 18.12 #1 #3 #10 #11; `round_robin_generator.dart`; `models.dart` (MatchGame,
  TournamentConfig, ActiveTournament).
- **Sentuh:** `lib/models/models.dart`, `lib/services/schedule/group_stage.dart` (baru),
  `lib/services/schedule/round_robin_generator.dart`; test baru `test/services/group_stage_test.dart`,
  `group_stage_property_test.dart`, kasus baru di `test/services/score_format_test.dart`.
- **Kriteria terima:** tabel 18.2, 18.3, 18.4, 18.5 lolos dengan nama `AC-G3 16A …`, `AC-G4 16B …`, `AC-G5 16C …`,
  `19k …`; I1–I6 sebagai properti (P 6–15 × G × C 1–10, suite biasa, cepat); `withScore`/`asWalkover`/`copyWith`
  mempertahankan `phase`, `config.copyWith(players: …)` mempertahankan `groupKnockout`; `forKnockout` (Best of 6 → 7,
  Americano 98 → 99, Race to tetap); `round_robin_generator_test.dart` dan `fixed_extra_rounds_test.dart` lolos tanpa
  diubah; tidak meng-import `package:flutter` di service.
- **Bergantung:** tidak ada.

## GG-2 · Bagan, lolos, peringkat akhir, label round — opus

- **Tujuan:** `services/schedule/knockout_bracket.dart` (topologi, `sources`, `sourceLabel`, `seedOf`, `layout`, `build`,
  `resolve`, `dependents`, `flipCheck`, `roundTab`/`roundTitle`) dan `services/ranking/group_knockout_ranking.dart`
  (`groupTables`, `qualifierPlan` + `withPicks`, `finalEntries`); getter model `canCreateBracket`, cabang Grup + Gugur
  di `isFinal` dan `canAddRounds` (§18.9 Status, 18.10).
- **Baca:** `logic.md` §18.6–18.10, 18.12; `ranking_calculator.dart` (`rank`, `compare`, `standingEntries`).
- **Sentuh:** dua file service baru, `lib/models/models.dart` (hanya tiga getter), test baru
  `test/services/knockout_bracket_test.dart`, `knockout_bracket_property_test.dart`, `group_knockout_ranking_test.dart`.
- **Kriteria terima:** semua tabel 18.6–18.9 (16D-i/ii/iii, 20l, 20o, 16E, 16B 21w–21y, 16F + tiga varian, 22d, 22e, 22g,
  22h–22i), AC-G6, AC-G7 (tanpa pilihan → `withPicks` null), AC-G8 properti paruh, AC-G9, AC-G10 (lewat `formatFor`),
  AC-G11, AC-G13, AC-G14; I7–I12 properti; label round 21b ("Semifinal"), 21s ("SF1", "SF2", "Juara 3", "Final"), 21v
  ("PF1–2", "PF3–4"), 4 grup 3 court ("PF1–3", "PF4"); `ranking_calculator_test`/`ranking_v2_test` lolos tanpa diubah.
- **Bergantung:** GG-1.

- **Review GG-2 (2026-11-17): Approve.** Tindak lanjut opsional (belum ada pemilik, ambil di task yang menyentuh
  file itu): (1) properti `knockout_bracket_property_test` sebagian tautologis — tambah pembanding independen sisi
  Final/SF/J3 dari match sumber, cek `FlipBlocked`/`FlipAllowed` terhadap dependent, id `finalEntries` unik; (2)
  komentar kelas `knockout_bracket.dart:58` kecualikan `build` (melempar); (3) `_withSides` pakai
  `MatchGame.copyWith(pair1:, pair2:)` (dititipkan ke GG-4); (4) `flipCheck` dengan id bukan sisi match → penjaga; (5)
  test contoh PF berganti pemenang setelah SF berskor → `FlipBlocked([semifinal])`. `pairById('')` → null masuk GG-4.

## GG-3 · Codec + aturan baca — sonnet

- **Tujuan:** bentuk dan aturan baca final GG-0 di `TournamentCodec` (`encode`, `decode`, `canEncode`) + pengaturan
  terakhir kalau GG-0 memutuskannya.
- **Baca:** `docs/data.md` → Grup + Gugur (GG-0); `logic.md` §18.11; `tournament_codec.dart`, `last_settings.dart`.
- **Sentuh:** `lib/services/storage/tournament_codec.dart`, `lib/services/storage/last_settings.dart` (kalau GG-0);
  test baru `test/services/group_knockout_codec_test.dart`.
- **Kriteria terima:** round-trip `encode`→`decode` identik di tiga keadaan AC-G15 (fase grup 20b, setelah Buat bagan
  21a, tengah gugur 21c) dan setelah diakhiri (21t); tiap aturan baca GG-0 punya payload ditolak; fixture literal
  3.7.x (round-robin, sparing, Mexicano) terbaca dan ter-encode byte-sama (AC-G16); payload dengan penanda didecode oleh
  salinan aturan decoder 3.7.1 → null (test seperti `sparing_codec_test`).
- **Bergantung:** GG-0, GG-2 (`layout`/`resolve` untuk validasi sisi).

- **Review GG-3 (2026-11-17): Request changes → selesai di main session** (literal Mexicano 3.7.x di AC-G16).
  Opsional: `canEncode` false untuk GR13–GR16 (terutama Final done tanpa pemenang); test ukuran pakai id panjang UUID
  dan tulis angkanya di komentar; properti acak skor/WO → `canEncode` + round trip (cek di review GG-4). Risiko: kalau
  kelak Atur pasangan/tukar pemain dibuka untuk Grup + Gugur, sisi match ≠ `fixedPairs` → encode gagal.

## GG-4 · Controller + provider + fixture golden bersama — opus

- **Tujuan:** §18.10: `startIfNeeded` cabang Grup + Gugur, `createBracket(picks)`, `submitScore`/`markWalkover` (kunci
  grup, `flipCheck`, `resolve`, satu `state =`), `standingEntriesProvider` → `finalEntries`, `groupTablesProvider` baru.
  Fixture bersama untuk semua golden layar: `test/hifi/screens/grup_gugur_fixture.dart` (16A: awal 20a, 20b, 20e/16D-ii,
  16D-iii 20h, 20l, 20q diakhiri R4, bagan 21a, 21c SF1, 21f, 21i selesai, 21q tanpa juara 3, 21t diakhiri R7, 21s 1
  court; 16B: 20m, 20o, 21u, 21w, 21x, 21y; 16C: 20p) — data, nama, jam persis frame.
- **Baca:** `logic.md` §18.8, 18.10, 18.12 #2 #6 #7; `tournament_controller.dart`; frame catatan 20–22 (data saja).
- **Sentuh:** `lib/features/schedule/tournament_controller.dart`, fixture baru, test baru
  `test/services/group_knockout_flow_test.dart`.
- **Kriteria terima:** alur penuh 16A lewat controller: start → isi R1–R6 → `canCreateBracket` (AC-G6) → `createBracket`
  → SF → ubah SF1 (allowed/blocked AC-G9) → Final → `isFinal` (AC-G14); match grup ditolak setelah bagan (AC-G12); 16D-iii
  tanpa pilihan tidak mengubah state (AC-G7); kill + buka lagi di tiga keadaan sama persis (AC-G15, setelah GG-3 di-merge);
  `fixed_add_rounds_test`, `sparing_fixed_flow_test`, `resume_tournament_test` lolos tanpa diubah.
- **Bergantung:** GG-1, GG-2; GG-3 hanya untuk test kill/buka (merge GG-3 dulu).

- **Review GG-4 (2026-11-17): Request changes → selesai di main session** (penjaga `generateNextRound`/`withdrawPlayer`
  di Grup + Gugur; test alur cek `canEncode` di tiap `read()`). Untuk GG-7/GG-9: setelah `finishNow`, mengubah SF1
  sampai pemenang berganti masih boleh dan sisi Final cancelled ikut berganti (sesuai §18.8, tanpa frame) — layar
  mengikuti perilaku turnamen diakhiri yang sudah ada; kalau frame bertentangan, tanya host. Jam fixture 20h, 20l,
  21u, 21w–21y diambil dari frame terdekat: kalau golden beda, tambah konstanta `at…` baru, jangan ubah yang ada.
  Opsional: `startIfNeeded` pakai `config.isGroupKnockout` + assert id grup ada di `fixedPairs`.

## GG-5 · Konfigurasi 19a–19l — sonnet

- **Tujuan:** segmented Round-robin / Grup + Gugur (hanya Fixed biasa, `groupCountsFor`), baris Fase grup / Gugur,
  sheet Fase grup (2/4 grup), sheet Gugur + sheet babak (stepper ganjil), juara 3 Ada / Tidak ada, ringkasan baris Gugur
  ("Race to 4–9", "· tanpa Juara 3"), tombol dengan `GroupStage.estimate`; config keluar membawa `GroupKnockout` (groups
  kosong). Rangkai teks ringkasan di fungsi murni yang di-test (pola `ConfigSummary`). Pengaturan terakhir sesuai GG-0.
- **Baca:** `screens/19-grup-gugur-persiapan.md` 19a–19l; `logic.md` §18.1 (`forKnockout`), 18.2, 18.5, 14.5;
  `konfigurasi_screen.dart`.
- **Sentuh:** `lib/features/konfigurasi/**`, `lib/services/schedule/config_summary.dart`,
  `lib/services/storage/last_settings.dart` (bagian pengaturan, koordinasi dengan GG-3 kalau keduanya menyentuh);
  test `test/hifi/screens/grup_gugur_konfigurasi_test.dart` (baru), `test/services/config_summary_test.dart`.
- **Kriteria terima:** golden 19a–19l lolos; golden 03a–03q, 13h–13j, 14f–14g lolos tanpa diubah (8 pemain = tanpa
  segmented); AC-G1 (10/22/24 pemain, Sparing/Mixed/Mexicano tanpa segmented); tombol 19b "· 8 round · 16 match", 19i
  dan 19k lewat booking; 19h Best of 6 → babak Best of 7, stepper 7 → 5/9.
- **Bergantung:** GG-1; bagian pengaturan terakhir: GG-0.

## GG-6 · Pasangan Manual + layar Grup 19m–19y — sonnet

- **Tujuan:** Pasangan dibuka Manual untuk Grup + Gugur, tombol "Lanjut" ke layar Grup baru; `GroupDraft` (§18.14);
  layar Grup (chip A–D, label "n dari t", alasan di tombol, Acak, gulir 19w/19x); dialog kunci 19y → `/schedule` dengan
  `config.copyWith(groupKnockout: … groups)`.
- **Baca:** `screens/19-…` 19m–19y; `logic.md` §18.14, 18.2; `pair_setup_screen.dart`, `services/pairing/pair_draft.dart`
  (pola); router.
- **Sentuh:** `lib/features/pair_setup/**`, `lib/features/groups/` (baru), `lib/services/pairing/group_draft.dart` (baru),
  router (satu rute); test `test/services/group_draft_test.dart`, `test/hifi/screens/grup_gugur_grup_test.dart` (baru).
- **Kriteria terima:** golden 19m–19y; data test 18.14; AC-G2; golden Pasangan lama 04a–04h dan sparing lolos tanpa
  diubah; config yang dioper ke Jadwal lewat `copyWith` (Pitfall `identical`).
- **Bergantung:** GG-1, GG-4.

## GG-7 · Jadwal fase grup + Buat bagan + baris gugur — sonnet

- **Tujuan:** Jadwal Grup + Gugur: label `.grp` "Grup A", subjudul fase, tanpa Istirahat, court tanpa match tidak
  tampil, "Buat bagan" (pola 06v) → sheet pilih slot (20i–20l, dari `qualifierPlan`) → dialog (20g/20k/20o) →
  `createBracket`; tab round gugur dengan `roundTab`/`roundTitle`, baris gugur "SF1 · Race to 6" + kode slot, sisi tbd
  "Pemenang SF1", tab "Bagan" di ujung kanan (isi = widget kosong yang diisi GG-9), strip tab memudar kiri-kanan (21v).
- **Baca:** `screens/20-…` (20a–20c, 20e, 20g, 20i–20m, 20o–20q), `screens/21-…` (21b, 21c, 21e, 21f, 21i, 21o, 21q,
  21s, 21v); `logic.md` §18.7, 18.10; `schedule_fixed_screen.dart`, `widgets/schedule_match_row.dart`, `round_tabs.dart`.
- **Sentuh:** `lib/features/schedule/schedule_fixed_screen.dart`, `lib/features/schedule/widgets/**`,
  `lib/features/schedule/group_knockout/` (baru: sheet, dialog, stub Bagan); test
  `test/hifi/screens/grup_gugur_jadwal_test.dart` (baru).
- **Kriteria terima:** golden semua frame di atas; AC-G6 (Buat bagan hilang kalau satu match Belum), AC-G7 (Batal/
  tutup app → tanpa perubahan); golden Jadwal Fixed/sparing/tambah round lama lolos tanpa diubah.
- **Bergantung:** GG-4.

## GG-8 · Klasemen grup + Peringkat akhir + Detail — sonnet

- **Tujuan:** Klasemen Grup + Gugur: sebelum bagan tabel per grup tanpa tab metode; setelah bagan tab Peringkat
  (`finalEntries`, kolom Babak = `stage`) + Fase grup (tabel + slot A1/A2 dari `seedOf`); subjudul "Grup + Gugur".
  Detail: angka fase grup, label "Grup A · Race to 6", riwayat semua match dengan label babak, tanpa "Beda lawan".
- **Baca:** `screens/20-…` 20d, 20f, 20h, 20n; `screens/22-…` 22a–22k; `logic.md` §18.6, 18.9, 18.10 (Detail);
  `leaderboard_screen.dart`, `detail_player_screen.dart`.
- **Sentuh:** `lib/features/leaderboard/**`, `lib/features/detail_player/**`; test
  `test/hifi/screens/grup_gugur_klasemen_test.dart` (baru).
- **Kriteria terima:** golden 20d, 20f, 20h, 20n, 22a–22k; nomor dari `position` (bukan indeks); golden Peringkat/
  Detail lama lolos tanpa diubah.
- **Bergantung:** GG-4.

## GG-9 · Bagan + Input Skor/WO gugur — opus

- **Tujuan:** widget Bagan (`.bagan`: 2 grup dua kolom 172/14; 4 grup geser per kolom 160/14 dengan intip 10 pt,
  posisi geser awal; kartu, garis penghubung tinta/abu, titik bola, WO di kolom skor, Final/Juara 3 tanpa kode; ketuk →
  Input Skor kalau bisa diisi); Jadwal terbuka di tab Bagan setelah Buat bagan (21a). Input Skor/WO memakai
  `formatFor` (keypad, subjudul babak), `flipCheck` (dialog 21k, pesan 21l, tanpa dialog 21m), teks WO per babak (21n).
- **Baca:** `screens/21-…` 21a, 21d, 21g, 21h, 21j–21n, 21p, 21r, 21t, 21u, 21w–21y; CSS `.bagan` hanya ada di
  `design/hifi.html` (`grep -n '\.bagan' design/hifi.html`, baris ±676; baca blok itu saja, jangan file utuh) dan
  `.gg-*` di `components.md`; `logic.md` §18.8, 18.12 #4 #7; `score_input_screen.dart`, `walkover_sheet.dart`.
- **Sentuh:** `lib/features/schedule/group_knockout/bagan_view.dart` (+ widget kartu), `lib/features/score_input/**`;
  test `test/hifi/screens/grup_gugur_bagan_test.dart`, `grup_gugur_input_skor_test.dart` (baru).
- **Kriteria terima:** golden semua frame di atas; AC-G9, AC-G10 (21h 6–2 tidak bisa diketik), AC-G11 lewat layar;
  golden Input Skor lama (07a–07o) dan sparing lolos tanpa diubah.
- **Bergantung:** GG-7.

## GG-10 · Bagikan + caption + live — sonnet

- **Tujuan:** poster Ringkas/Lengkap dari `finalEntries` dengan kolom kanan `stage` (22l–22r), fakta "8 pasangan · 8
  round · 16 match", baris kecil "Padel · Grup + Gugur · tanggal"; caption "n. A + B — Juara" dan "Hasil per Round" dengan
  label babak (sisi tbd → `sourceLabel`); live penonton: Jadwal + Klasemen Grup + Gugur tanpa tab Bagan dan tanpa aksi
  (AC-G17).
- **Baca:** `screens/22-…` 22l–22r; `logic.md` §18.9, 18.10 (Bagikan, Live), §16, §17; `share_content.dart`,
  `result_text_builder.dart`, `features/live/**`.
- **Sentuh:** `lib/features/share/**`, `lib/services/share/result_text_builder.dart`, `lib/features/live/**` (hanya
  sembunyikan Bagan/aksi); test `test/hifi/screens/grup_gugur_bagikan_test.dart` (baru), kasus baru di
  `test/services/result_text_builder_test.dart`, `test/hifi/screens/live_test.dart` (kasus baru).
- **Kriteria terima:** golden 22l–22r; caption 22l dan 22p persis; AC-G18 (podium 16F, tanpa juara 3 empat anak tangga);
  golden Bagikan lama (11a–11m, 13q–13w, 18a–18t) dan test caption lama lolos tanpa diubah.
- **Bergantung:** GG-4 (layar Jadwal live mengikuti GG-7 — kalau GG-7 belum merge, kerjakan bagian live terakhir).

## GG-11 · Rilis 3.8.0 — main session + tech-lead

- Versi 3.8.0 + `appVersion` (MINOR); `docs/architecture.md` (bagian Grup + Gugur), `docs/ui-v2.md` (frame 19–22, nama
  widget), `CLAUDE.md` (Arsitektur/Pitfalls oleh tech-lead; Status oleh main session); `docs/security.md` butir decode
  (main session); full `flutter test` + golden semua frame; `tool/build_web.sh` + Chrome untuk live (Pitfalls web).
- Uji di HP (host): alur 16A penuh offline (AC-G19).


# (lama) Task — Poster Lengkap arah B "Podium mini" (rencana 3.7.0, MINOR)

Pemilik: tech-lead. Daftar task sebelumnya (Poster podium PP-n, selesai, rilis 3.6.0) ada di riwayat git:
`git show 3a95d55:docs/tasks.md`.

## PATCH 3.7.1 · ukuran & perataan poster (umpan balik host uji HP 2026-11-13) — SELESAI, belum push

Status 2026-11-13: keputusan 91–92 di PRD; hi-fi final 2667bfd + kontras kepala memudar 6 pt 6afbde6 (disetujui host:
4 ekstrapolasi, kontras ≥ 4,5, 6 pt cukup); painter + `court_floor.dart` + golden; suite penuh lolos (1180); versi
3.7.1+23. Sisa: push ke `main` setelah host bilang (deploy web), publish artifact hi-fi, uji share di HP.

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
