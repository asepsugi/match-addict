# Logika yang berubah di desain v2

Ditulis tangan (bukan hasil `tool/hifi_extract.py`). Setiap butir mengubah `lib/services/**` atau model, jadi
**wajib test** sesuai aturan `CLAUDE.md`. Angka di "data test" sama dengan angka di frame hi-fi, jadi test dan golden
saling menguatkan.

**Status: §1–§13 sudah diimplementasi di model/service dan ter-test** (§13 Sparing = 3.2.0). **§14 Mexicano +
Konfigurasi diringkas (3.4.0) = spec, belum diimplementasi** (task MX-n / KF-n di `docs/tasks.md`).
Layar tinggal memakainya; jangan menulis ulang aturannya di widget. Lokasi implementasi ditulis di tiap bagian.

## 1. Format skor

Implementasi: `ScoringMethod` + `ScoreFormat` (`lib/models/models.dart`), aturan sah `ScoreRules.judge`
(`lib/services/scoring/score_entry.dart`); test `test/services/score_format_test.dart`.

| Format | Parameter | Default | Skor sah | Seri |
|---|---|---|---|---|
| Race to N game | N = 2–9 | 6 (kedua olahraga) | N lawan 0..N−1 (murni: selesai begitu satu tim mencapai N; tanpa 7–5/7–6, keputusan host 2026-10-22) | tidak pernah |
| Best of N game | N = 1–15 | 5 | a + b ≤ N dan pemenang ≥ ⌊N ÷ 2⌋ + 1 | kalau N genap dan a = b = N ÷ 2 |
| Americano N poin | N = 2–99 | 21 | a + b ≤ N dan pemenang ≥ ⌊N ÷ 2⌋ + 1 | kalau N genap dan a = b = N ÷ 2 |

- Disimpan sebagai satu `SetScore` per match, jadi ranking/share/codec tidak bercabang.
- **Best of & Americano boleh berhenti lebih awal** (keputusan host 2026-10-26, app 2.8.0): begitu pemenang mencapai
  skor menang terkecil ⌊N ÷ 2⌋ + 1 (`ScoreFormat.minWinningScore`), lawan tidak mungkin mengejar, jadi total boleh
  kurang dari N (11–5 di Americano 21, 3–1 di Best of 5). Dulu total wajib N, jadi yang kalah dapat sisa poin yang tidak
  dimainkan secara gratis di Total Point. Pesan: total > N → "Total poin lebih dari 21" / "Total game lebih dari 5"
  (07n); pemenang di bawah batas → "Minimal skor pemenang 11" (07o, termasuk 5–5 di Americano 21). Seri hanya dengan
  total penuh, jadi `canDraw` dan kolom D tidak berubah. Simpanan lama (selalu total N) tetap sah.
- **Data lama tidak dimuat** (keputusan host 2026-10-22, menggantikan "data lama harus tetap terbaca"): turnamen dari
  app lama (skor per set, `schemaVersion` 1) diabaikan saat app v2 dibuka. Simpanan v2 = `schemaVersion` 2 + `appVersion`
  (versi app yang menulisnya).
- Konfigurasi: durasi match stepper ±5, **selalu kelipatan 5** (minimal 5); ketikan dibulatkan ke kelipatan 5 terdekat.

## 2. Batas angka di keypad Input Skor

Implementasi: `ScoreEntry` (`score_entry.dart`).

- Isi satu kotak tidak bisa melebihi: Race to N → N · Best of N → N · Americano → total. Tombol angka yang
  akan melewatinya mati.
- Digit ditambahkan di belakang isi kotak selama masih ada digit yang muat. **Kotak yang sudah penuh** (tidak ada digit
  lagi yang bisa ditambahkan; 0 selalu penuh) **atau baru dipilih** (ketuk kotak, →, pindah otomatis) menerima ketikan
  berikutnya sebagai **pengganti** isinya. Jadi yang mati hanya angka di atas batas (keputusan host 2026-10-22).
  Setelah digit membuat kotak penuh, kursor pindah ke kotak lawan kalau kotak itu kosong.
- Belum ada kotak aktif (skor tersimpan dibuka, 07i): semua angka mati sampai salah satu kotak diketuk (atau →).
- Kombinasi dicek setelah dua kotak terisi (pesan di frame 07d/07e/07h). **Tombol tidak dimatikan berdasarkan
  isi kotak lawan** (koreksi 6–4 → 4–6 harus bisa tanpa mengubah lawan dulu).
- Best of dan Americano: mengisi satu sisi mengisi kotak lawan dengan N − x **hanya kalau kotak itu kosong atau masih
  berisi nilai otomatis** (pudar, ikut berubah selama sisi pertama diketik: 1 → 20, 11 → 10). Kotak lawan yang sudah
  diketik sendiri, juga skor tersimpan yang dibuka lagi (07i), tidak dihitung ulang (keputusan host 2026-10-26).

Data test: Race to 6 → kosong: 7–9 mati; Race to 9 → satu digit, semua aktif; Americano 21 → setelah "2" hanya 0 dan 1;
Race to 6 berisi "4" (07b) → 7–9 mati; Best of 5 berisi "3" (07e) → 6–9 mati; Americano 21 berisi "13" (07g) → semua
aktif; 07i → semua mati.
Diterima: 6–0 … 6–5. Ditolak: 6–6 ("Hanya satu tim yang bisa mencapai 6"), 5–3 ("Belum ada yang sampai 6"), 7–5 / 7–6 / 7–3.
Isi otomatis (07m): Americano 21 ketik 1, 1 → 11–10 (otomatis); → lalu 5 → 11–5 sah, 11 tidak jadi 16. 13, → 9 → 13–9
"Total poin lebih dari 21" (07n). Best of 5: 2, → 1 → "Minimal skor pemenang 3" (07o); 3–1 sah.

## 3. Walkover (menggantikan "games WO tidak dihitung", PRD 4.4)

Implementasi: `ScoreFormat.woWinnerScore` + `RankingCalculator.rank` (nilai WO masuk `woPoints` → `totalPoint`, tidak
ke selisih); test `test/services/ranking_v2_test.dart`.

| Format | Pemenang WO dapat | Yang kalah |
|---|---|---|
| Race to N | N game | 0 |
| Best of N / Americano | max(rata-rata game/poin dari match yang dia **mainkan**, ⌊total ÷ 2⌋ + 1) | 0 |

- Rata-rata dibulatkan ke bilangan bulat terdekat (,5 ke atas). Belum pernah main → ⌊total ÷ 2⌋ + 1.
- Dihitung ulang tiap kali klasemen dihitung (rata-rata berubah kalau dia main lagi).
- Menang/kalah tetap masuk W–L–D dan Win %. **Selisih tidak berubah** untuk kedua tim.
- Skor menang terkecil: Americano 21 → 11 · Americano 24 → 13 · Best of 5 → 3 · Best of 6 → 4.

Data test: lihat data set 2 di bawah (Budi rata-rata 14 ≥ 13 → +14; Joko rata-rata 8,5 < 13 → +13) dan Fixed 09c
(Race to 6: Gina · Hana menang WO di R2 → +6, total 17 → 23, selisih tetap +7).

## 4. Peringkat

- Urutan = nilai metode (Total Point atau Win %) → selisih → nama. Hanya angka yang tampil (keputusan host 2026-11-02):
  head-to-head dan Total Point sebagai pemisah Win % dihapus. `RankingCalculator.compare`.
- Nilai metode dan selisih sama → **nomor sama**, nomor berikutnya melanjutkan (1, 1, 2 — bukan 1, 1, 3). W–L–D tidak
  membedakan nomor.
- Kolom W–L–D dan +/− (selisih, "+12" / "−4" / "0") di **kedua** metode; kolom terakhir = nilai metode. **D hanya ada kalau format bisa seri**
  (Best of genap, Americano genap); selain itu W–L. Win % dibulatkan tanpa desimal di tabel, 1 desimal di Detail.
- Label satuan mengikuti format: "Poin" (Americano) / "Game" (Race to, Best of).
- **Status Mixed**: Final kalau `isFinished || (courtsAvailableForRound(n+1).isEmpty && isRoundComplete(n))`;
  kembali Sementara setelah Lanjutkan/tambah jam. Fixed: Final kalau diakhiri atau semua match selesai.
- Subjudul sementara "Padel · Mixed · Sementara · R3 · 6 dari 6 match"; final "Padel · Mixed · Final · 4 round · 7 match"
  (round & match yang dimainkan; match "Tidak dimainkan" tidak dihitung, ditulis di catatan bawah).

### Data set 1 — frame 09a/09b, Detail 10a, Bagikan 11a (Americano 24, R1–R3, 6 match, Gilang masuk belakangan)

| Match | Tim 1 | Tim 2 | Skor |
|---|---|---|---|
| R1 M1 | Andi · Hana | Budi · Eko | 14–10 |
| R1 M2 | Dewant · Citra | Fajar · Joko | 15–9 |
| R2 M1 | Andi · Gina | Fajar · Indra | 15–9 |
| R2 M2 | Dewant · Joko | Budi · Hana | 14–10 |
| R3 M1 | Andi · Dewant | Citra · Indra | 13–11 |
| R3 M2 | Eko · Gina | Fajar · Hana | 12–12 |

Total Point (poin, selisih): 1 Andi 42 +12 (3–0–0) · 1 Dewant 42 +12 · 2 Hana 36 0 (1–1–1) · 3 Fajar 30 −12 ·
4 Gina 27 +6 · 5 Citra 26 +4 · 6 Joko 23 −2 · 7 Eko 22 −4 · 8 Budi 20 −8 · 8 Indra 20 −8 · belum main: Gilang.
Win %: 1 Andi 100 · 1 Dewant 100 · 2 Gina 75 · 3 Citra 50 +4 · 4 Hana 50 0 · 5 Joko 50 −2 · 6 Eko 25 · 7 Fajar 17 ·
8 Budi 0 · 8 Indra 0.
Detail Andi: 42 poin · 100% · 3–0–0 · +12; beda partner 3/10, beda lawan 5/10.

### Data set 2 — frame 09d/09e/09f (Americano 24, R1–R4, 7 dari 8 match, 1 WO, 1 seri)

| Match | Tim 1 | Tim 2 | Skor |
|---|---|---|---|
| R1 M1 | Andi · Budi | Citra · Dewant | 16–8 |
| R1 M2 | Eko · Fajar | Gina · Hana | 13–11 |
| R2 M1 | Andi · Citra | Eko · Indra | 11–13 |
| R2 M2 | Budi · Joko | Dewant · Gina | WO (Dewant · Gina tidak main) |
| R3 M1 | Andi · Fajar | Hana · Joko | 14–10 |
| R3 M2 | Budi · Indra | Citra · Gina | 12–12 |
| R4 M1 | Dewant · Eko | Fajar · Joko | 17–7 |
| R4 M2 | Andi · Hana | Budi · Gina | belum dimainkan (09f: "Tidak dimainkan" setelah Akhiri) |

Kredit WO: Budi (16 + 12) ÷ 2 = 14 → +14; Joko (10 + 7) ÷ 2 = 8,5 → di bawah 13 → +13.
Total Point (poin, selisih): 1 Eko 43 +14 · 2 Budi 42 +8 (2–0–1) · 3 Andi 41 +10 · 4 Fajar 34 −4 · 5 Citra 31 −10 ·
6 Joko 30 −14 · 7 Dewant 25 +2 · 7 Indra 25 +2 · 8 Gina 23 −2 · 9 Hana 21 −6 (Dewant dan Indra: poin dan selisih sama
→ nomor sama, Dewant di atas karena nama).
Win %: 1 Eko 100 · 2 Budi 83 · 3 Indra 75 · 4 Andi 67 +10 · 5 Fajar 67 −4 · 6 Dewant 33 +2 · 7 Joko 33 −14 ·
8 Gina 17 −2 · 9 Citra 17 −10 · 10 Hana 0.

## 5. Generator Mixed: undian seri dikunci per round

Implementasi: `EndlessRoundGenerator.priorityOrder` / `generateRound(seed:)`. Urutan pemilihan = (jumlah main,
round terakhir main, kunci undian, id), lalu pemain telat yang perlu jeda dipindah ke paling bawah (§5a). Kunci undian: `Random(drawSeed + nomorRound)` dibagikan ke pemain yang diurut
id. `drawSeed` = FNV-1a dari id turnamen (`ActiveTournament.drawSeed`), **tidak** disimpan sebagai kunci baru; perkaliannya
dipecah supaya hasilnya sama di web. Test `test/services/mixed_priority_test.dart`: urutan dua kali hitung untuk round
yang sama identik; round berbeda memberi undian berbeda; hasil `generateRound` = daftar prioritas yang ditampilkan.

### 5a. Pemain telat menyusul (keputusan host 2026-10-25, app 2.7.0)

Menggantikan kredit catch-up (`matchCredits`, ≤ 2.6), yang menyejajarkan pemain baru dengan pemain aktif paling jarang
main sehingga selisihnya tetap selamanya. Kunci `credits` di simpanan lama diabaikan.

- Pemain telat = `ActiveTournament.latePlayerIds`: pemain aktif yang absen di salah satu round yang sudah dibuat (tidak
  main dan tidak ada di daftar istirahat round itu) — masuk telat atau kembali setelah keluar.
- Tanpa kredit, pemain telat paling sedikit main jadi otomatis di atas. Jeda: kalau jumlah mainnya masih di bawah yang
  paling banyak main **dan** dia main di k round tepat sebelumnya, dia dipindah ke paling bawah urutan (istirahat 1
  round kalau slotnya cukup tanpa dia).
- k = max(2, ⌊slot ÷ yang istirahat⌋ + 1); tanpa yang istirahat tidak ada jeda. Main k dari k + 1 round selalu lebih
  sering dari bagian pemain lain (slot ÷ pemain), jadi dia pasti menyusul.
- Pemain yang hadir sejak awal tidak kena jeda: undian seri kadang memberi mereka k round beruntun (5 pemain / 1 court
  bisa 8), dan memotongnya bisa membuat selisih main jadi 2.

| Pemain / court | Pemain lain main | k | Pola pemain telat |
|---|---|---|---|
| 12 / 1 | 1 dari 3 round | 2 | menyusul di round pertama, lalu rotasi biasa |
| 12 / 2 | 2 dari 3 | 3 | MMM-MMM-… (selisih rata-rata turun ±0,1 per round) |
| 14 / 2 | 4 dari 7 | 2 | MM-MM-… |
| 14 / 3 | 6 dari 7 | 7 | MMMMMMM-… |
| 12 / 3 | semua | — | semua main tiap round, selisih tetap |

Test: `test/services/mixed_priority_test.dart` (grup "pemain telat menyusul dengan jeda": k per baris tabel, pemain
lama dan yang sudah menyusul tidak kena jeda) dan `test/services/mixed_roster_test.dart` (10 pemain + 2 setelah R3,
2 court → kedua pemain baru "MMM-MMM-MMM-"; 1 court → selisih ≤ 1 tiap round).

## 6. Daftar istirahat (Jadwal Mixed)

- Round terakhir (tab = n): yang tidak main di round n, dihitung dari **pemain aktif sekarang** (yang keluar tidak
  tampil, yang baru ditambah langsung masuk). Dibagi dua memakai urutan generator untuk round n+1 dengan slot
  K = 4 × court yang sisa booking-nya sekarang masih muat satu match (`courtsAvailableAt(now)`, jam sungguhan sejak
  turnamen dimulai): masuk K teratas → "Istirahat · Prioritas main di R(n+1)", sisanya →
  "Istirahat lagi di R(n+1)". Kalau semua kebagian slot, hanya daftar pertama.
- Waktu habis (tidak ada court yang muat round n+1): K dihitung dari **semua** court, seperti frame 06l — daftar tetap
  menunjukkan siapa yang main duluan kalau host menambah jam. Implementasi `ActiveTournament.restingAfterLastRound`.
- Round lewat: `restingPlayerIdsByRound[k]` apa adanya, tanpa tag prioritas.
- Fixed: hanya pasangan bye (`byePairIdByRound`), maksimal satu. Fixed sparing: beberapa pasangan per round (§13.1).

## 7. Estimasi Lanjutkan turnamen (sheet 08c)

Implementasi `ActiveTournament.capacityAhead` (test `test/services/resume_tournament_test.dart`): sisa = max(0, booking − menit berjalan sejak turnamen dimulai); k per court = ⌊(sisa + tambahan) ÷ durasi⌋;
round = k terbesar; match = Σ min(court dengan k ≥ r, ⌊aktif ÷ 4⌋). "Court berkurang mulai R…" (`fewerCourtsFrom`)
hanya untuk court yang main di R(n+1) lalu habis di tengah; court yang sejak awal tidak dapat tambahan bukan "berkurang"
(bug kode lama, sudah diperbaiki).
Data test 08c: durasi 15, n = 8, sudah berjalan 2 jam, Court 1 +1 jam, Court VIP +0, 10 pemain → 4 round (R9–R12), 1 court, 4 match.

## 8. Label round

Tidak ada nomor round yang ditulis tetap. Tabel lengkap (n = `roundCount`, c = `currentRound`, k = tab, m =
`match.roundNumber`, p = round yang punya match selesai/WO) ada di hi-fi → Fondasi → "Label round: selalu dinamis".

## 9. Bagikan

- Nomor "#n". Peringkat 1 (semua yang bernomor 1) diberi lencana emas `#E3B341` bertulisan ink.
- Lengkap: Feed 1:1 sampai 10 baris satu kolom; 11–20 dua kolom rata, ⌈n/2⌉ kiri, urut ke bawah dulu, baris kiri-kanan
  sejajar (grid ⌈n/2⌉ baris tetap). Dua kolom: baris hanya nama + nilai. Story 9:16 satu kolom sampai 20 baris.
- Fixed menghitung "pasangan" ("Semua 10 pasangan", "+n pasangan lainnya").

## 10. Court di tengah turnamen (Mixed) · sisa booking per court

Keputusan host 2026-10-22 (frame 06a, 06i, 06p–06t, 07a–07l, 08c, 08e–08k). Mabar sering mulai dengan 1 court karena
court lain baru kosong di jam berikutnya.

**Model.** Tiap `Court` punya `startMinute` = menit sejak `createdAt` saat court itu mulai (court dari Konfigurasi = 0;
kunci simpanan opsional, data lama tetap terbaca → MINOR, `schemaVersion` tetap 2). Ujung booking = `startMinute +
bookingDurationMinutes`. Sisa = `max(0, ujung − elapsedMinutes(now))`; semua turunan (`courtsAvailableAt`,
`canGenerateNextRound`, `canResume`, `isFinal`, `capacityAhead`, `restingAfterLastRound`) tetap lewat
`remainingBookingMinutes`, jadi cukup satu titik yang berubah. Booking selalu kelipatan 60.

**Tampilan waktu.** Hitung mundur jam:menit ("02:00", "01:14", "00:58"; ":" = durasi, jam dinding ditulis "20.02"),
diperbarui tiap menit, berhenti di "00:00".
- **Court habis atau tinggal beberapa menit** (sisa < durasi match) tidak ikut round berikutnya; slot dan daftar
  Prioritas main dihitung dari court yang tersisa, jadi tetap sama dengan hasil Buat (sudah begitu sejak jam sungguhan;
  dijaga `test/services/court_availability_test.dart`: sisa 16 dan tepat 15 → ikut, sisa 10 dan habis → tidak).
- Tik layar diselaraskan ke pergantian menit sejak `createdAt`, bukan `Timer.periodic` dari layar dibuka (dulu bisa
  tertinggal sampai 59 detik: kotak jam masih "00:15" dan daftar masih untuk 2 court, padahal Buat sudah memakai 1 court).
- Jadwal: subjudul tanpa waktu. Strip court 42 pt di semua round (Detail tetap 34). Di round yang sedang berjalan
  (Mixed: `roundCount`; Fixed: `currentRound`) dan turnamen belum diakhiri, strip berisi nomor + kotak jam tinta 22%
  (kontras ≥ 5:1 di 10 warna) untuk **semua** baris round itu, termasuk yang sudah ada skornya. Tanpa warna peringatan.
- Input Skor: "Round 5 · Americano 21 · sisa 02:00" untuk match di round yang sedang berjalan (juga saat mengubah
  skornya). Sisa < durasi match → bagian "sisa 00:12" clay; 0 → "waktu habis" clay. Round lewat: tanpa sisa.
- Kelola court / detail court: jendela jam "19.00–21.00 · sisa 00:58" atau "· waktu habis". Lanjutkan (08c): "Sisa
  00:45", "Waktu habis → 01:00" (dulu "45m", "→ 1j").

**Kelola court (menu ⋯ Mixed, selama belum diakhiri).** Label daftar "{n} court" (+ " · {h} habis"). Court baru (hanya
kalau court < 10): warna = palet berikutnya, nama kosong = "Court {n+1}", booking 1–12 jam (default 2), catatan
"Sampai {jam sekarang + booking}". Booking < durasi match → angka clay + error, tombol mati (seperti 03d).

**Kapan court dipakai** — satu aturan untuk court baru dan court yang (setelah diubah) jadi muat lagi:
1. Round terakhir masih berjalan, court itu belum punya match di round tersebut, sisa ≥ durasi match, dan yang
   istirahat ≥ 4 → **langsung main**: satu match baru di round itu (`matchNumberInRound` = terbesar + 1) untuk 4 pemain
   teratas `priorityOrder(roundNumber: n + 1)` di antara yang istirahat; namanya tertulis sebelum tombol ditekan
   ("Langsung main di R5"). Pasangan dengan penalti yang sama (`_bestArrangement`). `restingPlayerIdsByRound[n]`
   dikurangi keempatnya. Selisih match ≤ 1 tetap karena yang diambil selalu jumlah main terendah.
2. Selain itu, kalau court baru menambah slot round berikutnya
   (`slotsFor(aktif, court muat + baru) > slotsFor(aktif, court muat)`) → tombol "Tambah court · mulai R{n+1}".
3. Selain itu → "Tambah court · belum terpakai" (tetap boleh).

**Detail court (ketuk di daftar)** — sheet aksi: nama, warna, jam hanya pratinjau sampai **Simpan** (mati sampai ada
perubahan); subjudul ikut pratinjau. Stepper = panjang booking dalam jam: + memperpanjang ujung, − minimal 1 jam (ujung
lewat dari sekarang → court habis, match yang sedang jalan tetap bisa diisi). Court yang sudah habis: stepper 0 jam
(− mati); tambahan dihitung dari sekarang → `startMinute = elapsed, booking = tambahan` (sama hasilnya dengan Lanjutkan
`max(ujung, sekarang) + tambahan`; Lanjutkan juga menulis ulang `startMinute` untuk court yang habis supaya jendelanya
benar). Kembali ke 0 sebelum Simpan = tanpa perubahan. Simpan → aturan "Kapan court dipakai" di atas.

**Hapus court** ("Hapus", aksi teks clay di kanan atas detail): hanya untuk court **bernomor terakhir** (nomor court =
urutannya; menghapus court di tengah akan menggeser nomor court lain, termasuk di match lama), yang belum punya match
selesai/WO, dan bukan satu-satunya court. Ada match belum dimainkan di court itu → dialog "Hapus Court 2?" · "Match R5
di court ini ikut dihapus." · Batal / Hapus; match dihapus, pemainnya kembali ke `restingPlayerIdsByRound[n]`. Tanpa
match → langsung dihapus. Batalkan Rn menghapus match-nya saja; court tetap.

**Data test (frame 06p–06t, 08e–08k)** — Padel, Americano 21, durasi 15, 10 pemain (Andi P, Budi S, Citra L, Dewant R,
Eko M, Fajar K, Gina R, Hana T, Indra W, Joko S). Mulai 19.00, Court 1 booking 120. Id turnamen `t-court-329705`: undian
seri di R6, R8, R9, R10 sama dengan riwayat di bawah (fixture `courtTournament`, `test/hifi/screens/schedule_fixture.dart`).
- R1 Andi·Budi vs Citra·Dewant · R2 Eko·Fajar vs Gina·Hana · R3 Andi·Citra vs Indra·Joko · R4 Budi·Dewant vs Eko·Gina ·
  R5 Fajar·Indra vs Hana·Joko (belum diisi). 20.02 (elapsed 62): Court 1 "00:58"; Prioritas main di R6 (slot 4) = Andi,
  Citra (istirahat sejak R3) + Dewant, Gina (undian); istirahat lagi = Budi, Eko.
- Tambah Court 2 (startMinute 62, booking 120 → sampai 22.02): langsung main di R5 = Andi, Citra, Dewant, Gina; match
  R5 #2 Andi·Dewant vs Citra·Gina. R6 slot 8 → Prioritas main di R6 = Budi, Eko.
- R6 (2 court) Budi·Fajar vs Citra·Eko, Gina·Joko vs Hana·Indra (Andi, Dewant istirahat) · R7 Budi·Indra vs Eko·Joko,
  Andi·Hana vs Dewant·Fajar (Citra, Gina istirahat; setelah R7 semua 4 match). Tidak ada pasangan yang berulang.
- 20.48 (elapsed 108), R7 lengkap: Court 1 "00:12" (< 15, tidak ikut R8, "Buat R8 · 1 court"), Court 2 "01:14";
  Prioritas main di R8 = Citra, Gina. Tambah Court 3 → "Tambah court · mulai R8".
- Court 3 saat R5 berjalan (2 court, 2 istirahat): "Tambah court · belum terpakai".
- R8 (Court 2) Citra·Budi vs Gina·Indra · R9 (Court 2) Andi·Eko vs Fajar·Joko (tanpa ulang partner). 21.04 (elapsed 124): Court 2 "00:58",
  Court 1 waktu habis; Prioritas main di R10 = Citra, Dewant, Gina, Hana; istirahat lagi = Budi, Indra. Detail Court 1
  +1 jam → startMinute 124, booking 60 ("21.04–22.04 · sisa 01:00"); langsung main di R9 = Citra, Dewant, Gina, Hana.

## 11. Live score · relay tanpa database

Keputusan host 2026-10-24 (frame 06c, 06d, 06i, 12a–12o). Host membagikan link; pemain lain melihat Jadwal, Klasemen,
dan Detail di browser. Tidak ada database: relay (`relay/src/index.js`, Cloudflare Worker + satu Durable Object per kode,
paket gratis) hanya memegang salinan turnamen terakhir.

**Relay.** `POST /live` (isi = JSON `TournamentCodec`) → `201 {code, token}`; kode 6 karakter dari
`23456789ABCDEFGHJKMNPQRSTUVWXYZ`, diulang kalau sudah dipakai. `PUT /live/KODE` dan `DELETE` wajib
`Authorization: Bearer token` (relay menyimpan SHA-256-nya saja; salah → 403). `GET /live/KODE?since=rev` → `200 {rev,
payload}`, `204` kalau `rev` sama, `404` kalau tidak ada. Isi ditolak (400) kalau bukan JSON dengan `schema` angka dan
objek `tournament`, atau lebih dari 256 KB (413). Data terhapus 3 hari setelah kiriman terakhir (alarm + dicek saat
dibaca). Durable Object, bukan KV: KV bisa basi sampai 60 detik. CORS terbuka (isinya memang publik); GET tanpa header
tambahan supaya browser penonton tidak preflight tiap 10 detik. Uji: `relay/smoke.sh`.

**HP host** (`LiveHostController`, hidup sepanjang app). Sesi `{tournamentId, code, token, sentAt}` disimpan di box
Hive yang sama (kunci `live`, satu sesi). Live = sesi milik turnamen aktif. Setiap perubahan `tournamentProvider`
mengirim turnamen utuh (token tidak pernah ikut isi); satu kiriman berjalan sekaligus, perubahan selama itu dikirim
sesudahnya sebagai keadaan terbaru. Gagal jaringan → "Menunggu internet", dicoba lagi 30 detik kemudian dan di setiap
perubahan. Relay menjawab 404/403 (kedaluwarsa, token lain) → sesi dibuang, menu kembali menawarkan mulai. App dibuka
ulang → langsung kirim keadaan terakhir. Turnamen aktif diganti turnamen lain dan sesinya bukan milik Turnamen
terakhir ("Hapus & mulai baru") → DELETE (sebisanya) dan sesi dibuang; "Selesai" tidak menghapus, resume dari Beranda
melanjutkan kode yang sama. Hentikan tanpa internet → gagal, live tetap menyala.

**Penonton** (`LiveViewController`). `main()` membaca `#/live/KODE` (huruf kecil diterima); kalau ada, seluruh app
berjalan sebagai penonton: `tournamentProvider` = salinan dari relay, simpanan Hive penonton tidak dibuka. Cek pertama
langsung, lalu tiap 10 detik (`since` = rev terakhir), tiap 1 menit kalau `isFinal`; berhenti saat halaman tidak
terlihat dan langsung dicek saat terlihat lagi. Dua kegagalan berturut-turut → "Offline" (data tetap). 404 → "Live
tidak ditemukan", berhenti mengecek. `TournamentCodec.decode` null (skema lain) → "Live tidak bisa dibuka". Tab Mixed
yang sedang di round terakhir ikut pindah saat round baru muncul (mengetuk tab terakhir = ikut round terakhir). Jam
hitung mundur memakai jam HP penonton terhadap `createdAt` host. Tes: `test/services/live_score_test.dart`.

## 12. Round tambahan Fixed

Keputusan host 2026-11-03 (frame 06v–06z, 04f–04h, 09g, 10d; PRD 3.3a), dari turnamen live TBNE36: Padel, 16 pemain
= 8 pasangan, 2 court 4 jam, 15 menit → round-robin 28 match = 14 round = 3 j 30 m, sisa 30 menit.

- **Kapan:** `ActiveTournament.canAddRounds` = Fixed, belum diakhiri, semua match terisi. Fixed yang diakhiri tetap
  tidak bisa dilanjutkan.
- **Putaran:** genap → satu circle round (tiap pasangan +1, n/2 match); ganjil → satu siklus Hamilton (Walecki: pasangan
  terakhir di pusat, jalur zig-zag i, i+1, i−1, …, i+m dibagi dua putaran yang masing-masing mengistirahatkan satu
  pasangan, ditutup satu match di antara keduanya) → tiap pasangan +2, n match. Putaran ke-k (k = `extraPutaran`,
  disimpan, kunci simpanan opsional) memakai circle round k mod (n − 1) atau siklus k mod m: putaran tambahan
  berturut-turut = round-robin kedua tanpa lawan ketiga kali. Tiap putaran mulai di round baru; byes hanya untuk
  dua bagian berpasangan ganjil (match penutupnya tanpa baris Istirahat).
- **Jumlah putaran** (`RoundRobinGenerator.extraRounds` → `extend`): k_c = ⌊(sisa court + tambahan) ÷ durasi⌋ (sama
  dengan `capacityAhead`); putaran ditambah satu per satu sampai jumlah round ≥ k terbesar. Round ke-r memakai court
  dengan k_c ≥ r; setelah semua habis, court dengan k terbesar (lewat booking, "lewat booking (round − k terbesar) ×
  durasi"). k terbesar 0 → tidak ada yang dibuat ("Tambah jam minimal satu court").
- **Atur pasangan** (`PairDraft`): mulai dari `config.fixedPairs`; pemain tanpa pasangan (yang tidak ikut putaran
  sebelumnya) langsung di "belum berpasangan". Ubah = slot dikosongkan; pasangan baru mengisi slot kosong pertama;
  pemain baru unik (tidak peka huruf besar) terhadap `config.players`, maks 30 pemain. Yang dipasangkan saja yang masuk
  `config.players`; `config.fixedPairs` diganti hanya kalau susunannya berubah (`changedFrom`).
- **Klasemen:** `ActiveTournament.standingPairs` = pasangan sekarang yang setiap match anggotanya memakai id pasangan
  itu; sisanya per pemain (`standingEntries`). `pairById` juga mencari pasangan lama di match (baris Istirahat round
  lama). Detail: "Beda partner" di Fixed hanya kalau partner > 1; lawan dibanding pemain − 1 − partner.
- Data test: `test/services/fixed_extra_rounds_test.dart` (8 pasangan sisa 2/3 round → R15–R16 / R15–R18; Court 1
  +1 jam → R17–R20 di Court 1; 5 pasangan sisa 1 round → R6–R8 = 2 + 2 + 1 match; round-robin kedua untuk 2–15
  pasangan), `fixed_add_rounds_test.dart` (controller, Budi pulang/Rizky masuk, simpanan). Fixture frame:
  `test/hifi/screens/fixed_extra_fixture.dart`.

## 13. Sparing · dua klub (3.2.0)

Keputusan host 19 + K1–K12 (PRD §13, 2026-11-04); frame 13a–13q (inti), 14a–14y (alur Fixed), 15a–15y (alur
Mixed, disetujui host 2026-11-07). **Status: sudah diimplementasi** (logika + semua layar Fixed dan Mixed, rilis 3.2.0) — task
SP-0…SP-19 di `docs/tasks.md`. Logikanya di `lib/` dengan test (2026-11-08): Fixed
`services/schedule/sparing_fixed_generator.dart` (SP-2), Mixed `EndlessRoundGenerator.generateSparingRound` +
`ActiveTournament.sparingActiveCourts` (SP-3), skor klub `services/ranking/club_score.dart` (SP-4). Prototipe
`tool/sparing_proto/` yang dulu membuktikan aturan ini sudah dihapus (isinya: `git show 13646f4:tool/sparing_proto/…`);
generator produksi memberi hasil identik untuk input yang sama (dicek tech-lead pada review SP-3). Turnamen biasa tidak
berubah sedikit pun (AC-S19): setiap cabang sparing dimulai dari `config.isSparing`.

Istilah: klub pertama `k1` (blok atas layar Pemain), klub kedua `k2`; `p1`/`p2` pasangan, `n1`/`n2` pemain aktif,
`C` court, `C'` court aktif.

### 13.1 Model

- `Club {id, name}`; `TournamentConfig.clubs: List<Club>?` — null = turnamen biasa, selain itu tepat dua, urutan =
  klub pertama, klub kedua (`isSparing`). `Player.clubId: String?` — wajib untuk semua pemain turnamen sparing,
  termasuk pemain pengganti (Atur pasangan) dan pemain baru (Kelola pemain); pemain tidak pernah pindah klub (S1, K8).
- Pasangan tidak menyimpan klub; klubnya = klub kedua anggotanya (selalu sama, S2). Pasangan klub = `config.fixedPairs`
  yang anggotanya klub itu, **urutan daftar = indeks generator** (`G1…`, `M1…`). Atur pasangan mempertahankan slot
  (PairDraft mengisi slot kosong), jadi indeks pasangan lain tidak bergeser.
- Setiap match: `pair1` = pasangan klub pertama, `pair2` = klub kedua (S4). Dijamin generator; layar tidak pernah
  menukar sisi kecuali Detail (K9: tim pemain itu di atas).
- Istirahat Fixed sparing bisa beberapa pasangan per round: `ActiveTournament.restingPairIdsByRound` (baru, lihat
  13.10). `byePairIdByRound` tetap untuk Fixed biasa dan kosong di sparing.

### 13.2 Fixed · jadwal awal (algoritma diagonal)

`g = FPB(p1, p2)`, `L = KPK(p1, p2)`, `C' = min(C, p1, p2)` (court yang tidak aktif = court bernomor terakhir).

1. Slot match diberi nomor berurutan dalam **blok K = 0, 1, 2, …**. Slot `s = 0..L−1` di blok K =
   pasangan klub pertama ke-`(s mod p1)` lawan pasangan klub kedua ke-`((s + K) mod p2)`.
2. Jadwal awal = blok `0..g−1` (`M = g·L = p1·p2` slot). Blok K memuat tepat kombinasi `(i, j)` dengan
   `j − i ≡ K (mod g)` (CRT), jadi g blok berturut-turut = setiap kombinasi tepat sekali.
3. Slot dipotong berurutan jadi round berisi `C'` match di Court 1..C'. Round terakhir boleh kurang. `R = ⌈M ÷ C'⌉`.
4. `restingPairIdsByRound[r]` = semua pasangan (klub pertama dulu, urut daftar) yang tidak main di round r.

Kenapa benar: urutan klub pertama murni berputar; urutan klub kedua berputar di dalam blok dan semua pasangannya sama
rata di akhir blok → selisih main satu klub ≤ 1 setelah **setiap slot**, apalagi setiap round. Satu round berisi `C' ≤
min(p1, p2)` slot berurutan → tidak ada pasangan dua kali. Di batas blok indeks klub kedua hanya naik 1, jadi pasangan
kembar hanya mungkin di round berukuran tepat `p2` yang melintasi batas blok; round seperti itu selalu mulai di
kelipatan `p2`, dan `p2` membagi `L`.

**Jebakan (sudah makan korban di prototipe):** geser blok **tanpa** `mod g`. Varian `(s + K mod g)` lolos di jadwal
awal tapi gagal di round tambahan berantai: 4 / 6 pasangan, 3 court, tambah round ketiga dengan sisa [3, 6, 13] →
R31 satu pasangan klub kedua main dua kali. Test properti 13.12 menangkapnya; jangan dihapus.

Ini menggantikan invariant circle method (3.3) untuk sparing saja: round boleh berisi slot dari blok berbeda karena
larangan main dua kali per round dijaga langsung. `RoundRobinGenerator` tidak disentuh.

### 13.3 Fixed · round tambahan (K5)

- Satu **satuan** = satu blok = `L` match; pasangan klub pertama +`L ÷ p1`, klub kedua +`L ÷ p2`.
- Satuan ke-u (u = `extraPutaran` + i, i = 0, 1, …) = blok `K = g + u`. Jadi kombinasinya sama dengan blok `u mod g`
  jadwal awal (satuan pertama = lawan blok 0), dan g satuan berturut-turut = semua kombinasi sekali lagi (tidak ada
  pertemuan ketiga sebelum semua bertemu dua kali). `extraPutaran` disimpan = jumlah satuan yang sudah dibuat
  (pemakaian ulang kunci 3.1.0, 13.10).
- `roundsLeft[c]` dan `fit = max(roundsLeft)` sama dengan §12. Round ke-r tambahan memakai
  `min(|court dengan roundsLeft ≥ r| (kosong → court dengan roundsLeft = fit), p1, p2)` court, court bernomor kecil
  dulu. Jumlah satuan = `⌊kapasitas round 1..fit−1 ÷ L⌋ + 1` = paling sedikit satuan yang membuat jumlah round ≥ fit
  (aturan §12 yang sama, dibulatkan ke atas, boleh lewat booking). fit = 0 → tidak ada yang dibuat.
- Slot semua satuan dalam satu kali "Buat R…" dipotong **menerus** (tidak mulai round baru per satuan). Aman karena
  jumlah court per round tidak pernah naik di dalam satu kali tambah; kalau suatu saat Fixed bisa menambah court di
  tengah, tiap blok harus mulai di round baru atau test properti diulang.
- Atur pasangan yang mengubah `p1`/`p2`: satuan berikutnya dihitung dari jumlah baru (g, L baru), `extraPutaran`
  tetap dihitung naik. Semua invariant tetap berlaku di dalam tambahan itu (bukti di atas tidak bergantung pada K awal).
- "lewat booking" = (round tambahan − fit) × durasi, format jam:menit (§12).

### 13.4 Fixed · estimasi Konfigurasi (K10)

Dari jumlah pemain (pasangan = ⌊n ÷ 2⌋ per klub; sisa ganjil ditahan di Pasangan, K12): `R = ⌈p1·p2 ÷ C'⌉`, `M =
p1·p2`, lewat = `R × durasi − booking terpendek di antara Court 1..C'`.
- lewat > 0 → "Lanjut · R round · lewat booking hh:mm" (tanpa match dan court).
- selain itu → "Lanjut · R round · M match", ditambah " · C' court" kalau `C' < C`. Tanpa "±".
- Catatan "Lebih lama dari booking …" (booking < durasi) tidak berubah dari Fixed biasa.

Data test (Padel 15 mnt, court 2 jam): 8/6 di 2 court → "Lanjut · 6 round · 12 match" (13h); 16/14 di 4 court →
"Lanjut · 14 round · lewat booking 01:30" (14f); 8/4 di 3 court → "Lanjut · 4 round · 8 match · 2 court" (14g);
28/2 di 2 court → "Lanjut · 14 round · lewat booking 01:30"; 9/6 di 2 court = 8/6.

### 13.5 Fixed · pasangan

- Acak: `PairGenerator.random` per klub (klub pertama dulu), satu "Acak ulang" untuk keduanya (14a).
- Manual: dua ketukan membentuk pasangan hanya kalau sesama klub; ketukan ke klub lain memindah pilihan ke pemain itu
  (14b, AC-S4). Urungkan melepas pasangan terakhir dari klub mana pun.
- Ganjil di satu klub → satu sisa di klub itu; Buat jadwal mati "· n pemain tanpa pasangan" (n = jumlah sisa kedua
  klub, 14c, K12, AC-S3). Dua sisa beda klub tidak pernah dipasangkan.
- Atur pasangan (14o): satu bagian per klub; pasangan hanya dari chip klub itu; pemain baru masuk klub bagian tempat
  ia diketik, unik (tidak peka huruf besar) terhadap **kedua** klub, total ≤ 30; Simpan mati "· minimal 1 pasangan
  tiap klub" kalau satu klub tanpa pasangan.

### 13.6 Mixed · per klub

- Court aktif round baru `C' = min(|courtsAvailableAt(now)| (kosong → semua court), ⌊n1 ÷ 2⌋, ⌊n2 ÷ 2⌋)`; slot klub =
  `2·C'`. **Satu fungsi** `ActiveTournament.sparingActiveCourts` (di model, karena `capacityAhead` juga memakainya
  dan model tidak meng-import services) menggantikan `slotsFor` di semua pemakainya untuk sparing:
  `generateSparingRound`, slot R(n+1) / `restingByClubAfterLastRound`, `courtUse`/`courtMatch`,
  `ActiveTournament.capacityAhead.matchesPerRound` (= `min(⌊n1 ÷ 2⌋, ⌊n2 ÷ 2⌋)`, tanpa batas court),
  `EndlessRoundGenerator.sparingEstimate` (Konfigurasi Mixed, sheet Cara kerja Mixed). Turnamen biasa tetap `slotsFor`.
- Siapa main: `priorityOrder` dipanggil **per klub** dengan pemain aktif klub itu saja, `slots` = slot klub, seed dan
  `latePlayerIds` sama → jeda pemain telat `k = max(2, slot klub ÷ istirahat klub + 1)` per klub dengan sendirinya.
  Ambil `2·C'` teratas tiap klub.
- Susunan: acak terpisah per klub, match i = (klub1[2i], klub1[2i+1]) vs (klub2[2i], klub2[2i+1]); penalti sama
  (ulang match 1000, partner 10, lawan 3, 400 percobaan). Pasangan sesama klub dan lawan sesama klub mustahil secara
  konstruksi (S2, S3).
- `EndlessRoundGenerator.restingByClubAfterLastRound` mengembalikan daftar Prioritas / Istirahat lagi **per klub**,
  dari panggilan `priorityOrder` yang sama persis dengan Buat R(n+1) (AC-S11). `restingAfterLastRound` di turnamen
  sparing = gabungan keduanya (supaya pemanggil lama tetap benar); layar sparing memakai yang per klub.
- `courtUse` (Kelola court): "langsung main" kalau round berjalan, court belum punya match, muat, dan **tiap klub**
  punya ≥ 2 yang istirahat; pemainnya = 2 teratas `priorityOrder(n+1)` tiap klub di antara yang istirahat, dengan slot
  klub dari `C'` round berikutnya (court baru ikut). "Round berikutnya" kalau `C'` dengan court ini > tanpa court ini.
- Kelola pemain: tambah wajib memilih klub (AC-S12); Keluarkan mati kalau klub itu tinggal 2 aktif; Kembalikan = ke
  klubnya; total aktif 4–30 tetap.
- Batalkan Rn, Lanjutkan turnamen, Akhiri, `isFinal`: tidak berubah; `C'` dihitung ulang per round.
- Estimasi Konfigurasi: Max Round = `maxRounds`; Court Aktif = `C'` dari semua court; Total Match = round × `C'`;
  Match/Pemain per klub = ±(Total Match × 2 ÷ n klub). Tombol "Mulai Round 1 · ±R round" + " · C' court" kalau `C' < C`
  (13i, 13j).

### 13.7 Skor klub (K2, K11)

Satu fungsi murni `ClubResult.of(active)` (`lib/services/ranking/club_score.dart`; widget-nya bernama `ClubScore`), dipakai Jadwal, Klasemen, Beranda, poster,
caption, Live — tidak dihitung ulang di widget.
- Per match `done`: menang 1, seri ½ (simpan sebagai setengah-poin bulat, `halfWins`), kalah 0; Total Point klub +=
  game sisi klub; selisih klub += game sendiri − game lawan.
- Per match `wo`: klub lawan pasangan WO +1 menang; Total Point klub pemenang += **nilai WO klub** = rata-rata nilai WO
  kedua pemain pemenang, dibulatkan ,5 ke atas: `(v(a) + v(b) + 1) ~/ 2`, `v` = nilai per WO yang sama dengan
  `RankingCalculator` (`format.woWinnerScore(rata-rata pemain itu)`). Selisih tidak berubah. Fixed dan Race to: v(a) =
  v(b), jadi sama dengan nilai pasangan. Klasemen pemain tetap nilai masing-masing.
- `pending`/`cancelled` diabaikan. Satu match dihitung sekali per sisi (13C: 56, bukan 112).
- Unggul: `halfWins` → Total Point klub → sama = Seri (bola di kedua baris). Selisih hanya tampil, tidak menentukan.
  Tampilan "6½" (bukan 6,5), satuan Total Point ikut format ("game"/"poin").
- Status Sementara/Final = `isFinal` biasa.

### 13.8 Klasemen per klub, Detail

- `RankingCalculator.rank` sekali untuk semua pemain, lalu `standingEntries` **per klub** (standing pemain klub itu +
  `standingPairs` klub itu) → nomor mulai #1 di tiap klub, aturan nomor rapat sama (K3). Satu provider
  (mis. `clubStandingEntriesProvider` → daftar (klub, baris)) untuk Klasemen, Detail, Bagikan, caption, Live; jangan
  menomori lintas klub. "Belum main" di dalam tabel klubnya (14p). "1 match WO" di bawah tabel terakhir.
- Detail (K9): subjudul "Peringkat n · {klub} · olahraga · mode · format"; riwayat tim sendiri di atas; Beda lawan =
  lawan berbeda ÷ pemain klub lain (Fixed 14v "6 / 6", 14w "8 / 8"); Beda partner Fixed tetap tersembunyi selama
  pasangan tidak berubah.

### 13.9 Beranda, Bagikan, caption

- Beranda sparing tanpa nama: baris kecil "{klub1} {skor} – {skor} {klub2}" menggantikan "olahraga · mode · n pemain",
  "0 – 0" sebelum ada hasil (14x). Dialog mulai baru: "{klub1} vs {klub2}, Round n" (14y). Sparing bernama: nama di
  baris kecil, skor klub di baris sendiri — frame 15w/15y (alur Mixed, disetujui host 2026-11-07).
- Versi app (keputusan 20): "v{appVersion}" di kanan atas banner di semua kondisi Beranda (01a–01f, 01h, 01i). Golden
  2% tidak menangkap teks sekecil ini → test wajib `find.text('v$appVersion')`.
- Poster Ringkas (13q): `.pscore` (dua baris klub, klub pertama atas, Total Point · selisih + match menang, tanpa bola)
  di bawah judul; lalu per klub label `.pclub` (+ "+n pasangan/pemain lainnya" kalau terpotong) dan 3 teratas klub itu.
- Caption: baris pertama "🏆 {klub1} {menang}–{menang} {klub2} · {olahraga}" (seri skor + Total Point sama: "… · Seri ·
  Padel"), nama turnamen di baris kedua kalau ada, lalu blok "Klasemen Akhir · {klub}" per klub (baris sama dengan
  caption biasa), kaki sama. Lengkap menambah "Hasil per Round" (baris match klub pertama dulu). Teks persis: 13q.
- Lengkap / Feed / Story sparing (frame 13r–13w, disetujui host 2026-11-08, diimplementasi SP-15): Lengkap = semua
  baris bernomor per klub dengan label `.pclub`; pasangan dan Story selalu satu kolom, Mixed di pratinjau/Feed satu
  kolom per klub. Ukuran `.pscore`/`.pclub` per target di catatan frame (`13-sparing.md`; Story ×0,75). Kepadatan
  (`sparingPosterDensity`, hanya Lengkap): label klub dihitung satu baris, skor klub tidak; ambang 8 baris (satu kolom),
  10 per kolom (dua kolom per klub), 16 baris nama (Story); lebih dari itu huruf × ambang ÷ baris.

### 13.10 Data (final, DBA SP-0 — bentuk lengkap, aturan baca, dan risiko di `docs/data.md` → Sparing)

Semua kunci baru **opsional** dan hanya ditulis untuk turnamen sparing; simpanan 3.1.0 = turnamen biasa apa adanya
(AC-S19); encode turnamen biasa tidak berubah satu byte; `schemaVersion` tetap 2; kategori MINOR.
- `config.clubs`: `[{"id": "club-1", "name": "PB Garuda"}, {"id": "club-2", "name": "Matcha Club"}]`, tepat dua, urutan
  = klub pertama, kedua; id berbeda, nama tak kosong. `isSparing` = `clubs != null`.
- `config.players[].club`: id klub, di **setiap** pemain turnamen sparing (asli, pengganti dari Atur pasangan, baru dari
  Kelola pemain, yang sudah keluar). Tidak pernah berubah (K8).
- `restingPairs`: `{"6": ["pairId", …]}` per round, hanya Fixed sparing, ditulis kalau tidak kosong. `bye` tidak berisi
  nomor round di sparing.
- `bye.sparing = "1"`: penanda revisi bentuk sparing, **sengaja** kunci yang tidak bisa di-`int.parse` supaya decoder
  3.1.0 gagal (→ null) dan tidak salah membaca sparing sebagai turnamen biasa; decoder 3.2.0 membuangnya sebelum
  membaca nomor round. Wajib ada kalau `clubs` ada, dan sebaliknya.
- `extraPutaran`: Fixed sparing = jumlah **satuan** yang sudah dibuat (13.3); tafsir ikut `isSparing`. ≥ 0; Mixed
  sparing 0.
- Mixed sparing: istirahat tetap `resting` (id pemain); klubnya dari `players[].club`.
- Rusak → `decode` null: `clubs` bukan dua klub valid; pemain tanpa `club` / klub tak dikenal; kunci sparing tanpa
  `clubs` (atau sebaliknya `clubs` tanpa penanda); anggota pasangan beda klub atau tidak ada di `config.players`;
  `pair1` bukan klub pertama / `pair2` bukan klub kedua (S2, S4); `restingPairs`/`extraPutaran` salah tipe atau negatif.
  Tidak diperiksa saat baca: id di `restingPairs` yang tidak ketemu, jumlah pemain/pasangan per klub (helper klub di model
  harus total, tidak melempar).
- Data live: relay menyimpan JSON codec apa adanya, tidak berubah, tanpa deploy. Penonton web 3.1.0 yang masih
  ter-cache melihat "Live tidak bisa dibuka" (bukan data campur klub); host 3.1.0 yang tersisa membaca null dan
  simpanannya tidak ditimpa. Ukuran: 30 pemain, 7/8 pasangan, 56 match per satuan, ±37 KB per satuan, batas relay 256 KB.

### 13.11 Data test (= angka PRD dan frame, dicek generator + kalkulator 2026-11-04)

Pasangan 13A: G1 Andi · Budi, G2 Citra · Dewi, G3 Eko · Fajar, G4 Gita · Hadi; M1 Indra · Joko, M2 Kiki · Lina,
M3 Maya · Nanda. Padel, Race to 6, 15 mnt, 2 court × 2 jam.

| Round | Court 1 | Court 2 | Istirahat | Skor 13C |
|---|---|---|---|---|
| R1 | G1–M1 | G2–M2 | G3, G4, M3 | 6–3 · 4–6 |
| R2 | G3–M3 | G4–M1 | G1, G2, M2 | 6–5 · 6–4 |
| R3 | G1–M2 | G2–M3 | G3, G4, M1 | 6–4 · WO (G2 absen) |
| R4 | G3–M1 | G4–M2 | G1, G2, M3 | 6–2 · 3–6 |
| R5 | G1–M3 | G2–M1 | G3, G4, M2 | 2–6 · 6–1 |
| R6 | G3–M2 | G4–M3 | G1, G2, M1 | 6–0 · 5–6 |

- Jumlah main per round: Garuda 1·1·0·0 → 1·1·1·1 → 2·2·1·1 → 2·2·2·2 → 3·3·2·2 → 3·3·3·3; Matcha 1·1·0 → 2·1·1 →
  2·2·2 → 3·3·2 → 4·3·3 → 4·4·4 (AC-S5).
- Skor klub: setelah R1–R2 + R3 Court 1: 4 – 1, 28 – 22 (14h); setelah R5: 6 – 4, 45 – 43, +8/−8 (13k, 13n, 14l
  diakhiri "Final · 5 round · 10 match"); akhir: 7 – 5, 56 – 49, +13/−13, Final 12 dari 12 (13l, 13o, AC-S14, S15).
- Klasemen Total Point akhir (13o): Garuda #1 Eko · Fajar 18 (+11) 3–0 · #2 Andi · Budi 14 (+1) · #3 Gita · Hadi 14
  (−2) · #4 Citra · Dewi 10 (+3); Matcha #1 Maya · Nanda 23 (+4) 3–1 · #2 Kiki · Lina 16 (−3) · #3 Indra · Joko 10
  (−14). Win % (13p): Garuda 100 · 67 · Citra · Dewi 33 (+3) · Gita · Hadi 33 (−2); Matcha 75 · 50 · 0. Setelah R5
  (13n): Garuda Andi · Budi 14 (+1) · Eko · Fajar 12 (+5) · Citra · Dewi 10 (+3) · Gita · Hadi 9 (−1); Matcha Maya ·
  Nanda 17 (+3) · Kiki · Lina 16 (+3) · Indra · Joko 10 (−14).
- Round tambahan setelah R6, sisa 30 mnt (fit 2): 1 satuan = 12 match, R7–R12, lewat booking 01:00, Garuda +3,
  Matcha +4 (14n, AC-S18): R7 G1–M2, G2–M3 · R8 G3–M1, G4–M2 · R9 G1–M3, G2–M1 · R10 G3–M2, G4–M3 · R11 G1–M1, G2–M2 ·
  R12 G3–M3, G4–M1. 4 / 2 pasangan, 3 court: satuan 4 match; 3 / 3: satuan 3.
- Skor lain di jadwal yang sama (skor klub pertama dulu, urut R1 C1, R1 C2, …):
  - 14s: 6–4, 3–6, 6–2, 4–6, 5–6, 6–3, 6–5, 2–6, 4–6, 6–4, 5–6, 3–6 → 5 – 7, 56 – 60, −4/+4; Matcha #1 Kiki · Lina 24
    (+9) · #2 Indra · Joko 19 (−3) · #3 Maya · Nanda 17 (−2); Garuda Eko · Fajar 17 (+4) · Citra · Dewi 15 (+2) · Andi ·
    Budi 15 (−1) · Gita · Hadi 9 (−9).
  - 14t: 6–4, 6–5, 3–6, 6–2, 5–6, 2–6, 6–3, 4–6, 6–4, 3–6, 6–4, 5–6 → 6 – 6, 58 – 58 → Seri.
  - 14u (Americano 20): 12–8, 9–11, 13–7, 10–10, 11–9, 8–12, 14–6, 7–13, 9–11, 12–8, 11–9, 6–14 → 6½ – 5½, 122 – 118
    poin, +4/−4; Garuda 38 · 32 · 29 · 23, Matcha 44 · 42 · 32 (AC-S16).
- Ukuran lain (AC-S6): 8 / 4 pemain di 3 court → R1 G1–M1, G2–M2 · R2 G3–M1, G4–M2 · R3 G1–M2, G2–M1 · R4 G3–M2,
  G4–M1, Court 3 tanpa match (14m); 2 / 2 pasangan 1 court → 4 match 4 round; 14 / 1 pasangan 2 court → 14 round,
  Court 2 kosong; 8 / 7 di 4 court → 56 match 14 round; 3 / 3 di 2 court → 9 match 5 round.
- K11 (AC-S15a): Mixed Americano 21, WO dimenangkan Andi (v 14) + Budi (v 17) → Total Point klub +16; Andi +14, Budi +17.
- Mixed 13B (8 / 6, 2 court, 15 mnt, 2 jam; AC-S8): tiap round 2 match, 4 + 4 slot; setelah R6 Garuda 3 semua, Matcha
  4 semua; setelah R8 Garuda 4 semua, Matcha {6, 6, 5, 5, 5, 5}. Kelola court saat R4 berjalan (AC-S13): Court 3
  langsung berisi 2 Garuda + 2 Matcha (keduanya yang istirahat), R5 = 3 match dan 6 Matcha main. Oki masuk Matcha
  setelah R3: main R4, R5, istirahat R6 (k = 2). Nanda keluar setelah R3: 4 dari 5 Matcha main per round. Tabel 8
  round 13.4 PRD (8/6, 7/6, 8/3, 15/15, 2/2) cocok semua. Susunan di 13m dan 15a–15y (alur Mixed, disetujui host 2026-11-07)
  ditulis designer sebagai "hasil generator" (prototipe yang sekarang identik dengan
  `EndlessRoundGenerator.generateSparingRound`). Reproduksi untuk fixture golden (SP-18): undian `seed: 0x5eed`
  dipanggil langsung (bukan FNV-1a id turnamen, jadi fixture memilih id yang menghasilkan seed itu atau menulis match
  secara eksplisit), `Random` per frame sesuai pembuka `screens/15-sparing-mixed.md`. Test grup "frame 13m / 15*" di
  `test/services/sparing_mixed_test.dart` mengunci R1–R4, Prioritas per klub, Court 3 (15o/15p), Oki (15n), dan 8/3
  (15e).

### 13.12 Test properti (wajib ikut ke `test/services/`)

- Fixed jadwal awal — 1–15 pasangan per klub × 1–10 court (2250 ukuran): `M = p1·p2`; `R = ⌈M ÷ C'⌉`; semua round
  berisi `C'` kecuali terakhir; court = Court 1..C'; tiap kombinasi tepat sekali; nol pasangan dua kali per round;
  pair1 klub pertama; selisih main satu klub ≤ 1 setelah setiap round; total per pasangan p2 / p1.
- Fixed round tambahan — ukuran sama × 8 tambahan berantai (sisa per court sama, menurun, acak 0–14): round ≥ fit;
  satuan minimal; round penuh kecuali terakhir; court sesuai `roundsLeft`; selisih ≤ 1 setelah setiap round (lintas
  jadwal awal + tambahan); di batas satuan jumlah main satu klub sama persis; tiap kombinasi `1 + ⌊u/g⌋` atau
  `1 + ⌈u/g⌉` kali.
- Mixed — 2–28 pemain per klub (total ≤ 30) × court 1/2/3/4/7/10 × 30 round: `C'` match per round, partner sesama
  klub, pair1 klub pertama, tanpa pemain dua kali per round, selisih main satu klub ≤ 1. Ukuran AC-S9 + pemain telat
  di R4 dan keluar di R7: selisih ≤ 1 di antara yang hadir sejak awal.
- Letak: Fixed penuh di suite biasa (`test/services/sparing_fixed_test.dart`, beberapa detik). Mixed ringkas (ukuran
  AC-S9 + pemain telat/keluar + 12 ukuran acak berseed) di `test/services/sparing_mixed_test.dart`; sweep penuh di
  `sparing_mixed_sweep_test.dart` (satu test per n1, 27 test, bersama `sparing_mixed_property.dart`), bertag `slow` dan
  dilewati `flutter test` biasa lewat `skip:` di `dart_test.yaml` — CI deploy tidak menjalankannya. Jalankan sebelum
  rilis (SP-19): `flutter test --tags slow --run-skipped` (tanpa `--run-skipped` tidak ada yang jalan). Waktu ±11–17
  menit tergantung beban mesin (di prototipe dulu ±86 detik).

## 14. Mexicano + Konfigurasi diringkas (3.4.0)

Keputusan host 23–40 (PRD §10, §14, 2026-11-11); frame 03a–03q, 13h–13j, 14f–14g (Konfigurasi), 16a–16g (Mexicano).
Fixed, Mixed, dan Sparing tidak berubah sedikit pun: setiap cabang Mexicano dimulai dari `config.mode`. Angka di bagian
ini dicek tech-lead 2026-11-11 dengan skrip + hitung tangan; semuanya cocok dengan PRD 14.6 dan catatan 16a/16b/16g.

### 14.1 Model

- `enum PartnerMode { fixed, mixed, mexicano }` (nilai baru di **akhir**). Label "Mexicano". Getter baru
  `PartnerModeX.isEndless` = `this != PartnerMode.fixed` (round dibuat satu per satu: Mixed dan Mexicano).
  `PartnerModeX.assetPath` tidak dipakai di mana pun → hapus, jangan menambah aset.
- Semua turunan yang sekarang memeriksa `mode == PartnerMode.mixed` (atau `switch` per mode) berlaku juga untuk
  Mexicano → pakai `isEndless`: `isFinal`, `runningRound`, `canManageCourts`, `canResume`, `canCancelLastRound`,
  `TournamentController.startIfNeeded` (R1 langsung dibuat), `resume`, Beranda baris turnamen terakhir → Lanjutkan
  (`home_screen.dart`), `shareRowNoun` ("pemain"), label tombol Konfigurasi "Mulai Round 1". **Kecuali**
  `TournamentController.addPlayer`: tetap hanya Mixed (keputusan 27).
- `ScoreFormat.forMexicano` (model, ter-test): Americano N → tetap; Race to / Best of → `Americano 21`. Dipakai
  Konfigurasi saat kartu Mexicano diketuk; kembali ke Fixed/Mixed tidak mengubah format (keputusan 34).
- `ActiveTournament.canReinstate(playerId)`: pemain yang keluar boleh dikembalikan kalau Mixed (seperti sekarang), atau
  Mexicano **dan dia hadir di setiap round 1..`roundCount`** (ada di match round itu atau di
  `restingPlayerIdsByRound[r]`). Tidak ada stempel waktu "dikeluarkan kapan": kehadiran dihitung dari match + daftar
  istirahat, jadi Batalkan round yang dibuat tanpa dia otomatis menghidupkan Kembalikan lagi (keputusan 39, 16g).
  `reinstatePlayer` menolak (null, tanpa mengubah state) kalau `canReinstate` false; sheet menyembunyikan aksinya.
- Invariant Mexicano: `latePlayerIds` selalu kosong (tidak ada tambah pemain, Kembalikan hanya kalau tidak absen).
  `config.clubs == null` dan `config.format.method == americano` selalu.

### 14.2 Undian terkunci (satu undian untuk prioritas main dan urutan Mexicano)

- `EndlessRoundGenerator.lockedDraw(playerIds, seed:, roundNumber:)` → `Map<String, int>`: diekstrak apa adanya dari
  `priorityOrder` (`Random(seed + roundNumber)`, `nextInt(1 << 30)` dibagikan ke id **urut id**). Nilai harus identik
  dengan sekarang: `mixed_priority_test.dart` dan semua golden Mixed lolos tanpa diubah.
- `priorityOrder(..., Map<String, int>? draw)`: parameter opsional; null = `lockedDraw(players, seed, roundNumber)`.
- Undian dibagikan ke **semua pemain aktif** (`activePlayers`), sama dengan prioritas main, lalu dipakai juga untuk
  memisahkan pemain bernomor sama di urutan Mexicano. Membagikannya hanya ke pemain yang main menghasilkan undian lain
  (nilai `Random` ke-k jatuh ke pemain lain) → "undian R2" di PRD 14B tidak berlaku lagi.
- **Cara menyuntik di test:** `draw: drawOf(['Budi', 'Gita', …])` dengan helper test
  `Map<String, int> drawOf(List<String> ids) => {for (final (i, id) in ids.indexed) id: i}` (id pemain di fixture =
  nama). Test determinisme (AC-M12, AC-M14) memakai undian asli dari `ActiveTournament.drawSeed`.

### 14.3 Generator (`EndlessRoundGenerator.generateMexicanoRound`, `services/schedule/endless_round_generator.dart`)

Di kelas yang sama dengan Mixed supaya `_History`, `priorityOrder`, `slotsFor`, `_pairOf` dipakai ulang, bukan disalin.

```
generateMexicanoRound(players = aktif, courts = courtsAvailableAt(now), history, roundNumber, seed, format, draw?):
  slots   = slotsFor(players, courts)                 // < 4 → null, sama dengan Mixed
  draw  ??= lockedDraw(players, seed, roundNumber)
  order   = priorityOrder(players, history, roundNumber, slots, draw: draw)   // latePlayerIds kosong
  playing = order.take(slots); resting = order.skip(slots)
  ranked  = mexicanoOrder(playing, history, format, draw)
  match i = mexicanoArrangement(ranked[4i..4i+3], history) di courts[i]; id 'm-r{n}-{i+1}', matchNumberInRound i+1
```

- `mexicanoOrder(players, history, format, draw)`: `standing` = `RankingCalculator.rank(players, history,
  RankingMethod.totalGames, format)` dijadikan peta per id; urut `RankingCalculator.compare(a, b, totalGames)` (Total
  Point turun → selisih turun) → `draw` naik → id. Pemain belum main = 0 / 0 dan ikut diurut dengan angka itu (U8).
  Match `pending`/`cancelled` tidak dihitung (aturan `RankingCalculator`); WO ikut lewat `woPoints`.
- `mexicanoArrangement(p[0..3], history)`: A = p0+p2 vs p1+p3, B = p0+p3 vs p1+p2, C = p0+p1 vs p2+p3. Beban = jumlah
  `_History.partnerCount` kedua tim (match WO dan `pending` dihitung, `cancelled` tidak — sama dengan `_History`).
  Beban terkecil; seri → A, lalu B, lalu C. Tim = `_pairOf(posisi kecil, posisi besar)` (jadi `player1Id` = posisi
  lebih kecil, nama itu ditulis dulu); `pair1` = tim berisi p0.
- Court: `courts[i]` dari `courtsAvailableAt(now)` = urut nomor court, jadi kelompok teratas di court bernomor
  terkecil **yang dipakai** (Court 1 habis → Court 2). Court lebih banyak dari slot ÷ 4 → court terakhir kosong.
- **Kelola court (langsung main, `courtMatch`)**: pemainnya tetap dari `courtUse` (4 teratas prioritas R(n+1) di
  antara yang istirahat, tidak berubah). Cabang Mexicano: susun dengan `mexicanoArrangement(mexicanoOrder(empat,
  matches, format, lockedDraw(aktif, seed, n)))`, tanpa `Random`. Undian = round **n** (round tempat match itu
  dibuat; asumsi tech-lead, PRD tidak menyebut, keduanya pasti). Skor round n yang sudah masuk ikut dihitung.
- Controller `generateNextRound`: cabang `mode == mexicano` memanggil generator ini dengan `activePlayers`,
  `courtsAvailableAt(now)`, `matches`, `drawSeed`, `config.format`. `restingAfterLastRound` **tidak berubah**: siapa
  istirahat tidak tergantung skor, jadi daftar Prioritas main = hasil Buat (AC-M11) dengan sendirinya.

**Invariant** (test properti AC-M8, `test/services/mexicano_property_test.dart`, di suite biasa — tanpa 400 percobaan
acak, cepat):
1. Selisih jumlah main antar pemain aktif ≤ 1 setelah setiap round (tidak ada pemain telat di Mexicano).
2. Tiap pemain paling banyak satu kali per round; tiap match 4 pemain berbeda.
3. Kelompok court ke-i = pemain ke-4i..4i+3 dari urutan Mexicano yang main (oracle di test dihitung ulang dari
   `RankingCalculator.compare` + undian, bukan memanggil `mexicanoOrder`); court ke-i = court muat ke-i.
4. Susunan terpilih beban terkecil dari A/B/C, seri → yang lebih dulu.
5. Pasti: input sama (match, pemain aktif, court muat, seed) → round sama persis.

### 14.4 Data test (= PRD 14.6 = frame; Padel, Americano 21, 15 menit, court 2 jam; id pemain = nama)

| Kasus | Undian disuntik | Hasil yang diharapkan |
|---|---|---|
| AC-M4 14A R1 | Andi, Budi, Citra, Dewi, Eko, Fajar, Gita, Hadi | C1 Andi·Citra vs Budi·Dewi (A, 0/0/0) · C2 Eko·Gita vs Fajar·Hadi. Skor 15–6, 9–12 |
| AC-M4 14A R2 | Citra, Andi, Fajar, Hadi, Gita, Eko, Budi, Dewi | beban 0/0/2 dua court → A: Citra·Fajar vs Andi·Hadi · Gita·Budi vs Eko·Dewi. Skor 11–10, 8–13 |
| AC-M5 setelah R2 | — | Citra 26 (+10) #1 · Andi 25 (+8) #2 · Fajar 23 (+4) #3 · Hadi 22 (+2), Eko 22 (+2) #4 · Dewi 19 (−4) #5 · Gita 17 (−8) #6 · Budi 14 (−14) #7; jumlah 168 |
| AC-M4 14A R3 (a) | …, Hadi, Eko, … (Hadi lebih dulu) | C1 Citra, Andi, Fajar, Hadi beban 2/0/2 → B Citra·Hadi vs Andi·Fajar · C2 Eko, Dewi, Gita, Budi 2/0/2 → B Eko·Budi vs Dewi·Gita |
| AC-M4 14A R3 (b) | …, Eko, Hadi, … | C1 Citra, Andi, Fajar, Eko 1/0/1 → B Citra·Eko vs Andi·Fajar · C2 Hadi, Dewi, Gita, Budi 1/0/1 → B Hadi·Budi vs Dewi·Gita |
| AC-M15 WO | R2 C2 WO, Gita·Budi absen | Eko 20 (−3), Dewi 17 (−9), Gita 9 (−3), Budi 6 (−9); R3 tanpa seri, undian apa pun: = R3 (a) |
| AC-M6 14B R1 | Andi … Joko | Indra, Joko istirahat; match = 14A R1 |
| AC-M6 14B R2 | Budi, Gita, Andi, Eko, Indra, Dewi, Fajar, Joko, Citra, Hadi | Citra, Hadi istirahat; urutan Andi, Fajar, Gita, Eko \| Budi, Dewi, Indra, Joko; A: Andi·Gita vs Fajar·Eko · Budi·Indra vs Dewi·Joko (beban 0/0/1) |
| AC-M6 14B R3–R5 | undian asli, skor sah apa pun | R3 Citra, Hadi, Indra, Joko main; setelah R5 semua 4 match |
| 16g (fixture) | R2 skor 12–9, 10–11; Gita keluar; R3 Citra, Hadi, Indra, Joko, Andi, Dewi, Eko, Fajar, Budi | setelah R2 Andi 27 (+12), Gita 21 (0), Fajar 21 (0), Eko 18 (−6), Dewi 17 (−8), Budi 16 (−10), Citra 15 (+9), Hadi 12 (+3), Joko 11 (+1), Indra 10 (−1), jumlah 168; R3 Budi istirahat, A Andi·Eko vs Fajar·Dewi · Citra·Joko vs Hadi·Indra |
| AC-M7 14C | R1 Andi, Budi, Citra, Dewi · R2 Andi, Citra, Budi, Dewi | R1 A Andi·Citra vs Budi·Dewi 12–9 · R2 0/0/2 A Andi·Budi vs Citra·Dewi 10–11 · R3 Citra 23 (+4), Andi 22 (+2), Dewi 20 (−2), Budi 19 (−4) 2/0/2 B Citra·Budi vs Andi·Dewi 14–7 · R4 Citra 37 (+11), Budi 33 (+3), Andi 29 (−5), Dewi 27 (−9) 2/2/2 A Citra·Andi vs Budi·Dewi |

- AC-M9 ukuran: 4/1 tanpa istirahat; 5/1 satu istirahat per round, setelah R5 semua 4 match; 7/2 hanya Court 1, 3
  istirahat; 30/10 Court 1–7 dipakai, Court 8–10 kosong, 2 istirahat.
- AC-M8 ukuran 4/1, 5/1, 7/2, 8/2, 9/2, 10/2, 12/3, 16/4, 30/10 × 30 round, skor Americano 21 acak berseed yang sah
  (`ScoreRules.judge` menerima) + ±10% WO; booking cukup panjang (pakai `now` tetap).
- AC-M10: dua `ActiveTournament` sama, Buat R(n+1) setelah `rankingMethodProvider` = Win % vs Total Point → match sama.
- AC-M12: undian asli; Batalkan R3 lalu Buat R3 → identik; Batalkan R3, keluarkan Gita, Buat R3 → tanpa Gita.
- AC-M13: koreksi skor R2 setelah R3 dibuat → match R3 tidak berubah, Klasemen berubah, R4 dari angka baru.
- AC-M14: `encode` → `decode` (kill + buka lagi) setelah skor R2 lengkap → Buat R3 identik dengan tanpa kill.
- AC-M16 (`canReinstate`): Gita keluar setelah R2 dibuat → true; R3 dibuat tanpa dia → false; Batalkan R3 → true lagi
  (16g); Keluarkan mati saat aktif 4; `addPlayer` di Mexicano tidak mengubah state.
- AC-M17: 12 pemain / 2 court, R1 berjalan, tambah Court 3 → match baru = 4 yang istirahat, susunan dari
  `mexicanoOrder` dengan `lockedDraw(aktif, seed, 1)` (semua 0 / 0 → urutan = undian R1, susunan A); R2 tiga court,
  kelompok teratas di Court 1.
- AC-M18: 8 pemain, 3 court (Court 1 1 jam, Court 2–3 2 jam), 15 menit; R1–R4 di Court 1–2; pada menit 60 Court 1
  habis → R5 kelompok teratas di Court 2, berikutnya di Court 3.

### 14.5 Konfigurasi diringkas + pengaturan terakhir (keputusan 33–38)

- Satu layar: Nama, Pasangan (kartu tanpa deskripsi), baris Skor `"{format.label} · {durasi} menit"` (durasi kosong
  → "– menit" clay), baris Court `"{n} court · {j} jam"` atau `"{terpendek}–{terpanjang} jam"`; rincian di sheet
  (03d–03g, 03i–03p). Aturan teks dan tata letak: `screens/03-konfigurasi.md`. Rangkai teks di satu fungsi murni yang
  di-test (tidak ada aturan domain baru).
- Kartu: biasa `[fixed, mixed, mexicano]`; sparing `[fixed, mixed]` (AC-M2). Mexicano → `format.forMexicano` (AC-M1);
  sheet Skor Mexicano tanpa segmented (03e). Estimasi dan tombol Mexicano = Mixed ("Mulai Round 1 · ±n round", AC-M3).
- **Pengaturan terakhir per olahraga** (`services/storage/last_settings.dart`, bentuk final: dba, MX-0):
  `LastSettings {mode, format, matchDurationMinutes, courts: [{name?, colorIndex, bookingMinutes}]}` dibuat dari
  config saat turnamen **dimulai** (`startIfNeeded` membuat state baru; resume tidak). Nama court = null kalau sama
  dengan "Court n" (nama default ditulis ke config saat kosong, jadi bandingkan dengan label default, bukan kosong).
  Tidak ikut: nama turnamen, pemain, klub, pasangan.
- Konfigurasi dibuka: ada simpanan olahraga itu → isi semua nilai (court mendapat **id baru**); tidak ada / tak terbaca
  → default 03a (Fixed, Race to 6, durasi olahraga, 2 × 2 jam). Sparing + simpanan Mexicano → mode Mixed, format dan
  court tetap (`LastSettings.forSparing`). Tennis dan padel terpisah.
- Data test: Padel Mexicano Americano 24, 15 menit, 3 court × 2 jam (03q) disimpan → Padel dibuka = 03q; Tennis dibuka
  = 03a dengan 20 menit; Sparing Padel → Mixed, Americano 24, 3 court; nama "Mabar Jumat" tidak terbawa; JSON rusak →
  default tanpa melempar.

### 14.6 Data (draf tech-lead; final oleh dba di MX-0, `docs/data.md` → Mexicano)

- Simpanan turnamen: hanya `config.mode = "mexicano"`. Tidak ada kunci baru; `schemaVersion` tetap 2; Fixed, Mixed,
  dan Sparing ter-encode byte-sama.
- **Versi ≤ 3.3.x menolak tanpa penanda tambahan** (AC-M20, U7). Bukti: `_readConfig` memakai
  `PartnerMode.values.byName(j['mode'] as String)` (`tournament_codec.dart:200`; sama sejak commit pertama bc38717:111,
  3.1.0 10817f4:122, 3.2.0 564ea67:186, 3.3.2 di `main`), di dalam `try … catch (_) { return null; }`
  (`tournament_codec.dart:68,106-110`). `byName("mexicano")` di enum `{fixed, mixed}` melempar `ArgumentError` →
  `decode` null. Akibatnya: penonton web lama → "Live tidak bisa dibuka" (`live_view_controller.dart:83-85`); host
  versi lama → `loadActive` null, `listenSelf` mengabaikan null (`tournament_controller.dart:34`) jadi simpanan tidak
  ditimpa sampai host memulai turnamen baru (sama dengan risiko yang diterima di K13). Jadi tidak perlu penanda di `bye`
  dan tidak perlu menaikkan `schemaVersion` → **MINOR**.
- Aturan baca baru (usulan; payload yang tidak bisa ditulis penulis mana pun = rusak): `mode` mexicano + `config.clubs`
  → null; `mode` mexicano + `scoring` ≠ americano → null. `canEncode` memakai aturan yang sama.
- Pengaturan terakhir: kunci baru di box Hive `tournament` (usulan `settings.tennis` / `settings.padel`, JSON
  `{"v":1,"mode","scoring","target","duration","courts":[{"name","colorIndex","bookingMinutes"}]}`), di luar
  `TournamentCodec`, tidak pernah lewat relay. Nilai di luar batas (format `isValid`, durasi kelipatan 5 dalam 5–180,
  court 1–10, warna 0–9, booking kelipatan 60 dalam 60–720, mode tak dikenal) → abaikan entri itu (default). Versi lama
  tidak membaca kunci ini.

### 14.7 Jebakan untuk engineer dan reviewer

1. Undian dibagikan ke semua pemain aktif, bukan hanya yang main (14.2) — kalau salah, 14B R2 dengan undian asli
   tetap "lolos" di test yang menyuntik undian; hanya test determinisme yang membandingkan dengan `priorityOrder` yang
   menangkapnya. Wajib ada test: undian yang dipakai urutan Mexicano = `lockedDraw(aktif, seed, n)`.
2. Jangan memakai urutan `RankingCalculator.rank` (pemisah nama) atau `StandingEntry.position` (null untuk belum main)
   sebagai urutan Mexicano. Pakai `compare` + undian + id.
3. Generator tidak boleh membaca `rankingMethodProvider` / `standingsProvider` (ikut tab Klasemen, AC-M10).
4. Tidak ada `Random()` di jalur Mexicano, termasuk `courtMatch`; `_bestArrangement` hanya untuk Mixed (AC-M12, M14).
5. Ganti `== PartnerMode.mixed` dengan `isEndless` di semua turunan 14.1, **kecuali** `addPlayer`. `switch` per mode
   yang exhaustive akan gagal kompilasi; `==`/`!=` tidak — cari semuanya (`grep -rn "PartnerMode\." lib`).
6. Codec: jangan pernah mengganti `byName` dengan fallback (`orElse: mixed`): itu yang membuat versi lama menolak dan
   versi baru menolak mode masa depan. Test: payload `mode: "zzz"` → null.
7. Kembalikan Mexicano dihitung dari kehadiran per round (14.1), bukan dari "round terakhir sebelum dikeluarkan".
8. `removeCourt` mengembalikan pemain ke `restingPlayerIdsByRound[n]` dan Kelola court mengambil dari sana: keduanya
   menjaga "hadir di round n", jadi `canReinstate` dan `latePlayerIds` tetap benar — jangan mengubahnya.
9. Pengaturan terakhir: id court baru per turnamen; "Court n" default disimpan null; disimpan saat turnamen dimulai,
   bukan saat Konfigurasi ditinggalkan (Fixed bisa batal di Pasangan).
10. Sheet Skor Mexicano tanpa segmented: mengetuk Mixed/Fixed sesudahnya menampilkan segmented lagi dengan Americano
    terpilih (format tidak kembali).
