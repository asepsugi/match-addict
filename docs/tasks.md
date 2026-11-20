# Task — 3.9.0 Kosongkan skor + perilaku kecil + visual/frame (MINOR)

Pemilik: main session. Branch `fitur-3-9-0` (dari `main` 9b2d902, 3.8.1+25 yang belum di-push). Produk: PRD §17 (aturan
K1–K8, UI 17.2, tabel mode 17.3, dampak 17.4, contoh 17A–17E, AC-K1–K14, P5 17.10 + AC-P1–P5, C-17 17.11 + AC-B1) dan
keputusan 113–121. Sumber temuan: `design/review/ux-review*.md` (status keputusan di `ux-review.md`). Isi: P7 Kosongkan
skor / Hapus WO · P5 (A-8, A-9, B-10, B-21) · C-17 · P6 visual (C-7, C-18, C-15) · P4 (frame + catatan). **Di luar
rilis ini (3.10.0):** GU9 + A-15 (skala teks 1,3: ukur dulu).

Aturan semua task: hi-fi dulu, lalu spec, lalu kode; golden `expectMatchesHifi` setelah `python3 tool/hifi_extract.py`
(`docs/ui-v2.md`); `dart format` hanya hunk sendiri; tanpa dependensi baru (B-10 native hanya kalau tanpa izin/dependensi
baru, selain itu "Hasil disalin" tetap); wording UI + "tanpa kalimat penjelas" berlaku; versi 3.9.0+26 + `appVersion`
hanya di task rilis. **Maks 3 agen paralel, satu agen per kelompok frame (hanya melihat frame-nya sendiri, cek dengan
skrip/lembar kontak), agen berhenti ~150k konteks.** Mulai sesi baru (`/clear`) per fase.

## Urutan

| Task | Isi | Siapa | Dicek |
|---|---|---|---|
| KS-0 | PRD §17 + keputusan 113–121 | product-manager (selesai 2026-11-18), jawaban host = keputusan 121 | dab6e14 |
| KS-1 | Hi-fi kelompok A (Kosongkan/Hapus WO). Ubah 07i, 07j. Baru: Input Skor kedua kotak kosong → "Kosongkan skor"; dialog Kosongkan (court · gugur dengan susunan baru · setelah diakhiri); gugur diblok (21l, Kosongkan mati); sheet WO + "Hapus WO"; dialog Hapus WO (tanpa skor lama · skor lama 6–4); Fixed round dikunci lagi (R4 terkunci, catatan "R3", seri 06). Baca PRD §17.1–17.6 | ui-ux-designer opus/high | main session |
| KS-2 | Hi-fi kelompok B (P5). Ubah 02b ("Tempel · Urungkan"), 04b + 04g (dialog "Buang 3 pasangan manual?", "Buang perubahan pasangan?"), 11c (toast "Gambar diunduh · hasil disalin"). Baca PRD §17.10 | ui-ux-designer opus/high | main session |
| KS-3 | Hi-fi kelompok C1: 20b "Buat bagan · tunggu 7 match" (§17.11); C-7 bagan 21u–21y mengintip 24 pt + label kolom; C-18 label 12 → 13 px (`.grp`, `.gg-babak`, `.bagan .mh/.ch`); C-15 pratinjau Tukar 17d/17g/17l nama masuk tebal; B-16 samakan data uji; C-12 verifikasi catatan "menunggu host" sisa | ui-ux-designer opus/high | main session |
| KS-4 | Hi-fi kelompok C2 (P4 frame baru): B-7 Klasemen 30 pemain nama panjang, B-8 penonton tanpa internet, B-9 toast Hentikan offline, B-18 Detail Win % desimal, C-3 sheet Tukar 22 kandidat, C-4 Beranda Grup + Gugur + dialog mulai baru, C-10 error Sparing tahap 2 + "Pilih klub" | ui-ux-designer opus/high (setelah KS-1…3, maks 3 paralel) | main session |
| KS-5 | B-22 aturan pemisah "·" / "&" / "+" di `components.md`; Cakupan "Sudah disetujui"; render ulang (`tool/hifi_extract.py`), cek noise; publish ulang artifact `H9ZVDUfYvEBXsoBqih4iov` | main session | — |
| KS-6 | Spec + tugas kode: `design/spec/logic.md` §19 (K1–K8, aturan ketersediaan 17.3, selesai → batal, aturan catatan kunci 17.4, mengosongkan gugur = GU11 tanpa pemenang, kalimat B-21, B-10 gagal vs share sheet ditutup, N di C-17, data uji 17A–17E) + pecah tugas kode + tandai mana yang butuh model kuat | tech-lead opus/high (boleh paralel dengan KS-4) | — |
| KS-7 | Kode dari spec KS-6 (`design/spec/logic.md` §19), golden per frame baru; dipecah KS-7a…KS-7e di bawah | engineer: KS-7a opus/medium, sisanya sonnet | review logika: fresh tech-lead; layar: main session |
| KS-8 | Cek web B-10 (`tool/build_web.sh` + Chrome); full test sekali | main session | — |
| KS-9 | Rilis 3.9.0+26 + `appVersion`, merge ke `main`, push (deploy) hanya setelah host bilang, status CLAUDE.md + memory | main session | — |

### Jebakan dari PM untuk tech-lead (KS-6)

1. `MatchGame.copyWith` tidak bisa mengembalikan `woLoserPairId`/`woReason` ke null: mengosongkan butuh konstruktor ala
   `_with` yang tetap membawa `phase`.
2. `flipCheck` butuh pemenang non-null; mengosongkan butuh varian. Hapus WO yang kembali ke skor lama dihitung sebagai
   perubahan pemenang.
3. `_confirmFlip`: `FlipBlocked` mengembalikan true dan layar langsung tutup, jadi pesan 21l harus tampil di UI.
4. Match grup setelah Buat bagan masih terbuka di Input Skor dan simpan diam-diam tidak berbuat apa-apa: Kosongkan/Hapus WO
   wajib cek `isGroupKnockoutLocked` di UI juga.
5. Catatan kunci di `schedule_fixed_screen.dart:201` selalu menyebut R(terpilih−1): salah setelah ada yang dikosongkan;
   pakai aturan 17.4.
6. `share_result_screen.dart:67` memakai `catch (_)`: menutup share sheet (atau galat render) bisa memicu unduhan; pisahkan.
7. Best of/Americano: mengosongkan kotak dengan ⌫ tidak boleh mengisi otomatis kotak lawan.
8. Keadaan data baru (round lama Fixed kosong padahal round sesudahnya berskor; SF dikosongkan dengan Final yang menulis
   "Pemenang …") harus tetap termuat dari simpanan 3.8.x, decoder, dan payload live.
9. Setelah diakhiri, match Fixed yang dikosongkan jadi "Tidak dimainkan" dan tidak bisa diisi lagi.

Ditangani di spec (KS-6, 2026-11-20): #1 → §19.1; #2 → §19.2 langkah 4; #3 → §19.5; #4 → §19.2 langkah 2; #5 →
§19.1 `lockedBy`; #6 → §19.7 B-10 (fakta share_plus 10.1.4 di sana: ditutup = `dismissed`, bukan exception); #7 → §19.5;
#8 → §19.9; #9 → §19.6 `AC-K11 17A-iii`. Ringkasan untuk reviewer: §19.11.

### KS-7 rincian (tech-lead, 2026-11-20)

Urutan: **gelombang 1 paralel** KS-7a + KS-7c + KS-7d (berkas tidak bersinggungan, worktree masing-masing) → review
KS-7a oleh tech-lead fresh → **gelombang 2** KS-7b (butuh API KS-7a dan baseline golden 20x dari KS-7d) → KS-8. Tiap
task: baca `CLAUDE.md`, §19 (bagian yang disebut), dan frame-nya sendiri saja; `flutter analyze` + test berkas sendiri;
full test sekali di KS-8. Semua MINOR; tanpa dependensi baru; tanpa naik versi.

| Task | Isi | Berkas (baca/ubah) | AC ditutup | Test + golden wajib | Model | Bergantung |
|---|---|---|---|---|---|---|
| **KS-7a** Inti logika | §19.1–19.3, 19.5 (aturan ⌫ + `isEmpty` saja), 19.6, 19.9: `cleared`/`withoutWalkover`, `lockedBy`, `pendingGroupMatches`/`waitsForBracket`; `flipCheck(…, String?)`; `ScoreReset.check/apply` (baru); `ScoreEntry.backspace` + `isEmpty`; controller `clearScore`/`removeWalkover` (satu `state =`). Tanpa UI | `lib/models/models.dart`, `lib/services/schedule/knockout_bracket.dart`, `lib/services/scoring/score_reset.dart` (baru), `lib/services/scoring/score_entry.dart`, `lib/features/schedule/tournament_controller.dart`; baca `tournament_codec.dart` | AC-K3 (logika), K4, K5, K6 (logika), K7, K8 (logika), K9 (logika), K10, K11, K13, P5, B1 (hitungan) | `score_reset_test.dart` + `score_reset_fixture.dart` (17A–17E persis §19.6), properti R1–R7 + I7–I9, roundtrip codec §19.9, `score_format_test` ⌫, model (`phase` terbawa, `lockedBy`, N), controller (tersimpan, false tanpa perubahan). Tanpa golden | **opus/medium** (lintas modul + varian GU11) | — |
| **KS-7c** P5 layar | §19.7 A-8, A-9, B-10 (B-21 sudah di KS-7a) | `lib/features/setup_peserta/setup_peserta_screen.dart`, `…/widgets/name_list_field.dart`, `lib/features/pair_setup/pair_setup_screen.dart`, `lib/features/pair_edit/pair_edit_screen.dart`, `lib/services/pairing/pair_draft.dart` (`differsFrom`), `lib/features/share/share_result_screen.dart`, `lib/features/share/share_download.dart` + `_stub`/`_web` (baru) | AC-P1, P2, P3, P4 (logika; web di KS-8) | test `PairDraft.differsFrom`; widget Pemain/Pasangan/Atur pasangan; fungsi tahap Bagikan (§19.7); golden **02e, 04i, 04j, 11c, 11n, 11a** (11a/11c data = 09a, B-16) + 02b/04b/04g tetap lulus | sonnet/medium | — |
| **KS-7d** P6 visual | C-15 nama masuk tebal di pratinjau Tukar (`.swap-in`); C-18 label 12 → 13 px (`.grp`, `.gg-babak`, `.bagan .mh/.ch`); C-7 bagan kolom 153, jarak 14, mengintip 24 pt (`design/spec/screens/21-…md`) | `lib/features/schedule/mixed/swap_player_sheet.dart`, `lib/core/widgets/match_score_row.dart` (`.grp`/`.gg-babak`), `lib/features/schedule/group_knockout/bagan_view.dart`; **jangan** sentuh `schedule_fixed_screen.dart` | — (visual, keputusan 120) | golden **17d, 17g, 17j, 17l, 17p, 21a–21z yang berubah, 22j, 22k**, dan frame 20x yang lulus; frame 20x yang masih gagal hanya karena tombol "Buat bagan · tunggu N" ditulis di laporan → KS-7b | sonnet/low | — |
| **KS-7b** Layar Kosongkan / Hapus WO + C-17 | §19.4 (catatan kunci), 19.5, 19.8: tombol "Kosongkan skor" (varian baru `.btn-secondary.danger`), dialog per `outcome` + preview, pesan 21l mati, sheet WO "Hapus WO" (`MabarSheet.action`, hasil sealed), pop hanya kalau `true`; `lockedBy` di catatan kunci; action bar "Buat bagan · tunggu N" | `lib/features/score_input/score_input_screen.dart`, `walkover_sheet.dart`, `knockout_text.dart` + teks dialog (`reset_text.dart`, baru, murni), `lib/core/widgets/mabar_controls.dart` (varian), `lib/core/widgets/mabar_layers.dart` (`action` di `showMabarSheet` kalau perlu), `lib/features/schedule/schedule_fixed_screen.dart` | AC-K1, K2, K3, K5, K6, K8, K9, K11 (layar), K12 (tanpa aksi penonton), B1 | test teks dialog (judul court/kode, tiga isi, preview tbd), widget Input Skor (AC-K1/K2, 07s, 07x, blocked tidak pernah pop), sheet WO (AC-K3), catatan kunci 17A-ii; golden **07p, 07q, 07r, 07s, 07t, 07u, 07v, 07w, 07x, 06aa, 06ab, 06ac, 20b** + 20x sisa dari KS-7d; 07i/07j/06a–06c tetap lulus | sonnet/medium | KS-7a (review lolos), KS-7d |
| **KS-7e** P4 | Keputusan 128: kode B-7 (09h), B-8 (12p), C-3 (17s/17t), C-4 (22s–22u, teks nama format ikut GL), C-10 (15z2); golden saja B-9 (12q), B-18 (10e) | ditentukan saat brief | — | golden 09h, 10e, 12p, 12q, 15z1–15z4, 17s, 17t, 22s–22u | sonnet/medium | KS-7b, GL |

- Review: KS-7a → tech-lead fresh (diff + §19.11, jalankan test-nya sendiri) sebelum KS-7b mulai. KS-7b/7c/7d → main
  session (diff + golden). `docs/architecture.md` (bagian Kosongkan skor / Hapus WO) ditulis tech-lead saat review
  KS-7a. Tidak perlu DBA (§19.9: tanpa kunci baru, `schemaVersion` tetap 2); kalau KS-7a ternyata butuh kunci baru →
  berhenti dan lapor.
- KS-8 tambahan: Atur pasangan + back browser (A-9), unduh dua file di Chrome desktop dan Safari (B-10, §19.12 #2).

### Status (2026-11-20, sesi ketiga)

- Host "setuju" semua: 9 rekomendasi KS-4 = **keputusan 128**, Point % 18.11 = **keputusan 129**, GL 127 a–c dikonfirmasi.
  PRD, Cakupan hi-fi, `docs/data.md` (#9), aturan pemisah B-22 (hi-fi `#pemisah` → `components.md`) diperbarui = KS-5.
- KS-7e (dipilah main session dari keputusan 128): kode = B-7 (09h, nama Mixed dua baris), B-8 (12p, "Tidak ada
  internet" + "Coba lagi"), C-3 (17s/17t footer sheet Tukar), C-4 (22s–22u, nama format + babak di Beranda/dialog;
  teks ikut GL), C-10 (15z2 "Pilih klub"); golden saja = B-9 (12q), B-18 (10e). Frame #8 (sheet WO gugur "Hapus WO"
  mati) masih menunggu designer — gabung dengan RP-1/GL.
- Berikutnya: KS-7 gelombang 1 (7a + 7c + 7d paralel).

### Status (2026-11-20, serah terima ke sesi baru — lama)

- KS-0 selesai (dab6e14). KS-1…KS-3 digabung (4c75cbd), hi-fi v98 disetujui host 2026-11-20 tanpa catatan.
- KS-4 selesai: 13 frame P4 (09h, 10e, 12p, 12q, 15z1–15z4, 17s, 17t, 22s–22u), hi-fi v99 terbit. KS-6 selesai: spec
  `logic.md` §19 + rincian KS-7a…KS-7e (di atas). Keduanya di b0d1e7f.
- **Langkah pertama sesi baru:** konfirmasi singkat ke host 9 rekomendasi di bawah (host menjawab "oke" 2026-11-20
  bersamaan dengan permintaan serah terima; pastikan itu persetujuan sebelum mengubah PRD), lalu catat sebagai keputusan
  bernomor (lanjut dari 121) di PRD §17 + hi-fi + Cakupan, dan perbarui KS-7e.
  1. B-7 (09h): nama Mixed panjang dua baris (tinggi 62), bukan potong satu baris → kode + ubah 09h.
  2. B-8 (12p): penonton tanpa internet → "Tidak ada internet" + "Coba lagi" (sekarang memuat terus = 12o) → kode + ubah 12p.
  3. B-9 (12q): perilaku app dipertahankan (sheet tetap terbuka, toast di atasnya) → golden saja.
  4. B-18 (10e): Detail membulatkan Win % (`winPercent.round()`); perbaiki catatan 09b ("1 desimal" salah) → golden saja.
  5. C-3 (17s/17t): Batal/Tukar ke slot footer `MabarSheet` (menempel), pratinjau tidak ikut digulir → kode + ubah 17s/17t.
  6. C-4 (22s–22u): Beranda/dialog Grup + Gugur tulis "Grup + Gugur" + nama babak ("Semifinal"), bukan "Fixed"/"Round 7"
     → kode + gambar ulang 22s–22u.
  7. C-10: "Pilih klub" (15z2) sudah sesuai usulan disetujui; kode ganti "Tambah" mati di KS-7. Dua varian Sparing (Kelola
     court "mulai R…", Tukar 12 kandidat) ditunda, digambar nanti dengan fixture `tool/sparing_proto`.
  8. Frame baru: sheet WO gugur dengan "Hapus WO" mati + pesan 21l (desainer, kelompok kecil).
  9. `docs/data.md` + satu baris: keadaan data baru 3.9.0 (round Fixed lama kosong, SF dikosongkan) tetap sah di GR13–GR16,
     `schemaVersion` 2 (main session).
- Setelah itu: KS-5 (B-22 pemisah di `components.md`, Cakupan "Sudah disetujui", render, publish) → KS-7 gelombang 1
  (7a opus/medium + 7c + 7d paralel, worktree, base = HEAD `fitur-3-9-0`) → review 7a fresh tech-lead → 7b → 7e → KS-8 → KS-9.
- Catatan tech-lead: B-10 di 3.8.1 web sudah mengunduh sendiri lewat fallback share_plus tanpa caption/toast; spec
  mematikan `downloadFallbackEnabled`. Risiko unduhan ganda Chrome / share Safari setelah render async → cek di KS-8.
- 3.8.1+25 masih belum di-push (ditahan host).
- Ide ranking sudah dibahas (2026-11-20) → jalur **RP** di bawah. Rename "Grup + Gugur" → jalur **GL** di bawah.

### Jalur RP · Point % (keputusan 122–126, PRD §18) — serah terima 2026-11-20 (sesi kedua)

Hasil ukur (simulasi main session, 600 turnamen/skenario, Mixed 7–16 pemain, Americano 21 + Race to 6): Total Point
merugikan pemain yang main lebih sedikit (0,7–1,3 posisi); Point % paling tepat dan adil; Win % tetap (keputusan 21
"menang dulu"). Host setuju 4 usulan: persen, tab ketiga (Total Point tetap ada), default Americano + urutan Mexicano →
Point %, WO = "nilai WO – 0", masuk 3.9.0 (MINOR), tanpa perubahan data. PRD §18 ditulis product-manager (belum
di-commit; angka contoh dihitung tangan, belum dibuktikan test).

**Langkah pertama sesi baru:** tanyakan host 3 pertanyaan PRD §18.11 (rekomendasi: setujui semua), catat sebagai
keputusan bernomor lanjut dari 127:
  1. U-RP2: Point % tampil bulat, nomor dibandingkan dari angka bulat (52,4% dan 51,6% + selisih sama = nomor sama).
     Bergantung B-18 (rekomendasi #4 di atas) — konfirmasi bersamaan.
  2. U-RP6: 2 besar grup Grup + Gugur Americano dipilih dari Point % (ikut default format).
  3. U-RP1, U-RP3–5: urutan tab Total Point · Point % · Win %; "57% poin" di poster/caption; belum main = 0% di urutan
     Mexicano; Point % selalu di statline Detail.
Risiko tercatat di §18.9: turnamen Americano 3.8.x terbuka di Point % (nomor beda dari poster lama); Mexicano berjalan
dipasangkan dari Point %; Grup + Gugur Americano di fase gugur bisa menampilkan label A2 di baris #3. Desainer cek:
"57%" Point % vs Win % tanpa satuan (Story, Lengkap dua kolom); label "Point" bersebelahan "Poin" di Detail.

| Task | Isi | Oleh |
|---|---|---|
| RP-0 | PRD §18 + keputusan 122–126 (selesai, belum commit) + jawaban host 18.11 | product-manager → main session |
| RP-1 | Hi-fi: Klasemen 09a–09h (tab ketiga; 09a Americano buka di Point %), Detail 10a–10e, Bagikan 11a–11m + 18a–18t, penonton live 12-an, Sparing per klub 13n/14-an/15t, Mexicano 16a–16g, tabel grup Americano 20d/22b; Cakupan "Sudah disetujui"; spec `design/spec/screens/09-klasemen.md` (baris 30–31), `16-mexicano.md` (5, 15, 25, 37, 77), `20-grup-gugur.md` (49), `12-live-score.md` (106). Satu agen per kelompok frame, maks 3 paralel | ui-ux-designer opus/high |
| RP-2 | Spec `design/spec/logic.md` §20 + rincian RP-3 di bawah (selesai 2026-11-20, belum commit) | tech-lead opus/high |
| RP-3 | Kode dari §20, dipecah RP-3a…RP-3d di bawah | engineer (lihat rincian) + review RP-3a fresh tech-lead |
| RP-4 | Golden frame berubah, full test ikut KS-8, rilis ikut KS-9 | main session |

### RP-3 rincian (tech-lead, 2026-11-20)

Spec: `design/spec/logic.md` §20 (kontrak kode 20.1–20.7, data test 20.8, invariant 20.9, test 20.10, jebakan 20.11).
Semua angka PRD §18 dihitung ulang dan cocok; yang berubah tanpa ditulis PRD: **R3 AC-M15** dan **R3 fixture 16g**
(20.8, 20.12). Semua MINOR; tanpa dependensi baru; tanpa kunci simpanan baru (DBA tidak perlu; kalau ternyata butuh →
berhenti dan lapor); tanpa naik versi. Tiap task: baca `CLAUDE.md`, §20 bagian yang disebut, frame-nya sendiri saja;
`flutter analyze` + test berkas sendiri; full test sekali di KS-8.

**Urutan:** RP-3a **bisa mulai sekarang** (tanpa frame), paralel dengan KS-7 gelombang 1 → review RP-3a oleh tech-lead
fresh (diff + 20.11, jalankan test sendiri; tech-lead menulis `docs/architecture.md` → Ranking & Mexicano saat review) →
setelah frame RP-1 disetujui: RP-3b ∥ RP-3c (berkas tidak bersinggungan) → RP-3d. **Gabung RP-3a ke `fitur-3-9-0`
bersama RP-3b**, bukan sendiri: RP-3a mengganti default Americano sehingga golden Americano/Mexicano gagal sampai
golden-nya diperbarui (20.11 #12); kalau digabung sendiri, `fitur-3-9-0` merah selama KS-7b/7e/KS-8.

| Task | Isi | Berkas (baca/ubah) | AC ditutup | Test + golden wajib | Model | Bergantung |
|---|---|---|---|---|---|---|
| **RP-3a** Logika | §20.1–20.6: `RankingMethod.pointPercent` + label; `PlayerStanding.woPointsConceded`/`pointsPlayed`/`pointPercent` (bulat bilangan bulat); WO pass atas semua id di `matches`; `woPairValue` (dipakai juga `ClubResult`); `compare`; `defaultMethod`; `mexicanoOrder` Point %; komentar Grup + Gugur/controller. Tanpa UI | `lib/models/models.dart` (enum saja; KS-7a juga mengubah berkas ini di hunk lain), `lib/services/ranking/ranking_calculator.dart`, `lib/services/ranking/club_score.dart` (baris 116–118), `lib/services/schedule/endless_round_generator.dart` (`mexicanoOrder`), `lib/services/ranking/group_knockout_ranking.dart` (komentar), `lib/features/schedule/tournament_controller.dart:115` (komentar; rebase kalau KS-7a sudah masuk) | AC-RP2 (logika), RP3, RP4, RP5, RP6, RP7 (tanpa NaN), RP8, RP11, RP12 (angka), RP13, RP15 (logika) | `point_percent_test.dart` + `point_percent_fixture.dart` (20.8 semua baris non-Mexicano + properti invariant 1–4 termasuk `rank(subset)` = `rank(semua)`); `mexicano_test.dart` AC-M15 + 16g diubah ke 20.8, 18D baru, AC-M4–M7 tidak disentuh; oracle `mexicano_property_test.dart`; `group_knockout_ranking_test.dart` AC-RP13; `sparing_score_test.dart` 13C; provider default AC-RP2 + penonton. Tanpa golden; laporkan golden yang gagal dan cocokkan dengan 20.11 #12 | sonnet/medium (rumus + kontrak persis di §20; jebakan subset 20.11 #5 wajib dicek reviewer) | — |
| **RP-3b** Klasemen + Detail | §20.7 baris Klasemen/Sparing/Detail: tiga tab (urutan U-RP1), nilai + judul kolom lewat `switch` (juga `tableMethod` grup), statline Point % selalu (letak/label dari frame) | `lib/features/leaderboard/leaderboard_screen.dart`, `lib/features/detail_player/detail_player_screen.dart`, komponen statline/tabel di `lib/core/widgets/` hanya kalau frame mengubah bentuknya | AC-RP1, RP2 (layar), RP7 (layar), RP9, RP14 (layar sama) | widget: ganti tab mengurutkan ulang + kolom; Detail "–" belum main; golden **09a–09h, 10a–10e** + frame tab Point % baru dari RP-1 | sonnet/medium | RP-3a (review lolos), frame RP-1 09/10, KS-7e (09h/10e, B-7 tabel) dan GL (string di kedua berkas) sudah digabung atau rebase |
| **RP-3c** Bagikan + caption | §20.7 baris poster + caption: `sharePosterData`/`podiumPosterData` lewat `switch` (Point % = bentuk Total Point dengan nilai "57%"), `ResultTextBuilder.build(…, required method)` | `lib/features/share/share_content.dart`, `lib/features/share/share_result_screen.dart`, `lib/services/share/result_text_builder.dart` | AC-RP10, RP7 (poster/caption) | `result_text_builder_test.dart` (18A baris pertama persis; Total Point/Win % byte-sama), `share_poster_test.dart` + `sparing_share_test.dart` (tambah `method:`; Point % "57%" + detail satuan), golden **11a, 11c** + frame poster Point % dari RP-1 | sonnet/low | RP-3a, frame RP-1 11/18, **KS-7c digabung** (berkas `share_result_screen.dart` dan golden 11a/11c) |
| **RP-3d** Golden sisa | Golden yang berubah hanya karena default/tab/statline, tanpa kode layar: Mexicano, Sparing, Grup + Gugur, penonton | `test/hifi/screens/*` saja (+ fixture kalau frame memakai data baru); kode `lib/` tidak disentuh — kalau perlu, berhenti dan lapor | AC-RP11 (16g), RP12 (layar), RP13 (layar), RP14 | golden **16a–16g** (16g R3 baru), **13n, 13o, 13p, 14p, 14s, 14t, 14u, 15s, 15t, 14v, 14w, 15u, 15v, 20d, 22b, 22j, 22k**, 12x yang menampilkan Klasemen/Detail; frame lain yang tetap lulus disebut di laporan | sonnet/low | RP-3b (statline + tab), frame RP-1 |

**Frame terdampak untuk brief designer RP-1** (tambahan/penegasan atas daftar RP-1 di tabel atas):
- **16g berubah isi**, bukan hanya teks: R3 = Citra·Hadi vs Andi·Joko · Fajar·Dewi vs Indra·Eko (sampai 3.8.x Andi·Eko
  vs Fajar·Dewi · Citra·Joko vs Hadi·Indra); `16-mexicano.md` baris 77–78 ditulis ulang dengan Point % (angka 18D, §20.8).
  16a/16b: urutan Point % = Total Point (tidak ada pasangan berubah), hanya teks "Total Point" → "Point %".
- **Statline Detail di semua frame Detail** (U-RP5), bukan hanya 10a–10e: juga Sparing 14v, 14w, 15u, 15v; Grup + Gugur
  22j, 22k; Detail penonton/Mexicano kalau ada.
- **Sparing Klasemen** dirinci: 13n, 13o, 13p, 14p, 14s, 14t (tab bar tiga, tetap Win %), **14u** (Americano 20) dan
  **15t** (Mixed Sparing Americano 21) terbuka di Point %. Bagikan Sparing 13q–13w (Race to 6) tidak berubah.
- Bagikan: hanya frame berdata Americano yang berubah (11a/11c = data 09a set1 → Point %); designer mencatat mana di
  11b, 11e–11m, 18a–18t yang Americano.
- Angka Point % untuk fixture yang sudah ada (09a/09b set1, 09d–09f set2) di §20.8 baris "Golden data": pakai itu supaya
  golden tidak butuh fixture baru. Frame contoh baru sebaiknya memakai data 18A/18C (fixture `point_percent_fixture`).

### Jalur GL · Label "Group - Playoff" (keputusan 127) — level 0 (teks), ikut 3.9.0

- Konfirmasi host dulu (PRD keputusan 127 a–c): nama format di tempat lain ikut? (string di kode:
  `konfigurasi_screen.dart:518`, `detail_player_screen.dart:80`, `leaderboard_screen.dart:32`,
  `share_content.dart:17`; hi-fi 19a/19b/19x… `.seg`, ±62 kemunculan teks di `design/hifi.html` termasuk catatan,
  54 di PRD). Rekomendasi #6 C-4 (22s–22u) menulis "Grup + Gugur" → ikut nama baru.
- Lalu main session: hi-fi (frame + catatan yang tampil di UI), kode, golden. Nama fitur di dokumen internal (PRD §16,
  GU-n, nama kelas) boleh tetap "Grup + Gugur" kecuali host minta.

---

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
- **UX-1 selesai** (hi-fi teks P3 + K3, frame baru 20r/21z, A-6 tepi `edge` semua isian tidak fokus). Keputusan host
  2026-11-18 atas pertanyaan UX-1 (setuju semua rekomendasi): label sheet Tambah jam/Lanjutkan "Jam booking"; Akhiri saat
  Perempat final / Semifinal belum lengkap menyebut babak yang batal saja ("Semifinal, Final, dan Juara 3 tidak
  dimainkan."), tanpa "#1"; kotak nama court `.inline-field` ikut tepi `edge`; 01i langkah 2–3 tanpa keterangan
  (langkah 2 tetap "Add to Home Screen"). Tebakan agen dipakai: "Klasemen" di 06c + 9 frame "seperti 06c"; 08d/15j
  ikut "Tambah jam". PRD menyusul di UX-5.
- Jebakan UX-2 diperbaiki: `tool/hifi_extract.py` menyalin tabel `#semantics` ke `components.md`.
- **UX-3 selesai** (1e7a547): kontras, `MabarTouchOutset` area ketuk 48, Semantics + `test/core/ux3_semantics_test.dart`.
- **UX-4 selesai** (0041d0c): teks P3 + K3, `lib/services/schedule/finish_notice.dart` (dialog Akhiri per mode) + test,
  golden 20r/21z. Frame 15m dibuat setinggi batas sheet 92% (akibat paragraf K3 dihapus) → golden lolos. Pilihan
  engineer (belum ditanyakan host, bawa ke UX-5): metode di subjudul Detail tidak ditulis untuk Sparing dan Grup + Gugur
  (Cakupan hanya 10a/10b/10d/12k); B-20 "Istirahat" ikut berlaku di penonton Sparing; aturan "olahraga dibuang dulu
  kalau tidak muat" (B-6) belum diterapkan, subjudul tetap elipsis.
- **UX-5 selesai** (2026-11-18): 4 agen product-manager (opus, worktree terpisah, digabung tanpa konflik) mengaudit PRD
  §5.1–5.11, §6, §7, §13–§16 terhadap `design/spec/screens/*.md`; kode = kebenaran. PRD disamakan dengan app 3.8.1
  (dialog Akhiri per mode, "Jam booking", Klasemen, kontras/area ketuk/Semantics di §7, teks UI Sparing/Mexicano/Tukar,
  label "usulan" yang sudah disetujui dibersihkan). 14 butir catatan hi-fi yang tertinggal diperbaiki
  (`design/hifi.html` → `tool/hifi_extract.py --no-png`), butir Cakupan "audit PRD ↔ catatan hi-fi" ditambah. Tidak ada
  pertanyaan yang perlu host: pilihan engineer UX-4 ternyata sudah tertulis di hi-fi (14v Sparing, 22j Grup + Gugur,
  keputusan 103; B-20 berlaku umum di 12l).
- Dua celah kode yang ketemu saat audit, diperbaiki dengan test: **B-20** penonton yang diakhiri kehilangan pemain
  "Istirahat lagi" (sekarang satu daftar "Istirahat" berisi semua; 5790a33, test di `live_test.dart`) dan **B-6**
  subjudul Detail membuang olahraga dulu kalau tidak muat (`MabarAppBar.shorterSubtitle`, bf38015,
  `test/core/app_bar_subtitle_test.dart`).
- **UX-6** (rilis 3.8.1+25): versi dan `appVersion` dinaikkan, di-merge ke `main` lokal (a7b506a), hi-fi di-publish ulang
  (artifact `H9ZVDUfYvEBXsoBqih4iov`, v97). **Belum di-push** atas permintaan host (2026-11-18); push = deploy web.

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
