# Logika yang berubah di desain v2

Ditulis tangan (bukan hasil `tool/hifi_extract.py`). Setiap butir mengubah `lib/services/**` atau model, jadi
**wajib test** sesuai aturan `CLAUDE.md`. Angka di "data test" sama dengan angka di frame hi-fi, jadi test dan golden
saling menguatkan.

**Status: §1–§14 sudah diimplementasi di model/service dan ter-test** (§13 Sparing = 3.2.0; §14 Mexicano +
Konfigurasi diringkas = 3.4.0, task MX-n / KF-n di riwayat git `docs/tasks.md`). **§15 Tukar pemain (3.5.0) sudah
diimplementasi** (task TP-n di riwayat git `docs/tasks.md`). **§16 Poster podium (3.6.0) sudah diimplementasi**
(task PP-n di `docs/tasks.md`).
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
- Ringkas = poster podium (§16). Lengkap = arah B "Podium mini" sejak rencana 3.7.0 (§17): kolom (Mixed/Mexicano > 10
  baris di Feed, > 20 di Story → dua kolom rata; pasangan Fixed selalu satu kolom) dan kepadatan satu rumus dari tinggi
  baris (keputusan 80, 81). Ambang lama (Story selalu satu kolom, 20 baris) tidak berlaku lagi.
- Fixed menghitung "pasangan" ("Semua 10 pasangan").

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
- Poster Ringkas (13q, sejak 3.6.0): podium dua blok skor klub (§16, keputusan 62, 72). `.pscore`/`.pclub` tidak
  dipakai lagi.
- Caption: baris pertama "🏆 {klub1} {menang}–{menang} {klub2} · {olahraga}" (seri skor + Total Point sama: "… · Seri ·
  Padel"), nama turnamen di baris kedua kalau ada, lalu blok "Klasemen Akhir · {klub}" per klub (baris sama dengan
  caption biasa), kaki sama. Lengkap menambah "Hasil per Round" (baris match klub pertama dulu). Teks persis: 13q.
- Lengkap sparing (13s–13w, rencana 3.7.0): §17 — skor klub hanya di blok podium mini, kepala klub `.lclub` = nama +
  "56 game · +13" (2 satuan baris, keputusan 83), Mixed dua kolom per klub (Feed selalu, Story > 20 pemain; keputusan
  86), kepadatan satu rumus (80). `sparingPosterDensity` dan ambang 8 / 10 / 16 baris dihapus.

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
- **Final (dba, MX-0, 2026-11-12): bentuk dan kunci di atas dipakai apa adanya**; rincian lengkap di `docs/data.md` →
  Mexicano. Tambahan yang belum ada di draf: (1) entri `mode` mexicano dengan `scoring` ≠ americano = tak terbaca (sama
  dengan aturan baca turnamen); (2) `v` ≠ 1 = tak terbaca; (3) String JSON > 16 KB = tak terbaca; (4) nama court kosong/spasi
  dibaca null, panjang tidak dibatasi; (5) satu pelanggaran membuat seluruh entri default, tanpa perbaikan sebagian.

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

## 15. Tukar pemain · Mixed (3.5.0)

PRD §15 (aturan T1–T10, contoh 15A/15B/15C, tabel 15.4, AC-T1…T17), keputusan 48–59 (§10), frame 17a–17r
(`screens/17-tukar-pemain-mixed.md`) + ikon di frame Jadwal lama (daftar di TP-2). Fixed, Mexicano, dan turnamen tanpa
tukar tidak berubah sedikit pun. Angka di bagian ini dicek tech-lead 2026-11-12 dengan hitung tangan dari aturan
`priorityOrder` (§5): semuanya cocok dengan PRD 15A/15B/15C dan catatan 17a–17r.

### 15.1 Bentuk perubahan (tanpa model, kunci, atau `schemaVersion` baru)

Tukar = satu `ActiveTournament` baru yang hanya berbeda di dua tempat:
1. **Satu match** M (round terakhir n, `pending`): pemain keluar P diganti pemain masuk Q **di slot yang sama**
   (`pair1`/`pair2` dan `player1Id`/`player2Id` tetap posisinya). Id pasangan yang berubah dihitung ulang dari
   pemainnya (`EndlessRoundGenerator.pairId(player1Id, player2Id)`, kunci yang sama dengan `_pairOf`), supaya tukar
   balik menghasilkan match yang identik. `id`, `roundNumber`, `matchNumberInRound`, `courtId`, `status`, `sets`
   tetap; pasangan lawan objek yang sama.
2. **`restingPlayerIdsByRound[n]`**: Q diganti P **di indeks Q** (urutan daftar tetap, tukar balik identik); Q tidak
   ada di daftar (pemain baru setelah Rn dibuat, pemain yang dikembalikan) → P ditambahkan di akhir. Round lain tidak
   disentuh.

Tidak berubah: `config` (pemain, court, klub), `withdrawnPlayerIds`, `extraPutaran`, `byePairIdByRound`,
`restingPairIdsByRound`, match lain, `tournament.id`/`createdAt`/`isFinished`. `TournamentCodec` **tidak diubah**:
`resting` dibaca tanpa memeriksa isinya (`tournament_codec.dart:97-100`), dan cek sparing hanya klub pasangan
(`:125-137`), yang tetap benar karena Q sesama klub P. Jadi simpanan/payload 3.5.0 berisi tukar terbaca 3.4.x apa
adanya (kodenya sama), simpanan 3.4.x terbaca 3.5.0 apa adanya → **MINOR**, `schemaVersion` tetap 2, tanpa penanda.
Relay tidak diubah. DBA tidak perlu task; baris riwayat di `docs/data.md` ditulis saat rilis (TP-3).

### 15.2 Service (`lib/services/schedule/player_swap.dart`, baru, Dart murni)

```dart
/// Tukar pemain Mixed (PRD §15). Semua fungsi total: input tidak sah → false / kosong / null, tidak melempar.
abstract final class PlayerSwap {
  /// T1 + T2: [match] bisa ditukar. `config.mode == PartnerMode.mixed` (BUKAN `isEndless`: Mexicano dikunci,
  /// keputusan 52; Fixed tidak berlaku, 53), `!tournament.isFinished`, `match.roundNumber == roundCount`,
  /// `match.status == MatchStatus.pending`. Tidak melihat waktu booking (15.4: waktu habis tetap boleh).
  static bool isSwappable(ActiveTournament active, MatchGame match);

  /// T4: [inId] boleh masuk menggantikan pemain tim [team]: pemain aktif (bukan `withdrawnPlayerIds`), tidak main
  /// di round n, dan di sparing klubnya = klub [team] (keputusan 51). Tidak bergantung jam.
  static bool isCandidate(ActiveTournament active, Pair team, String inId);

  /// Ikon tim: `isSwappable(match) && team ∈ {match.pair1, match.pair2} && ada ≥ 1 kandidat`. Tidak butuh jam.
  static bool canSwapTeam(ActiveTournament active, MatchGame match, Pair team);

  /// Kandidat untuk sheet, dibagi dan diurut **sama persis** dengan daftar Istirahat Jadwal pada [now]:
  /// biasa = `EndlessRoundGenerator.restingAfterLastRound(active, now)`; sparing = entri klub [team] dari
  /// `restingByClubAfterLastRound(active, now)`. Kosong kalau `!isSwappable`. Tidak menghitung ulang apa pun.
  static ({List<Player> priority, List<Player> later}) candidates(
      ActiveTournament active, MatchGame match, Pair team, DateTime now);

  /// T3: [match] dengan [inId] di slot [outId] (id pasangan dihitung ulang). Dipakai pratinjau sheet DAN [apply],
  /// supaya pratinjau = hasil. [outId] tidak ada di match → [match] apa adanya.
  static MatchGame swapped(MatchGame match, {required String outId, required String inId});

  /// T3 + T5: turnamen setelah tukar (15.1), atau null kalau tidak sah: match tidak ada / `!isSwappable`, [outId]
  /// bukan pemain match itu, `!isCandidate(team berisi outId, inId)`, `outId == inId`.
  static ActiveTournament? apply(ActiveTournament active,
      {required String matchId, required String outId, required String inId});
}
```

- [outId] **boleh** pemain yang sudah dikeluarkan (keputusan 54): dia tetap dicatat di `resting[n]`, tidak tampil di
  daftar Istirahat (dihitung dari pemain aktif), tidak menjadi kandidat.
- [inId] **boleh** pemain yang ditambah setelah Rn dibuat (keputusan 55): dia aktif dan tidak main di round n.
- `EndlessRoundGenerator.pairId(String a, String b)` = satu baris publik yang meneruskan `_pairKey`; tidak ada
  perubahan lain di generator.

**Controller** (`TournamentController.swapPlayer`, `features/schedule/tournament_controller.dart`):

```dart
/// Tukar pemain Mixed (PRD §15). False = tidak sah, state tidak berubah.
bool swapPlayer({required String matchId, required String outId, required String inId}) {
  final current = state;
  final next = current == null ? null : PlayerSwap.apply(current, matchId: matchId, outId: outId, inId: inId);
  if (next == null) return false;
  state = next; // simpan lokal + live ikut dari sini
  return true;
}
```

Tanpa `saveActive`, tanpa kirim live, tanpa `clockProvider` (tukar tidak bergantung jam).

### 15.3 Invariant (wajib di test)

Untuk setiap tukar sah dari keadaan A ke B, n = `A.roundCount`:
1. **Satu match.** Tepat satu match berbeda (id sama, posisi di `matches` sama); match lain identik. Di match itu Q
   tepat di slot P, tiga pemain lain di slot semula, id/court/nomor/status/sets tetap.
2. **Satu orang satu tempat per round.** Di round n tiap pemain paling banyak satu kali di semua match + `resting[n]`;
   `resting[n] ∩ main(n) = ∅`. (Berlaku juga setelah tukar beruntun dan setelah Kelola court.)
3. **Daftar istirahat.** `B.resting[n]` = `A.resting[n]` dengan Q diganti P di indeks Q, atau + P di akhir.
4. **Tanpa kehilangan kehadiran.** `B.latePlayerIds ⊆ A.latePlayerIds`; sama persis kecuali Q keluar dari daftar
   telat **tepat** kalau round n satu-satunya round yang dia lewatkan (pemain baru setelah R1 dibuat di n = 1, AC-T12;
   atau dikembalikan setelah hanya Rn dibuat tanpa dia). Q yang juga absen di round sebelumnya tetap telat (definisi
   `latePlayerIds` = absen di round mana pun). P aktif tidak pernah masuk `latePlayerIds` karena tukar (AC-T6).
5. **Sparing.** `clubOf(Q) == clubOf(P)`; S2 (partner sesama klub) dan S4 (`pair1` klub pertama) tetap.
6. **Tukar balik = identik.** `apply(apply(A, M, P→Q), M, Q→P)` ter-encode **byte-sama** dengan A
   (`TournamentCodec.encode`, T9/AC-T5). Berlaku untuk pasangan buatan generator (id = `pairId`), yaitu semua Mixed.
7. **Daftar = Buat (T6).** Setelah tukar, himpunan `restingAfterLastRound(B, now).priority` ⊆ pemain yang dipilih
   `generateRound(n+1)` pada `now` yang sama, dan `.later` ∩ pilihan = ∅ (sama dengan AC-S11 untuk sparing).
8. **Tidak sah = tidak berubah.** `apply` null dan `swapPlayer` false: match Selesai/WO/Tidak dimainkan, round < n,
   turnamen diakhiri, Fixed, Mexicano, Q main di round n, Q dikeluarkan, Q klub lain, P bukan di match, P == Q.
9. **Ikon ⇔ kandidat.** `canSwapTeam` == (`candidates(now)` tidak kosong) untuk `now` apa pun (ikon tidak pernah
   membuka sheet kosong).

Tidak ada invariant fairness baru (keputusan 50): selisih main boleh jadi 2 karena tukar (T7, 15B). Test properti
fairness yang ada (`mixed_priority_test`, `sparing_mixed_*`, `mexicano_property_test`) tidak memakai tukar dan harus
lulus tanpa diubah.

### 15.4 Data test (= PRD 15.3 = frame; Padel, Americano 21, 15 menit, 2 court × 2 jam; id pemain = nama)

**Fixture dasar 15A/15B** (literal, bukan generator): R1 C1 Andi·Citra vs Budi·Dewi, C2 Eko·Gita vs Fajar·Hadi,
istirahat Indra, Joko · R2 C1 Andi·Gita vs Fajar·Eko, C2 Budi·Indra vs Dewi·Joko, istirahat Citra, Hadi · R3 C1
Citra·Indra vs Hadi·Joko, C2 Dewi·Eko vs Fajar·Gita, istirahat Andi, Budi. R1–R2 terisi (skor sah apa pun), R3: 15A
C1 12–9 & C2 Belum (17a), 15B keduanya Belum (17f). Jam 17a: sisa 01:20 → 40 menit sejak mulai.

**Undian.** Daftar istirahat yang tampil (Andi, Budi / Andi, Dewi / Andi, Citra) tidak bergantung undian, jadi golden
cukup fixture di atas. Yang bergantung undian hanya "Buat R3/R4". Test level controller memakai undian terkunci asli,
jadi **id turnamen fixture dicari sekali** (pola `t-court-329705`, tulis alasannya di komentar) supaya:
- R3: `lockedDraw(10 id, seed, 3)` menaruh Andi dan Budi di dua nilai terbesar di antara Andi, Budi, Dewi, Eko, Fajar,
  Gita (AC-T9: Batalkan R3 → Buat R3 → Andi, Budi istirahat lagi);
- R4: draw Gita dan Fajar < draw Eko < draw Budi dan Dewi (= undian PRD "Gita, Fajar, Andi, Joko, Eko, Citra, Budi,
  Hadi, Dewi, Indra" untuk pemain yang seri).
Peluang ±1/450 per id; skrip pencari dibuang setelah id ketemu. Test level service boleh menyuntik
`draw: drawOf([...])` ke `priorityOrder` (§14.2).

| AC | Langkah | Hasil yang diharapkan |
|---|---|---|
| AC-T2 | 15A: `swapPlayer(m-r3-2, Dewi → Budi)` | R3 C2 Budi·Eko vs Fajar·Gita, Budi = `pair1.player1Id`; id `m-r3-2`, court, nomor sama; `pair1.id` = `pairId(Budi, Eko)`; C1 tidak berubah dan `isSwappable(C1)` false (skor) |
| AC-T3 | lanjutan | `resting[3]` = [Andi, Dewi]; Jadwal: Prioritas main di R4 = Andi, Dewi, `later` kosong; jumlah main Andi 2, Budi 3, Dewi 2; Buat R4 → istirahat {Eko, Budi}, Andi dan Dewi main |
| AC-T5 | lanjutan: `swapPlayer(m-r3-2, Budi → Dewi)` | encode byte-sama dengan sebelum tukar pertama; Buat R4 → istirahat {Eko, Dewi} |
| AC-T7 | 15B: `swapPlayer(m-r3-1, Citra → Budi)` | C1 Budi·Indra vs Hadi·Joko (Budi·Indra pernah partner di R2, tetap sah); Prioritas main di R4 = {Citra, Andi} (himpunan; tampil "Andi, Citra", 15.7), main: Citra 1; Andi, Hadi, Indra, Joko 2; Budi, Dewi, Eko, Fajar, Gita 3; Buat R4 → istirahat {Budi, Dewi}; lalu R5, R6 (skor apa pun, undian apa pun): min/maks/selisih = R4 2/4/2, R5 3/5/2, R6 4/5/1 (tabel 15B) |
| AC-T9 | 15A sebelum skor C1: tukar Dewi → Budi, `cancelLastRound`, `generateNextRound` | `resting[3]` = {Andi, Budi}, Dewi main; pasangan **tidak** di-assert (acak, lihat 15.6) |
| AC-T6 | 15A dan 15B setelah tukar | `latePlayerIds` kosong. Juga: 10 pemain / 2 court, R1, tukar P keluar, Buat R2 → P main di R2 (0 main, prioritas teratas) dan `latePlayerIds` kosong setelah R2 |

"Buat R(n+1)" di semua tabel = setelah semua match round n diisi (skor sah apa pun; skor tidak memengaruhi siapa main
di Mixed) dan dengan `clockProvider` di-override ke jam yang court-nya masih muat.

**15C Sparing** (fixture `sparing_mixed_fixture.dart`, R4 generator 13B = latar 15b/17k): R4 C1 Budi·Hadi vs
Lina·Nanda, C2 Andi·Dewi vs Indra·Kiki; istirahat Garuda Citra, Eko, Fajar, Gita; Matcha Joko, Maya.

| AC | Langkah | Hasil |
|---|---|---|
| AC-T8 | `candidates(C2, Indra·Kiki)` / `(C2, Andi·Dewi)` | {Joko, Maya} / {Citra, Eko, Fajar, Gita}; `isCandidate(Indra·Kiki, Citra)` false, `apply(Kiki → Citra)` null |
| AC-T8 | `swapPlayer(C2, Kiki → Maya)` | C2 Andi·Dewi vs Indra·Maya; `restingByClubAfterLastRound`: Matcha {Joko, Kiki}, Garuda tidak berubah; S2/S4 lolos `_isValidSparing` (encode → decode tidak null) |
| AC-T8 | Garuda 4 / Matcha 6, 2 court, R1 (17n) | tim Garuda `canSwapTeam` false, tim Matcha true, kandidat Matcha = 2 yang istirahat |

**Lain-lain**

| AC | Data | Hasil |
|---|---|---|
| AC-T1 | 15A C1 (skor), C2 setelah WO, tab R2, `finishNow`, mode Fixed, mode Mexicano (fixture 14B R2), 8 pemain / 2 court R2 | `canSwapTeam` false semua; `swapPlayer` false dan state `identical` |
| AC-T10 | (a) 12 pemain / 2 court, R2 berjalan (4 istirahat), tukar P → Q di Court 2, `addCourt` Court 3 | match baru Court 3 = 4 yang istirahat **termasuk P**; `resting[2]` kosong |
| AC-T10 | (b) 14 pemain / 2 court, R2 berjalan (6 istirahat), `addCourt` Court 3 (langsung main, 2 tersisa), tukar P → Q di match Court 3, `removeCourt(Court 3)` | Q dan tiga pemain Court 3 lainnya kembali ke `resting[2]`, P tetap di sana; `resting[2]` 6 orang tanpa duplikat. (Court 2 tidak bisa dihapus: punya match R1 selesai, `canRemoveCourt`) |
| AC-T11 | 9 pemain / 2 court (Andi…Indra), R1, Hadi di C2 dikeluarkan, tukar Hadi → Indra | Indra main; `resting[1]` berisi Hadi, daftar Istirahat tampil tanpa Hadi; `reinstatePlayer(Hadi)` sebelum Buat R2 → `latePlayerIds` kosong, Hadi tampil di Istirahat |
| AC-T12 | 9 pemain / 2 court, R1 (Indra istirahat), `addPlayer(Joko)`, tukar Hadi (aktif) → Joko | `latePlayerIds` kosong (sebelum tukar = {Joko}); Prioritas main di R2 = Hadi, Indra; Buat R2 → Hadi dan Indra main |
| AC-T13 | 15A setelah tukar: encode → decode | match + `resting` sama; Buat R4 → istirahat {Eko, Budi} (sama dengan tanpa kill). `finishNow` → `isSwappable` false; `resume` → C2 `pending` lagi, `canSwapTeam` true |
| AC-T15 | 15A setelah tukar, isi C2 15–6 | `RankingCalculator.rank`: Budi 3 match, Dewi 2; Total Point Budi +15, Dewi tidak berubah; teks share/caption tanpa kata "tukar"/"ditukar" |
| AC-T16 | literal 3.4.0 payload (fixture codec yang ada) | decode → encode byte-sama (tes yang ada lulus tanpa diubah). `git diff` kosong di `lib/services/storage/`, `lib/models/`, `relay/` dicek reviewer, **bukan** di unit test (CI checkout tanpa branch `main`; perubahan sah di masa depan akan menggagalkannya) |

**Properti** (`test/services/player_swap_property_test.dart`, suite biasa, cepat): ukuran 9/2, 10/2, 12/2, 14/3, 30/4,
sparing 8/6 dan 4/6 di 2 court; 12 round; tiap round Random berseed memilih 0–2 tukar sah acak (dari
`canSwapTeam` + `candidates`) sebelum skor diisi, kadang tukar balik → invariant 15.3 #1–#5, #7, #9 setelah tiap tukar,
#6 untuk tukar balik. Tidak meng-assert selisih main.

### 15.5 Layar (ringkas; rincian visual di `screens/17-tukar-pemain-mixed.md`)

- `MatchScoreRow` (`core/widgets/match_score_row.dart`): `MatchScoreSide` mendapat aksi tukar opsional (null = tanpa
  ikon). Ikon `MabarIcons.arrowsLeftRight` (Phosphor Bold `arrows-left-right`, codepoint dari `style.css`
  `@phosphor-icons/web@2.1.1`, sama dengan konstanta lain) 16 pt `--court`, berpusat di titik kolom bola 7 pt (nama
  tidak bergeser); area ketuk 44 × 42 dari tepi strip court, separuh atas/bawah baris; label aksesibilitas
  "Tukar pemain {nama · nama}". Komponen tidak tahu aturan tukar.
- `ScheduleMatchRow` meneruskan dua callback; `schedule_mixed_screen.dart` mengisinya hanya kalau `!watching &&
  PlayerSwap.canSwapTeam(active, m, pair)`. Penonton live (`watching`) tidak pernah dapat ikon; host dengan live aktif
  dapat.
- Sheet baru `features/schedule/mixed/swap_player_sheet.dart` (`showMabarSheet`, pola sheet WO): judul "Tukar pemain",
  subjudul "Round n · Court c" (+ " · {klub}" sparing), pratinjau = `MatchScoreRow` tanpa hitung mundur/ikon/Isi skor
  dari `PlayerSwap.swapped` setelah dua pilihan (sebelumnya match apa adanya), grup "Diganti" (dua pemain tim, urut
  baris), grup kandidat dari `PlayerSwap.candidates` dengan label `RestingList` yang sama ("Istirahat · Prioritas main
  di R(n+1)" / "Istirahat lagi di R(n+1)"), `MabarChip` dua kolom; satu pilihan di Diganti, satu pilihan lintas grup
  kandidat, ketuk ulang = lepas. "Tukar" (ikon + label) mati sampai dua pilihan → `swapPlayer` → tutup sheet, tanpa
  dialog/toast. Batal, scrim, geser, back → tanpa perubahan.

### 15.6 Jebakan untuk engineer dan reviewer

1. **Mexicano dikunci**: syaratnya `mode == PartnerMode.mixed`, bukan `isEndless` (kebalikan jebakan §14.7 #5). Test
   AC-T1 Mexicano wajib.
2. **Tanpa undi ulang**: `apply` tidak memanggil generator, `_bestArrangement`, atau `Random`; hanya mengganti satu id.
3. **Id pasangan dihitung ulang** dengan `pairId`, slot pemain tidak diurut ulang (Budi di slot Dewi tetap
   `player1Id` walau `pairId` mengurutkan nama). Lupa → tukar balik tidak byte-sama (AC-T5); mengurutkan slot → nama
   di baris berpindah sisi.
4. **`resting[n]`** diganti di indeks, P tidak pernah dobel, P yang dikeluarkan **tidak** disaring (TU1) — kalau
   disaring, Kembalikan sebelum Buat R(n+1) membuat P jadi pemain telat (AC-T11 gagal).
5. **Kandidat hanya dari `restingAfterLastRound` / `restingByClubAfterLastRound`** (label dan urutan = Jadwal). Widget
   tidak menyaring pemain, tidak menghitung prioritas, tidak menukar pemain sendiri untuk pratinjau (`swapped`).
6. **Jangan menyentuh** `latePlayerIds`, `withdrawnPlayerIds`, `config`, codec, relay. `git diff` TP-1 di
   `lib/services/storage/` dan `relay/` harus kosong.
7. **`Random()` tanpa seed di Mixed**: `generateRound` dan `courtMatch` mengacak pasangan, jadi Batalkan + Buat (AC-T9)
   dan Buat R4 setelah tukar balik (AC-T5) hanya sama di **siapa main/istirahat**, bukan pasangannya. Test
   membandingkan himpunan pemain; kesamaan penuh (AC-T5, AC-T13) dibuktikan lewat encode state, bukan lewat round
   yang dibuat ulang. Jangan menambah parameter `random` ke controller hanya untuk test.
8. **Status `pending`**, bukan "tanpa skor": WO tidak punya `sets` tapi bukan pending; `finishNow` mengubah pending
   jadi `cancelled`, `resume` mengembalikannya (AC-T13).
9. **Golden 2% bisa lolos tanpa ikon** (16 pt × beberapa baris): tiap golden Jadwal yang disentuh TP-2 juga
   meng-assert jumlah ikon dengan finder (17a 2, 17f 4, 17n 2, 17r 0, 06m 0, 06t 0, 16b 0, 12h 0, 06a 0).
10. Frame lama yang sekarang berikon digambar ulang oleh designer; kalau fixture golden-nya menurut aturan **tidak**
    boleh berikon (atau sebaliknya), berhenti dan laporkan (aturan `CLAUDE.md`: frame vs catatan → tanya host), jangan
    mengubah fixture supaya cocok.

### 15.7 Urutan nama daftar Istirahat 17h (dijawab host 2026-11-12)

Host setuju rekomendasi: daftar Istirahat tetap urut daftar pemain (aturan lama, `screens/06-jadwal-mixed.md`). 17h,
17i, catatannya, dan PRD 15B sudah dikoreksi jadi "Andi, Citra" (koreksi data contoh, tanpa perubahan perilaku);
golden 17h tidak lagi di-skip.

## 16. Poster podium · Bagikan Ringkas (rencana 3.6.0)

PRD §5.9 + keputusan 60–74 (§10), frame 11a, 11c, 11d, 13q, 13r (`screens/11-bagikan.md`, `screens/13-sparing.md`) dan
18a–18t (`screens/18-poster-podium.md`), Komponen `PodiumPoster (PodiumScenePainter)` + token `posterPodium`. Poster
Lengkap (dirombak kemudian di §17), caption (`ResultTextBuilder`), Klasemen, dan simpanan **tidak berubah** → MINOR, tanpa `schemaVersion`, tanpa
DBA. Angka di bagian ini dicek tech-lead 2026-11-13 terhadap teks dan geometri SVG frame di `design/hifi.html`
(`<rect>` blok, garis belakang, posisi bola): semuanya cocok dengan aturan di bawah.

Di luar scope (PATCH terpisah, jangan ikut): kontras baris poster Lengkap di tema hijau/jingga/teal, data frame 11h.

### 16.1 Siapa naik podium (keputusan 64, 65, 68, 69; Sparing 62)

Masukan = baris Klasemen apa adanya (`standingEntriesProvider`, urutan dan `StandingEntry.position` tidak diubah);
Sparing = `ClubResult` (`clubScoreProvider`). Nomor rapat (1, 2, 2, 3), jadi nomor di podium selalu 1, 2, atau 3.

Bukan Sparing — R = baris dengan `position != null`, urut Klasemen:
1. R kosong → **Kosong** (69, 18t): tanpa blok, panel hanya wordmark + fakta.
2. k = min(3, |R|); p = `R[k−1].position`; calon = semua baris R dengan `position ≤ p` (selalu awalan R, termasuk yang
   senomor dengan baris ke-k).
3. |calon| ≤ 4 → **Anak tangga** = calon (65).
4. |calon| > 4 → buang seluruh kelompok nomor p (65, "kelompok nomor yang utuh"). Sisa tidak kosong → **Anak tangga** =
   sisa (selalu ≤ 2 baris). Sisa kosong (artinya p = 1 dan baris #1 > 4) → **Kerumunan** (68, 18s): satu blok emas lebar
   tanpa bola, satu baris panel.

Sparing — `ClubResult` r:
5. `r.first.halfWins + r.second.halfWins == 0` (belum ada match selesai/WO) → **Kosong** (asumsi, pertanyaan terbuka
   16.8 #1). Selain itu → **Klub**: dua blok, klub pertama selalu kiri dan baris atas (S4); `r.lead` = draw → keduanya
   level 1; selain itu yang unggul level 1, lainnya level 2. Seri ditentukan `lead` (match menang → Total Point), bukan
   dihitung ulang (18o: 6–6 dan 50–48 → yang 50 emas).

Blok (berlaku untuk semua jenis):
- **Level** = nomor (`position`), Sparing = 1/2 di atas. Tinggi = `tinggi[level−1]` dari tabel ukuran, **bukan** urutan
  baris (64): #1 #1 #2 → dua blok setinggi #1. Level 1 = emas (`goldBlock`), level 2/3 = warna tema.
- **Muka blok** = `'$position'`; Sparing = `ClubTally.winsLabel` ("6½"); Kerumunan = "1".
- **Bola** = jumlah nama di baris (`entry.players.length`: Mixed/Mexicano 1, pasangan 2, pemain tunggal Fixed campuran 1);
  Sparing dan Kerumunan 0.
- **Urutan slot** kiri → kanan, sebagai indeks baris (0 = baris pertama): 1 → [0]; 2 → [0, 1]; 3 → [1, 0, 2];
  4 → [1, 0, 2, 3]; Sparing → [klub pertama, klub kedua]. Urutan slot memakai indeks baris, bukan nomor: #1 #1 #2 →
  slot 2 · 1 · 3, jadi #2 di kanan (18g).
- **Ukuran pasangan** (`.duo`) = ada baris anak tangga berisi dua nama (18e, 18l). Tinggi baris panel dan tinggi blok
  ikut ukuran pasangan untuk semua baris. Sparing, Kerumunan, Kosong: tidak pernah (asumsi Kerumunan Fixed: 16.8 #2).

Invariant (wajib di test):
- I1. Anak tangga 1–4 baris, semua bernomor, awalan dari R (urutan Klasemen), dan tidak ada nomor yang terpotong: kalau
  satu baris bernomor n naik, semua baris bernomor n naik.
- I2. Dua baris dengan nomor sama → level, tinggi, warna sama; nomor beda → level beda.
- I3. Emas ⇔ level 1. Selalu ada minimal satu blok emas kecuali Kosong.
- I4. Jumlah bola = jumlah nama di baris yang naik (Kerumunan/Sparing 0).
- I6. Podium maksimal: Anak tangga berisi minimal min(3, |R|) baris, atau satu kelompok nomor utuh berikutnya akan
  membuatnya > 4 baris; Kerumunan terjadi ⇔ jumlah baris #1 > 4.
- I5. Hasil hanya bergantung pada `entries` (atau `ClubResult`); tidak membaca jam, provider, atau metode Klasemen
  langsung (metode sudah tercermin di `position`).

### 16.2 Panel dan teks (keputusan 61, 63, 68, 71)

Baris panel urut Klasemen (baris atas = baris pertama), bukan urutan slot.
- Lencana: "#n" ("#" warna teks kedua); #1 lencana emas (`#E3B341`, tinta, "#" tinta 75%), nama lebih tebal. Sparing:
  skor klub tanpa "#" (`ClubTally.winsLabel`), emas untuk klub level 1.
- Nama: Mixed satu nama; pasangan dua nama bertumpuk (`.who2`); pemain tunggal di poster campuran satu nama di tengah
  baris berukuran pasangan (18l). Sparing: nama klub.
- Nilai = nilai metode + selisih, **dengan satuan di Feed dan Story** (63): Total Point `80` + "poin · +34" (satuan dari
  `format.unit`); Win % `100%` + "· +19" (`winPercent.round()`, sama dengan `sharePosterData`). Sparing:
  `ClubTally.totalPoint` + "game · 0" = `ClubResult.detailLabel` (selalu Total Point klub, tidak ikut metode Klasemen).
- Kerumunan (68): satu baris, lencana emas "#1", nama = "{n} pemain" / "{n} pasangan" (n = jumlah baris #1), nilai dari
  baris #1 pertama (semua baris #1 identik nilai dan selisihnya karena `compare` = 0).
- Kepala: bernama → judul = nama, baris kecil "Klasemen akhir|sementara · {tanggal}"; tanpa nama → judul "Klasemen
  akhir|sementara", baris kecil "{olahraga} · {mode} · {tanggal}" (`config.mode.label`: Mexicano menulis "Mexicano").
  Tanggal "6 Nov 2026" (`createdAt`, bulan singkat seperti `share_content.dart`).

**Baris fakta** (63, 71) = bagian berikut digabung " · ", tanpa tanggal:
1. olahraga (`sport.label`), **hanya kalau bernama**;
2. "{n} {kata}" dengan n = jumlah baris Klasemen (termasuk "Belum main"; Sparing = jumlah baris kedua klub) dan kata =
   "pemain" (Mixed/Mexicano) / "pasangan" (Fixed semua pasangan); Fixed campuran (kata null, 09g) → bagian ini
   **dihilangkan** (71, 18l);
3. Final (`isFinal`): "{playedRoundCount} round", "{playedMatchCount} match"; Sementara: "R{currentRound}",
   "{playedMatchCount} dari {matches.length} match" (ekspresi yang sama dengan subjudul Klasemen,
   `leaderboard_screen.dart:23`);
4. "{w} WO" kalau ada match WO (Final dan Sementara).

Ukuran teks (rincian `tokens.json → posterPodium`): nama mengecil **bersama** sampai muat, batas bawah 11,5, lalu elipsis
per nama (18m); fakta mengecil dari 10,5 sampai muat dan tidak pernah terpotong (11d: 9,3); nilai tidak pernah dipotong;
judul satu baris di 22 (Story 27), kalau tidak muat satu baris → 18,5 (Story 23) maksimal dua baris (11d, 18m;
pemicu "tidak muat satu baris" adalah bacaan tech-lead atas `.ptitle.two`).

### 16.3 Tema (keputusan 66, 67; 70 diganti 76)

- Bawaan = **lapangan**: palet ikut `config.sport` (`posterPodium.courtThemes`: padel lantai `#BC5A33`, tennis
  `#1E6BB8`, latar `court-deep`). Sepuluh gradien `ShareTheme` tetap bisa dipilih; turunan warnanya per tema ada di
  `posterPodium.gradientThemes` (pakai nilainya apa adanya, jangan menurunkan ulang dengan rumus).
- Deret: 11 lingkaran 27 pt satu baris (lingkaran lapangan = belang `court-deep` / putih / lantai, 180°, 46–54%), sama
  di Ringkas dan Lengkap sejak keputusan 76 (rencana 3.7.0, §17.8). Keputusan 70 (Lengkap 10 lingkaran 30 pt, lapangan
  dipetakan ke biru) hanya berlaku di 3.6.x. Gradien yang dipilih berlaku untuk kedua format (18b → 11b). Pilihan tidak
  disimpan.
- Panel 86% di semua tema; teks panel pakai `panelText`/`panelText2` token, garis baris teks panel 16% (lembut 20%).

### 16.4 API yang diusulkan (`lib/services/share/podium.dart`, baru, Dart murni)

```dart
/// Poster podium (PRD §5.9, keputusan 61–65, 68, 69). Total: tidak melempar; tidak membaca jam/provider.
sealed class Podium {
  /// [entries] = `standingEntriesProvider` apa adanya. [clubs] != null → Sparing (entries diabaikan).
  static Podium of({required List<StandingEntry> entries, ClubResult? clubs});
}

/// 69: tidak ada yang bernomor (Sparing: skor klub 0 – 0).
final class PodiumEmpty extends Podium {}

/// 65: 1–4 baris, urut Klasemen.
final class PodiumSteps extends Podium {
  final List<StandingEntry> rows;
  bool get pairSize; // ada baris dua nama
  List<PodiumBlock> get blocks; // kiri → kanan (urutan slot 16.1)
}

/// 68: baris #1 lebih dari empat.
final class PodiumCrowd extends Podium {
  final List<StandingEntry> rows; // semua baris #1, urut Klasemen
  PodiumBlock get block; // level 1, muka "1", 0 bola
}

/// 62: dua blok klub.
final class PodiumClubs extends Podium {
  final ClubResult result;
  List<PodiumBlock> get blocks; // [first, second]
}

class PodiumBlock {
  final int level; // 1–3; menentukan tinggi dan warna
  final String face; // angka di muka blok
  final int balls;
  bool get gold => level == 1;
}

/// Pindahan `shareRowNoun` (features/share) supaya service bisa memakainya; satu fungsi saja, yang lama dihapus.
String? rowNoun(ActiveTournament active, List<StandingEntry> rows);

/// Baris fakta 16.2. [rows] = baris Klasemen (Sparing: baris kedua klub digabung). [isFinal] dari layar
/// (`active.isFinal(clock())`), service tidak membaca jam.
String podiumFacts({required ActiveTournament active, required List<StandingEntry> rows, required bool isFinal});
```

Teks baris panel (lencana, nama, nilai, kepala) dibentuk di `features/share/share_content.dart` (fungsi baru
`podiumPosterData`, pola yang sama dengan `sharePosterData`) dari `Podium` + `podiumFacts`; widget hanya menggambar.

### 16.5 Data test (= frame; nama test memakai id frame + nomor keputusan, mis. `18i K65 …`)

Baris dibuat literal (`StandingEntry` + `PlayerStanding` yang menghasilkan nilai/selisih frame). Pola selisih: Americano
21 Mixed dengan semua main m kali → selisih = 2 × poin − 21m.

| Frame | Baris Klasemen (nomor · nama · nilai · selisih) | Hasil |
|---|---|---|
| 18c | #1 Hana 80 +34, #2 Gina 76 +26, #3 Fajar 69 +12, #4 68 +10 (12 pemain) | Steps 3; slot [1,0,2]; level slot [2,1,3]; bola 3 |
| 11a | #1 Andi 42 +12, #1 Dewant 42 +12, #2 Hana 36 0, #3 Fajar 30 −12, #4 Gina 27 +6 (data set 1, §4) | Steps 3 (Fajar tidak naik); level slot [1,1,2] |
| 18f | #1 Eko 61 +17, #2 Fajar 58 +11, #2 Gina 58 +11, #3 55 +5 (8 pemain, m = 5) | Steps 3; level slot [2,1,2] |
| 18g | #1 Budi 60 +15, #1 Dewant 60 +15, #2 Gina 57 +9 | Steps 3; level slot [1,1,2] |
| 18h | #1 Andi 62 +19, #2 Citra 59 +13, #3 Eko 56 +7, #3 Hana 56 +7, #4 52 −1, 49, 45, 41 | Steps 4; slot [1,0,2,3]; level slot [2,1,3,3] |
| 18q-3 | #1 Budi 60 +15, #1 Maya 60 +15, #2 Oki 55 +5, #2 Rizky 55 +5, … | Steps 4; level slot [1,1,2,2] |
| 18q-4 | #1 Nanda 63 +21, #2 Kiki, Putri, Hana 56 +7, … | Steps 4; level slot [2,1,2,2] |
| 18i | #1 Joko 78 +30, #2 Andi 74 +22, #3 ×3 67 +8, 7 lainnya | 5 calon → buang #3 → Steps 2; slot [0,1]; level [1,2] |
| 18q-1 | Fixed R1, 6 pasangan, tiga 6–4: #1 ×3 100% +2, #2 ×3 0% −2 | Steps 3, semua level 1, pairSize, bola 6 |
| 18q-2 | Americano R1 8 pemain, dua 12–9: #1 ×4 12 +3, #2 ×4 9 −3 | Steps 4 semua level 1 (tepat batas) |
| 18q-5 | #1 Lina 64 +23, #2 ×4 53 +1 | 5 calon → buang #2 → Steps 1; slot [0] |
| 18s | Americano R1 12 pemain, tiga 12–9: #1 ×6 12 +3, #2 ×6 9 −3 | Crowd n = 6; panel "6 pemain", "12" + "poin · +3" |
| batas | #1 ×5 (dibuat dari 18s dengan satu baris #1 lebih sedikit) | Crowd n = 5 |
| 18j | Fixed tennis 3 match: #1 67% +3, #2 33% −3 | Steps 2; level [1,2]; pairSize |
| 18l | #1 Indra + Joko 95 +22, #2 Andi 91 +14 (tunggal), #3 Eko + Fajar 89 +10 (data 09g) | Steps 3; pairSize; bola slot [1,2,2] = 5 |
| 18t | 12 pemain, semua `position == null` | Empty |
| 13q | Sparing 13C Final: Garuda 7 – 5 Matcha | Clubs [L1 emas "7", L2 "5"] |
| 18n | 14s: Garuda 5 – 7 Matcha, TP 56 – 60 | Clubs [L2 "5", L1 emas "7"] (klub pertama tetap kiri) |
| 18o | 14t: 6 – 6, TP 58 – 58 | Clubs [L1 "6", L1 "6"], dua emas |
| 18o-b | 6 – 6, TP 50 – 48 (catatan 18o) | Clubs [L1 "6", L2 "6"] |
| 18p | 14u: 6½ – 5½ | Clubs [L1 "6½", L2 "5½"] |
| 16.8 #1 | Sparing tanpa match selesai, 0 – 0 | Empty |

Baris fakta (`podiumFacts`), teks persis frame:

| Frame | Keadaan | Fakta |
|---|---|---|
| 18c | bernama, Final, Mixed 12, 6 round, 18 match | `Padel · 12 pemain · 6 round · 18 match` |
| 18d | tanpa nama, sama | `12 pemain · 6 round · 18 match` |
| 18e | tanpa nama, Fixed 6 pasangan, 15 match | `6 pasangan · 5 round · 15 match` |
| 11d | bernama, Final, 1 WO | `Padel · 10 pemain · 4 round · 8 match · 1 WO` |
| 11a / 11c | bernama / tanpa nama, Sementara R3 lengkap | `Padel · 11 pemain · R3 · 6 dari 6 match` / `11 pemain · R3 · 6 dari 6 match` |
| 18k | bernama, Sementara R3, 7 dari 9 | `Padel · 12 pemain · R3 · 7 dari 9 match` |
| 18l | tanpa nama, Fixed campuran | `16 round · 32 match` |
| 18t | bernama, R1 belum ada skor | `Padel · 12 pemain · R1 · 0 dari 3 match` |
| 18s | bernama, R1 tiga skor | `Padel · 12 pemain · R1 · 3 dari 3 match` |
| 18q-1 / 18q-2 | tanpa nama, Sementara R1 | `6 pasangan · R1 · 3 dari 3 match` / `8 pemain · R1 · 2 dari 2 match` |
| 13q | tanpa nama, Sparing Fixed, 1 WO | `7 pasangan · 6 round · 12 match · 1 WO` |

Untuk fakta, `ActiveTournament` dibuat dari fixture yang sudah ada kalau ada (data set 1 `bagikan_test.dart`,
`sparingFull` `sparing_bagikan_test.dart`, 09g); sisanya cukup turnamen dengan jumlah round/match/WO yang sama (nilai
pemain tidak berpengaruh ke fakta).

### 16.6 Tata letak gambar (untuk PP-2; bukan logika domain, tetap diuji)

Kanvas: kartu pratinjau 358 × 372 (ukuran Feed, panel inset samping 13), Feed 360 × 360, Story 360 × 640; Feed dan
Story diekspor ×3 (1080 × 1080, 1080 × 1920). Story podium **bukan** kanvas 203 × 360 poster Lengkap. Semua angka di
token `posterPodium`; turunan yang dicek dari SVG frame:
- Panel: tinggi = 6 + baris × tinggi baris + kaki (Feed 26, Story 34); bawah panel di inset 14 (Story 84).
  **Dasar blok** = atas panel − 10. Kosong: dasar dihitung seperti panel tiga baris (garis belakang sama dengan 18c).
- Lebar blok per jumlah anak tangga (1, 2 → 101; 3 → 78; 4 → 64; Story 124/124/96/78); Kerumunan = 3 × lebar 3
  (234, Story 288); Sparing = lebar 2. Kelompok blok + kedalaman dx dipusatkan: x0 = ⌊(W − (n·w + dx)) / 2⌋
  (Feed 3 blok 55, 2 blok 71, 1 blok 121; kartu 3 blok 54).
- Kedalaman (dx, dy) Feed (16, −10), Story (22, −13). Muka atas blok yang bersebelahan dan sama tinggi menyatu (satu
  poligon, 18g/18q). Muka samping hanya di kanan blok yang tetangga kanannya **lebih rendah atau tidak ada** (18n).
- Angka muka: ukuran = round(0,656 × tinggi), Archivo 800 wdth 72, dipusatkan dengan cap-height (garis dasar ≈
  tengah blok + 0,344 × ukuran); lebih dari satu karakter dikecilkan sampai ±70% lebar blok (18p). Rumus yang cocok
  dengan frame (PP-2, diukur di 18p, satu-satunya frame dua karakter): ukuran = round(min(0,656 × tinggi, 0,7 × lebar
  ÷ (0,54 × jumlah karakter))), perkiraan 0,54 em per karakter, bukan lebar terukur font (Feed 63, Story 80).
- Judul: coba 22 (Story 27) terhadap W − 44; tidak muat → 18,5 (Story 23), jumlah baris (1–2) dari layout sebenarnya.
  Nama panel mengecil per 0,5 dari ukuran dasar sampai 11,5; fakta per 0,1 dari 10,5 (cocok 18m Story 11,5, 11d 9,3).
- Bola (`MabarBall`, jangan menyalin painternya): Feed 22 / pasangan 19, Story 30 / 26, jarak pasangan 2; pusat
  horizontal = tengah blok + dx/2; bawah bola = atas blok + dy/2 + 2; bayangan elips rx 0,41 × ukuran, warna
  `ball.shadow`. Tinggi bola di atas blok (rise) = ukuran + |dy|/2 − 2 (Feed 25, pasangan 22; Story 34,5, pasangan 30,5).
- **Batas tinggi**: h1' = min(h1, ⌊dasar − bawahKepala − 12 − rise⌋); tinggi lain = round(h × h1'/h1). Cek: 18h Story
  (panel 4 baris, dasar 338, kepala 151,7) → 139 / 100 / 67; 11d Story (judul dua baris, kepala 172,6, dasar 380) →
  160 / 115 / 77; 18m Story pasangan (dasar 344) → 128 / 92 / 62; Feed di semua frame tetap. bawahKepala dihitung dengan
  line-height CSS (`_CssLines`), bukan metrik font Flutter, supaya pembulatan ke bawah sama.
- Garis belakang lapangan: y = dasar − (h3' + 6) dengan h3' = tinggi #3 baku varian itu setelah batas tinggi, walau
  tidak ada blok #3 (Sparing, 2 anak tangga, Kosong); sudut di x 40 (Story 44), tebal garis tepi 4,5 (Story 5,5).
- **Lantai = lapangan utuh** (keputusan 91, generator hi-fi `tool/hifi_court_floor.py`, token
  `posterPodium.court`): tennis/padel dengan semua garis resmi lalu dipotong kanvas. Titik (u, v, t) m →
  x = sudut + S·u − k·g·v, y = garis belakang + g·v − S·t; k = dx ÷ |dy| blok podium poster itu (Lengkap: podium
  mini; tanpa blok tetap k susunannya); S = garis samping kanan memotong tepi bawah di W − sudut; g = net 10 di bawah
  kanvas. Net tidak digambar. Padel: dinding kaca belakang + kiri dan pagar kawat, tiap lapis satu kelompok
  ber-opacity; di belakang kepala (kotak `.phead`/`.lhead` + 4, dibulatkan keluar) dinding opacity 0,25, memudar
  smoothstep 6 pt ke luar. Urutan: dinding (dengan mask), lantai, garis dalam, garis tepi, lalu podium. Geometri =
  `lib/services/share/court_floor.dart` (diuji), painter hanya menggambar.

### 16.7 Jebakan untuk engineer dan reviewer

1. **Nomor dari `position`**, jangan dari indeks (`CLAUDE.md` Pitfalls). Tinggi dan emas dari nomor; urutan slot dari
   indeks baris. Tukar keduanya → 18g (#2 di kanan) dan 18f (dua #2 sama tinggi) salah.
2. **Pangkas per kelompok utuh**, bukan `take(4)`: #1 #2 #3 #3 #3 → dua anak tangga, bukan empat. Dan bukan
   `take(3)`: #1 #2 #3 #3 → empat.
3. **Nomor rapat**: setelah #1 #1 datang #2, bukan #3. Jangan menulis aturan yang menganggap #3 selalu ada.
4. **Kerumunan hanya kalau #1 > 4**; #1 tepat 4 = empat blok emas (18q-2). Nilai Kerumunan dari satu baris #1, jangan
   dijumlah.
5. **Sparing tidak memakai baris pemain** di podium; emas/tinggi dari `ClubResult.lead`, angka dari `winsLabel`. Jangan
   menghitung ulang skor klub di widget. Klub pertama selalu kiri walau kalah (18n).
6. **Fakta**: tanpa tanggal (tanggal di baris kecil kepala); kata hilang di Fixed campuran; olahraga hanya kalau
   bernama; Sementara memakai `matches.length` (match yang sudah dibuat), bukan estimasi. `isFinal` dioper dari layar
   (jam dari `clockProvider`), service tidak memanggil `DateTime.now()`.
7. **18t tombol Bagikan tetap aktif** (69); jangan menambah kondisi mati/teks "belum ada skor".
8. **Satu `rowNoun`**: pindahkan `shareRowNoun`, jangan menyalin; pemakai lama (keterangan Lengkap, `more` Lengkap)
   memakai yang baru.
9. **Lengkap tidak berubah di 3.6.0** (dirombak di rencana 3.7.0, §17): `SharePoster`, `SharePosterTarget` (Story 202,5 × 360), `sparingPosterDensity`, golden
   11b, 11e–11l, 13s–13w lolos tanpa diubah. Cabang Ringkas lama (`shareSummaryCount`, `shareClubSummaryCount`, "+n …
   lainnya" untuk Ringkas) dihapus, bukan dibiarkan mati.
10. **Ekspor Story ×3 dari 360 × 640**: target podium punya ukuran dan `exportPixelRatio` sendiri (3); jangan memakai
    `SharePosterTarget.story` untuk podium (hasilnya 1080 × 3413 atau gambar gepeng).
11. **Warna dari token**, termasuk turunan gradien lembut (`gradientThemes`), bukan `Colors.white` atau rumus baru;
    panel `alpha 0.86`. Emas sama di semua tema.
12. **Golden 2% bisa lolos dengan bola/lencana kurang** (benda kecil): test gambar juga meng-assert jumlah `MabarBall`
    dan teks lencana per frame (18c 3, 18e 6, 18l 5, 18n 0, 18s 0, 18t 0).
13. **Caption tidak berubah** (`ResultTextBuilder`): tes caption 13q dan 11a yang lama lolos tanpa diubah.

### 16.8 Pertanyaan terbuka — dijawab host 2026-11-13: ketiga asumsi disetujui (keputusan 72–74 di PRD)

1. Sparing yang belum punya match selesai (skor klub 0 – 0): tidak ada frame. Asumsi: ikut keputusan 69 → Kosong
   (lapangan kosong, fakta "7 pasangan · R1 · 0 dari 6 match"), bukan dua blok emas "0". Rekomendasi: setujui asumsi.
2. Kerumunan (68) di Fixed: frame 18s hanya Mixed. Asumsi: baris dan blok ukuran tunggal (baris satu teks "6
   pasangan", tanpa bola), bukan ukuran pasangan. Rekomendasi: setujui.
3. Kerumunan di Fixed campuran (kata null): asumsi nama baris "{n}" tanpa kata, mengikuti 71/09g. Kasusnya hampir
   mustahil (perlu > 4 baris #1 setelah atur ulang). Rekomendasi: setujui, atau host memilih kata.

## 17. Poster Lengkap · Podium mini (rencana 3.7.0)

PRD §5.9 + keputusan 76–88 (§10), frame 11b, 11e–11m (`screens/11-bagikan.md`) dan 13s–13w (`screens/13-sparing.md`),
Komponen → `.lk` + token `posterLengkap` (warna, panel, kaki, wordmark, fakta = `posterPodium`). Caption
(`ResultTextBuilder`), keterangan di bawah tab, Klasemen, simpanan, dan poster Ringkas **tidak berubah** → MINOR, tanpa
`schemaVersion`, tanpa DBA. Angka di bagian ini dicek tech-lead 2026-11-13 terhadap teks dan geometri SVG frame di
`design/hifi.html` (rect blok, path garis belakang, `--row`, `--s`, `--k`, `right` kepala): semuanya cocok dengan rumus
di bawah.

Menggantikan: ambang baris lama §9 (10 baris, 15 per kolom, 16/20 baris nama), `sparingPosterDensity` (§13.9),
keputusan 70 (§16.3: Lengkap 10 × 30 pt, lapangan = biru), kanvas Story 202,5 × 360, kepala lama (piala, `eyebrow`,
`summary`, `.pscore`, `.pclub`).

### 17.1 Susunan dan isi

Satu poster = `.scene` (`PodiumScenePainter`: latar, lantai, garis belakang, podium mini) + `.lhead` (judul, baris
kecil) di kiri atas + `.lpanel` (baris, lalu kaki) di bawah. Kanvas sama dengan poster podium (`PodiumPosterTarget`):
kartu 358 × 372 (tata letak Feed, panel inset samping 13), Feed 360 × 360, Story 360 × 640; Feed dan Story diekspor ×3.
Tema = `PodiumTheme` yang sama dengan Ringkas (17.8).

- **Judul dan baris kecil** = kepala poster podium (16.2 "Kepala"): bernama → nama + "Klasemen akhir|sementara ·
  {tanggal}"; tanpa nama → "Klasemen akhir|sementara" + "{olahraga} · {mode} · {tanggal}".
- **Kaki** = wordmark + baris fakta `podiumFacts` (16.2), sama persis dengan podium (11b: "10 pasangan · 9 round · 45
  match"; 11e: "Padel · 20 pemain · 8 round · 32 match"; 13s: "7 pasangan · 6 round · 12 match · 1 WO").
- **Baris** = semua baris Klasemen bernomor (`position != null`), urut Klasemen; nilai metode + selisih (77,
  `SharePosterRow` tetap: `value`, `detail` satuan atau null untuk Win %, `diff`). Tanpa W–L.
- **Sparing**: per klub (klub pertama dulu) kepala `.lclub` = nama klub + `ClubResult.detailLabel(tally)` ("56 game ·
  +13"), **tanpa angka skor** (83); lalu baris bernomor klub itu dari `clubStandingEntriesProvider` (nomor mulai 1 di
  tiap klub, #1 tiap klub lencana emas).
- **Kosong** (87, 11m Story): `Podium.of` = `PodiumEmpty` → panel hanya kaki (tanpa baris dan tanpa kepala klub),
  garis belakang tanpa blok.

### 17.2 Podium mini: siapa naik (79, 85)

= `Podium.of(entries:, clubs:)` apa adanya (16.1), **tidak ada aturan baru**. Pemetaan ke blok = pemetaan Ringkas di
`podiumPosterData` (satu fungsi bersama, jangan disalin): `PodiumSteps` → blok per slot (urutan 2 · 1 · 3 · 4, tinggi
dari nomor); `PodiumCrowd` → satu blok lebar level 1, muka "1", 0 bola; `PodiumClubs` → dua blok skor klub
(`winsLabel`), klub pertama kiri; `PodiumEmpty` → tanpa blok. Ukuran bola pasangan ⇔ `PodiumSteps.pairSize`. Podium
mini tidak menulis nama.

### 17.3 Kolom dan satuan baris (81, 86, 88)

| Kasus | Kartu / Feed | Story |
|---|---|---|
| Fixed (semua pasangan, Fixed campuran, Sparing Fixed) | 1 kolom | 1 kolom; baris pasangan ditumpuk (`.prow.duo`) |
| Mixed / Mexicano, n baris | n > 10 → 2 kolom rata | n > 20 → 2 kolom rata |
| Sparing Mixed, n1 + n2 baris | selalu 2 kolom per klub | n1 + n2 > 20 → 2 kolom per klub; selain itu 1 kolom |

- Gerbang dua kolom = `config.mode.isEndless` (Mixed, Mexicano), **bukan** "tidak ada baris pasangan".
- **2 kolom rata**: k = ⌈n/2⌉; kiri baris 0 … k−1, kanan k … n−1 (urut ke bawah dulu); baris kiri-kanan sejajar, n
  ganjil → slot kanan bawah kosong (11i 7–6, 11j).
- **2 kolom per klub** (86): kiri klub pertama, kanan klub kedua, tiap kolom diawali kepala klubnya; k = 2 + max(n1,
  n2); klub yang lebih kecil menyisakan slot kosong di bawah (13u dua slot). Satu kolom tidak pernah berisi dua klub.
- **1 kolom**: urut Klasemen; Sparing = kepala klub pertama, barisnya, kepala klub kedua, barisnya.
- **Satuan** (dipakai kepadatan) = tinggi kolom terpanjang dalam tinggi baris: baris biasa 1; kepala klub 2; Story
  Fixed: **semua** baris 2 kalau ada baris dua nama (seperti `.duo` Ringkas 18l dan Lengkap lama; nama ditumpuk hanya
  di baris yang memang dua nama — asumsi 17.13 #2). Dua kolom rata = k; dua kolom per klub = k; Kosong = 0.
- **Susunan ukuran** (kunci `posterLengkap.density`): `feed1` (kartu/Feed 1 kolom), `feed2` (kartu/Feed 2 kolom),
  `story1`, `story2`.

### 17.4 Kepadatan (80)

```
ruang       = bawahPanel − (garisBelakang + jarakPanel) − 6 − kaki
tinggiBaris = min(batasBaris, ruang ÷ satuan)
s           = min(batasSkala, tinggiBaris ÷ acuan)
tinggiPanel = 6 + satuan × tinggiBaris + kaki        atasPanel = bawahPanel − tinggiPanel
```

bawahPanel: kartu 358, Feed 346, Story 556 (640 − 84); jarakPanel 9 (Story 10); kaki 26 (Story 34); garisBelakang dari
17.5. Daftar pendek berhenti di batas baris: panel memendek dari atas, lantai tampil lebih banyak (11h atas 170).

| Susunan | acuan | batasBaris | batasSkala | kolom nomor | jarak | nomor / nama / nilai / sisa (× s) | satuan di nilai |
|---|---|---|---|---|---|---|---|
| feed1 | 22 | 30 | 1,04 | 30 | 8 | 15 / 13,5 / 16 / 10,5 | ya ("52 game · +18") |
| feed2 | 18 | 40 (keputusan 92; dulu 26) | 1,0 | 22 | 5 | 13 / 12 / 13,5 / 10 | tidak ("89 · +31") |
| story1 | 17 | 42 | 1,33 | 30 | 8 | 14 / 13,5 / 15 / 10,5 | tidak |
| story2 | 18 | 30 | 1,0 | 22 | 5 | 13 / 12 / 13,5 / 10 | tidak |

Kolom nomor dan jarak juga × s. Batas skala = ukuran panel podium (nama 13,5 × 1,04 = 14 Feed; × 1,33 = 18 Story).
Kepala klub: nama = nama × 1,06 × s (800, w95, elipsis), baris kedua = sisa × s (600, teks kedua), jarak 2s, tinggi
2 × tinggiBaris. Yang **tidak** ikut s: judul, baris kecil, wordmark, fakta, podium mini.

Invariant (wajib di test):
- L1. Tiap baris yang tampil muncul tepat sekali; dibaca kolom kiri atas → bawah lalu kanan, urutannya = urutan
  Klasemen (Sparing: klub pertama lalu kedua, masing-masing urut Klasemen klub).
- L2. Fixed tidak pernah dua kolom. Dua kolom per klub: tiap kolom berisi tepat satu klub dan diawali kepalanya.
- L3. satuan × tinggiBaris ≤ ruang (panel tidak menabrak garis belakang + jarak); tinggiBaris ≤ batasBaris, s ≤
  batasSkala; s tidak naik kalau satuan bertambah (ruang sama).
- L4. Hasil hanya dari angka masukan (target, mode, jumlah baris, ruang): tidak membaca jam, provider, atau font.

### 17.5 Kepala, kolom judul, garis belakang (82, 84)

- **Kanan kepala** = 22 + lebarPodium + 12; lebarPodium = slot × lebarSlot + dx. Slot = jumlah anak tangga (Steps 1–4),
  3 untuk Kerumunan **dan** Kosong (11m: kolom judul tetap 118 / 126), 2 untuk Klub.

  | Podium | Steps 1 | Steps 2 / Klub | Steps 3, Kerumunan, Kosong | Steps 4 |
  |---|---|---|---|---|
  | kanan kepala kartu/Feed (Story) | 74 (78) | 108 (114) | 118 (126) | 124 (130) |

- Lebar kolom judul = W − 22 − kanan (kartu 358, Feed/Story 360).
- **Judul** 800 w95, line-height 1,1: 22 (Story 27) kalau muat satu baris; tidak muat → 18,5 (Story 23), jumlah baris
  1–2 dari layout sebenarnya; masih lebih dari dua baris di 18,5/23 → elipsis di baris kedua (82).
- **Baris kecil** 700, 12,5 (Story 15), jarak dari judul 4 (Story 6), selalu satu baris: lebih lebar dari kolom judul →
  turun per 0,5 sampai muat, paling kecil 11; di 11 masih tidak muat → elipsis (CSS `.lsub`), tidak pernah dua baris
  (84).
- **bawahKepala** = atasKepala (22; Story 98) + baris × ukuranJudul × 1,1 + jarak + ukuranBarisKecil × 1,2, dengan
  ukuran baris kecil **sesudah** dikecilkan; line-height CSS, bukan metrik font Flutter (pola `_CssLines` 16.6).
- **garisBelakang** y = round(bawahKepala + 14) (Story + 18). Sudut x 40 (Story 44), tebal 4,5 (5,5); lantai
  lapangan utuh sama dengan Ringkas (16.6, keputusan 91) dengan k podium mini (Feed 1,5, Story 1,6).

### 17.6 Geometri podium mini (79, 85; token `posterLengkap.miniPodium`)

- Dasar blok = garisBelakang. Tinggi #1 / #2 / #3 = 34 / 24 / 16 (Story 52 / 37 / 25), **tetap**: tanpa batas tinggi
  dan tanpa tinggi pasangan (beda dengan Ringkas 16.6).
- Lebar slot: 1–2 slot → 34, 3 → 26, 4 → 21 (Story 36, 36, 28, 22). Kerumunan = satu blok 3 × lebar 3 (78; Story 84).
- x0 = W − 22 − dx − slot × lebarSlot; blok ke-i di x0 + i × lebarSlot (kanan blok + dx = W − 22).
- Kedalaman (dx, dy) = (6, −4), Story (8, −5). Muka atas menyatu, muka samping, urutan gambar, warna = Ringkas.
- Angka muka = rumus Ringkas yang sama (`_faceSizeFor`): round(0,656 × tinggi), lebih dari satu karakter dibatasi
  0,7 × lebar ÷ (0,54 × jumlah karakter); w72, 800, garis dasar = tengah blok + 0,344 × ukuran.
- Bola (`MabarBall.paint` lewat painter): 9 / pasangan 8 (Story 12 / 10), jarak antarbola pasangan **1** (Ringkas 2);
  pusat x = tengah blok + dx/2; bawah bola = atas blok + dy/2 **+ 1** (Ringkas + 2); bayangan sama dengan Ringkas (rx
  0,41 d, ry 0,13 d, pusat di bawah bola − 0,5).

### 17.7 Panel dan baris (`.lpanel`, `.prow`)

- Panel: kiri/kanan 14 (kartu 13), bawah 14 (Story 84), radius 14, padding 6 / 12 / 0 (dua kolom 6 / 10 / 0), warna
  panel 86% dan teks dari `PodiumTheme`; tiap baris bergaris bawah 1 `panelLine`.
- Dua kolom: column-gap 14, garis tengah 1 `panelLine` di 50% lebar, dari 3 di bawah atas kolom sampai 3 di atas
  bawahnya.
- Baris = [kolom nomor] [nama, sisa lebar] [nilai, selebar isinya], jarak antarsel = jarak × s; tinggi = tinggiBaris
  (duo dan kepala klub 2 ×).
- Nomor w72 800, "#" warna teks kedua; #1 lencana emas = lencana podium (`#E3B341`, tinta, "#" tinta 75%, padding
  0,08 / 0,3 em, digantung −0,3 em, radius 0,35 em) dengan ukuran nomor × s. Satu widget lencana untuk kedua poster.
- Nama 600 w88 (#1 800), line-height 1,2; kartu/Feed pasangan "A + B" satu baris; Story pasangan ditumpuk
  (line-height 1,16).
- Nilai w72 + sisa 600 warna teks kedua, jarak 3 × s: feed1 "52" + "game · +18" (Win %: "80%" + "· +8"); feed2,
  story1, story2 "89" + "· +31". **Nilai tidak pernah dipotong.**
- **Nama dikecilkan bersama** (kn) per poster/target (kartu, Feed, Story dihitung sendiri): dari 1 turun 0,02 sampai
  setiap nama muat di sel namanya (ukur dengan bobot baris itu: #1 800), paling kecil 0,82; sesudah itu elipsis per
  nama. Nilai di frame: 11e kartu, 11f Feed, 11h, 11j (11, 13, 15, 17) = 0,94; 11j (19), 11l Story = 0,86; lainnya 1
  (kolom nilai selebar nilai terlebar se-poster, keputusan 92).
- Kaki `.psig` = kaki podium (wordmark + fakta mengecil per 0,1 dari 9,5, keputusan 92, tidak pernah terpotong), tinggi 26 (34).

### 17.8 Tema (76, menggantikan 70)

- Deret tema di tab Ringkas dan Lengkap **sama**: 11 lingkaran 27 pt satu baris (lapangan + 10 gradien), tinggi deret
  30. Lengkap memakai `PodiumTheme` yang sama dengan Ringkas: lapangan → `PodiumTheme.court(sport)` (tidak lagi
  dipetakan ke biru), gradien → `PodiumTheme.gradient(t)`. Pilihan berlaku untuk kedua format, tidak disimpan.
- Warna blok, panel, teks, lantai, garis = token `posterPodium` apa adanya (11h biru, 11b/13u peach). Turunan
  `ShareTheme.ink` lama tidak dipakai poster lagi; enum `ShareTheme` tetap (gradien dan lingkaran deret).

### 17.9 API yang diusulkan

`lib/services/share/lengkap.dart` (baru, Dart murni, wajib test) — hanya aturan kolom (81, 86, 88) dan kepadatan (80):

```dart
/// Kunci `posterLengkap.density`.
enum LengkapSizing { feed1, feed2, story1, story2 }

/// Satu sel kolom poster Lengkap. [club] = 0 kalau bukan Sparing.
sealed class LengkapCell { int get units; }
final class LengkapRowCell extends LengkapCell { final int club; final int row; final int units; } // row = indeks di klubnya
final class LengkapClubCell extends LengkapCell { final int club; int get units => 2; }

class LengkapGrid {
  final LengkapSizing sizing;
  final List<List<LengkapCell>> columns; // 1 atau 2 kolom
  final int units;                       // satuan kolom terpanjang
}

/// [rowCounts]: bukan Sparing [n]; Sparing [n1, n2]. [endless] = `config.mode.isEndless`. [pairs] = ada baris dua nama.
LengkapGrid lengkapGrid({required bool story, required bool endless, required List<int> rowCounts, required bool pairs});

class LengkapDensity { final double rowHeight; final double scale; }

/// 17.4. [space] = ruang panel (dihitung tata letak dari garis belakang). units == 0 → rowHeight 0, scale 1.
LengkapDensity lengkapDensity({required LengkapSizing sizing, required int units, required double space});
```

Tetap dipakai apa adanya: `Podium.of`, `podiumFacts`, `rowNoun` (`services/share/podium.dart`).

`lib/features/share/` (tata letak + gambar; bukan logika domain, tetap diuji):
- `widgets/podium_poster.dart`: satu fungsi penempatan blok + bola dipakai `podiumLayout` (Ringkas) dan fungsi baru
  `miniPodiumLayout` (17.6) — keduanya menghasilkan `PodiumLayout` untuk `PodiumScenePainter` yang sama; beda Lengkap
  hanya parameter (dasar = garis belakang, tinggi tetap, jarak bola 1, angkat +1). Lencana emas dan kaki `.psig`
  dijadikan widget bersama (ukuran sebagai parameter), bukan disalin. Kepala Lengkap (ukuran judul/baris kecil, jumlah
  baris, bawahKepala, garisBelakang, kanan kepala) dihitung satu fungsi yang bisa diuji tanpa merender poster.
- `widgets/share_poster.dart`: `SharePoster` ditulis ulang sebagai `.lk` (target `PodiumPosterTarget`, tema
  `PodiumTheme`). `SharePosterRow` tetap (fixture hasil `tool/hifi_extract.py` memakainya). `SharePosterData` jadi:
  `sport`, `title`, `subtitle`, `blocks` (`List<PodiumBlockData>`), `wide`, `pairBalls`, `endless`, `rows`, `clubs`
  (`SharePosterClub`: `name`, `detail`, `rows`; `more` dihapus), `facts`. Dihapus: `SharePosterTarget`,
  `SharePosterClubScore`, `sparingPosterDensity`, `_RowSizes`, `_density`, `eyebrow`, `summary`, `more`, `complete`,
  `clubScore`.
- `share_content.dart`: `sharePosterData` memetakan `Podium.of` + kepala + `podiumFacts` lewat helper yang sama dengan
  `podiumPosterData` (kepala dan blok tidak ditulis dua kali).
- `share_exports.dart`: `lengkapImages(SharePosterData, PodiumTheme)` = Feed 360 × 360 dan Story 360 × 640 dari
  `PodiumPosterTarget`, ×3; nama berkas tidak berubah.

### 17.10 Data test (= frame; nama test memakai id frame + nomor keputusan, mis. `13w K86 …`)

Kolom, satuan, kepadatan (`lengkapGrid` + `lengkapDensity`; s dibulatkan 3 desimal, frame menulis nilai terpotong, jadi
bandingkan dengan toleransi 0,002):

| Frame | Kasus | Target | Susunan | Kolom (k) | Satuan | Ruang | Tinggi baris | s |
|---|---|---|---|---|---|---|---|---|
| 11b | Fixed 10 pasangan | kartu | feed1 | 1 | 10 | 238 | 23,8 | 1,04 |
| 11e | Mixed 20, bernama | kartu | feed2 | 2 (10) | 10 | 242 | 24,2 | 1 |
| 11f | sama | Feed / Story | feed2 / story1 | 2 (10) / 1 | 10 / 20 | 230 / 315 | 23 / 15,75 | 1 / 0,926 |
| 11g | Fixed 10 pasangan | Feed / Story | feed1 / story1 | 1 / 1 | 10 / 20 | 226 / 336 | 22,6 / 16,8 | 1,027 / 0,988 |
| 11h | Mixed 12 | kartu | feed2 | 2 (6) | 6 | 238 | 39,67 | 1 |
| 11i | Mixed 13 | kartu | feed2 | 2 (7) | 7 | 238 | 34 | 1 |
| 11j | Mixed 5 / 7 / 9 | kartu | feed1 | 1 | 5 / 7 / 9 | 238 | 30 / 30 / 26,44 | 1,04 |
| 11j | Mixed 11 / 13 / 15 / 17 / 19 | kartu | feed2 | 2 (6/7/8/9/10) | sama | 238 | 39,67 / 34 / 29,75 / 26,44 / 23,8 | 1 |
| 11k K88 | Fixed 15 pasangan | Feed / Story / kartu | feed1 / story1 / feed1 | 1 | 15 / 30 / 15 | 226 / 336 / 238 | 15,07 / 11,2 / 15,87 | 0,685 / 0,659 / 0,721 |
| 11l K81 | Mixed 30, judul 2 baris | Feed / Story / kartu | feed2 / story2 / feed2 | 2 (15) | 15 | 209 / 315 / 221 | 13,93 / 21 / 14,73 | 0,774 / 1 / 0,818 |
| 11m | Mixed 12, #1 × 6 | Feed | feed2 | 2 (6) | 6 | 230 | 38,33 | 1 |
| 11m K87 | belum ada match | Story | story1 | 1 | 0 | — | — | panel = 6 + kaki |
| 13s | Sparing Fixed 4 + 3 | kartu | feed1 | 1 | 7 + 2×2 = 11 | 238 | 21,64 | 0,983 |
| 13t | sama | Feed / Story | feed1 / story1 | 1 | 11 / 7×2 + 4 = 18 | 226 / 336 | 20,55 / 18,67 | 0,934 / 1,098 |
| 13u | Sparing Mixed 8 + 6 | kartu | feed2 | 2 per klub (10) | 10 | 238 | 23,8 | 1 |
| 13v | sama | Feed / Story | feed2 / story1 | 2 per klub / 1 | 10 / 14 + 4 = 18 | 226 / 336 | 22,6 / 18,67 | 1 / 1,098 |
| 13w K86 | Sparing Mixed 16 + 14 | Feed / Story / kartu | feed2 / story2 / feed2 | 2 per klub (18) | 18 | 226 / 336 / 238 | 12,56 / 18,67 / 13,22 | 0,698 / 1 / 0,735 |

Batas (wajib): Mixed 10 baris Feed → 1 kolom, 11 → 2 (11j); Mixed 20 Story → 1 kolom, 21 → 2 (K81); Fixed 15 pasangan
Story → 1 kolom (K88); Sparing Mixed 3 + 3 Feed → 2 kolom per klub, k = 5; Sparing Mixed total 20 Story → 1 kolom, 21 →
2 per klub (K86); Mexicano mengikuti Mixed.

Kepala dan garis belakang (17.5; ukur dengan `loadHifiFonts()`):

| Frame | Target | Judul | Ukuran judul · baris | Baris kecil | Kanan | Garis belakang |
|---|---|---|---|---|---|---|
| 11b | kartu | Klasemen akhir | 22 · 1 | 12,5 | 118 | 79 |
| 11e / 11f | kartu, Feed / Story | Mabar Jumat PB Garuda | 18,5 · 1 / 23 · 2 | 12,5 / 15 | 118 / 126 | 75 / 191 |
| 11g, 11k | Feed / Story | Klasemen akhir | 22 · 1 / 27 · 1 | 12,5 / 15 | 118 / 126 | 79 / 170 |
| 11j (5, 19) | kartu | Klasemen akhir | 22 · 1 | 12,5 | 124 (4 anak tangga) | 79 |
| 11l | Feed, kartu / Story | Liga Akhir Tahun Padel Kemang | 18,5 · 2 / 23 · 2 | 12,5 / 15 | 118 / 126 | 96 / 191 |
| 11m K84 | Feed / Story | Mabar Jumat PB Garuda | 18,5 · 1 / 23 · 2 | 12,5 / **13** | 118 / 126 | 75 / 188 |
| 13s–13w | kartu, Feed / Story | Klasemen akhir | 22 · 1 / 27 · 1 | 12,5 / 15 | 108 / 114 (Klub) | 79 / 170 |

Podium mini (17.6), rect blok (x, y, lebar, tinggi) dan angka:

| Frame | Target | Blok kiri → kanan | Angka | Bola |
|---|---|---|---|---|
| 11b | kartu | (252,55,26,24) (278,45,26,34) (304,63,26,16) | 16 / 22 / 10 | 6 × 8, mis. blok kiri x 259,5 dan 268,5, y 46 |
| 11f | Feed | (254,51,26,24) (280,41,26,34) (306,59,26,16) | 16 / 22 / 10 | 3 × 9, blok tengah x 291,5 y 31 |
| 11f | Story | (246,154,28,37) (274,139,28,52) (302,166,28,25) | 24 / 34 / 16 | 3 × 12, blok kiri x 258 y 140,5 |
| 11j (5) | kartu | (246,55,21,24) (267,45,21,34) (288,63,21,16) (309,63,21,16) | 16 / 22 / 10 / 10 | 4 |
| 11m K85 | Feed / Story | (254,41,78,34) / tanpa blok | 22 / — | 0 / 0 |
| 13s | kartu | (262,45,34,34) (296,55,34,24) | "7" 22 / "5" 16 | 0 |
| 13u | kartu | (262,45,34,34) (296,55,34,24) | "10" 22 / "6" 16 | 0 |
| 13v, 13w | Story | (258,118,36,52) (294,133,36,37) | "10" 23 / "6" 24 | 0 |

Pemetaan isi (`sharePosterData`, fixture yang sudah ada: data set 1 `bagikan_test.dart`, `sparingFull`, 15f, 13w):
- 11m Feed (`podium_poster_data` 18s): `wide`, satu blok level 1, 12 baris, 6 lencana emas; 11m Story (18t): blok
  kosong, `rows` kosong, fakta "Padel · 12 pemain · R1 · 0 dari 3 match".
- 13s: blok [L1 "7", L2 "5"], `clubs` = [PB Garuda "56 game · +13" 4 baris, Matcha Club "49 game · −13" 3 baris],
  fakta "7 pasangan · 6 round · 12 match · 1 WO".
- 13u: `clubs` detail "83 game · +14" / "69 game · −14"; 13w: "83 game · +16" / "67 game · −16".
- Sparing 0 – 0: blok kosong, panel hanya kaki (87), tanpa kepala klub.

### 17.11 Golden

- Komponen (`test/hifi/components/share_poster_test.dart`, data `share_poster_data.dart`): 11b, 11e, 11h, 11i (kartu);
  11f, 11g (Feed x 0 360 × 360, Story x 374 360 × 640); 11k, 11l (+ kartu x 748 358 × 372); 11m (Feed + Story, baru);
  11j (delapan kartu skala 1:2, baru, pola kisi 18q/18r di `podium_poster_test.dart`). Toleransi 2%; Feed/Story 11l 3%.
- Gambar sparing (`test/hifi/screens/sparing_bagikan_test.dart`): 13t, 13v, 13w (13w 3%), rect Story/kartu seperti di
  atas.
- Layar: 11b, 11e, 11h, 11i, 18b (`bagikan_test.dart`), 13s, 13u (`sparing_bagikan_test.dart`).
- Regresi Ringkas wajib tetap lolos tanpa diubah: 11a, 11c, 11d, 13q, 13r, 18a–18t.
- Selain golden: jumlah bola dari `layout.balls` (11b 6, 11f 3, 11j-5 4, 11m 0, 13s 0), jumlah lencana emas (11m Feed
  6, 13s 2), teks fakta dan judul per frame (pola 16.7 #12).

### 17.12 Jebakan untuk engineer dan reviewer

1. **Jangan menyalin podium.** Satu `Podium.of`, satu `PodiumScenePainter`, satu `_faceSizeFor`, satu penempatan
   blok/bola, satu lencana, satu kaki. Beda Lengkap hanya parameter (17.6). Golden Ringkas yang lolos tanpa diubah
   adalah buktinya.
2. **Urutan ketergantungan terbalik dari Ringkas**: kepala → garis belakang → podium mini dan atas panel → kepadatan.
   Di Ringkas panel menentukan dasar blok; di Lengkap garis belakang yang menentukan.
3. **bawahKepala memakai ukuran baris kecil sesudah dikecilkan** (11m Story 188, bukan 191) dan line-height CSS.
4. **Kolom judul dari slot**, bukan dari blok yang tergambar: Kerumunan dan Kosong = 3 slot (118 / 126), Klub 2.
5. **Fixed tidak pernah dua kolom**, juga Story 15 pasangan (88) dan Fixed campuran; gerbangnya `mode.isEndless`.
6. **Sparing dua kolom per klub**, bukan ⌈n/2⌉ (86): k = 2 + klub terbesar. Feed Mixed sparing selalu dua kolom
   per klub, Story hanya kalau total > 20.
7. **Kepala klub tanpa skor** (83): skor hanya di blok; teks dari `ClubResult.detailLabel`, jangan menghitung ulang.
8. **Satu rumus kepadatan** (80): ambang lama (10 baris, 15 per kolom, 16/20 baris nama, `sparingPosterDensity`,
   `_RowSizes` per varian) dihapus, bukan dibiarkan mati.
9. **Story 360 × 640**: `SharePosterTarget` (Story 202,5 × 360) dihapus; Lengkap memakai `PodiumPosterTarget` dan
   ekspor ×3. Memakai kanvas lama = gambar gepeng.
10. **Satuan hanya di feed1.** Ringkas tetap selalu bersatuan (63); jangan menyamakan keduanya.
11. **kn per target**: kartu, Feed, dan Story dihitung sendiri (11f Feed 0,94, Story 1).
12. **Golden 2% tidak menangkap bola/lencana kecil**: assert jumlahnya (17.11).
13. **Caption dan keterangan tab tidak berubah**: tes caption 11a/13q dan "Semua n …" lama lolos tanpa diubah.
14. **Nomor dari `position`** (Pitfalls `CLAUDE.md`); kembar senomor (11e #5 dan #12, 13w #2/#3/#13).
15. **Tema lapangan di Lengkap bukan biru lagi** (70 diganti): 11e = lapangan padel; 18b (gradien dipilih, pindah ke
    Lengkap tetap terpilih) tetap lolos.
16. Render poster di test wajib `loadHifiFonts()` + `MabarTheme.light()` (Pitfalls).

### 17.13 Pertanyaan terbuka — dijawab host 2026-11-13: kedua asumsi disetujui (keputusan 89–90 di PRD)

1. **Sparing Lengkap belum ada match (0 – 0)**: tidak ada frame. Asumsi: ikut 72 + 87 → garis belakang tanpa blok,
   panel hanya kaki (tanpa kepala klub), kolom judul selebar 3 slot seperti Kosong lain (118 / 126), jadi setelah
   match pertama judul melebar ke 108 / 114. Rekomendasi: setujui (tanpa kasus khusus Sparing).
2. **Story Fixed campuran** (pasangan diatur ulang, ada pemain tunggal; 09g): tidak ada frame Lengkap. Asumsi: semua
   baris setinggi pasangan (2 satuan), nama ditumpuk hanya di baris dua nama — sama dengan `.duo` Ringkas 18l dan
   perilaku Lengkap lama. Rekomendasi: setujui.
