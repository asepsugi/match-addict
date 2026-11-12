# Task — Tukar pemain (Mixed) 3.5.0

Pemilik: tech-lead. Sumber: PRD §15 (T1–T10, 15A/15B/15C, tabel 15.4, AC-T1…T17) + keputusan 48–59 (§10),
`design/spec/logic.md` §15 (service, invariant, data test, jebakan, pertanyaan terbuka 15.7),
`design/spec/screens/17-tukar-pemain-mixed.md` + frame 17a–17r, `components.md` → `MatchScoreRow` (`.team .w.swap`).
Daftar task sebelumnya (Mexicano MX-n + Konfigurasi KF-n, selesai) ada di riwayat git: `git show fd5f70f:docs/tasks.md`;
Sparing SP-n: `git show 8af509b:docs/tasks.md`.

Aturan untuk semua task:
- Kerja di branch `tukar-pemain` (worktree per agen), **bukan** `main`: tiap push ke `main` = deploy. Rilis 3.5.0 = satu
  merge (TP-3) atas perintah host.
- Fixed, Mexicano, dan turnamen Mixed tanpa tukar tidak berubah: semua test lama lolos tanpa diubah. Golden yang boleh
  berubah **hanya** frame Jadwal yang digambar ulang dengan ikon di fd5f70f: 06f, 06h, 06i, 06j, 06k, 06o, 06p, 06q,
  06s, 06u, 08e, 08g, 08h, 08i, 08j, 08k, 12a, 12b, 12c, 12d, 12e, 12g, 13m, 15b, 15c, 15d, 15e, 15g, 15h, 15n, 15p
  (31 frame), plus frame baru 17a–17r. Test golden-nya tidak diubah kecuali menambah assert jumlah ikon.
- Logika hanya di `lib/services/**` dengan test; widget tidak menyaring kandidat, tidak menghitung prioritas, tidak
  menukar pemain sendiri. Mutator berakhir di `state =` (tanpa `saveActive`, tanpa kirim live). Jebakan wajib dibaca
  sebelum mulai: `logic.md` §15.6.
- Nama test memakai ID AC PRD (`AC-T3 …`) dan id frame golden (`17e …`).
- Golden: data persis frame, `clockProvider` di-override; golden 2% bisa lolos tanpa ikon 16 pt, jadi jumlah ikon
  dicek dengan finder (`logic.md` §15.6 #9).
- `dart format` lebar 120 hanya untuk berkas baru dan hunk sendiri.
- Engineer dan reviewer hanya menjalankan test yang disentuh perubahannya; `flutter test` penuh sekali per merge di
  main session. Kategori semua task: MINOR (bagian dari 3.5.0); versi dinaikkan di TP-3 saja.
- Tidak ada perubahan simpanan (`logic.md` §15.1): DBA dan security tidak perlu task. Kalau engineer merasa perlu
  menyentuh `lib/services/storage/` atau `relay/`, berhenti dan laporkan.

## Peta urutan

| Gelombang | Task | Agen |
|---|---|---|
| 1 | TP-1 (logika + controller) | 1 |
| 2 | setelah TP-1 di-merge ke branch: TP-2 (ikon, sheet, golden) | 1 |
| 3 | TP-3 rilis (main session + QA) | 1 |

Tidak ada yang paralel: TP-2 butuh `PlayerSwap` dan `swapPlayer` untuk ikon dan untuk golden 17e/17m/17q, dan
keduanya kecil. Berkas bersama TP-1 ↔ TP-2: tidak ada (TP-2 hanya memanggil API TP-1; fixture service TP-1 dipakai
ulang oleh fixture golden TP-2).

Sebelum TP-2 sampai di 17h, main session menanyakan `logic.md` §15.7 ke host (urutan nama "Citra, Andi" vs
"Andi, Citra"). Sampai dijawab, golden 17h `skip` dengan alasan; task lain tidak tertahan.

---

## TP-1 · Tukar pemain: service + controller
- **Goal:** `logic.md` §15.1–§15.4: `PlayerSwap` (isSwappable, isCandidate, canSwapTeam, candidates, swapped, apply),
  `EndlessRoundGenerator.pairId`, `TournamentController.swapPlayer`, dengan test data 15A/15B/15C dan properti.
- **Baca:** `logic.md` §5, §6, §10 (Kelola court, hapus court), §15; PRD 15.1, 15.3–15.6; `models.dart`
  (`ActiveTournament`: `activePlayers`, `restingPlayersByClub`, `latePlayerIds`, `canCancelLastRound`,
  `canRemoveCourt`, `copyWith`); `endless_round_generator.dart` (`priorityOrder`, `restingAfterLastRound`,
  `restingByClubAfterLastRound`, `courtUse`, `_pairOf`/`_pairKey`); `tournament_controller.dart` (`generateNextRound`,
  `cancelLastRound`, `removeCourt`, `_placeCourt`, `finishNow`, `resume`); test `mixed_priority_test.dart`,
  `court_manage_test.dart`, `mixed_roster_test.dart` (pola fixture), `test/hifi/screens/sparing_mixed_fixture.dart`
  (15C), `schedule_fixture.dart` (`courtTournament`, pola id yang dipilih untuk undian).
- **Ubah:** `lib/services/schedule/player_swap.dart` (baru), `lib/services/schedule/endless_round_generator.dart`
  (hanya `static String pairId(String a, String b) => _pairKey(a, b);` + dok), `lib/features/schedule/tournament_controller.dart`
  (`swapPlayer` saja). **Tidak** menyentuh `models.dart`, codec, relay, layar.
- **Test baru:** `test/services/player_swap_fixture.dart` (fixture 15A/15B literal dengan id turnamen hasil pencarian
  undian §15.4 + komentar alasan; skrip pencari dihapus), `test/services/player_swap_test.dart` (AC-T1, T2, T3, T5,
  T6, T7, T8, T9, T10 a/b, T11, T12, T13, T15; invariant §15.3 #8 per alasan tolak; AC-T16 `git diff` dicek reviewer,
  bukan di test),
  `test/services/player_swap_property_test.dart` (§15.4 Properti, suite biasa, < 10 detik).
- **Acceptance:** semua baris tabel §15.4 hijau di level service/controller; Buat setelah Batalkan/tukar balik hanya
  dibandingkan sebagai himpunan pemain (§15.6 #7); kesamaan penuh lewat `TournamentCodec.encode` byte-sama; test lama
  `mixed_priority_test`, `court_manage_test`, `mixed_roster_test`, `sparing_*`, `mexicano_*`, `tournament_store_test`
  lolos tanpa diubah; `git diff` di `lib/services/storage/`, `lib/models/`, `relay/` kosong; `flutter analyze` tanpa
  peringatan baru.
- **Dependensi:** tidak ada. **Model:** default engineer, sonnet / medium (aturan kecil dan sudah dirinci; yang licin
  hanya pencarian id undian dan invariant #6, keduanya tertulis di spec).
- **Review:** tech-lead, diff saja, daftar periksa §15.3 + §15.6 (opus / medium). Re-review diff perbaikan: main
  session.

## TP-2 · Ikon tukar di Jadwal + sheet "Tukar pemain" + golden
- **Goal:** keputusan 58–59, frame 17a–17r, ikon di 31 frame Jadwal lama; AC-T1 (UI: ikon hanya di tempat yang sah,
  penonton tanpa ikon), AC-T4 (batal tanpa perubahan), AC-T14 (penonton tanpa aksi), AC-T15 (tanpa tanda "ditukar").
- **Baca:** `logic.md` §15.5–§15.7; `screens/17-tukar-pemain-mixed.md` + PNG 17a–17r; `components.md` → `MatchScoreRow`
  (`.team .w.swap`, area ketuk di Komponen `.bug`, `design/hifi.html` sekitar baris 839–840) dan `MabarChip`
  (`.chips.cols`), `showMabarSheet`; `docs/ui-v2.md` → Golden; `core/widgets/match_score_row.dart`,
  `features/schedule/widgets/schedule_match_row.dart`, `features/schedule/schedule_mixed_screen.dart`, sheet WO
  (pola judul/subjudul + tombol mati), `widgets/resting_list.dart` (label); test `test/hifi/screens/jadwal_mixed_test.dart`,
  `jadwal_mixed_sparing_test.dart`, `kelola_court_test.dart`, `live_test.dart`, `test/hifi/components/schedule_test.dart`.
- **Ubah:** `lib/core/theme/mabar_icons.dart` (`arrowsLeftRight`, codepoint dari `style.css` `@phosphor-icons/web@2.1.1`),
  `lib/core/widgets/match_score_row.dart` (aksi tukar opsional per sisi, ikon 16 pt di kolom bola, area ketuk 44 × 42,
  label aksesibilitas), `lib/features/schedule/widgets/schedule_match_row.dart` (dua callback),
  `lib/features/schedule/schedule_mixed_screen.dart` (isi callback hanya kalau `!watching && PlayerSwap.canSwapTeam`),
  `lib/features/schedule/mixed/swap_player_sheet.dart` (baru). Golden: `test/hifi/screens/tukar_pemain_test.dart` +
  `swap_fixture.dart` (baru; 17a–17i dari fixture TP-1, 17j dari `courtTournament` R5 = 06p, 17k–17m dari
  `sparing_mixed_fixture` R4 13B, 17n literal Garuda 4 / Matcha 6, 17o–17q AC-T11/T12, 17r 8 pemain / 2 court R2).
  Frame sesudah tukar (17e, 17h, 17m, 17q) dibuat dengan **mengetuk** ikon → chip → Tukar di test, bukan fixture
  literal. Golden komponen baris berikon di `components/schedule_test.dart` kalau wilayah Komponen-nya bisa diambil.
- **Test baru:** widget test AC-T4 (Batal, scrim, back → state `identical`, store tidak ditulis), Tukar mati sampai
  dua pilihan, satu pilihan lintas grup kandidat (17j), ketuk ulang = lepas, sheet tertutup tanpa toast; jumlah ikon
  per frame (§15.6 #9) termasuk 06a (Fixed), 06m (diakhiri), 06t (round lewat), 16b (Mexicano), 12h (penonton) = 0;
  `find.text` "Round 4 · Court 2 · Matcha Club" (17l).
- **Acceptance:** golden 17a–17r lolos (17h menunggu §15.7); 31 golden lama lolos **tanpa mengubah fixture**-nya
  (kalau aturan dan frame berbeda: berhenti, laporkan, §15.6 #10); golden lain tidak berubah; `flutter analyze` tanpa
  peringatan baru.
- **Dependensi:** TP-1 di-merge ke branch. **Model:** default engineer, sonnet / medium.
- **Review:** main session (diff + golden terkait), seperti MX-2; tidak ada logika baru. Tech-lead hanya kalau diff
  menyentuh `lib/services/**` atau controller.

## TP-3 · Rilis 3.5.0 (main session)
- **Goal:** `pubspec.yaml` 3.5.0+19, `appVersion` 3.5.0. Docs: `docs/architecture.md` → Mixed (butir "Tukar pemain":
  `PlayerSwap`, `swapPlayer`, invariant §15.3 ringkas, Mexicano/Fixed tidak), `docs/data.md` → baris "Riwayat bentuk
  simpanan" 3.5.0 (tanpa kunci baru; `resting[n]` bisa berubah oleh tukar dan boleh berisi pemain yang dikeluarkan;
  codec tidak berubah, bukti `logic.md` §15.1), `docs/ui-v2.md` (golden 17a–17r + ikon tukar di `MatchScoreRow`),
  `logic.md` status baris 7 (§15 diimplementasi), `CLAUDE.md` (status, riwayat versi 3.5.0, baris `docs/tasks.md` di
  Area docs: "sekarang: Tukar pemain TP-n"), header PRD §15 (PM).
- **Acceptance:** `flutter analyze` tanpa peringatan baru; `flutter test` penuh lulus; `tool/build_web.sh` sukses +
  precache 200. QA (sonnet / medium): AC-T13 di Chrome (tukar → tutup tab → buka lagi), AC-T14 dua tab (host 3.5.0
  build lokal + penonton) dan link live dari build 3.5.0 dibuka di web produksi 3.4.0 → match hasil tukar tampil benar
  (bukti nyata AC-T16), AC-T17 offline. Merge `tukar-pemain` → `main` hanya atas perintah host.
- **Security:** tidak perlu agen terpisah: tidak ada jalur input, decode, atau dependensi baru.
- **Dependensi:** semua.
