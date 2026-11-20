# PRD — Match Addict, Aplikasi Mabar Tennis/Padel (Klub/Komunitas)

**Versi dokumen:** 3.0 — sejalan dengan hi-fi v2 (`design/hifi.html`, disetujui host 2026-10-21; Kelola court 2026-10-22; nama turnamen dan batas 30 pemain 2026-10-23; live score 2026-10-24; nama lengkap di baris match, Akhiri di Beranda, dan pemain telat menyusul 2026-10-25; Best of/Americano berhenti lebih awal 2026-10-26; nama Match Addict dan peringkat dengan selisih 2026-11-02; round tambahan Fixed 2026-11-03; default metode Klasemen ikut format skor 2026-11-11) dan app **3.1.0**; Sparing (§13) disetujui host 2026-11-04, rencana app 3.2.0, belum
ada di hi-fi; Mexicano (§14) + Konfigurasi diringkas diputuskan host 2026-11-11…12 (keputusan 23–47), app 3.4.0, hi-fi 03a–03q dan 16a–16g;
Tukar pemain Mixed (§15) diputuskan host 2026-11-12 (keputusan 48–59), rencana app 3.5.0, hi-fi 17a–17r;
Grup + Gugur (§16) diputuskan host 2026-11-17 (keputusan 93–103), rencana app 3.8.0, hi-fi
19a–22r; Kosongkan skor / Hapus WO + perilaku kecil + tombol mati Buat bagan (§17) diputuskan host 2026-11-18
(keputusan 113–120), rencana app 3.9.0, frame menyusul dari designer; metode peringkat ketiga **Point %** (§18)
diputuskan host 2026-11-20 (keputusan 122–126), ikut 3.9.0, frame menyusul dari designer.
**Platform:** Android + iOS + Web/PWA (1 codebase — Flutter)
**Target user:** Host mabar klub/komunitas tennis & padel, 4–30 pemain per turnamen, 1 HP host, offline

Acuan visual dan perilaku per layar ada di hi-fi (frame 01a–12o + catatan perilaku) dan `design/spec/`. PRD ini
memuat aturan produk dan logika; kalau ada beda dengan hi-fi soal tampilan, hi-fi yang benar. Aturan logika rinci +
data test: `design/spec/logic.md`.

---

## 1. Ringkasan Eksekutif

Aplikasi untuk host turnamen mabar yang:

- Mengundi pasangan (mode Fixed), mengacak pasangan tiap round (mode Mixed), atau memasangkan menurut klasemen tiap
  round (mode Mexicano, §14)
- Membuat jadwal adil: tiap orang main sama banyak (selisih ≤ 1), partner & lawan merata
- Mencatat skor satu angka per tim dalam format Race to N, Best of N, atau Americano N
- Menghitung peringkat Total Point, Point %, atau Win %, termasuk walkover (WO)
- Membagikan hasil sebagai gambar (Feed 1:1 & Story 9:16) + teks caption

---

## 2. Teknologi

- **Flutter** (Android, iOS, Web/PWA dari satu codebase), state **Riverpod**, routing **go_router**. Di web/PWA back
  browser (= back Android) menutup layar, sheet, atau dialog teratas seperti app native; go_router tidak menulis
  riwayat browser.
- Penyimpanan lokal **Hive** (JSON lewat codec sendiri, tanpa TypeAdapter). Tanpa server/cloud.
- Bagikan: `screenshot` (render poster) + `share_plus` (share sheet sistem).
- Huruf **Archivo** variabel (sumbu `wdth` + `wght`), ikon **Phosphor Bold** (font resmi, `MabarIcons`).
- PWA: service worker sendiri (`web/sw.js`), di-deploy ke GitHub Pages dari branch `main`.

---

## 3. Alur & Algoritma

### 3.0 Terminologi

- **Match** = 1 laga antar 2 sisi (mis. `Andi · Citra vs Budi · Dewant`).
- **Round** = 1 batch di mana court dipakai paralel sekali. Fixed: total round = ⌈total match ÷ jumlah court⌉ per
  putaran circle.
- **Court** = lapangan fisik; 1 match per court per round. Tiap court punya nama, warna, jam mulai, dan durasi booking
  sendiri; di Mixed court bisa ditambah di tengah turnamen (court lain sering baru kosong di jam berikutnya).
- Istilah UI: istilah olahraga tetap Inggris (court, round, match, set, WO, Win %, Point %, Total Point); semua orang disebut
  **pemain** (bukan peserta); Klasemen / Bagikan / Beranda (bukan Ranking / Share / Home); posisi pemain tetap "Peringkat n".

### 3.1 User Flow

```
[Beranda] → [Pemain] → [Konfigurasi] ─ Fixed → [Pasangan] → [Jadwal Fixed]
   ↑ Lanjutkan            (format skor,  ├ Mixed → [Jadwal Mixed] (R1 langsung dibuat, sheet Cara kerja Mixed)
   │                      court, durasi) └ Mexicano → [Jadwal Mexicano] (seperti Mixed, §14)
[Jadwal] ↔ [Input Skor] ↔ [Walkover]
[Jadwal] → [Klasemen] → [Detail Pemain]
[Klasemen] → [Bagikan] → Selesai → [Beranda]
```

### 3.2 Mode Partner

Sparing (dua klub bertanding, Fixed maupun Mixed; keputusan 19): §13. Aturan di bawah ini tetap berlaku untuk turnamen
biasa. Mode ketiga **Mexicano** (pasangan dari klasemen tiap round, hanya Americano; keputusan 23–27): §14.

#### A. Fixed Partner (Pasangan Tetap)

- Pasangan dibuat **Acak** (otomatis saat layar dibuka, bisa acak ulang) atau **Manual** (ketuk dua pemain).
- "Buat jadwal" memunculkan dialog konfirmasi: pasangan tidak bisa diubah setelah jadwal dibuat.
- Round-robin penuh dibuat sekaligus. Pasangan ganjil → satu pasangan istirahat (bye) per round. Pemain ganjil →
  "Buat jadwal" menunggu sampai genap ("· 1 pemain tanpa pasangan", catatan "Fixed butuh jumlah pemain genap" + Ubah
  pemain, 04c).
- Round dibuka berurutan: round berikutnya terkunci sampai semua skor round sebelumnya terisi. Match di round mana pun
  bisa dikosongkan atau WO-nya dihapus (§17, 3.9.0); round sesudahnya terkunci lagi sampai match itu terisi.
- Fairness Fixed = fairness antar pasangan, bukan individu.
- **Round tambahan** (3.3a): setelah semua match terisi, host bisa menambah round supaya semua pasangan main lagi
  dengan jumlah yang sama, dari sisa booking + jam tambahan per court. Sebelumnya pasangan bisa diatur ulang dan pemain
  pengganti dimasukkan (pemain yang pulang tidak ikut, poinnya tertinggal).
- Fixed **tidak bisa dilanjutkan** setelah diakhiri; yang pulang di tengah round-robin tetap WO.
- Format turnamen Fixed kedua, **Grup + Gugur** (fase grup lalu bagan gugur; keputusan 93–101, rencana 3.8.0): §16.
  Aturan di atas berlaku untuk format round-robin; yang berbeda di Grup + Gugur ditulis di §16.

#### B. Mixed Partner (Pasangan Berganti, "endless")

- Tidak ada target match: R1 dibuat saat Konfigurasi selesai, host menekan **Buat R(n+1)** untuk round berikutnya.
- Buat R(n+1) aktif kalau round terakhir lengkap (selesai/WO) dan masih ada court yang waktunya cukup.
- **Batalkan Rn**: round terakhir yang belum ada skor sama sekali boleh dihapus (bukan R1), mis. karena ada pemain
  datang terlambat; host menambah pemain lalu Buat Rn lagi.
- **Kosongkan skor / Hapus WO** (§17, 3.9.0): hanya match di round terakhir. Skor round sebelumnya hanya bisa diganti
  atau dijadikan WO; kalau round terakhir belum ada skor sama sekali, Batalkan Rn membuat round sebelumnya jadi round
  terakhir (satu round ke belakang saja).
- **Kelola pemain** di tengah turnamen: tambah, keluarkan (pemain tidak dihapus; nama & statistik tetap), kembalikan.
  Aktif minimal 4, maksimal 30.
- **Kelola court** (menu ⋯, selama belum diakhiri): tambah court, ubah nama/warna/jam lewat detail court (tombol
  Simpan), hapus court bernomor terakhir yang belum punya skor. Court yang ditambah atau dipesan ulang saat round
  berjalan langsung dipakai untuk 4 pemain prioritas teratas (keputusan host 2026-10-22). Aturan: `logic.md` §10.
- **Lanjutkan turnamen** (tambah jam per court 0–6) setelah diakhiri atau waktu booking habis, juga dari Beranda
  untuk turnamen terakhir.

### 3.3 Algoritma Round-Robin (Fixed)

Circle method; total match & round dihitung di awal.

```
function generateRoundRobin(pairs):
    n = pairs.length
    if n ganjil: tambah dummy "bye"
    fixed = pairs[0]; rotate = pairs[1..n-1]
    for round in 0..n-2:
        matches = [fixed vs rotate[last]] + [rotate[i] vs rotate[n-3-i] for i in 0..n/2-2]
        rotate = [rotate[last]] + rotate[0..last-1]
        yield matches
```

**Invariant:** satu putaran circle dipotong menjadi round sebesar jumlah court; dua putaran tidak pernah digabung
(kalau digabung, satu pasangan bisa main di dua court bersamaan).

### 3.3a Round Tambahan (Fixed)

Keputusan host 2026-11-03, dari turnamen live TBNE36 (16 pemain, 2 court 4 jam, 15 menit → 14 round, sisa 30 menit).
Aturan rinci + data test: `logic.md` §12.

- Muncul setelah semua match terisi dan turnamen belum diakhiri ("Tambah round", 06v).
- Satuannya **putaran**: tiap pasangan main sekali lagi; pasangan ganjil +2 (satu pasangan selalu istirahat per putaran
  round-robin, jadi +1 untuk semua tidak mungkin).
- Jumlah putaran = paling sedikit yang mengisi sisa booking + jam tambahan per court (0–6 jam, seperti Lanjutkan Mixed),
  dibulatkan ke atas supaya jumlah main sama. Boleh lewat booking; sheet menulis "lewat booking 00:15". Host yang
  memutuskan kapan berhenti lewat Akhiri (match yang belum main jadi Tidak dimainkan).
- Lawan: urutan round-robin diulang dari awal (R15 = lawan R1); pasangan ganjil memakai siklus Walecki. Tidak ada yang
  bertemu lawan yang sama tiga kali sebelum semua bertemu dua kali. Court yang booking-nya habis lebih dulu berhenti
  dipakai.
- **Atur pasangan** (04f–04h) sebelum round tambahan: "Ubah" memisahkan pasangan, pemain pengganti diketik, dua pemain
  diketuk jadi pasangan baru (mengisi tempat pasangan yang dipisah). Pemain yang tidak dipasangkan tidak ikut; skornya
  tetap dan poinnya tertinggal — konsekuensi yang diterima host.

### 3.4 Algoritma Mixed — Fair Generation

```
function generateNextRound(activePlayers, history, courts, round):
    slots = courtsAvailableAt(now) × 4
    order = activePlayers.sortBy(
        matchCount ASC,                   // paling sedikit main
        lastRoundPlayed ASC,              // paling lama istirahat
        lockedDraw(drawSeed + round),     // undian seri DIKUNCI per round
        id)
    k = max(2, slots ÷ (activePlayers − slots) + 1)   // bulat ke bawah; tanpa yang istirahat → tanpa jeda
    order = order tanpa pemain telat yang perlu jeda + mereka di paling bawah
            // telat = absen di round sebelumnya; jeda = di bawah yang paling banyak main dan sudah main k round beruntun
    playing = order.take(slots); resting = order.skip(slots)
    pairing terbaik dari 400 percobaan, penalti: ulang match persis 1000, ulang partner 10, ulang lawan 3
```

- `drawSeed` = FNV-1a dari id turnamen. Karena undian dikunci, daftar "Istirahat · Prioritas main di R(n+1)" yang
  tampil di Jadwal selalu sama dengan hasil Buat R(n+1).
- **Properti fairness:** selisih jumlah main antar pemain yang hadir sejak awal ≤ 1 setiap saat; yang istirahat
  diprioritaskan di round berikutnya. Tukar pemain oleh host (§15) bisa membuatnya 2 sementara; prioritas yang sama
  memulihkannya.
- **Pemain telat menyusul** (keputusan host 2026-10-25): pemain baru/kembali (absen di salah satu round yang sudah
  dibuat) paling sedikit main, jadi diprioritaskan, tapi istirahat 1 round setelah main k round beruntun supaya tidak
  main terus. k = 2, atau satu lebih dari ritme pemain lain kalau 2 belum cukup untuk menyusul (12 pemain / 2 court:
  pemain lain main 2 dari 3 round → k = 3). Jeda berhenti begitu jumlah mainnya sama dengan yang paling banyak main.
  Menyusulnya sebanding dengan sisa istirahat: 10 pemain + 2 setelah R3 di 2 court → selisih rata-rata turun ±0,1
  match per round; 1 court langsung ≤ 1; kalau semua main tiap round (12 pemain / 3 court) tidak bisa dikejar.
  Hanya untuk prioritas jadwal, tidak ikut peringkat. Dulu (≤ 2.6) pemain telat disejajarkan dengan yang paling jarang
  main lewat kredit, jadi selisihnya tetap selamanya; kredit di simpanan lama diabaikan.
- Waktu booking dihitung dari **jam sungguhan** sejak court itu mulai (keputusan host 2026-10-22), bukan dari
  jumlah round × durasi. Court ikut round yang dibuat sekarang kalau sisa booking-nya (ujung booking − menit berjalan)
  masih muat satu match, jadi round yang selesai lebih cepat dari durasinya menyisakan waktu untuk round tambahan.
- Court yang waktu booking-nya habis tidak dipakai lagi; kalau semua habis, slot dihitung dari semua court (untuk
  daftar prioritas) dan tombolnya menjadi "Tambah jam".

### 3.5 Estimasi & Waktu

- Durasi match kelipatan 5 menit (minimal 5). Default Tennis 20 menit, Padel 15 menit; court default 2 × 2 jam.
- Konfigurasi: ±round = booking terpendek ÷ durasi, match = round × court — perkiraan; jumlah round sebenarnya
  mengikuti jam (3.4). Booking terpendek < durasi → error yang menyebut court penyebabnya.
- Lanjutkan turnamen dan detail court: waktu court dihitung dari sekarang kalau booking-nya sudah lewat,
  `max(ujung booking, sekarang) + tambahan`.
- Sisa booking ditulis per court sebagai hitung mundur jam:menit ("01:46") di kotak jam strip court (round yang sedang
  berjalan) dan di subjudul Input Skor; subjudul Jadwal tidak menulis waktu.
  Estimasi dalam jumlah match (rumus di catatan frame 08c, `ActiveTournament.capacityAhead`).

---

## 4. Skor & Penilaian

### 4.1 Format Skor

Satu angka per tim untuk ketiga format (disimpan sebagai satu `SetScore` per match). Dipilih di Konfigurasi, berlaku
untuk tennis maupun padel.

| Format | Arti | N | Skor akhir sah | Seri |
|--------|------|---|----------------|------|
| **Race to N** (default 6) | Duluan N game | 2–9 | N lawan 0…N−1 (match selesai begitu satu tim mencapai N; tanpa 7–5/7–6) | Tidak |
| **Best of N** (default 5) | Paling banyak N game | 1–15 | Jumlah ≤ N, pemenang ≥ ⌊N ÷ 2⌋ + 1 | Kalau N genap (N÷2 sama) |
| **Americano N** (default 21) | Poin reli, paling banyak N | 2–99 | Jumlah ≤ N, pemenang ≥ ⌊N ÷ 2⌋ + 1 | Kalau N genap (N÷2 sama) |

- Best of & Americano boleh berhenti begitu lawan tidak mungkin mengejar (pemenang sudah ⌊N ÷ 2⌋ + 1, mis. 11–5 di
  Americano 21), supaya yang kalah tidak dapat sisa poin gratis. Total lebih dari N ditolak ("Total poin lebih dari
  21"), pemenang di bawah batas ditolak ("Minimal skor pemenang 11"). Seri hanya dengan total penuh (2026-10-26).
- Best of & Americano: mengisi satu sisi otomatis mengisi kotak lawan dengan `N − x` hanya kalau kotak itu masih
  kosong atau masih otomatis; kotak yang sudah diketik (juga skor tersimpan) tidak dihitung ulang.
- Keypad sendiri: tombol angka yang membuat isi kotak melebihi batas format mati (Race to N: N; Best of N: N;
  Americano: total). Tombol tidak melihat isi kotak lawan. Kotak yang sudah penuh atau baru dipilih menerima ketikan
  berikutnya sebagai pengganti isinya; saat mengubah skor tersimpan, angka mati sampai salah satu kotak diketuk
  (keputusan host 2026-10-22). Pesan validasi persis seperti frame 07d, 07n, dan 07o.
- Seri dihitung setengah menang di Win %.
- Format best of 3 set (app lama) sudah dihapus; turnamen app lama tidak dimuat (lihat 5.10).

### 4.2 Metode Peringkat

| Metode | Cara hitung |
|--------|-------------|
| **Total Point** | Jumlah game/poin yang dimenangkan lintas match (+ nilai WO, lihat 4.4) |
| **Point %** (sejak 3.9.0, §18) | Game/poin didapat ÷ game/poin dimainkan (didapat + kalah) × 100, lintas match; WO dihitung seperti skor nilai WO–0 (4.4) |
| **Win %** | Menang = 1, seri = 0,5, kalah = 0, dibagi jumlah match |

**Default mengikuti format skor** (keputusan 21, diubah keputusan 123 sejak 3.9.0): Race to dan Best of → **Win %**;
Americano (juga Mexicano) → **Point %**. Sebelum 3.9.0 Americano → Total Point.
- Race to dan Best of dimenangkan per match, jadi jumlah menang dulu, seperti klasemen round-robin resmi tennis,
  padel, pickleball, dan badminton (menang dulu, baru selisih). Di Americano tiap poin memang tujuannya; Point %
  menilai poin itu per poin yang dimainkan, jadi pemain yang mainnya lebih sedikit (istirahat, telat) tidak tertinggal
  hanya karena kurang main (§18.0).
- Contoh Race to 6, tiga match: Gita · Andi 2W–1L, 16 game, +1 (kalah 15 game); Dewi · Citra 1W–2L, 16 game, +2 (kalah
  14 game). Win %: Gita · Andi 67% di atas Dewi · Citra 33%. Total Point: 16 sama, selisih +2 menaruh Dewi · Citra di
  atas. Point %: Dewi · Citra 53% (16 ÷ 30) di atas Gita · Andi 52% (16 ÷ 31).
- Contoh kedua: A kalah 5–6, kalah 5–6, menang 6–0 (16 game, 1W–2L); B menang 6–5, menang 6–5, kalah 0–6 (12 game,
  2W–1L). Win %: B di atas A. Total Point: A di atas B. Point %: A 57% di atas B 43% (§18, contoh 18B). Karena itu
  Point % tidak menggantikan Win % di Race to/Best of (keputusan 122).

Metode dipilih di layar Klasemen (tidak di setup) dan dipakai juga oleh Detail & Bagikan; urutan tab tetap
**Total Point · Point % · Win %** (sebelum 3.9.0 Total Point · Win %; urutan baru usulan U-RP1, §18.8). Pilihan host
bertahan selama turnamen itu, tidak disimpan: turnamen berganti atau app dibuka ulang → kembali ke default formatnya.
Berlaku sama untuk Fixed, Mixed, Mexicano, Sparing (klasemen per klub), dan penonton live. Grup + Gugur tanpa tab
(GU8, 16.5).

### 4.3 Tie-Breaker & Nomor Peringkat

1. Nilai metode (Total Point, Point %, atau Win %) → 2. Selisih game/poin → nomor sama, baris diurutkan nama

- Hanya angka yang tampil di Klasemen dan poster yang menentukan nomor, supaya alasannya terbaca: kolom +/− (selisih)
  memisahkan nilai yang sama. Head-to-head tidak dipakai (di Mixed antar tiga pemain bisa berputar), begitu juga Total
  Point sebagai pemisah Win % atau Point %.
- **Point % dibandingkan dari angka bulat yang tampil** (usulan U-RP2, §18.2): 52,38% dan 52,00% sama-sama "52%", lalu
  selisih yang memisahkan. Win % tetap dibandingkan dari nilai persisnya seperti sebelum 3.9.0.
- Nilai metode dan selisih sama → **nomor sama**, dan nomor berikutnya melanjutkan: #1, #2, #2, #3 (bukan 1, 2, 2, 4).
  W–L–D tidak membedakan nomor.
- Pemain yang belum main (pemain baru, termasuk pengganti dari Atur pasangan Fixed) dikelompokkan di "Belum main"
  tanpa nomor.
- Fixed: satu baris per pasangan (dua nama), posisinya mengikuti anggota terbaik. Setelah pasangan diatur ulang
  (3.3a), pasangan yang tidak pernah berubah tetap satu baris; pemain yang pasangannya berubah, yang tidak ikut lagi,
  dan pemain pengganti tampil sendiri-sendiri (09g).

### 4.4 Walkover (WO)

**Alur:** tombol WO di Input Skor → sheet → pilih pasangan yang tidak bisa main → alasan opsional (Absen / Cedera /
Waktu habis / Lainnya; ketuk lagi untuk melepas) → Simpan. Membuka WO yang sudah ada menampilkan pilihannya; menyimpan
skor di match WO mengubahnya jadi match selesai. Sejak 3.9.0 sheet WO tersimpan punya **"Hapus WO"**: match kembali ke
skor lama kalau ada, kalau tidak ke Belum (§17, batas per mode 17.3).

**Dampak:**
- Pasangan lawan menang, pasangan WO kalah; keduanya +1 match.
- Total Point pemenang WO ikut format skor (keputusan host 2026-10-21):
  - Race to N → pemenang dapat N game.
  - Best of N & Americano → rata-rata game/poin dari match yang benar-benar dia mainkan (bulat ,5 ke atas), tapi tidak
    pernah di bawah skor menang terkecil ⌊N ÷ 2⌋ + 1 (Americano 21 → 11, 24 → 13; Best of 5 → 3); belum pernah main →
    skor menang terkecil.
- Pasangan WO 0 game/poin. Selisih game/poin tidak berubah untuk keduanya.
- **Point % (sejak 3.9.0, keputusan 125):** WO dihitung seperti skor "nilai WO – 0". Tiap pemenang: didapat + nilai WO
  dia sendiri (aturan di atas), kalah + 0. Tiap pemain pasangan WO: didapat + 0, kalah + **nilai WO pasangan lawan**;
  di Mixed Best of/Americano kedua pemenang bisa punya nilai beda, jadi dipakai rata-ratanya dibulatkan ,5 ke atas
  (sama dengan nilai WO klub K11, 13.5). Contoh: Race to 6 → pemenang 6 dari 6, pasangan WO 0 dari 6; Americano 21
  pemenang Andi 14 dan Budi 17 → Citra dan Dewi masing-masing kalah 16 (contoh 18C).
- Alasan WO tampil di baris Jadwal.

### 4.5 Status Match

| Status | Definisi | Dampak peringkat |
|--------|----------|------------------|
| Belum | Belum diisi | — |
| Selesai | Skor masuk | Dihitung |
| WO | Satu pasangan tidak bisa main | Menang/kalah dihitung (4.4) |
| Tidak dimainkan | Turnamen diakhiri sebelum match dimainkan | **Tidak dihitung sama sekali**; kembali "Belum" kalau Mixed dilanjutkan |

Sejak 3.9.0 (§17): Selesai → Belum lewat **Kosongkan skor**; WO → Selesai (skor lama) atau Belum lewat **Hapus WO**.
Setelah diakhiri, keduanya menghasilkan Tidak dimainkan (U-1, 17.8).

### 4.6 Status Sementara / Final

- **Fixed:** Final setelah diakhiri atau semua match terisi; kembali Sementara setelah round tambahan dibuat.
- **Mixed:** Final setelah diakhiri, atau waktu booking semua court habis (jam sungguhan) **dan** round terakhir lengkap. Kembali
  Sementara kalau dilanjutkan.
- Final: subjudul "… · Final · 5 round · 10 match"; poster menulis "Klasemen akhir". Sementara: "… · R3 · 6 dari 8 match".
- Kosongkan skor / Hapus WO (§17) yang membuat match Belum mengembalikan status ke Sementara menurut aturan di atas;
  turnamen yang sudah diakhiri tetap Final.

---

## 5. Fitur per Layar (v2)

Frame di hi-fi adalah kriteria selesai. Ringkasannya:

### 5.1 Beranda (01a–01j)
- Banner sudut lapangan tampak atas (tennis biru court, padel terracotta) dengan animasi tennis ↔ padel; panel bawah:
  pilih olahraga (diingat dari turnamen terakhir, default Tennis) + satu tombol "Mulai turnamen …".
- Turnamen berjalan: info round + "Lanjutkan" di banner; mulai baru → dialog yang menyebut turnamen yang akan dihapus.
- Turnamen terakhir Mixed → baris riwayat → sheet Lanjutkan turnamen. Fixed tidak tampil.
- Turnamen yang sudah diakhiri tapi belum lewat Selesai di Bagikan juga tampil sebagai turnamen terakhir, bukan
  turnamen berjalan; Mulai turnamen memindahkannya ke slot terakhir tanpa dialog (2026-10-25).
- Turnamen bernama: nama menggantikan "olahraga · mode · n pemain" di banner dan baris riwayat (satu baris, elipsis)
  dan "olahraga · mode" di dialog mulai baru.
- Web/PWA: baris "Pasang Match Addict di HP" (dialog bawaan browser, atau sheet "Pasang di iPhone" untuk iPhone/iPad:
  tiga langkah lewat Bagikan di Safari, catatan kaki "Hanya dari Safari"; 01i).
- Versi app "v" + `appVersion` (mis. "v3.8.1") di kanan atas banner, tidak bisa diketuk, di semua kondisi Beranda
  (keputusan 20, 2026-11-04; hi-fi 01b).

### 5.2 Pemain (02a–02d)
- Satu kotak teks (tempel dari WhatsApp); parser membuang nomor/bullet, spasi ganda, baris kosong, dan duplikat
  (tidak peka huruf besar, yang pertama dipertahankan).
- Toolbar: Tempel, Contoh (hanya saat kosong), Hapus semua. Hasil = daftar bernomor dua kolom.
- Hapus semua tanpa dialog; sesudahnya toolbar "Tempel · Urungkan" sampai isi kotak berubah, lalu kembali seperti biasa
  (3.9.0, keputusan 115, 17.10).
- Lanjut aktif untuk 4–30 pemain (Fixed dan Mixed).

### 5.3 Konfigurasi (03a–03q)
- Nama turnamen opsional paling atas (maks 40 karakter, dipangkas; kosong = tanpa nama). Hanya diisi di sini, tidak
  bisa diubah setelah turnamen dibuat.
- Mode Fixed/Mixed (Mexicano: 14.2), format skor (4.1), durasi match (stepper ±5), jumlah court 1–10, per court nama/warna (10 warna
  preset)/booking. Estimasi di tombol. Fixed → Pasangan; Mixed → langsung Jadwal + R1.
- Satu layar yang selalu muat (keputusan 33): Skor ("Race to 6 · 20 menit") dan Court ("2 court · 2 jam"; booking
  berbeda "6 court · 1–2 jam") masing-masing satu baris, rinciannya di sheet yang langsung berlaku. Dibuka dengan
  pengaturan turnamen terakhir per olahraga (keputusan 36, 38); turnamen pertama di HP: Fixed, Race to 6, 20 menit
  (Padel 15), 2 court × 2 jam.

### 5.4 Pasangan — Fixed (04a–04h)
- Acak / Manual (pilih, lepas pilihan, Urungkan), pemain ganjil + "Ubah pemain", dialog kunci pasangan.
- Atur pasangan sebelum round tambahan (04f–04h): Ubah per pasangan, pemain pengganti, "Simpan pasangan · n tidak
  main", hasilnya di baris Pasangan sheet Tambah round.
- Dialog hanya kalau ada yang hilang (3.9.0, keputusan 116, 17.10): Manual → Acak dengan pasangan manual "Buang N
  pasangan manual?"; ← di Atur pasangan dengan perubahan "Buang perubahan pasangan?". Acak → Manual dan layar Grup
  tanpa dialog.

### 5.5 Jadwal Fixed (06a–06e, 06v–06z) & Mixed (06f–06u)
- Tab round yang bisa digeser (tepi dipudarkan), label kanan "x/y match" atau "Waktu habis"; ganti round hanya lewat tab.
- Baris match bergaya scorebug dengan strip court berwarna (42 pt; di round yang sedang berjalan + kotak jam sisa
  booking court itu); ketuk → Input Skor (juga untuk mengubah, mengosongkan, atau menghapus WO, §17).
- Round terkunci (Fixed, Grup + Gugur): pudar dengan catatan "Terbuka setelah semua skor Rn terisi", n = round paling
  akhir yang belum lengkap sebelum round yang dilihat (sama dengan R(n−1) kecuali ada match yang dikosongkan; 17.4,
  usulan U-5).
- Nama pemain ditulis lengkap ("Andi P · Budi S"), di baris match, Input Skor, WO, riwayat Detail, dan Istirahat Fixed,
  supaya pemain bernama depan sama terbedakan. Tidak muat → tiap nama dipotong elipsis sendiri; nama yang muat di
  separuh lebar tetap utuh (06u).
- Istirahat: Fixed paling banyak satu pasangan; Mixed di round terakhir dibagi "Istirahat · Prioritas main di R(n+1)"
  dan "Istirahat lagi di R(n+1)".
- Menu ⋯: Live score (§5.11), Kelola court (Mixed), Cara kerja Mixed (sheet; muncul otomatis sekali saat R1 dibuat), dan
  Akhiri turnamen (dialog).
  Setelah diakhiri: Akhiri dan Kelola court hilang; Fixed tinggal Live score (06c, 12f), Mixed Live score + Cara kerja
  Mixed (06m).
- Dialog "Akhiri turnamen?" · tombol "Akhiri"; isinya per mode (PATCH 3.8.1, keputusan 112): Fixed (juga Sparing Fixed)
  "Match yang belum main tidak dihitung. Turnamen tidak bisa dilanjutkan."; Mixed dan Mexicano "Match yang belum main
  tidak dihitung." karena bisa dilanjutkan; Grup + Gugur di §16 (20r, 21z).
- Mixed: Buat R(n+1) / Batalkan Rn / Pemain (n) / Tambah jam / Lanjutkan turnamen.
- Sheet tambah jam booking (grup "Jam booking", 0–6 jam per court) berjudul dan bertombol menurut pemicunya (PATCH
  3.8.1): dari Waktu habis (turnamen belum berhenti) "Tambah jam"; setelah diakhiri atau dari Beranda "Lanjutkan
  turnamen" dengan tombol "Lanjutkan". Isi sama (08c).
- Mixed (bukan Mexicano/Fixed): tukar pemain di match round terakhir yang belum diisi dengan pemain yang istirahat
  (§15, keputusan 48–59; sejak 3.5.0, hi-fi 17a–17r: ikon di baris match).
- Fixed setelah semua match terisi: ikon Klasemen + "Tambah round" → sheet jam booking per court, baris Pasangan,
  "n match lagi tiap pasangan" dan "Buat R15–R16" (3.3a).
- Back (tombol ‹, back HP, back browser) selalu ke Beranda, bukan ke Atur turnamen/Pasangan: dari sana "Buat jadwal"
  memulai turnamen baru dan skor yang sudah diisi hilang. Turnamen dilanjutkan dari Beranda (keputusan 22).

### 5.6 Input Skor & Walkover (07a–07o)
- Papan skor gelap: nama lengkap satu pemain per baris, satu angka besar per tim, keypad sendiri, pesan validasi,
  "Perbarui skor" saat mengubah. Saat mengubah, angka dan ⌫ mati sampai satu kotak diketuk (PATCH 3.8.1).
- Kalimat hasil sama di semua format: nama pemenang + "menang" + skor pemenang–kalah ("Andi P & Budi S menang 13–8"),
  bukan selisih (PATCH 3.8.1).
- Subjudul menulis sisa booking court itu untuk match di round yang sedang berjalan ("· sisa 02:00").
- WO lewat sheet (4.4).
- Sejak 3.9.0 (§17, keputusan 113–114): mode ubah, kedua kotak dikosongkan dengan ⌫ → tombol "Kosongkan skor"
  (sekunder, clay) → dialog "Kosongkan skor Court 1?" · "Match kembali belum dimainkan." · Batal / Kosongkan. Sheet WO
  tersimpan: "Hapus WO" di kanan kepala sheet. Batas per mode 17.3.

### 5.7 Klasemen (09a–09g)
- Tabel: # · nama · Main (jumlah match dimainkan, WO ikut) · W–L–D (W–L kalau format tidak bisa seri) · +/− (selisih)
  · nilai metode; peringkat 1 diberi bola.
- Toggle Total Point / Win %, status di subjudul, catatan WO / tidak dimainkan, ketuk baris → Detail. Tombol Bagikan.
- Sejak 3.9.0 (§18): toggle tiga tab **Total Point · Point % · Win %**; kolom nilai tab Point % = persen bulat ("57%"),
  judul kolom "Point %" seperti "Win %". Bentuk final di hi-fi (frame baru, designer).
- Pemain tanpa match selesai/WO di grup "Belum main". Fixed: satu baris per pasangan; pasangan yang berubah, pemain
  yang tidak ikut lagi, dan pemain pengganti tampil per pemain (09g).

### 5.8 Detail Pemain (10a–10d)
- Satu baris statistik (label mengikuti format skor: Poin/Game), beda partner/lawan, kalah WO, riwayat match terbaru
  di atas (Mixed menampilkan partner; menang WO menulis "+N"). Fixed menampilkan "Beda partner" hanya kalau
  pasangannya pernah diatur ulang (10d).
- Subjudul: "Peringkat n · metode · olahraga · mode · format skor" ("Peringkat 1 · Total Point · Padel · Mixed ·
  Americano 24"); nomor dan metode mengikuti pilihan di Klasemen (PATCH 3.8.1). Belum main: "Belum main" tanpa
  metode. Kalau tidak muat satu baris, olahraga dibuang dulu (B-6). Sparing (klub, tanpa metode) dan Grup + Gugur
  (babak, "Grup + Gugur", tanpa metode dan format) punya subjudul sendiri: §13.7 dan §16.9.
- Belum ada match: riwayat menulis "Belum ada match" saja (PATCH 3.8.1).
- Sejak 3.9.0 (§18.5): metode Point % di subjudul ditulis "Point %" ("Peringkat 1 · Point % · Padel · Mixed ·
  Americano 21"); baris statistik menampilkan Point % pemain itu di **semua** tab (angka pemain tidak tergantung tab),
  bulat seperti Klasemen, "–" kalau belum main. Letak dan muat di 390 oleh designer (usulan U-RP5).
- Beda partner / Beda lawan dihitung dari match Selesai dan WO; di match WO kedua sisi ikut, sama dengan kolom Main
  (keputusan 118, B-21; contoh 13C Maya · Nanda 8 / 8, 17.10).

### 5.9 Bagikan (11a–11m, 18a–18t)
- Kartu pratinjau + deret tema (11 pilihan: lapangan ikut olahraga sebagai bawaan + 10 gradien, sama di Ringkas dan
  Lengkap; keputusan 66, 76) + Ringkas (poster podium) / Lengkap (semua yang bernomor). Nomor "#n"; peringkat 1 lencana
  emas, digantung ke kiri supaya "#1" sejajar dengan nomor di bawahnya.
- Tiap baris = nilai metode + selisih, sama dengan Klasemen: "42 poin · +12", "100% · +12". Lengkap menulis satuan hanya
  di Feed satu kolom; dua kolom dan Story tanpa satuan ("42 · +12"). Ringkas selalu dengan satuan.
  Point % (sejak 3.9.0, usulan U-RP3): "57% poin · +9" (Race to/Best of "57% game · +9") di tempat Total Point menulis
  satuan, "57% · +9" di tempat tanpa satuan. Caption: baris metode Point % menulis Point % menggantikan Win % (18.5).
- Dua gambar 1080×1080 dan 1080×1920 dibagikan lewat share sheet sistem dengan caption teks hasil. Gagal (sejak 3.9.0,
  keputusan 117, mengganti aturan 2026-10-22 "caption disalin + toast Hasil disalin"): kedua PNG diunduh, caption
  disalin, toast "Gambar diunduh · hasil disalin"; tanpa tombol baru. Share sheet ditutup tanpa memilih → tidak ada
  apa-apa; gambar gagal dibuat → hanya caption + "Hasil disalin" (17.10).
- Kepala poster (Ringkas dan Lengkap): tanpa nama → judul "Klasemen akhir|sementara" + baris kecil "olahraga · mode ·
  tanggal"; bernama → judul = nama (maks dua baris) + baris kecil "Klasemen akhir|sementara · tanggal", olahraga pindah
  ke depan baris fakta. Caption dibuka "🏆 {nama} · Padel" (tanpa nama "🏆 Match Addict · Padel").
- **Sejak 3.6.0 (keputusan 60–74, hi-fi 11a, 11c, 11d, 13q, 13r, 18a–18t): Ringkas = poster podium**, bukan daftar 5 teratas. Ilustrasi sudut lapangan + podium
  (angka di muka blok, satu bola per pemain) dan panel nama sedikit transparan berisi baris yang naik podium (nomor,
  nama, nilai metode + selisih dengan satuan di Feed dan Story) + wordmark + baris fakta turnamen. Nomor sama → tinggi
  sama; maksimal 4 anak tangga (keputusan 65). Sparing: dua blok skor klub. Tema bawaan = palet lapangan ikut olahraga,
  10 gradien tetap bisa dipilih.
- **Sejak 3.7.0 (keputusan 76–88, hi-fi 11b, 11e–11m, 13s–13w): Lengkap = arah B "Podium mini"**, satu keluarga
  dengan poster podium. Judul + baris kecil di kiri, podium mini (angka + bola, tanpa nama) di garis belakang di
  kanannya, semua baris bernomor di panel 86% di atas lantai, kaki wordmark + baris fakta seperti podium. Yang naik
  podium mini = aturan poster podium, termasuk lebih dari 4 di #1 (satu blok emas lebar) dan belum ada match (tanpa
  blok; panel hanya wordmark + fakta).
  - Kolom: Mixed/Mexicano lebih dari 10 baris di Feed dan lebih dari 20 di Story → dua kolom rata (⌈n/2⌉ di kiri, urut
    ke bawah). Pasangan Fixed selalu satu kolom, juga Story 15 pasangan; Story menumpuk dua nama pasangan.
  - Kepadatan: tinggi baris = ruang panel ÷ jumlah baris, dengan batas atas; ukuran huruf baris mengikuti tinggi baris
    dan paling besar seukuran panel podium. Tidak ada lagi ambang jumlah baris per kasus. Daftar pendek: panel memendek
    dari atas.
  - Judul maksimal dua baris di samping podium mini (22 → 18,5; Story 27 → 23), elipsis hanya kalau ukuran terkecil
    masih tidak muat; baris kecil selalu satu baris, mengecil per 0,5 sampai paling kecil 11.
  - Sparing: skor klub hanya di blok podium mini; panel per klub diawali nama klub + "83 game · +14" (tanpa skor).
    Mixed sparing dibagi dua kolom per klub (Feed selalu, Story di atas 20 pemain), bukan ⌈n/2⌉.
- "Selesai" memindahkan turnamen ke slot terakhir lalu kembali ke Beranda.

### 5.10 Penyimpanan Data
- Lokal di HP (Hive), tanpa sinkronisasi. Satu turnamen aktif + satu turnamen terakhir.
- Auto-save setiap perubahan; app di-kill → lanjut dari state terakhir.
- Data terhapus hanya kalau storage app dibersihkan / app di-uninstall.
- Format simpanan: `schemaVersion` 2 + **`appVersion`** (versi app yang menulisnya). Data rusak, dari skema lain,
  atau tanpa `appVersion` diabaikan (app tetap terbuka). **Turnamen dari app lama (1.x, skor per set) tidak dimuat di
  app v2** — keputusan host 2026-10-22.
- Satu-satunya data yang keluar dari HP adalah live score (5.11), dan hanya setelah host memulainya.

### 5.11 Live score (12a–12o)
- Host memulai live dari menu ⋯ Jadwal (Fixed dan Mixed, juga setelah diakhiri) lewat dialog "Mulai live score?",
  karena nama pemain jadi bisa dilihat siapa saja yang punya link. Mulai butuh internet sekali; gagal → toast, live
  tidak menyala.
- Sheet Live score: link `asepsugi.github.io/match-addict/#/live/KODE` (kode 6 karakter tanpa 0/O/1/I/L), jam kiriman
  terakhir ("Terkirim 19.53" / "Menunggu internet · terakhir terkirim 19.48"), Bagikan link (share sheet; gagal → link
  disalin), Hentikan (dialog → data live dihapus; tanpa internet live tetap menyala dan toast memberi tahu).
- Setiap perubahan turnamen dikirim utuh ke relay, jadi tidak ada antrean: tanpa internet dicoba lagi tiap 30 detik
  dan setiap ada perubahan, yang terkirim selalu keadaan terbaru. App tetap jalan offline seperti biasa.
- Live tetap ada setelah "Selesai" (turnamen terakhir) dan berlanjut dengan kode yang sama kalau dilanjutkan dari
  Beranda. "Hapus & mulai baru" menghentikan live turnamen yang dibuang.
- Penonton membuka link di browser (web Match Addict, tanpa pasang): Jadwal, Klasemen (tanpa Bagikan, metode dipilih
  sendiri dari tiga tab sejak 3.9.0, default sama dengan host; metode tidak ada di payload), dan Detail, baca saja. Dicek tiap 10 detik selama halaman terlihat, tiap menit setelah Final. Tag "Live" di
  Jadwal; setelah dua kali gagal berturut-turut "Offline · 19.48" (jam cek terakhir yang berhasil; PATCH 3.8.1, B-17);
  hilang saat Final. Subjudul memakai nama turnamen kalau ada. Simpanan turnamen penonton sendiri tidak tersentuh.
- Penonton turnamen yang diakhiri (juga Sparing) melihat judul "Istirahat" saja, tanpa "Prioritas main di R…", karena
  belum tentu ada round berikutnya; Jadwal host tetap menulisnya (PATCH 3.8.1, B-20, hi-fi 12l).
- Relay tanpa database: satu salinan terakhir per kode, terhapus 3 hari setelah perubahan terakhir atau saat Hentikan.
  Aturan rinci: `design/spec/logic.md` §11.

---

## 6. Daftar Layar

| Layar | Frame |
|-------|-------|
| Beranda (+ dialog mulai baru, sheet pasang di iPhone, ikon app) | 01a–01j |
| Pemain | 02a–02d |
| Konfigurasi (+ sheet Skor, sheet Court, sheet warna court) | 03a–03q |
| Pasangan (Fixed) + Atur pasangan sebelum round tambahan | 04a–04h |
| Jadwal Fixed + sheet Tambah round | 06a–06e, 06v–06z |
| Jadwal Mixed (+ sheet Cara kerja Mixed, strip court + hitung mundur) | 06f–06u |
| Sheet Kelola pemain, Tambah jam / Lanjutkan turnamen, Kelola court + detail court | 08a–08k |
| Input Skor + sheet Walkover (+ Kosongkan skor / Hapus WO §17, 3.9.0: frame baru menyusul dari designer) | 07a–07o |
| Klasemen | 09a–09g |
| Detail Pemain | 10a–10d |
| Bagikan | 11a–11m |
| Live score: menu, dialog, sheet di HP host; halaman penonton (Jadwal, Klasemen, Detail) | 12a–12o |
| Sparing (§13): umum, Fixed, Mixed | 13a–13w, 14a–14y, 15a–15y |
| Mexicano (§14) | 03c, 03e, 03q, 16a–16g |
| Tukar pemain Mixed (§15) | 17a–17r |
| Poster podium + gambar poster Bagikan (§5.9) | 18a–18t |
| Grup + Gugur (§16, 3.8.0): pilihan format + jumlah grup + format per babak di Konfigurasi, penempatan pasangan ke grup, Jadwal fase grup, langkah Buat bagan (+ pilih yang lolos saat seri), bagan gugur di Jadwal, dialog Akhiri (20r, 21z), Klasemen grup + peringkat akhir | 19a–19y, 20a–20r, 21a–21z, 22a–22r |

State teks sederhana tanpa frame: "Halaman tidak ditemukan", "Belum ada turnamen berjalan" (juga Detail kalau
pemainnya tidak ada, 10c). Input Skor (match tidak ada) dan Jadwal Mixed (belum ada round) menampilkan layar kosong.

---

## 7. Design System (ringkas; sumber: hi-fi → Fondasi, `design/spec/tokens.json`)

- Arah: "papan skor pinggir lapangan" — tidak terkesan AI-generated.
- Warna: court `#1E6BB8`, court-deep `#164E8C`, ink `#0F1E2C`, ball `#CDE84A`, paper `#EEF2F5`, card `#FFFFFF`,
  line `#DCE3E9`, clay `#B9482A` (error/hapus/WO), padel `#BC5A33` (permukaan lapangan padel di Beranda saja),
  emas `#E3B341` (lencana #1 di Bagikan saja), 10 warna court.
- Teks: ink-2 `#3E4B57` (teks kedua, ikon), ink-3 `#5F6D7A` (keterangan kecil, placeholder, alasan di tombol tunggu;
  ≥ 4,5:1 di paper dan card). faint `#9AA6B1` hanya untuk chevron dan state mati, bukan teks yang harus dibaca dan
  bukan placeholder. Tepi semua isian yang tidak fokus (kosong maupun terisi) edge `#7D8A96` 1,5 pt; fokus court 2 pt,
  error clay 2 pt (PATCH 3.8.1, keputusan 112).
- Huruf Archivo: angka besar condensed (`wdth` 72, tabular), wordmark lebar (`wdth` 125).
- Ikon Phosphor Bold 24 pt (20 di dalam tombol). Area ketuk minimal 48 × 48 untuk semua kontrol, tampilan tetap
  (tombol ikon 44, aksi baris 36, aksi teks 44); pengecualian ikon tukar 44 × 42 (keputusan 48–57). Tombol utama 52 pt
  (PATCH 3.8.1).
- Label aksesibilitas (`Semantics`) per komponen: tabel di `design/spec/components.md` → Semantics. Status (menang,
  terpilih, terkunci, mati) ikut dibaca, bukan hanya dari warna atau bola (PATCH 3.8.1).
- Ikon app: sudut lapangan tennis + bola (opsi A), dari painter yang sama dengan banner Beranda.

### Prinsip "Tanpa Petunjuk"
- Tanpa tooltip/ikon bantuan; label dan tombol menjelaskan dirinya sendiri; status terbaca dari tampilan.
- Teks bantuan hanya kalau mencegah salah langkah (mis. pesan validasi skor, error konfigurasi).

---

## 8. Skala & Batasan

- 4–30 pemain (aktif, untuk Mixed), sama untuk Fixed dan Mixed. Court 1–10. Booking per court dalam jam.
- Fixed: 15 pasangan → 105 match; dengan 1 court sampai 105 round. Mixed bisa lebih dari 20 round.
- Makin banyak pemain dengan court yang sama, makin sedikit match per orang (Mixed) atau makin panjang round-robin
  (Fixed); turnamen besar biasanya diakhiri lewat "Akhiri" sebelum semua match Fixed dimainkan.

| Pemain | Fixed (pasangan) RR | Mixed 7 round (2 court) |
|--------|--------------------|--------------------------|
| 8 | 6 match | 14 match |
| 12 | 15 match | 14 match |
| 16 | 28 match | 14 match |
| 20 | 45 match | 14 match |
| 26 | 78 match | 14 match |
| 30 | 105 match | 14 match |

- Grup + Gugur (§16): 6–15 pasangan (12–30 pemain); 2 grup mulai 6 pasangan, 4 grup mulai 12 pasangan. Terpanjang:
  30 pemain, 2 grup, 1 court → 49 round fase grup + 4 round gugur = 53 round (16.4).

---

## 9. Fase Development

| Fase | Fitur | Status |
|------|-------|--------|
| MVP (1.x) | Setup, pairing, RR & Mixed, input skor, peringkat, share teks+gambar, simpan lokal, PWA | Selesai, live di web |
| 2.0 | Redesain v2 + format skor Race to/Best of/Americano + WO per format + perbaikan logika (`logic.md`) | Sedang dikerjakan |
| Berikutnya | Rilis Play Store (keystore sendiri), history banyak turnamen, multi-device | Belum |
| 3.8.0 (rencana) | Grup + Gugur (Fixed, §16): 2 atau 4 grup, court dikunci per grup, 2 besar tiap grup lolos ke bagan silang, format skor per babak, perebutan juara 3. Diusulkan host 2026-11-12 (backlog), dibuka lagi 2026-11-17 (keputusan 93–101); usulan GU1–GU16 + Q1–Q4 disetujui (keputusan 102); hi-fi 19a–22r disetujui (keputusan 103) | Dirancang (PRD + hi-fi) |
| Backlog | Monetisasi: buka ke publik, login Google (hanya untuk membuka fitur berbayar; app tetap jalan offline tanpa login), langganan per host, histori pertandingan milik host. Web/PWA dulu → Play Store → iOS kalau Android ramai. Usulan fitur terkunci: tambah pemain/jam/court setelah turnamen mulai, Sparing, Live Score, pilihan Total Point. Arah teknis: Firebase (Auth + Firestore + Functions), pembayaran Midtrans QRIS bayar di muka per periode. Dibahas host 2026-11-12, belum diputuskan | Belum |

---

## 10. Keputusan yang Sudah Diambil

1. Fixed: pasangan dikunci sekali di awal (dialog konfirmasi).
2. Mixed: ulang lawan dihindari lewat penalti (soft), bukan larangan.
3. Double round-robin Fixed: tidak dibuat di awal. Setelah round-robin selesai, round tambahan per putaran dari sisa
   booking (3.3a, 2026-11-03).
4. Share: gambar Feed & Story + caption teks.
5. Timer per match: tidak.
6. Metode "Kombinasi" dihapus (isinya identik dengan Win %).
7. Data turnamen app lama tidak dimuat di v2; simpanan membawa versi app (2026-10-22).
8. Court bisa ditambah di tengah turnamen, hanya Mixed; jam court baru dihitung dari saat ditambah dan court langsung
   dipakai kalau round sedang berjalan (2026-10-22).
9. Nama turnamen (usulan pemain): opsional, maks 40 karakter supaya gabungan klub ("PB Garuda x Matcha Club") muat,
   hanya diisi di Konfigurasi; tampil di Beranda, poster, dan caption. Di poster jadi baris kecil, bukan judul besar
   (2026-10-23).
10. Batas pemain 30 (dulu 20), sama untuk Fixed dan Mixed, karena kebutuhan nyata klub 24–26 orang. Poster Lengkap
    menyesuaikan: pasangan selalu satu kolom, dan di atas kepadatan frame yang sudah disetujui huruf baris dikecilkan
    sebanding (2026-10-23).
11. Live score tanpa database: relay kecil di Cloudflare (Worker + Durable Object, paket gratis) yang hanya memegang
    salinan turnamen terakhir per kode, terhapus 3 hari setelah perubahan terakhir. Penonton melihat Jadwal, Klasemen,
    dan Detail; Fixed dan Mixed. Preview link WhatsApp tetap generik (nama app, GitHub Pages statis) (2026-10-24).
12. Nama pemain di baris match ditulis lengkap, bukan nama depan: dua pemain bernama depan sama membuat siapa yang
    main membingungkan. Tidak muat → elipsis per nama (2026-10-25).
13. "Akhiri" mengakhiri turnamen juga di Beranda: yang sudah diakhiri tampil sebagai turnamen terakhir, bukan
    "Round n · Lanjutkan" (2026-10-25).
14. Pemain telat di Mixed menyusul jumlah main: diprioritaskan dengan jeda 1 round setelah k round beruntun (3.4),
    menggantikan kredit yang membuat selisihnya tetap (2026-10-25).
15. Best of & Americano boleh berhenti lebih awal begitu lawan tidak mungkin mengejar (pemenang ⌊N ÷ 2⌋ + 1); isi
    otomatis `N − x` hanya ke kotak lawan yang kosong, jadi koreksi skor tidak memberi poin gratis ke yang kalah (4.1)
    (2026-10-26).
16. Nama app **Match Addict** (dulu Mabar): wordmark "Match Addict", label ikon, web pindah ke
    `asepsugi.github.io/match-addict/`, bundle id `id.matchaddict.app` (2026-11-02).
17. Peringkat hanya ditentukan angka yang tampil: nilai metode lalu selisih (kolom +/− baru di Klasemen, selisih di
    setiap baris poster); keduanya sama → nomor sama dan nomor berikutnya melanjutkan (#1, #2, #2, #3). Head-to-head
    dihapus (4.3). Dipicu poster yang menulis 22 · 22 · 22 dengan nomor #2, #3, #4 tanpa terlihat alasannya
    (2026-11-02).
18. Round tambahan Fixed (3.3a): per putaran supaya semua pasangan main sama banyak, dari sisa booking + jam tambahan,
    dibulatkan ke atas dan boleh lewat booking; host yang mengakhiri. Lawan mengulang round-robin dari awal. Sebelumnya
    pasangan bisa diatur ulang dan pemain pengganti dimasukkan; Klasemen campuran (pasangan tetap satu baris, sisanya
    per pemain). Dipicu turnamen live TBNE36 yang selesai 14 round dengan sisa booking 30 menit (2026-11-03).
19. **Sparing** (§13, ide host): dua klub bertanding, Fixed maupun Mixed; partner selalu sesama klub, lawan selalu klub
    lain. Jumlah pemain klub boleh beda dan klub kecil main lebih sering; Fixed tiap pasangan bertemu tiap pasangan klub
    lain sekali; klub menang dari jumlah match menang (seri ½), lalu Total Point klub; klasemen per klub; dipilih di
    layar Pemain; minimal 2 pemain per klub, total 4–30; round tambahan Fixed per satuan KPK pasangan; poster dan
    caption dibuka skor klub; poster Ringkas = 3 teratas tiap klub (dikonfirmasi host; diganti keputusan 62); Detail menaruh tim sendiri di
    atas dengan nama klub di subjudul; estimasi Fixed sparing pasti ("Lanjut · 14 round · lewat booking 01:30");
    pemain ganjil per klub menahan Buat jadwal seperti Fixed biasa; nilai WO klub di Mixed Best of/Americano =
    rata-rata nilai WO kedua pemenang (rincian K1–K13). Turnamen
    biasa tidak berubah; rilis 3.2.0 MINOR (2026-11-04).
20. **Versi app tampil lagi di Beranda** (permintaan host): `appVersion` (`MAJOR.MINOR.PATCH`) ditampilkan di Beranda.
    Membatalkan sebagian keputusan hi-fi v2 yang menghapus footer "Skor tersimpan otomatis · v1.0" (Cakupan →
    Dihapus); teks "Skor tersimpan otomatis" tetap dihapus. Letak dan gaya oleh designer, ikut rilis 3.2.0
    (2026-11-04).
21. **Default metode Klasemen mengikuti format skor** (4.2): Race to dan Best of → Win %, Americano → Total Point;
    tab dan aturan urutan (nilai metode → selisih, 4.3) tidak berubah. Dipicu room live RM5HP5 "Sparing Senin"
    (Race to 6): Dewi · Citra 1W–2L (16, +2) di atas Gita · Andi 2W–1L (16, +1). Riset aturan resmi: skor
    menang/kalah selalu memakai jumlah menang dulu; total poin dulu hanya lazim di Americano. Rilis 3.3.0 MINOR
    (2026-11-11). **Diubah keputusan 123 (2026-11-20) untuk Americano:** default Americano → Point %; Race to dan Best
    of tetap Win %; tab ketiga Point % (keputusan 122).
22. **Back dari Jadwal ke Beranda** (5.5): sebelumnya back kembali ke Atur turnamen (atau Pasangan), dan "Buat jadwal"
    lagi di sana menghapus skor yang sudah diisi. Sekarang back di Jadwal Fixed dan Mixed (tombol, HP, browser)
    langsung ke Beranda; penonton live tidak berubah. Rilis 3.3.1 PATCH (2026-11-11).
23. **Mexicano** (§14) jadi mode pemasangan ketiga, sejajar Fixed dan Mixed, untuk tennis dan padel: R1 diundi, round
    berikutnya pemain dikelompokkan berempat per court menurut klasemen. Alasan: pasangan acak Mixed sering membuat
    match berat sebelah; Mexicano menyeimbangkan tanpa host menilai kemampuan pemain. Rencana 3.4.0 MINOR (2026-11-11).
24. Format skor Mexicano **hanya Americano**: urutannya memakai total poin, yang memang tujuan Americano (sejalan
    keputusan 21) (2026-11-11).
25. Istirahat di Mexicano memakai **aturan prioritas main Mixed** (3.4) apa adanya; yang main lalu dipasangkan menurut
    klasemen. Selisih jumlah main tetap ≤ 1 (2026-11-11).
26. Partner berulang di Mexicano **dihindari selama masih ada susunan lain di court itu** (1+3 vs 2+4 → 1+4 vs 2+3 →
    1+2 vs 3+4); pemain tidak dipindah court (2026-11-11).
27. **Sparing dan pemain telat di Mexicano ditunda**: Sparing tidak menawarkan Mexicano, dan pemain tidak bisa ditambah
    di tengah turnamen Mexicano (2026-11-11).
28. Pemain telat **tidak bisa ikut sama sekali** di turnamen Mexicano, juga saat R1; kalau belum ada skor, host memulai
    turnamen baru dari Beranda (14.12 Q1, 2026-11-11).
29. Pemain yang dikeluarkan di Mexicano **tidak bisa kembali setelah melewatkan satu round**; Kembalikan hanya untuk
    membetulkan salah ketuk sebelum round berikutnya dibuat (14.12 Q2, 2026-11-11).
30. Seri di urutan Mexicano **diundi, terkunci per round**, bukan diurut nama (14.12 Q3, 2026-11-11).
31. Urutan Mexicano **selalu Total Point → selisih**, apa pun tab Klasemen yang dipilih (14.3, U1, 2026-11-11).
    **Diubah keputusan 124 (2026-11-20):** urutan Mexicano = Point % → selisih → undian; tetap tidak tergantung tab.
32. Koreksi skor di Mexicano **tidak membuat ulang round yang sudah dibuat**; host memakai Batalkan round lalu Buat
    (14.7, U6, 2026-11-11).
33. **Konfigurasi diringkas** (usulan Arah A, `design/proposals/konfigurasi-mexicano.html`): tetap satu layar (Nama,
    Pasangan, Skor, Court); grup Skor dan Court masing-masing menjadi satu baris berisi nilainya, rinciannya di sheet.
    Tidak ada field yang hilang (5.3, 2026-11-11).
34. Memilih Mexicano saat format Race to/Best of → **Americano 21**; Americano yang sudah ada tetap N-nya; kembali ke
    Fixed/Mixed **tidak mengembalikan** format sebelumnya (14.2, U9, 2026-11-11).
35. Kartu mode (Fixed / Mixed / Mexicano) **tanpa teks deskripsi**: hanya gambar dan nama mode (2026-11-11).
36. Konfigurasi dibuka dengan **pengaturan turnamen terakhir di HP itu** (mode, format, durasi, court), bukan default
    tetap; dikerjakan setelah Arah A masuk hi-fi (2026-11-11).
37. Baris Skor di Konfigurasi menulis **"menit"**, tidak disingkat "mnt" (mis. "Race to 6 · 20 menit") (2026-11-11).
38. Pengaturan terakhir (keputusan 36) diingat **per olahraga** (tennis dan padel terpisah): mode, format + N, durasi,
    dan court (jumlah, nama, warna, booking). Nama turnamen tidak ikut. Terakhir Mexicano lalu host memilih Sparing →
    mode terisi Mixed, format dan court tetap (hi-fi 03q, 13h; 2026-11-11, bagian Sparing disetujui 2026-11-12).
39. Round Mexicano yang dibuat tanpa pemain yang dikeluarkan lalu **dibatalkan** → pemain itu belum melewatkan round,
    jadi "Kembalikan" muncul lagi (14.7, hi-fi 16g; 2026-11-11).
40. Teks sheet **"Cara kerja Mexicano"** (hi-fi 16c) disetujui apa adanya. Dialog Batalkan round Mexicano (16e):
    "Jadwal R2 dihapus. Keluarkan pemain atau ubah skor R1, lalu tekan "Buat R2" lagi." — tanpa kata "pulang", karena
    pemain yang keluar tidak selalu pulang (2026-11-11).
41. Disetujui dari usulan designer (hi-fi → Cakupan, 2026-11-11): catatan "Bisa berakhir seri", error durasi, dan
    "Isi durasi match" tampil di dalam sheet dan di bawah baris Skor di layar; action bar Konfigurasi ikut naik di atas
    keyboard dan durasi kosong ditulis "– menit" clay; data contoh R2–R3 di 16g menjadi data test; subjudul Jadwal
    Mexicano tidak menyebut nama mode.
42. Judul sheet warna court di Konfigurasi memakai **nama court**: "Warna Court VIP"; nama kosong = "Warna Court 2"
    (hi-fi 03k dibetulkan; 2026-11-12).
43. Subjudul sheet "Cara kerja Mexicano": **"R1 diundi." hanya selama R1**. Dibuka dari menu di round lanjut:
    "Isi semua skor, lalu tekan Buat R5." (hi-fi 16c; 2026-11-12).
44. Susunan Mexicano dengan **beban ulang terkecil** (jumlah kali berpasangan); seri → A, lalu B, lalu C (14.5, U3,
    2026-11-12).
45. Kelompok teratas Mexicano main di **court bernomor terkecil** yang dipakai (14.4, U4, 2026-11-12).
46. Versi lama (≤ 3.3.x) **menolak** simpanan dan payload live Mexicano, seperti K13 Sparing (14.8, U7, 2026-11-12).
47. Pemain yang belum main dihitung **0 / 0** di urutan Mexicano (14.3, U8, 2026-11-12).
48. **Tukar pemain (Mixed)** (§15): host bisa menukar pemain di match **round terakhir** yang skornya belum diisi (juga
    belum WO) dengan pemain yang sedang istirahat, secara manual. Round lama dan match Selesai/WO tidak bisa diubah,
    supaya riwayat dan Klasemen utuh. Rencana 3.5.0 MINOR (2026-11-12).
49. Tukar **satu lawan satu**: pemain yang masuk mengambil posisi persis pemain yang keluar (partner dan lawan tetap),
    tanpa undi ulang (15.1 T3, 2026-11-12).
50. **Fairness tanpa aturan baru**: prioritas main tetap dihitung dari riwayat (3.4), jadi pemain yang ditukar keluar
    otomatis naik prioritasnya dan daftar "Istirahat · Prioritas main di R(n+1)" ikut berubah (15.1 T6, 2026-11-12).
51. Sparing Mixed: tukar hanya dengan pemain istirahat **sesama klub** (15C, 2026-11-12).
52. **Mexicano dikunci**, tidak ada tukar pemain. Alasan host: tukar "akan mempengaruhi susunan klasemen" (pasangan
    Mexicano disusun dari Klasemen) (2026-11-12).
53. Fixed: tukar pemain tidak berlaku, karena tidak ada pemain istirahat perorangan; mengganti pemain Fixed tetap lewat
    Atur pasangan (3.3a) (2026-11-12).
54. Pemain yang sudah **dikeluarkan** tapi masih di match Belum round terakhir **boleh ditukar keluar**; dia dicatat
    istirahat di round itu (15.1 T5, TU1, 2026-11-12).
55. Pemain yang **ditambah setelah round terakhir dibuat** boleh ditukar masuk ke round itu; di R1 dia dihitung hadir
    sejak awal, bukan pemain telat (TU2, 2026-11-12).
56. Kandidat yang masuk = **seluruh daftar Istirahat** round terakhir, termasuk "Istirahat lagi" (TU3, 2026-11-12).
57. **Batalkan Rn menghapus tukar** bersama round-nya, tanpa teks tambahan di dialog Batalkan (TU4, 2026-11-12).
58. **Titik masuk tukar = ikon di baris match Jadwal**, di kolom bola pemenang, satu per tim, hanya di baris yang bisa
    ditukar (hi-fi 17a–17r). Menu ⋯ dan layar Input Skor ditolak: host berniat mengganti pemain "sejak pertandingan belum
    dimulai", sedangkan Input Skor berarti "pertandingan sudah dimulai". Ikon panah dua arah dipilih designer (host
    menyerahkan pilihan panah / panah melingkar / gerigi) (2026-11-12).
59. Sheet tukar satu langkah: judul "Tukar pemain", subjudul "Round n · Court c" (Sparing + nama klub), grup "Diganti"
    (dua pemain tim itu, bukan "Keluar" yang sudah berarti dikeluarkan), kandidat dengan label Istirahat Jadwal, tombol
    "Tukar" mati tanpa alasan sampai dua pilihan terisi (pola Simpan skor). Tanpa dialog konfirmasi dan tanpa toast.
    Area ketuk ikon 44 pt (boleh menutupi awal nama). Ikon juga di Jadwal host saat live aktif; halaman penonton tidak
    berubah (2026-11-12).
60. **Poster Ringkas diganti poster podium** (arah "Sudut lapangan": sudut lapangan, podium tiga dimensi, bola per
    pemain, panel nama di bawahnya), Feed 1080×1080 dan Story 1080×1920. Host: gambar lama "padat dengan text", diganti
    "ilustrasi podium nya saja dengan sedikit detail statistik". Poster Lengkap tetap ada sebagai pilihan kedua dan
    tidak berubah (2026-11-12).
61. Podium Fixed: satu anak tangga = satu pasangan (dua nama, dua bola). Mixed / Mexicano: satu pemain (2026-11-12).
62. Podium Sparing: dua blok skor klub, tanpa bola dan tanpa pemain terbaik tiap klub; perorangan hanya di poster
    Lengkap. Menggantikan "poster Ringkas = 3 teratas tiap klub" (K7) untuk Ringkas (2026-11-12).
63. Statistik podium: nilai metode + selisih untuk yang naik podium, plus satu baris fakta turnamen ("Padel · 12
    pemain · 6 round · 18 match"). Satuan ditulis di Feed dan Story ("80 poin · +34"). Judul tetap "Klasemen akhir" /
    "Klasemen sementara"; tanpa statistik tambahan (W–L) (2026-11-12).
64. **Peringkat kembar: tinggi podium harus sama.** Tinggi anak tangga ditentukan nomor, bukan urutan baris (#1, #2,
    #2 → dua anak tangga #2 sama tinggi; #1, #1, #2 → dua emas sama tinggi) (2026-11-12).
65. Yang naik podium = tiga baris teratas Klasemen. Kembar yang melewati tiga tempat: semua yang senomor dengan baris
    ketiga ikut naik, maksimal 4 anak tangga; lebih dari itu podium dipangkas ke kelompok nomor yang utuh (#1, #2, #3,
    #3, #3 → hanya #1 dan #2). Hanya dua baris bernomor → dua anak tangga, tanpa tempat kosong (2026-11-12).
66. Tema poster podium: palet lapangan ikut olahraga (padel terracotta, tennis biru court) jadi bawaan; sepuluh gradien
    lama tetap bisa dipilih (2026-11-12).
67. Panel nama di poster podium sedikit transparan (warna panel 86%, lantai/latar tembus), kontras teks tetap ≥ 4,5 : 1 (2026-11-12).
68. Lebih dari empat pemain di #1 (aturan pangkas 65 tidak menyisakan kelompok utuh): satu blok emas lebar tanpa bola
    dan satu baris panel "#1 · 6 pemain · 12 poin · +3" (Fixed: "6 pasangan") (hi-fi 18s, 2026-11-12).
69. Belum ada match selesai (tidak ada yang bernomor): poster podium = lapangan kosong tanpa blok, panel hanya wordmark
    + baris fakta "R1 · 0 dari 3 match". Tombol Bagikan tidak dimatikan (hi-fi 18t, 2026-11-12).
70. Deret tema di tab Ringkas = 11 lingkaran 27 pt (lapangan + 10 gradien); di tab Lengkap tetap 10 lingkaran 30 pt dan
    pilihan lapangan dipakai sebagai biru. Berlaku sampai Lengkap dirombak (2026-11-12).
71. Baris fakta saat Sementara: "R3 · 7 dari 9 match" (pola subjudul Klasemen). Podium Fixed yang bercampur pasangan
    dan pemain tunggal setelah atur ulang (hi-fi 18l): baris fakta tanpa hitungan pasangan/pemain (2026-11-12).
72. Sparing yang belum punya match selesai (skor klub 0 – 0): ikut keputusan 69, poster podium = lapangan kosong, bukan
    dua blok "0" (2026-11-13).
73. Lebih dari empat di #1 (keputusan 68) pada Fixed: baris dan blok ukuran tunggal, teks "6 pasangan" tanpa bola, bukan
    ukuran pasangan (2026-11-13).
74. Kasus 73 pada Fixed yang bercampur pasangan dan pemain tunggal: nama baris hanya angka "{n}" tanpa kata, mengikuti
    71/09g (2026-11-13).
75. Tema Bagikan hijau, jingga, teal: warna ujung gradien digelapkan satu tingkat (#15803D, #C2410C, #0F766E) supaya
    teks putih di baris bawah poster Lengkap ≥ 4,5 : 1; teks kecil 70% transparan dibiarkan (2026-11-13, PATCH 3.6.1).
76. **Poster Lengkap dirombak satu keluarga dengan poster podium**: tema bawaan palet lapangan ikut olahraga, kepala
    poster memakai sudut lapangan yang sama (kecil), daftar di panel bergaya panel podium. Deret tema di tab Ringkas
    dan Lengkap sama (11 lingkaran: lapangan + 10 gradien), menggantikan keputusan 70. Arah visual diputuskan lewat
    eksplorasi designer (2026-11-13).
77. Isi baris poster Lengkap tetap "nilai metode + selisih" seperti Klasemen (§5.9), tanpa W–L atau statistik
    tambahan; aturan kolom dan kepadatan §5.9 tetap kecuali eksplorasi mengusulkan lain dan host menyetujui (2026-11-13).
78. Data frame hi-fi 11h diperbaiki supaya konsisten (selisih tertulis +4 padahal seharusnya 0), sekalian di rombak
    Lengkap (2026-11-13).
79. Arah visual poster Lengkap = **B "Podium mini"** (`design/explore/bagikan-lengkap.html`): podium kecil (angka +
    bola, tanpa nama) berdiri di garis belakang di kanan judul, daftar di panel 86% di atas lantai. Pilihan host atas
    rekomendasi A (2026-11-13).
80. Kepadatan poster Lengkap memakai satu aturan: ukuran huruf baris mengikuti tinggi baris yang tersedia, dibatasi
    ukuran panel poster podium; menggantikan ambang jumlah baris per kasus di §5.9 (2026-11-13).
81. Story Mixed di atas 20 pemain dibagi dua kolom rata (seperti Feed); menggantikan "Story selalu satu kolom" untuk
    kasus itu. Pasangan Fixed tetap satu kolom (2026-11-13).
82. Judul poster Lengkap arah B: maksimal dua baris di samping podium mini, huruf mengecil bertahap seperti judul
    podium (22 → 18,5; Story 27 → 23); podium mini Story lebih ramping supaya kolom judul lebar; elipsis hanya kalau
    ukuran terkecil masih tidak muat (2026-11-13).
83. Sparing poster Lengkap: angka skor klub hanya di blok podium mini; kepala klub di panel = nama klub + "83 game ·
    +14" tanpa angka skor (2026-11-13).
84. Baris kecil di bawah judul poster Lengkap yang lebih lebar dari kolom judul: huruf mengecil per 0,5 sampai muat,
    paling kecil 11 (pola baris fakta); tidak pecah dua baris (2026-11-13).
85. Podium mini kasus khusus ikut podium Ringkas: lebih dari 4 di #1 (keputusan 68) = satu blok emas lebar tanpa bola;
    belum ada match selesai (keputusan 69) = garis belakang tanpa blok (2026-11-13).
86. Sparing poster Lengkap di Story dengan banyak pemain dibagi dua kolom per klub (13w), bukan ⌈n/2⌉, supaya satu
    kolom tidak berisi dua klub (2026-11-13).
87. Poster Lengkap saat belum ada match: panel hanya wordmark + baris fakta, seperti poster podium 18t (11m) (2026-11-13).
88. Story Fixed 15 pasangan tetap satu kolom (nama ±27 px di gambar 1080); keterbacaan diuji di HP setelah rilis
    (2026-11-13).
89. Poster Lengkap Sparing belum ada match (0 – 0): ikut 87 tanpa kasus khusus Sparing — garis belakang tanpa blok,
    panel hanya wordmark + fakta (tanpa kepala klub), kolom judul selebar kasus kosong lain; setelah match pertama
    judul menyempit (2026-11-13, tanpa frame; `logic.md` §17.13).
90. Story Fixed campuran (pasangan diatur ulang, ada pemain tunggal) di poster Lengkap: semua baris setinggi baris
    pasangan, nama ditumpuk hanya di baris dua nama — sama dengan Ringkas 18l (2026-11-13, tanpa frame).
91. **Lantai poster = lapangan utuh** (arah L1, eksplorasi `design/explore/bagikan-lapangan.html`): lapangan tennis /
    padel digambar utuh dengan semua garis resmi lalu dipotong kanvas — setengah lapangan dari sudut garis belakang
    (posisi sudut tetap) sampai dekat net, dilihat dari penonton di dekat net di sisi seberang sudut. Proyeksi sejajar:
    sumbu depth = depth blok podium poster itu (di Lengkap = podium mini), lebar horizontal, dinding tegak. Padel:
    dinding kaca belakang + kiri bertingkat + pagar kawat; net tidak digambar. Garis lewat di belakang podium dan
    panel; panel tetap 86% (keputusan 67). Posisi podium, judul, panel tidak berubah (2026-11-13).
92. **Ukuran & perataan poster 3.7.1** (uji HP host, 2026-11-13), semua poster Ringkas & Lengkap: nama di baris panel
    tidak lebih besar dari sub judul (Feed 12,5, Story 15); nilai rata kanan dan keterangan ("poin · +12") rata kiri
    dalam kolom selebar nilai terpanjang se-poster, supaya poin dan selisih sejajar walau jumlah digit beda; kaki lebih
    kecil satu tingkat (wordmark 11,5 → 10,5, bola 13 → 12, fakta 10,5 → 9,5); Lengkap Feed dua kolom: baris mengisi
    ruang panel (batas tinggi baris 26 → 40, huruf tetap) sehingga tidak ada celah antara kepala dan panel.
93. **Grup + Gugur** (§16) hanya untuk mode **Fixed** (pasangan tetap): pilihan format baru di bawah Fixed, round-robin
    biasa tetap ada (2026-11-17).
94. **2 besar tiap grup** lolos ke gugur. Jumlah grup **2 atau 4** saja (→ semifinal / perempat final, tanpa bye);
    minimal 3 pasangan per grup; batas 30 pemain tetap (2026-11-17).
95. **Pasangan dan grup diatur host secara default.** Host: "default untuk mode turnamen panjang ini pasangan diatur oleh
    host" dan "ya pembentukan pasangan nya manual secara default". Di Grup + Gugur, pembentukan pasangan **dan**
    penempatan pasangan ke grup sama-sama manual secara default, bukan undi acak. Tidak habis dibagi → ukuran grup
    selisih ≤ 1 (2026-11-17).
96. **Court dikunci per grup.** Host: "untuk court bisa dikunci 1 group main di court yang sama. tapi 1 court bisa
    bergantian dengan group lain." Satu grup main di court yang tetap; grup lebih banyak dari court → beberapa grup
    bergantian di satu court (2026-11-17).
97. **Bagan silang**: A1–B2 dan B1–A2; dengan 4 grup bagan diatur supaya pasangan dari grup yang sama paling cepat
    bertemu di final (2026-11-17).
98. **Peringkat grup** memakai metode Klasemen yang ada (nilai metode + selisih, 4.2–4.3). Seri di batas lolos
    (peringkat 2 vs 3) → head-to-head → masih seri: host memilih (2026-11-17).
99. **Format skor gugur per babak.** Host: "untuk fase gugur format skor boleh berbeda/berganti tiap tingkat". Race
    to / Best of / Americano + N diatur per babak: perempat final, semifinal, perebutan juara 3, final (2026-11-17).
100. **Perebutan juara 3** adalah opsi, **default nyala**, supaya poster podium tetap punya tempat ke-3 (2026-11-17).
101. **Bagan di Jadwal** saat fase gugur: skor terisi, pemenang maju otomatis setelah skor diinput. Bagan di poster
     Bagikan dan di live score: belum sekarang (2026-11-17).
102. **Usulan GU1–GU16 dan rekomendasi Q1–Q4 §16** disetujui host 2026-11-17 ("setuju semua"): lolos memakai metode
     default format grup tanpa tab metode (Q1), skor grup dikunci saat Buat bagan (Q2), peringkat akhir per babak/posisi
     grup dan baris menulis babak, termasuk poster (Q3; tampilan poster didesain ulang di fitur ini), court sisa ke grup
     yang paling lama selesai (Q4).
103. **Hi-fi Grup + Gugur 19a–22r** disetujui host 2026-11-17 ("setuju"), termasuk usulan desainer yang belum ada di
     §16 (daftar lengkap di hi-fi → Cakupan): pilihan format hanya Fixed ≥ 12 pemain; baris "Fase grup" + "Gugur"
     di Konfigurasi, gugur mengikuti format grup sampai diubah, juara 3 "Ada / Tidak ada"; layar Grup dengan chip A–D
     tanpa Urungkan, kelebihan "5 dari 4", Acak → Manual mengosongkan grup; label "Grup A" di baris match (95 pt);
     sheet "Pilih A2" / "Pilih A1 dan A2" saat seri; tab Bagan terakhir di strip, tab babak memakai kode ("PF1–2",
     "SF1", round Final + Juara 3 = "Final"), format skor di label match; bagan 8 tim digeser per babak; dialog
     "Ganti pemenang SF1?" dan penolakan kalau babak berikut sudah ada skor; Klasemen "Peringkat | Fase grup" dengan
     kolom # · Pasangan · Babak; podium #1 #2 #3 #3 tanpa Juara 3; Detail tanpa "Beda lawan". Poster selama fase grup
     dan halaman penonton live mengikuti aturan 22g, frame dibuat kalau host minta.
104. **Ubah format babak / juara 3 setelah jadwal dibuat (GU9) ditunda ke 3.8.x** (2026-11-17, "setuju"): belum ada
     frame; di 3.8.0 hanya diatur di Konfigurasi.
105. **Turnamen diakhiri di fase grup:** pasangan yang belum main sama sekali tampil "Belum main" tanpa nomor dan tidak
     naik podium (2026-11-17).
106. **Caption match gugur yang tidak dimainkan** dengan sisi belum diketahui menulis sumbernya ("Pemenang SF2"), bukan
     "?" (2026-11-17).
107. **Frame 19s benar, catatannya diperbaiki** (2026-11-17): contoh sebagian = Andi · Budi dan Citra · Dewi ke A,
     Indra · Joko ke B → "5 pasangan tanpa grup".
108. **Pseudocode round-robin 3.3 diperbaiki** (2026-11-17): pasangan dalam = `rotate[i] vs rotate[n-3-i]`; versi lama
     memasangkan `rotate[last]` dua kali. Kode (`round_robin_generator.dart`) sudah benar, perilaku tidak berubah.
109. **Frame 22q/22r Story dibetulkan ke aturan bawahKepala** (2026-11-17, "setuju"): baris kecil yang dikecilkan
     (15 → 12,5) memakai ukuran sesudah dikecilkan untuk garis belakang, podium mini, dan panel (logic.md §17.12 #3,
     sama dengan 11m); frame lama menurunkannya 3 pt. Kode tidak berubah.
110. **Catatan disamakan dengan app** (2026-11-18): menu ⋯ setelah diakhiri = Fixed tinggal Live score, Mixed Live score +
     Cara kerja (06m); sparing bernama menulis skor klub di samping round (15w). Kode tidak berubah.
111. **Paragraf penjelas Kelola pemain dihapus** (2026-11-18, K3): "Pemain baru langsung ikut main…" di 08a/15l/15m
     hilang; aturan menyusul tetap (2.7.0), hanya teks UI.
112. **PATCH 3.8.1 dari review UX hi-fi** (2026-11-18): paket P1 kontras, P2 area sentuh + Semantics, P3 teks dari
     `design/review/ux-review.md` dikerjakan sesuai usulan reviewer (rincian per id di `ux-review-A/B/C.md`). P4–P7
     diputuskan host kemudian di hari yang sama (keputusan 113–120). Setelah selesai, catatan PRD dan hi-fi diaudit supaya tidak berbeda. **Audit selesai 2026-11-18 (UX-5):** PRD §5,
     §6, §7, §13–§16 disamakan dengan app 3.8.1; catatan hi-fi yang tertinggal diperbaiki; kode = kebenaran bila beda.
113. **Kosongkan skor / Hapus WO** (2026-11-18, paket P7, temuan B-2 dan C-9): skor atau WO yang salah bisa dikembalikan.
     Bentuk UI usulan reviewer: Input Skor mode ubah, kedua kotak dikosongkan dengan ⌫ → "Perbarui skor" jadi
     "Kosongkan skor" (sekunder, tinta clay) → dialog "Kosongkan skor Court 1?" / "Match kembali belum dimainkan." /
     Batal · Kosongkan. Sheet WO yang dibuka dari WO tersimpan: "Hapus WO" di kanan kepala sheet (pola 12c / 08h); WO
     dihapus → skor lama kalau ada, kalau tidak Belum. Alasan: tanpa ini skor di match yang salah tetap "Selesai" dan
     ikut menentukan round berikutnya, Final, urutan Mexicano, dan bagan. Aturan: §17.
114. **Batas Kosongkan skor / Hapus WO** (2026-11-18): (1) Mixed dan Mexicano hanya round terakhir; Fixed dan Sparing
     Fixed round mana pun; (2) Grup + Gugur: match grup dilarang setelah bagan dibuat; (3) match gugur boleh, memakai
     dialog flipCheck yang sudah ada (21k/21l) kalau pemenangnya sudah maju; mengosongkan Final membuka jalan ke GU11,
     aturan GU11 tidak berubah. Alasan: round Mixed/Mexicano berikutnya dibuat dari hasil round sebelumnya, dan bagan
     dibuat dari skor grup yang dikunci (GU6). Rincian dan akibatnya: 17.3–17.4.
115. **"Hapus semua" di Pemain tanpa dialog, dengan Urungkan** (2026-11-18, A-8): toolbar "Tempel · Urungkan" (ikon
     arrow-counter-clockwise) sampai ada ketikan, lalu kembali "Tempel · Contoh". Alasan: dialog hanya untuk yang tidak
     bisa diurungkan; Hapus semua satu baris dengan Tempel yang paling sering diketuk. Aturan: 17.10.
116. **Dialog buang pasangan** (2026-11-18, A-9): "Buang N pasangan manual?" · Batal / Buang (bahaya) hanya saat
     pasangan manual akan hilang (Manual → Acak); "Buang perubahan pasangan?" · Batal / Buang saat ← (termasuk back
     Android) di Atur pasangan ada perubahan. Acak → Manual tanpa dialog; layar Grup tanpa dialog (Cakupan hi-fi).
     Alasan: sampai 15 pasangan hilang dengan satu ketukan. Aturan: 17.10.
117. **Bagikan gagal → unduh dua gambar + salin hasil** (2026-11-18, B-10): kedua PNG diunduh, caption disalin, toast
     "Gambar diunduh · hasil disalin", tanpa tombol baru. **Mengubah aturan 2026-10-22** (gagal → hanya caption disalin,
     "Hasil disalin"; tanpa tombol salin terpisah tetap berlaku). Alasan: di HP/browser tanpa share sheet, poster, inti
     fitur Bagikan, tidak bisa didapat sama sekali. Aturan: 17.10.
118. **Lawan WO tetap dihitung di "Beda lawan"** (2026-11-18, B-21), juga partner di "Beda partner"; kode tidak berubah,
     hanya aturan ditulis (5.8, 17.10).
119. **Tombol mati "Buat bagan · tunggu N match"** (2026-11-18, C-17): action bar fase grup = ikon Klasemen + tombol mati
     selama ada match grup Belum (pola 13m). Beda dengan Fixed 06v yang menyembunyikan Tambah round, karena Tambah round
     opsional dan Buat bagan wajib. Aturan: 17.11.
120. **P6 + P4 + GU9 + A-15 disetujui, pengelompokan rilis** (2026-11-18): **3.9.0 (MINOR)** = P5 + P7 + C-17 + P6 visual
     (C-7 bagan mengintip 24 pt + label kolom, C-18 label 12 → 13 px, C-15 pratinjau Tukar menebalkan nama yang masuk) +
     P4 (B-22 aturan pemisah di `components.md`, B-16 data uji, C-12 catatan "menunggu host", frame B-7, B-8, B-9, B-18,
     C-3, C-4, C-10). **3.10.0 (MINOR)** = GU9 (label babak diketuk → sheet 19f selama babak belum ada skor; C-2;
     menggantikan "3.8.x" di keputusan 104) + A-15 (skala teks sampai 1,3). C-6 usulan kedua dibahas bersama GU9.
121. **Usulan PM U-1–U-5 dan pertanyaan Q1–Q3 §17 disetujui** (2026-11-18, "setuju"): Q1 round lama Mixed/Mexicano hanya
     lewat Batalkan Rn satu round ke belakang, diterima untuk 3.9.0 (batas keputusan 114 tetap); Q2 Kosongkan skor/Hapus WO
     tetap boleh setelah turnamen diakhiri, match jadi Tidak dimainkan (U-1); Q3 mengosongkan match di round lama Fixed
     mengunci lagi round sesudahnya; U-2 Sparing Mixed ikut batas Mixed; U-3 match WO tanpa Kosongkan skor (jalannya Hapus
     WO); U-4 judul dialog gugur memakai kode match; U-5 catatan kunci round menyebut round terakhir yang belum lengkap;
     B-10 di Android/iOS asli hanya kalau tanpa izin atau dependensi baru, selain itu "Hasil disalin" tetap (tech lead
     memastikan).
122. **Point % jadi metode peringkat ketiga** (2026-11-20, host: "setuju 4 usulan. tapi gw mau Total Point tetap ada
     sebagai pilihan"): Point % = game/poin didapat ÷ game/poin dimainkan (didapat + kalah) × 100. Tab ketiga di
     Klasemen; **Win % tidak diganti, Total Point tetap ada**. Alasan: host bertanya apakah persen poin terhadap jumlah
     main menangani jumlah main yang tidak sama. Simulasi main session (600 turnamen per skenario, Mixed 7–16 pemain,
     ada yang istirahat + 2 pemain telat; Americano 21 dan Race to 6): Total Point menaruh pemain yang mainnya lebih
     sedikit 0,7–1,3 posisi di bawah kemampuannya, Point % dan Win % tidak; ketepatan urutan Point % paling tinggi
     (Americano 0,50–0,60 vs Win % 0,45–0,55 vs Total Point 0,41–0,56); nilai kembar Point % 0,3–2% (Win % 7–19%). Point %
     bisa menaruh 1W–2L di atas 2W–1L (contoh A/B 4.2), jadi tidak menggantikan Win %. Aturan: §18.
123. **Default metode Americano → Point %** (2026-11-20, mengubah keputusan 21 untuk Americano): Race to dan Best of
     tetap Win %. Berlaku juga untuk Mexicano dan Sparing Americano. Alasan: di Americano yang dimainkan sampai total N,
     Point % = rata-rata poin per match ÷ N, jadi urutannya sama dengan Total Point kalau jumlah main sama, dan tetap
     adil kalau tidak sama. Aturan: 4.2, §18.
124. **Urutan Mexicano = Point % → selisih → undian** (2026-11-20, mengubah keputusan 31): tetap tidak tergantung tab
     Klasemen. Alasan: dengan Total Point pemain yang baru istirahat tertinggal satu match dan turun ke court bawah
     (14B); Point % tidak. Aturan: 14.3, contoh 18D.
125. **WO di Point % = skor "nilai WO – 0"** (2026-11-20): pemenang didapat + nilai WO dia sendiri (4.4), kalah + 0;
     pasangan WO didapat + 0, kalah + nilai WO pasangan lawan (Mixed Best of/Americano: rata-rata nilai WO kedua
     pemenang, ,5 ke atas, sama dengan K11). Selisih tetap tidak berubah oleh WO. Angka "kalah" untuk pasangan WO
     dirinci PM dari "nilai WO – 0" (lawan mendapat nilai itu, jadi itulah yang dimainkan pasangan WO); tanpa angka kalah,
     WO tidak menurunkan Point % yang kalah. Aturan: 4.4, contoh 18C.
126. **Point % masuk 3.9.0 (MINOR)** sebagai jalur terpisah (task RP-n) (2026-11-20): tanpa perubahan bentuk data;
     metode tetap tidak disimpan dan tidak ada di payload live; `schemaVersion` tetap 2. Aturan: 18.9.
127. **Label pilihan "Grup + Gugur" → "Group - Playoff"** (2026-11-20, host: "gw mau ganti label pilihan "Grup + Gugur"
     menjadi "Group - Playoff""): pilihan format turnamen di Konfigurasi (`.seg` Round-robin / Group - Playoff, 19a).
     Dikonfirmasi host 2026-11-20 ("setuju"): (a) nama format di semua tempat yang menampilkannya ikut (subjudul Detail,
     judul/subjudul Klasemen, label mode di poster/caption, Beranda/dialog C-4 22s–22u); (b) label baris "Fase grup"/
     "Gugur" dan nama babak tidak berubah; (c) ditulis persis "Group - Playoff" (strip biasa berspasi), dicatat di aturan
     pemisah B-22. Nama fitur di dokumen internal (§16, GU-n, nama kelas) tetap "Grup + Gugur". Teks saja, perilaku
     tetap (level 0, ikut 3.9.0, jalur GL).
128. **Frame P4 KS-4 disetujui, 9 rekomendasi** (2026-11-20, host: "setuju"): (1) B-7 nama Mixed panjang dua baris
     (tinggi baris 62), tidak dipotong satu baris (09h, kode); (2) B-8 penonton tanpa internet → "Tidak ada internet" +
     "Coba lagi", bukan memuat terus (12p, kode); (3) B-9 sheet tetap terbuka, toast di atasnya (12q, perilaku app
     dipertahankan); (4) B-18 Detail membulatkan Win %, catatan 09b "1 desimal" dibetulkan (10e); (5) C-3 Batal/Tukar
     di footer sheet Tukar yang menempel, pratinjau tidak ikut digulir (17s/17t, kode); (6) C-4 Beranda/dialog Grup +
     Gugur menulis nama format + nama babak ("Semifinal"), bukan "Fixed"/"Round 7" (22s–22u, kode; nama format ikut
     keputusan 127); (7) C-10 "Pilih klub" (15z2) menggantikan "Tambah" mati, dua varian Sparing (Kelola court
     "mulai R…", Tukar 12 kandidat) ditunda; (8) frame baru sheet WO gugur dengan "Hapus WO" mati + pesan 21l;
     (9) keadaan data baru 3.9.0 (round Fixed lama kosong, SF dikosongkan) tetap sah, `schemaVersion` 2 (`docs/data.md`).
129. **Usulan PM Point % U-RP1–U-RP6 disetujui** (2026-11-20, host: "setuju" atas pertanyaan 18.11): Q1 Point % bulat,
     nomor dibandingkan dari angka bulat (U-RP2); Q2 grup Americano Grup + Gugur lolos dari Point % (U-RP6); Q3 urutan
     tab Total Point · Point % · Win % (U-RP1), "57% poin" di poster/caption (U-RP3), belum main = 0% di urutan Mexicano
     (U-RP4), Point % selalu di statline Detail (U-RP5).

---

## 11. Jawaban User (Dasar Keputusan)

1. Jumlah pemain maks: **16–20 orang**
2. Mode: **Fixed & Mixed sama-sama sering**
3. Skor = **skor pertandingan**; sejak v2 satu angka per tim (Race to / Best of / Americano), bukan per set
4. **Skip = WO** (lawan menang)
5. Device: **1 HP host** (multi-device nanti)
6. Simpan: 1 turnamen aktif + 1 terakhir, lokal
7. Pairing berbasis skill: **tidak sekarang**, dicatat untuk pengembangan
8. Target user: **klub/komunitas**
9. Sparing antar **2 klub**, Fixed maupun Mixed, pasangan sesama klub tidak jadi lawan; semua usulan PM disetujui
   (2026-11-04, §13)
10. Mexicano sebagai mode ketiga, hanya Americano, istirahat ikut prioritas Mixed, partner berulang dihindari per court;
    Sparing dan pemain telat di Mexicano ditunda (2026-11-11, §14)
11. Tukar pemain manual di Mixed: hanya round terakhir dan match yang belum diisi, satu lawan satu, fairness dari
    riwayat, Sparing sesama klub, Mexicano dikunci (2026-11-12, §15)
12. Grup + Gugur untuk Fixed: 2 atau 4 grup, 2 besar lolos ke bagan silang, pasangan dan grup diatur host secara
    default, court dikunci per grup, format skor per babak, perebutan juara 3 default nyala, bagan di Jadwal
    (2026-11-17, §16)
13. Review UX hi-fi P4–P7: Kosongkan skor / Hapus WO dengan batas per mode, perilaku kecil P5, tombol mati Buat bagan,
    semua rekomendasi reviewer; rilis 3.9.0, GU9 + skala teks 3.10.0 (2026-11-18, §17)
14. Peringkat Point % (poin didapat ÷ poin dimainkan) sebagai tab ketiga, default Americano dan urutan Mexicano; Win %
    tidak diganti, Total Point tetap ada sebagai pilihan; ikut 3.9.0 (2026-11-20, §18)

---

## 12. Versioning Aplikasi

Versi app mengikuti **semver `MAJOR.MINOR.PATCH+BUILD`** di `pubspec.yaml`, dan konstanta `appVersion`
(`lib/core/app_version.dart`) harus sama dengan `MAJOR.MINOR.PATCH`-nya (dijaga test). `appVersion` ikut tertulis di
setiap simpanan turnamen.

Setiap perubahan kode/logika/desain **wajib dikategorikan** sebelum dirilis:

| Kategori | Kapan | Contoh |
|----------|-------|--------|
| **MAJOR** (x.0.0) | Perubahan besar logika atau desain; data/perilaku lama tidak lagi kompatibel; `schemaVersion` naik | Redesain v2; format skor per set dihapus; aturan ranking/WO berubah sehingga peringkat lama berbeda |
| **MINOR** (2.x.0) | Fitur atau perilaku baru yang kompatibel dengan data & alur yang ada | Layar/sheet baru, format skor baru yang menambah pilihan, history banyak turnamen, kolom simpanan baru yang opsional |
| **PATCH** (2.0.x) | Perbaikan bug, teks, atau visual kecil tanpa mengubah perilaku yang disepakati | Salah hitung estimasi, typo, spacing/warna yang menyimpang dari hi-fi, crash |

Aturan:
- Satu rilis = kategori tertinggi dari perubahan di dalamnya (ada satu MAJOR → naik MAJOR, MINOR & PATCH kembali 0).
- Versi dinaikkan di commit yang membawa perubahan ke `main` (setiap push ke `main` = deploy web), bersama `appVersion`.
  Branch kerja boleh menumpuk perubahan; kategorinya ditentukan saat digabung.
- `BUILD` (`+N`) naik setiap rilis apa pun (Android `versionCode` / iOS build), tidak pernah turun.
- `schemaVersion` simpanan naik hanya kalau bentuk JSON tidak kompatibel, dan itu selalu MAJOR. Kolom baru yang
  opsional (data lama tetap terbaca) cukup MINOR tanpa menaikkan `schemaVersion`.
- Pesan commit/PR menyebut kategorinya (mis. `[minor]`), dan perubahan MAJOR mencatat keputusan host di PRD.

Rencana rilis (keputusan 120, 2026-11-18):

| Versi | Kategori | Isi | Alasan kategori |
|-------|----------|-----|-----------------|
| **3.9.0** | MINOR | Kosongkan skor / Hapus WO (§17.1–17.9), A-8, A-9, B-10, B-21 (17.10), tombol mati Buat bagan (17.11), P6 visual (C-7, C-18, C-15), P4 frame/catatan; **Point %** metode ketiga + default Americano + urutan Mexicano (§18, keputusan 122–126, task RP-n) | Perilaku baru yang kompatibel; tanpa kolom simpanan baru, `schemaVersion` tetap 2 (17.12, 18.9). Point % mengubah default Americano dan urutan Mexicano, tapi Total Point tetap bisa dipilih dan data lama terbaca apa adanya, sama seperti 3.3.0 mengganti default (MINOR) |
| **3.10.0** | MINOR | GU9 ubah format babak (sheet 19f), A-15 skala teks sampai 1,3 | Perilaku baru; bentuk data dinilai saat fitur ditulis |

---

## 13. Sparing — Dua Klub Bertanding

> **Disetujui host 2026-11-04** (keputusan 19, §10), rilis **3.2.0 (MINOR)**. Bagian lain PRD tidak berubah:
> turnamen biasa (bukan sparing) tetap persis seperti 3.1.0. Keputusan: 13.11 (K1–K13); verifikasi tech lead: 13.12.
> Diselaraskan dengan app 3.8.1 dan catatan hi-fi 13a–13w, 14a–14y, 15a–15y (2026-11-18, UX-5).

Ide host (2026-11-04): *"gw ada ide untuk menambahkan fitur sparing. dimana nanti 2 club akan bertanding. untuk mode
nya tetap bisa fixed maupun mixed partner, yang membedakan adalah pasangan dari club yang sama tidak akan menjadi
lawan."*

### 13.0 Situasi nyata

- Dua klub janjian main di satu tempat (mis. "PB Garuda" tuan rumah, "Matcha Club" tamu). Host dari salah satu klub
  memegang **satu HP**, offline, 1–4 court yang di-booking per jam.
- Jumlah pemain dua klub **jarang sama**: klub tamu biasanya datang lebih sedikit, ada yang telat atau pulang duluan.
- Yang ditunggu semua orang di akhir: **klub mana yang menang**, baru kemudian siapa pemain/pasangan terbaik di klubnya.
- Hasil dibagikan ke grup WhatsApp kedua klub.

Istilah di bagian ini: **klub pertama** = klub yang diisi pertama di layar Pemain, **klub kedua** = yang lain.
`p1`/`p2` = jumlah pasangan (Fixed), `n1`/`n2` = jumlah pemain aktif (Mixed), `C` = jumlah court.

### 13.1 Aturan inti

- **S1.** Setiap pemain milik tepat satu dari dua klub. Pemain tidak bisa pindah klub di tengah turnamen.
- **S2.** Partner selalu sesama klub.
- **S3.** Lawan selalu klub lain: setiap match = satu pasangan klub pertama melawan satu pasangan klub kedua. Dua
  pasangan sesama klub **tidak pernah** bertemu, juga di round tambahan, court tambahan, dan setelah Kelola pemain.
- **S4.** Di setiap match, klub pertama selalu sisi atas (pair1) di Jadwal, Input Skor, WO, dan poster, supaya penonton
  tidak perlu membaca nama untuk tahu sisi klubnya. **Pengecualian: Detail pemain** — riwayat tetap menaruh tim pemain
  itu di baris atas (aturan 10a/10b), dan nama klubnya ditulis di subjudul Detail (K9).
- **S5.** Mode Fixed/Mixed, format skor, durasi, court, WO, status match, Akhiri, dan Live score berlaku seperti turnamen
  biasa kecuali yang ditulis di bagian ini.

### 13.2 Memilih sparing dan mengisi pemain (K4)

- Layar Pemain mendapat pilihan **Mabar / Sparing** di paling atas. Mabar = layar sekarang.
- Sparing: dua blok, masing-masing = nama klub + kotak nama pemain (parser sama dengan 5.2, termasuk buang duplikat di
  dalam satu klub). Kotak nama klub tanpa label, placeholder "Nama klub pertama" / "Nama klub kedua".
- Nama klub wajib, maks 20 karakter (ketikan ke-21 tidak masuk), dipangkas. Lanjut **mati** kalau: nama klub kosong;
  dua nama klub sama (tidak peka huruf besar); satu klub < 2 pemain; total > 30; satu nama pemain ada di kedua klub
  (pesan validasi menyebut namanya — boleh karena mencegah salah langkah, Prinsip "Tanpa Petunjuk").
- Catatan (13d–13g). Abu-abu (host masih mengetik): "Isi nama klub" di bawah kotak nama klub, hanya kalau blok itu
  sudah berisi pemain; "Minimal 2 pemain" dan "Duplikat dibuang: …" di bawah daftar klubnya. Clay (salah isi): "Sama
  dengan klub pertama" di kotak klub kedua; "Maksimal 30 pemain" dan "Andi ada di dua klub" di bawah daftar klub kedua
  (lebih dari tiga nama: "Andi, Budi, Citra +2 ada di dua klub").
- Batas (K6): tiap klub **minimal 2** pemain (satu pasangan), total **4–30** (batas 30 yang sama, `maxPlayers`). Fixed
  dan Mixed sama.
- Konfigurasi tidak berubah kecuali: kartu mode hanya Fixed dan Mixed (tanpa Mexicano, keputusan 27; tanpa Grup +
  Gugur, GU14); pengaturan terakhir Mexicano → mode terisi Mixed (keputusan 38). Nama turnamen tetap opsional dan
  terpisah dari nama klub. Estimasi di tombol: Fixed sparing 13.3 (K10), Mixed sparing 13.4.
- Contoh: PB Garuda = Andi, Budi, Citra, Dewi, Eko, Fajar, Gita, Hadi (8); Matcha Club = Indra, Joko, Kiki, Lina,
  Maya, Nanda (6). Total 14 → Lanjut aktif. Matcha hanya "Indra" → Lanjut mati.

### 13.3 Fixed sparing

**Pasangan**
- Acak: diacak di dalam klub masing-masing. Manual: dua pemain yang diketuk harus sesama klub (mengetuk Andi lalu Indra
  tidak membentuk pasangan).
- Pemain ganjil di satu klub → satu sisa di klub itu, dan "Buat jadwal" menunggu sampai jumlah pemain tiap klub genap
  ("· n pemain tanpa pasangan", catatan "Fixed butuh pemain genap per klub" + Ubah pemain), sama dengan Fixed biasa
  (04c, 14c; K12). Dua sisa dari klub berbeda **tidak** dipasangkan (S2), jadi paling banyak dua sisa.

**Jadwal**
- Tiap pasangan klub pertama bertemu tiap pasangan klub kedua **tepat sekali**. Total match `M = p1 × p2`. Pasangan klub
  pertama main `p2` match, pasangan klub kedua main `p1` match — klub yang pasangannya lebih sedikit main lebih sering
  (K1).
- Court aktif `C' = min(C, p1, p2)` (satu pasangan tidak bisa main di dua court bersamaan, jadi court lebih dari jumlah
  pasangan klub kecil tidak terpakai). Court yang tidak aktif = court bernomor terakhir.
- Jumlah round `R = ⌈M ÷ C'⌉`; semua round berisi `C'` match kecuali round terakhir, dan tidak ada pasangan dua kali
  dalam satu round. (Karena `C' ≤ min(p1, p2)`, `R` tidak pernah kurang dari jumlah match pasangan klub kecil.) Ini
  berbeda dengan invariant 3.3: di sparing round boleh berisi match dari "putaran" berbeda, karena larangan main dua
  kali per round dijaga langsung.
- Setelah setiap round, selisih jumlah main antar pasangan **satu klub** ≤ 1, juga setelah round tambahan (terbukti
  tech lead 2026-11-04, T1 di 13.12).
- Istirahat: bisa beberapa pasangan per round, dari kedua klub (turnamen biasa paling banyak satu). Ditulis dua kolom,
  kiri klub pertama, kanan klub kedua, nama klub di atas kolomnya; klub tanpa yang istirahat → "–" (13k).
- Round dibuka berurutan, dialog kunci pasangan, Fixed tidak bisa dilanjutkan setelah diakhiri — sama dengan 3.2 A.

**Estimasi di tombol Lanjut Konfigurasi (K10)** — jadwal Fixed sparing pasti, jadi tanpa "±":
- Dasar: "Lanjut · R round · M match".
- Court aktif `C'` lebih sedikit dari court yang dipesan → tambah "· C' court".
- `R × durasi` lebih dari booking terpendek di antara court aktif (court yang tidak dapat match tidak membatasi jadwal)
  → "Lanjut · R round · lewat booking hh:mm" (selisihnya, format jam:menit seperti sheet Tambah round 3.3a). Jumlah
  match dan court tidak ditulis karena tidak muat di tombol; keduanya terlihat di Jadwal (K10). Tombol tetap aktif; host
  yang mengakhiri lewat Akhiri.
- Contoh (Padel 15 menit, tiap court 2 jam): 8 / 6 di 2 court → "Lanjut · 6 round · 12 match" (90 menit, muat);
  16 / 14 di 4 court → "Lanjut · 14 round · lewat booking 01:30" (210 − 120 = 90 menit); 8 / 4 di 3 court →
  "Lanjut · 4 round · 8 match · 2 court"; 28 / 2 di 2 court → "Lanjut · 14 round · lewat booking 01:30".

**Contoh 13A** — Padel, Race to 6, 15 menit, 2 court × 2 jam. Pasangan PB Garuda: G1 Andi · Budi, G2 Citra · Dewi,
G3 Eko · Fajar, G4 Gita · Hadi. Matcha Club: M1 Indra · Joko, M2 Kiki · Lina, M3 Maya · Nanda.
`M = 4 × 3 = 12`, `C' = 2`, `R = ⌈12 ÷ 2⌉ = 6` (90 menit, sisa booking 30 menit). Garuda 3 match per pasangan, Matcha
4. Jadwal = hasil generator (tech lead 2026-11-04):

| Round | Court 1 | Court 2 | Istirahat |
|-------|---------|---------|-----------|
| R1 | G1 vs M1 | G2 vs M2 | G3, G4, M3 |
| R2 | G3 vs M3 | G4 vs M1 | G1, G2, M2 |
| R3 | G1 vs M2 | G2 vs M3 | G3, G4, M1 |
| R4 | G3 vs M1 | G4 vs M2 | G1, G2, M3 |
| R5 | G1 vs M3 | G2 vs M1 | G3, G4, M2 |
| R6 | G3 vs M2 | G4 vs M3 | G1, G2, M1 |

Jumlah main setelah tiap round — Garuda (G1–G4): 1·1·0·0 → 1·1·1·1 → 2·2·1·1 → 2·2·2·2 → 3·3·2·2 → 3·3·3·3; Matcha
(M1–M3): 1·1·0 → 2·1·1 → 2·2·2 → 3·3·2 → 4·3·3 → 4·4·4.

Ukuran lain (estimasi di Konfigurasi = kolom Match, Round, Court aktif):

| Pemain klub 1 / 2 | Pasangan | Court | Court aktif | Match | Round | Match per pasangan |
|-------------------|----------|-------|-------------|-------|-------|--------------------|
| 8 / 6 | 4 / 3 | 2 | 2 | 12 | 6 | 3 / 4 |
| 6 / 6 | 3 / 3 | 2 | 2 | 9 | 5 | 3 / 3 |
| 8 / 4 | 4 / 2 | 3 | 2 | 8 | 4 | 2 / 4 |
| 4 / 4 | 2 / 2 | 1 | 1 | 4 | 4 | 2 / 2 |
| 16 / 14 | 8 / 7 | 4 | 4 | 56 | 14 | 7 / 8 |
| 28 / 2 | 14 / 1 | 2 | 1 | 14 | 14 | 1 / 14 (pasangan klub 2 main 14 round beruntun — konsekuensi K1 yang diterima host) |

8 / 4 di 3 court: R1 G1–M1, G2–M2 · R2 G3–M1, G4–M2 · R3 G1–M2, G2–M1 · R4 G3–M2, G4–M1; Court 3 kosong.

### 13.4 Mixed sparing

- Tiap match = 2 pemain klub pertama (berpasangan) vs 2 pemain klub kedua (berpasangan).
- Court aktif per round = `min(court yang muat satu match, ⌊n1 ÷ 2⌋, ⌊n2 ÷ 2⌋)`. Waktu habis (tidak ada court yang
  muat) → dihitung dari semua court, seperti 3.4. Slot per klub = 2 × court aktif.
- Siapa yang main = `priorityOrder` (3.4) **per klub**, dengan slot klub itu: jumlah main → paling lama istirahat →
  undian terkunci per round → id. Jeda pemain telat juga per klub: `k = max(2, slot klub ÷ istirahat klub + 1)`.
- Susunan pasangan: partner dari sesama klub yang terpilih, lawan dari klub lain; penalti tetap (ulang match persis
  1000, ulang partner 10, ulang lawan 3, terbaik dari 400 percobaan).
- **Fairness per klub:** selisih jumlah main antar pemain **satu klub** yang hadir sejak awal ≤ 1 setiap saat. Antar klub
  boleh berbeda, mengikuti slot ÷ pemain klub (K1). Tukar pemain sesama klub (§15) bisa membuatnya 2 sementara.
- Daftar Istirahat di round terakhir ("Istirahat · Prioritas main di R(n+1)" / "Istirahat lagi di R(n+1)") dipisah per
  klub (dua kolom seperti 13.3, kolom klub yang semua kebagian slot berisi "–") dan tetap sama persis dengan hasil Buat
  R(n+1). Penonton Live turnamen yang diakhiri: judul "Istirahat" saja, tanpa prioritas (12l, B-20); HP host tetap
  menulisnya.
- Estimasi di tombol Konfigurasi: "Mulai Round 1 · ±R round", R = booking terpendek ÷ durasi; court aktif lebih
  sedikit dari court yang dipesan → tambah "· C' court" (13i, 13j). Label Estimasi di sheet Cara kerja Mixed (15k):
  Max Round = R; Match/Pemain ditulis per klub ("Match/Pemain · PB Garuda", = Total Match × 2 ÷ pemain klub,
  dibulatkan ke bawah, dengan "±"); Court Aktif = rumus di atas; Total Match = round × court aktif. Aturan Fairness
  ketiga: "Selisih match antar pemain satu klub ≤ 1".

**Contoh 13B** — pemain 13.2 (Garuda 8, Matcha 6), Padel 15 menit, 2 court × 2 jam → ±8 round, court aktif
`min(2, 4, 3) = 2`, slot 4 Garuda + 4 Matcha per round, 2 match per round. Tombol "Mulai Round 1 · ±8 round"; Cara kerja:
Max Round 8, Match/Pemain ±4 (PB Garuda) dan ±5 (Matcha Club), Court Aktif 2, Total Match 16. Matcha 3 pemain (8 / 3)
→ "Mulai Round 1 · ±8 round · 1 court".
- Tiap round: 4 Garuda istirahat, 2 Matcha istirahat. Garuda bergantian penuh tiap 2 round (k = max(2, 4 ÷ 4 + 1) = 2);
  Matcha: 4 dari 6 main, semua +2 tiap 3 round (k = max(2, 4 ÷ 2 + 1) = 3).
- Setelah R6 (12 match): tiap Garuda 3 match, tiap Matcha 4 match.
- Setelah R8 (16 match, booking habis): tiap Garuda 4; Matcha dua pemain 6, empat pemain 5 (selisih 1).

Ukuran lain, 8 round:

| Pemain klub 1 / 2 | Court | Court aktif | Match | Match per pemain klub 1 / 2 |
|-------------------|-------|-------------|-------|-----------------------------|
| 8 / 6 | 2 | 2 | 16 | 4 / 5–6 |
| 7 / 6 | 2 | 2 | 16 | 4–5 / 5–6 |
| 8 / 3 | 2 | 1 | 8 | 2 / 5–6 (Court 2 tidak dipakai) |
| 15 / 15 | 4 | 4 | 32 | 4–5 / 4–5 |
| 2 / 2 | 1 | 1 | 8 | 8 / 8 (tanpa istirahat) |

### 13.5 Skor klub (K2)

- Setiap match selesai = satu hasil untuk klub: menang 1, seri ½ (sama dengan Win %), kalah 0. WO: klub lawan dari
  pasangan WO menang 1. Match Belum / Tidak dimainkan tidak dihitung.
- Di samping skor match: **Total Point klub** = jumlah game/poin sisi klub di setiap match + nilai WO (4.4), dan selisih
  klub (tanpa WO, seperti `gameDiff`). Satu match dihitung sekali per sisi, bukan per pemain (13C: 56, bukan 112). Adil
  antar klub karena kedua klub ada di setiap match.
- **Nilai WO klub (K11):** per match WO, nilai yang masuk Total Point klub pemenang = rata-rata nilai WO kedua pemain
  pemenang (4.4), dibulatkan ,5 ke atas. Contoh Mixed Americano 21: nilai WO Andi 14, Budi 17 → klub dapat
  (14 + 17) ÷ 2 = 15,5 → **16**. Di klasemen pemain tiap pemenang tetap mendapat nilainya sendiri (Andi 14, Budi 17).
  Fixed dan Race to N tidak terpengaruh karena nilai kedua pemenang selalu sama (13C: 6).
- Urutan: match menang → Total Point klub → sama semua = seri. Hanya angka yang tampil yang menentukan (sejalan 4.3).
- Status Sementara/Final sama dengan 4.6. Skor klub tampil di Jadwal dan Klasemen (papan di atas daftar/tabel, klub
  pertama di baris atas, bola di klub yang unggul, kedua baris kalau Seri, tanpa bola selama 0 – 0), poster, caption,
  Beranda, dan halaman Live (tanpa kalimat penjelas). Di kanan nama klub: Total Point klub · selisih ("56 game · +13").
  Setengah ditulis "½" ("6½ – 5½"), bukan 6,5. Skor klub selalu dari semua match yang sudah terisi, bukan round yang
  dibuka (14h).

**Contoh 13C** — hasil jadwal 13A (Race to 6):

| Round | Court 1 | Court 2 |
|-------|---------|---------|
| R1 | G1 6–3 M1 | G2 4–6 M2 |
| R2 | G3 6–5 M3 | G4 6–4 M1 |
| R3 | G1 6–4 M2 | G2 WO (Citra · Dewi absen) → M3 menang |
| R4 | G3 6–2 M1 | G4 3–6 M2 |
| R5 | G1 2–6 M3 | G2 6–1 M1 |
| R6 | G3 6–0 M2 | G4 5–6 M3 |

- Skor klub: **PB Garuda 7 – 5 Matcha Club** (Matcha: 4 menang + 1 WO). 12 dari 12 match → Final.
- Total Point klub: Garuda 56, Matcha 49 (43 game + 6 nilai WO Race to 6). Selisih Garuda +13, Matcha −13.
- Seri: Americano 20, satu match 10–10 dan sisanya 6 menang Garuda, 5 menang Matcha → "6½ – 5½".
- Skor match sama, mis. 6–6 dengan Total Point 50–48 → klub pertama di atas; 6–6 dan Total Point sama → Seri.

### 13.6 Klasemen pemain/pasangan (K3)

- Nilai, tie-breaker, WO, dan nomor sama dengan 4.2–4.4, tapi dikelompokkan **per klub**, masing-masing bernomor mulai
  #1. Alasannya: jumlah match antar klub berbeda (13.3/13.4), jadi Total Point satu tabel gabungan menguntungkan klub
  kecil; di dalam satu klub jumlah main sama (selisih ≤ 1).
- Data 13C, Total Point:
  - PB Garuda: #1 Eko · Fajar 18 (+11) · #2 Andi · Budi 14 (+1) · #3 Gita · Hadi 14 (−2) · #4 Citra · Dewi 10 (+3).
  - Matcha Club: #1 Maya · Nanda 23 (+4, 3 menang termasuk 1 WO) · #2 Kiki · Lina 16 (−3) · #3 Indra · Joko 10 (−14).
  - Kalau digabung, Maya · Nanda (23 dari 4 match) di atas Eko · Fajar (18 dari 3 match, menang semua) — contoh bias.
- Data 13C, Win %: Garuda #1 Eko · Fajar 100% · #2 Andi · Budi 67% · #3 Citra · Dewi 33% (+3) · #4 Gita · Hadi 33% (−2);
  Matcha #1 Maya · Nanda 75% · #2 Kiki · Lina 50% · #3 Indra · Joko 0%.
- Data 13C, Point % (sejak 3.9.0, §18; didapat ÷ dimainkan, WO R3 = 6–0 untuk Maya · Nanda): Garuda #1 Eko · Fajar 72%
  (18 ÷ 25, +11) · #2 Andi · Budi 52% (14 ÷ 27, +1) · #3 Gita · Hadi 47% (14 ÷ 30, −2) · #4 Citra · Dewi 43% (10 ÷ 23:
  kalah 7 game + 6 dari WO, +3); Matcha #1 Maya · Nanda 64% (23 ÷ 36, +4) · #2 Kiki · Lina 46% (16 ÷ 35, −3) · #3 Indra ·
  Joko 29% (10 ÷ 34, −14). Gita · Hadi di atas Citra · Dewi, kebalikan Win % (keduanya 33%, selisih memisahkan).
- Default per klub mengikuti format (4.2): Race to/Best of → Win %, Americano → Point %. Skor klub (13.5, K2) tidak
  berubah: tetap match menang → Total Point klub, karena kedua klub ada di setiap match.
- Klasemen, Detail, Bagikan, caption, dan Live memakai nomor yang sama (seperti `standingEntriesProvider` sekarang).

### 13.7 Interaksi dengan fitur yang ada

| Fitur | Perilaku di sparing |
|-------|-------------------------------|
| Kelola pemain (Mixed) | Daftar per klub, label "PB Garuda · 8 aktif" (· n keluar kalau ada). Tambah pemain wajib memilih klub: dua chip nama klub di bawah kotak nama, tanpa pilihan awal; Tambah mati sampai nama terisi dan satu klub dipilih. Nama dicek terhadap kedua klub ("Andi sudah ada di PB Garuda"). Keluarkan mati kalau klub itu tinggal 2 pemain aktif, alasannya di bawah daftar klub itu: "Butuh minimal 2 pemain per klub". Kembalikan = ke klubnya sendiri. Contoh: Nanda keluar setelah R3 → Matcha 5 aktif, court aktif tetap 2, 4 dari 5 Matcha main per round. |
| Pemain telat (Mixed) | Aturan 3.4 per klub. Contoh: Oki masuk Matcha setelah R3 → Matcha 7, slot 4, istirahat 3 → k = 2: Oki main R4 dan R5, istirahat R6 kalau masih di bawah yang paling banyak main. Garuda tidak terpengaruh. |
| Kelola court (Mixed) | Court baru langsung dipakai di round berjalan kalau **tiap klub** punya ≥ 2 pemain istirahat: 2 teratas prioritas tiap klub, ditulis "Langsung main di Rn" dengan kolom klub seperti Istirahat. Satu klub kurang dari 2 yang istirahat → court dipakai mulai R(n+1) ("· mulai R(n+1)", 15o). Contoh 13B saat R4 berjalan: tambah Court 3 → match baru 2 Garuda + 2 Matcha yang istirahat; R5 court aktif `min(3, 4, 3) = 3`, semua 6 Matcha main. |
| Batalkan Rn, Lanjutkan turnamen, Akhiri | Tidak berubah; court aktif dihitung ulang dengan rumus 13.4. |
| Round tambahan (Fixed, 3.3a) | Satuan = paling sedikit match yang memberi tambahan sama ke semua pasangan satu klub: `L = KPK(p1, p2)` match; klub 1 +L÷p1, klub 2 +L÷p2 per pasangan. Jumlah satuan dibulatkan ke atas dan boleh lewat booking (prinsip keputusan 18). Lawan melanjutkan urutan jadwal awal. Contoh 13A setelah R6, sisa 30 menit = 2 round: satuan 12 match = 6 round (R7–R12), "lewat booking 01:00", Garuda +3, Matcha +4. 8 / 4 pemain (4 / 2 pasangan): satuan 4 match, Garuda +1, Matcha +2. 6 / 6: satuan 3 match, +1. (K5) |
| Atur pasangan (Fixed) | Pasangan baru harus sesama klub; pemain pengganti diketik ke salah satu klub (satu bagian per klub). Jumlah pasangan klub boleh berubah; satuan round tambahan dihitung dari jumlah baru. Satu klub tanpa pasangan → tombol mati "· minimal 1 pasangan tiap klub" (14o). |
| Bagikan (K7) | Ringkas = podium skor klub: dua blok, angka di muka blok = skor klub, klub pertama blok kiri, klub yang unggul emas setinggi #1; tanpa daftar pemain (keputusan 62, 13q). Lengkap = podium mini skor klub + semua pasangan/pemain per klub, nomor mulai 1 tiap klub; kepala klub = nama + "56 game · +13" tanpa angka skor (keputusan 83, 13s–13w). Caption dibuka "🏆 PB Garuda 7–5 Matcha Club · Padel" (nama turnamen, kalau ada, di baris berikutnya); seri setengah "🏆 PB Garuda 6½–5½ Matcha Club · Padel"; menang dan Total Point sama "🏆 PB Garuda 6–6 Matcha Club · Seri · Padel". |
| Live score | Penonton melihat skor klub dan klasemen per klub, angka sama dengan HP host. Turnamen yang diakhiri: Istirahat tanpa "Prioritas main di R…" (13.4). |
| Beranda | Turnamen sparing tanpa nama: baris kecil "PB Garuda 6 – 4 Matcha Club" (skor klub menggantikan "vs", sebelum ada hasil "0 – 0") menggantikan "olahraga · mode · n pemain" (14x). Bernama: nama tetap di baris kecil, skor klub dua baris rata kanan di samping "Round n" (15w). Turnamen terakhir Mixed sparing tanpa nama: judul baris sama dengan baris kecil 14x; bernama: nama saja (15x). Dialog mulai turnamen baru menyebut "PB Garuda vs Matcha Club, Round 6" tanpa skor (14y). |
| Detail pemain (K9) | Riwayat tetap menaruh tim pemain itu di baris atas (10a/10b, pengecualian S4). Subjudul: peringkat di klubnya · nama klub · olahraga · mode · format skor, tanpa metode (beda dengan Detail biasa, B-6). "Beda partner" dihitung dari pemain klub sendiri, "Beda lawan" dari pemain klub lain (14v: 6 / 6 lawan Matcha Club). Contoh: Detail Maya · Nanda (Matcha Club, klub kedua, Final 13C) — subjudul "Peringkat 1 · Matcha Club · Padel · Fixed · Race to 6"; di riwayat R2 baris atas "Maya · Nanda", lawan "Eko · Fajar" di bawahnya. |

### 13.8 Data & versi

- Kunci simpanan baru yang **opsional**: daftar dua klub (id + nama) di config, dan klub tiap pemain. Simpanan tanpa
  kunci itu = turnamen biasa, jadi simpanan 3.1.0 tetap terbaca apa adanya. `schemaVersion` tetap 2.
- Kategori: **MINOR → 3.2.0** (fitur baru, data lama kompatibel, turnamen biasa tidak berubah). Jadi MAJOR hanya kalau
  host memutuskan sesuatu yang mengubah turnamen biasa.
- Relay live tidak perlu diubah (menyimpan JSON codec apa adanya).

### 13.9 Kriteria penerimaan

- **AC-S1** Pemain: Sparing, Garuda 8 + Matcha 6 → Lanjut aktif. Matcha 1 pemain → mati. 16 + 14 = 30 → aktif; 16 + 15
  → mati.
- **AC-S2** Nama klub kosong, atau "PB Garuda" dan "pb garuda" → Lanjut mati. "Andi" di dua klub → mati + pesan yang
  menyebut Andi.
- **AC-S3** Fixed Acak: tiap pasangan berisi dua pemain satu klub. Garuda 9 → 4 pasangan + 1 sisa; Matcha 6 → 3
  pasangan, tanpa sisa; dua sisa beda klub tidak pernah dipasangkan. Selama ada sisa, "Buat jadwal" mati dengan
  "· 1 pemain tanpa pasangan" (Garuda 9 / Matcha 7 → "· 2 pemain tanpa pasangan").
- **AC-S4** Fixed Manual: mengetuk Andi lalu Indra tidak membentuk pasangan.
- **AC-S5** Fixed 4 / 3 pasangan, 2 court: 12 match, 6 round; tiap pasangan Garuda tepat 3 match, Matcha tepat 4; tiap
  pasangan Garuda bertemu tiap pasangan Matcha tepat sekali; nol match sesama klub; tidak ada pasangan dua kali dalam
  satu round; semua round berisi 2 match; selisih main antar pasangan satu klub ≤ 1 setelah setiap round.
- **AC-S6** Fixed 4 / 2 pasangan, 3 court: 8 match, 4 round, Court 3 tidak pernah dapat match. 2 / 2 pasangan, 1 court:
  4 match, 4 round. 14 / 1 pasangan, 2 court: 14 match, 14 round, Court 2 kosong.
- **AC-S7** Jadwal, Input Skor, WO, dan poster: pasangan klub pertama selalu sisi atas match. Detail Maya (klub kedua):
  riwayat R2 menaruh "Maya · Nanda" di atas "Eko · Fajar", dan subjudul Detail (Final 13C) = "Peringkat 1 · Matcha
  Club · Padel · Fixed · Race to 6", tanpa metode.
- **AC-S7a** Estimasi tombol Lanjut Fixed sparing (Padel 15 menit, court 2 jam): 8 / 6 di 2 court → "Lanjut · 6 round ·
  12 match"; 16 / 14 di 4 court → "Lanjut · 14 round · lewat booking 01:30"; 8 / 4 di 3 court → "Lanjut · 4 round · 8
  match · 2 court"; tidak ada "±" di Fixed sparing.
- **AC-S8** Mixed 8 / 6, 2 court: tiap round 2 match, tiap match 2 Garuda vs 2 Matcha, partner sesama klub. Setelah R6
  tiap Garuda 3 match, tiap Matcha 4. Setelah R8 tiap Garuda 4, Matcha dua pemain 6 dan empat 5.
- **AC-S9** Mixed, test properti 30 round untuk 8/6, 7/6, 8/3, 15/15, 2/2: selisih main antar pemain satu klub yang
  hadir sejak awal ≤ 1 setelah setiap round; nol match sesama klub.
- **AC-S10** Mixed 8 / 3, 2 court: court aktif 1, Court 2 tidak dapat match dan tidak tampil di Jadwal; tombol
  Konfigurasi "Mulai Round 1 · ±8 round · 1 court", Cara kerja Mixed menulis Court Aktif 1.
- **AC-S11** Mixed: daftar "Prioritas main di R(n+1)" per klub sama persis dengan hasil Buat R(n+1).
- **AC-S12** Kelola pemain: menambah pemain tanpa klub tidak bisa; Keluarkan mati untuk pemain di klub yang tinggal 2
  aktif; pemain yang dikembalikan masuk klubnya sendiri.
- **AC-S13** Kelola court (contoh 13B, R4 berjalan): Court 3 baru langsung berisi 2 Garuda + 2 Matcha teratas prioritas
  yang istirahat; R5 berisi 3 match dan semua 6 Matcha main.
- **AC-S14** Skor klub data 13C: 7 – 5, Total Point 56 – 49, selisih +13 / −13, status Final setelah 12 dari 12 match.
  Sebelum R6 diisi: Sementara, 6 – 4.
- **AC-S15** WO R3 (Citra · Dewi): Matcha +1 menang, Maya · Nanda +6 Total Point, selisih kedua klub tidak berubah.
- **AC-S15a** Mixed Americano 21, WO dengan pemenang Andi (nilai WO 14) dan Budi (17): Total Point klub +16; klasemen
  pemain Andi +14, Budi +17; selisih klub dan pemain tidak berubah.
- **AC-S16** Seri Americano 20 (10–10) memberi ½ ke tiap klub: "6½ – 5½".
- **AC-S17** Klasemen per klub data 13C sama persis dengan 13.6 (Total Point dan Win %; sejak 3.9.0 juga Point %); Detail, Bagikan, caption, dan
  Live memakai nomor yang sama.
- **AC-S18** Round tambahan 13A setelah R6: satuan 12 match (R7–R12), sheet "lewat booking 01:00", Garuda +3, Matcha +4;
  nol match sesama klub. 4 / 2 pasangan: satuan 4 match.
- **AC-S19** Simpanan 3.1.0 (tanpa klub) dimuat sebagai turnamen biasa tanpa skor klub; semua test dan golden turnamen
  biasa lulus tanpa diubah.
- **AC-S20** App di-kill saat R3 sparing → dibuka lagi: klub, anggota, jadwal, dan skor klub sama; Live melanjutkan
  kode yang sama.
- **AC-S21** Semua kriteria di atas jalan offline (kecuali Live).

### 13.10 Belum sekarang

- Lebih dari 2 klub (liga/segitiga).
- Pemain tamu tanpa klub, atau partner lintas klub.
- Format "partai" (mis. best of 5 partai, klub menang begitu unggul 3), urutan partai yang diatur manual.
- Tempel satu daftar WhatsApp berisi dua klub (judul klub sebagai pemisah) — sekarang dua kotak terpisah.
- Warna/logo klub, handicap, pairing berbasis skill (11.7).
- Menyamakan jumlah main antar klub (secara matematis tidak mungkin kalau jumlah pemain beda, lihat K1).

### 13.11 Keputusan host (2026-11-04, "setuju semua")

- **K1.** Jumlah pemain dua klub boleh beda; klub yang lebih sedikit main lebih sering (Fixed 4 vs 3 pasangan: pasangan
  Garuda 3 match, pasangan Matcha 4), karena setiap match butuh satu pasangan dari tiap klub. Di Fixed tiap pasangan
  bertemu tiap pasangan klub lain tepat sekali. Ukuran timpang (28 vs 2: satu pasangan main 14 round beruntun) adalah
  konsekuensi yang diterima, bukan masalah terbuka.
- **K2.** Klub menang = jumlah match yang dimenangkan (seri ½, WO = menang untuk klub lawan); kalau sama, Total Point
  klub; masih sama = Seri.
- **K3.** Klasemen pemain/pasangan dipisah per klub, masing-masing mulai #1, karena satu tabel gabungan dengan Total
  Point menguntungkan klub kecil.
- **K4.** Sparing dipilih di layar Pemain (dua blok: nama klub + kotak nama pemain), bukan di Beranda atau Konfigurasi.
- **K5.** Round tambahan Fixed sparing per satuan `KPK(p1, p2)` match yang menyamakan tambahan main di dalam klub, walau
  satuannya bisa besar (12 match = 1,5 jam untuk 4 vs 3 pasangan); dibulatkan ke atas, host mengakhiri lewat Akhiri.
- **K6.** Minimal 2 pemain per klub, total tetap 4–30.
- **K7.** Poster dan caption dibuka dengan skor klub.
- **K8.** Aturan pendukung: dua klub saja; pemain tidak bisa pindah klub; klub pertama selalu sisi atas match (kecuali
  Detail, K9); nama klub
  wajib, maks 20 karakter, dua nama klub tidak boleh sama; nama pemain yang ada di dua klub memblokir Lanjut; Mode
  Fixed/Mixed tetap dipilih di Konfigurasi; nama turnamen terpisah dari nama klub; court yang tidak aktif = court
  bernomor terakhir.

Jawaban host berikutnya (2026-11-04):

- **K9.** Detail pemain: tim pemain itu tetap di baris atas riwayat (aturan 10a/10b), nama klub ditulis di subjudul
  Detail. Pengecualian S4 khusus untuk Detail.
- **K10.** Estimasi tombol Lanjut Fixed sparing tanpa "±" karena jadwalnya pasti: "Lanjut · R round · M match", ditambah
  "· n court" kalau court aktif lebih sedikit dari yang dipesan. Kalau jadwal lebih panjang dari booking terpendek di
  antara court aktif: "Lanjut · R round · lewat booking hh:mm", tanpa jumlah match dan court karena teks penuhnya tidak
  muat di tombol (jawaban host 2026-11-04 atas temuan designer di 14f). Contoh 16 / 14 di 4 court × 2 jam: "Lanjut · 14
  round · lewat booking 01:30".
- **K11.** Nilai WO untuk skor klub di Mixed Best of/Americano = rata-rata nilai WO kedua pemenang, dibulatkan ,5 ke
  atas (Andi 14, Budi 17 → 16); di klasemen pemain tiap pemenang tetap mendapat nilainya sendiri.
- **K12.** Pemain ganjil di satu klub Fixed sparing: "Buat jadwal" menunggu sampai jumlah pemain tiap klub genap, sama
  dengan Fixed biasa 04c (host 2026-11-04, 14c). Draft awal menulis sisa jadi "Belum main" dan jadwal tetap dibuat;
  itu dibatalkan.
- **K13.** App versi lama (≤ 3.1.0, masih ter-cache di PWA) tidak boleh membaca turnamen sparing sebagai turnamen biasa: simpanan dan payload live sparing membawa penanda yang membuat versi lama menolaknya, jadi penonton melihat "Live tidak bisa dibuka" sampai web-nya ter-update, dan HP host versi lama tidak menimpa turnamen sparing (host 2026-11-08; rincian `docs/data.md`).

### 13.12 Verifikasi tech lead (selesai 2026-11-04)

- **T1 — selesai.** "Selisih main antar pasangan satu klub ≤ 1 setelah setiap round" di Fixed sparing terbukti lewat
  algoritma + test properti untuk 2250 ukuran (1–15 pasangan per klub × 1–10 court) dan 8 kali tambah round berantai,
  jadi sekarang aturan (13.3, AC-S5). `R = ⌈M ÷ C'⌉`, semua round berisi `C'` match kecuali round terakhir.
- **T2 — selesai.** Angka 13A–13C dicek dengan generator dan kalkulator. Jadwal 13A dan tabel round 13C diganti dengan
  hasil generator (WO pindah ke R3); skor klub, Total Point, selisih, klasemen 13.6, 13B, tabel ukuran, 8 / 4 di 3
  court, dan contoh round tambahan tetap sama. Designer dan data test memakai angka di bagian ini.

---

## 14. Mexicano — Pasangan dari Klasemen

> **Diputuskan host 2026-11-11** (keputusan 23–27, §10), dirilis **3.4.0 (MINOR)** 2026-11-12. Aturan rinci di bagian ini
> yang tidak tertulis di keputusan itu adalah **usulan PM** (14.11), semuanya disetujui host (U3, U4, U7, U8 = keputusan 44–47).
> Hi-fi 03a–03q, 16a–16g (keputusan 28–43). Fixed, Mixed, dan Sparing tidak berubah.

Mexicano adalah **cara memasangkan pemain**, bukan format skor. Round 1 diundi; round berikutnya pemain diurutkan
menurut klasemen saat itu dan dikelompokkan berempat per court menurut peringkat yang berdekatan, jadi pemain kuat
bertemu pemain kuat. Tidak ada rulebook resmi; dasar aturan ini praktik umum klub/vendor padel (riset main session
2026-11-11): urutan per court 1+3 lawan 2+4, kalau partnernya berulang 1+4 lawan 2+3, lalu 1+2 lawan 3+4; skor poin
ala Americano; pemenang = total poin terbanyak.

### 14.0 Situasi nyata

- Klub padel/tennis main sore/malam, 8–16 orang di 2–4 court yang di-booking per jam. Host memegang **satu HP**,
  offline, sambil ikut main.
- Kemampuan pemain beragam. Di Mixed pasangan acak, jadi pemain kuat sering "menggendong" pemain baru dan match berat
  sebelah. Mexicano membuat match makin seimbang tiap round tanpa host menilai kemampuan siapa pun.
- Round berikutnya baru bisa dibuat setelah **semua** skor round sebelumnya masuk (pasangannya tergantung skor itu).
  Americano N berakhir di jumlah poin tetap, jadi court selesai hampir bersamaan; host mengisi skor di sela main.
- Yang ditunggu di akhir: siapa total poin terbanyak. Hasil dibagikan ke grup WhatsApp.

Istilah di bagian ini: **urutan Mexicano** = urutan pemain untuk memasangkan (14.3); **posisi 1–4** = urutan empat
pemain di satu court menurut urutan Mexicano; **pernah berpasangan** = satu tim di match mana pun di round yang sudah
dibuat (termasuk match WO).

### 14.1 Aturan inti

- **M1.** Mexicano = mode ketiga di Konfigurasi, sejajar Fixed dan Mixed, untuk tennis dan padel (keputusan 23).
- **M2.** Format skor hanya **Americano N** (N 2–99, default 21; aturan 4.1 termasuk berhenti lebih awal dan seri di N
  genap). Race to dan Best of tidak bisa dipilih selama mode Mexicano (keputusan 24).
- **M3.** Seperti Mixed, tidak ada target match: R1 dibuat saat Konfigurasi selesai, host menekan **Buat R(n+1)**.
  Buat R(n+1) aktif kalau round terakhir lengkap (selesai/WO) dan masih ada court yang waktunya cukup (3.4).
- **M4.** Siapa main dan siapa istirahat = aturan prioritas main Mixed (3.4) apa adanya; yang main lalu dipasangkan
  menurut urutan Mexicano (keputusan 25). Akibatnya selisih jumlah main antar pemain ≤ 1 setiap saat, sama dengan Mixed.
- **M5.** Partner berulang dihindari selama masih ada susunan lain **di court itu**; pemain tidak dipindah ke court lain
  untuk menghindarinya (keputusan 26).
- **M6.** Sparing tidak menawarkan Mexicano, dan pemain tidak bisa ditambah di tengah turnamen Mexicano (keputusan 27,
  14.7).
- **M7.** Wording UI ikut `CLAUDE.md`: "Mexicano" nama format, ditulis apa adanya seperti court/round/match; semua
  orang "pemain"; tanpa kalimat penjelas di layar (Prinsip "Tanpa Petunjuk", 7).

### 14.2 Konfigurasi & alur

- Layar Pemain tidak berubah (4–30 pemain). Kalau di layar Pemain dipilih Sparing, Konfigurasi hanya menawarkan Fixed
  dan Mixed.
- Konfigurasi: Mode **Fixed / Mixed / Mexicano**. Memilih Mexicano saat format Race to atau Best of → format menjadi
  **Americano 21**; kalau sudah Americano, N-nya tetap (mis. Americano 24 tetap 24). Kembali ke Fixed/Mixed tidak
  mengubah format (keputusan 34). Saat Mexicano, pilihan Race to/Best of tidak ditampilkan dan formatnya tertulis
  "Americano".
- Estimasi di tombol sama dengan Mixed (Max Round · Match/Pemain · Court Aktif · Total Match).
- Mexicano → langsung Jadwal + R1 (tanpa layar Pasangan), seperti Mixed. Jadwal Mexicano memakai kontrol Jadwal Mixed:
  Buat R(n+1) / Batalkan Rn / Pemain (n) / Tambah jam / Lanjutkan turnamen, daftar "Istirahat · Prioritas main di
  R(n+1)" dan "Istirahat lagi di R(n+1)", menu ⋯ (Live score, Kelola court, Cara kerja Mexicano, Akhiri turnamen).
  Sheet "Cara kerja Mexicano" (hi-fi 16c) menggantikan "Cara kerja Mixed": muncul sekali saat R1 dibuat, setelah itu
  lewat menu ⋯; teksnya keputusan 40 dan 43.

### 14.3 Urutan Mexicano (dasar memasangkan)

Pemain diurutkan (sejak 3.9.0, keputusan 124; sebelumnya langkah 1 = Total Point):

1. **Point %** turun, angka bulat seperti di Klasemen (4.2, 4.3; WO seperti skor nilai WO – 0, 4.4).
2. **Selisih** turun (4.3; WO tidak mengubah selisih).
3. Masih sama → **undian terkunci per round** (`lockedDraw(drawSeed + nomor round)`, undian yang sama dengan prioritas
   main 3.4), lalu id.

- Selalu Point %, **apa pun tab** yang dipilih host di Klasemen; memilih Total Point atau Win % tidak mengubah pasangan
  (U1, keputusan 124).
- Dihitung dari match Selesai/WO di round yang sudah dibuat. Pemain yang belum main dihitung 0 poin, Point % 0, selisih
  0, dan diurutkan dengan angka itu seperti pemain lain (di Klasemen mereka tetap di grup "Belum main"; U8 tetap, usulan
  U-RP4 §18.8).
- Pemain yang baru istirahat tidak lagi tertinggal satu match: Point %-nya tetap (contoh 18D).
- Contoh 14A–14C di bawah ditulis dengan Total Point. Hasil Buat round-nya **sama** dengan Point %: di 14A dan 14C semua
  pemain main sama banyak dan tiap match total 21, jadi urutan Point % = urutan Total Point; di R2 14B yang main dan
  urutannya juga sama (Indra, Joko 0%). Beda baru muncul setelah ada yang istirahat dan main lagi (18D).
- Langkah 1–2 = angka yang menentukan nomor Klasemen, jadi pemain dengan nomor lebih kecil selalu lebih dulu. Hanya
  pemain bernomor sama yang urutannya ditentukan undian, bukan nama (U2): nama membuat pemain berawalan "A" selalu di
  posisi 1 dan mendapat partner posisi 3, bukan 4.
- R1: semua pemain 0 / 0, jadi urutan R1 = undian R1. Tidak ada aturan khusus untuk R1.
- Undian terkunci membuat hasil Buat R(n+1) pasti: membuka ulang app, Batalkan lalu Buat lagi, atau HP lain dengan
  simpanan yang sama memberi round yang sama.

### 14.4 Siapa main & pengisian court

```
function generateMexicanoRound(activePlayers, history, courts, round):
    courtsUsed = court yang muat satu match (3.4), urut nomor court
    slots      = (min(activePlayers, courtsUsed × 4) ÷ 4, bulat ke bawah) × 4      // sama dengan Mixed
    order      = priorityOrder(...)                         // 3.4 apa adanya; tidak ada pemain telat di Mexicano
    playing    = order.take(slots); resting = order.skip(slots)
    ranked     = playing.sortBy(urutan Mexicano 14.3)
    for i in 0 .. slots÷4 − 1:
        court  = courtsUsed[i]                              // court bernomor terkecil dapat kelompok teratas
        [p1, p2, p3, p4] = ranked[4i .. 4i+3]
        match  = susunan 14.5 dari p1..p4
```

- Pemain yang istirahat **tidak** ikut dikelompokkan: kelompok dibentuk dari pemain yang main saja (14B).
- Court yang dipakai = court yang muat satu match, urut nomor; kelompok teratas ke court bernomor terkecil di antaranya
  (U4). Court lebih banyak dari pemain ÷ 4 → court bernomor terakhir kosong, seperti Mixed. Contoh: Court 1 habis lebih
  dulu dari Court 2 → kelompok teratas main di Court 2.
- Waktu habis di semua court → slot dihitung dari semua court untuk daftar prioritas, tombol jadi "Tambah jam" (3.4).

### 14.5 Susunan di satu court (partner berulang)

Empat pemain posisi 1–4 (urutan Mexicano). Tiga susunan, dicoba berurutan:

| Susunan | Sisi atas | Sisi bawah |
|---------|-----------|------------|
| A | 1 + 3 | 2 + 4 |
| B | 1 + 4 | 2 + 3 |
| C | 1 + 2 | 3 + 4 |

- **Beban ulang** satu susunan = berapa kali dua pasangannya pernah berpasangan, dijumlah (pasangan yang pernah
  berpasangan dua kali dihitung 2).
- Pilih susunan dengan beban ulang **terkecil**; sama → yang lebih dulu di tabel (A, lalu B, lalu C) (U3). Jadi A
  dipakai kalau tidak mengulang partner; B atau C hanya kalau A mengulang.
- Semua susunan mengulang (4 pemain / 1 court setelah R3) → tetap dipilih yang bebannya terkecil; match tetap dibuat.
- Sisi atas = tim berisi posisi 1. Di dalam tim, nama posisi lebih kecil ditulis dulu ("Citra · Hadi").
- Ulang lawan dan ulang match persis **tidak** dihindari (berbeda dengan penalti Mixed): lawan memang ditentukan
  peringkat.

### 14.6 Contoh hitung

Semua contoh: Padel, Americano 21, 15 menit, court 2 jam. "Undian Rn" = hasil `lockedDraw(drawSeed + n)`; data test
memilih id turnamen yang memberi undian ini (seperti fixture `courtTournament`) atau menyuntik undiannya. Angka
"22 (+2)" = Total Point 22, selisih +2.

**Contoh 14A — 8 pemain, 2 court** (Andi, Budi, Citra, Dewi, Eko, Fajar, Gita, Hadi). Tanpa istirahat.

R1 — undian R1: Andi, Budi, Citra, Dewi, Eko, Fajar, Gita, Hadi.

| Court | Posisi 1–4 | Susunan | Match | Skor |
|-------|------------|---------|-------|------|
| Court 1 | Andi, Budi, Citra, Dewi | A | Andi · Citra vs Budi · Dewi | 15–6 |
| Court 2 | Eko, Fajar, Gita, Hadi | A | Eko · Gita vs Fajar · Hadi | 9–12 |

Setelah R1: Andi 15 (+9), Citra 15 (+9), Fajar 12 (+3), Hadi 12 (+3), Eko 9 (−3), Gita 9 (−3), Budi 6 (−9), Dewi 6
(−9). Klasemen #1 Andi, Citra · #2 Fajar, Hadi · #3 Eko, Gita · #4 Budi, Dewi.

R2 — semua seri berpasangan; undian R2 menaruh Citra di atas Andi, Fajar di atas Hadi, Gita di atas Eko, Budi di atas
Dewi.

| Court | Posisi 1–4 | Susunan | Match | Skor |
|-------|------------|---------|-------|------|
| Court 1 | Citra, Andi, Fajar, Hadi | A (beban 0) | Citra · Fajar vs Andi · Hadi | 11–10 |
| Court 2 | Gita, Eko, Budi, Dewi | A (beban 0) | Gita · Budi vs Eko · Dewi | 8–13 |

Setelah R2: Citra 26 (+10), Andi 25 (+8), Fajar 23 (+4), **Hadi 22 (+2), Eko 22 (+2)**, Dewi 19 (−4), Gita 17 (−8),
Budi 14 (−14). Total 168 = 4 match × 21 × 2. Klasemen #1 Citra · #2 Andi · #3 Fajar · #4 Hadi, Eko · #5 Dewi · #6 Gita ·
#7 Budi.

R3 — **partner berulang** dan **seri di batas court**: Hadi dan Eko sama persis, undian R3 menentukan siapa ke Court 1.
Undian R3 menaruh Hadi di atas Eko:

| Court | Posisi 1–4 | Beban A / B / C | Dipilih | Match |
|-------|------------|-----------------|---------|-------|
| Court 1 | Citra, Andi, Fajar, Hadi | 2 (Citra·Fajar R2, Andi·Hadi R2) / 0 / 2 (Citra·Andi R1, Fajar·Hadi R1) | B | Citra · Hadi vs Andi · Fajar |
| Court 2 | Eko, Dewi, Gita, Budi | 2 (Eko·Gita R1, Dewi·Budi R1) / 0 / 2 (Eko·Dewi R2, Gita·Budi R2) | B | Eko · Budi vs Dewi · Gita |

Kalau undian R3 menaruh Eko di atas Hadi:

| Court | Posisi 1–4 | Beban A / B / C | Dipilih | Match |
|-------|------------|-----------------|---------|-------|
| Court 1 | Citra, Andi, Fajar, Eko | 1 (Citra·Fajar R2) / 0 / 1 (Citra·Andi R1) | B | Citra · Eko vs Andi · Fajar |
| Court 2 | Hadi, Dewi, Gita, Budi | 1 (Dewi·Budi R1) / 0 / 1 (Gita·Budi R2) | B | Hadi · Budi vs Dewi · Gita |

**Contoh 14B — 10 pemain, 2 court** (14A + Indra, Joko). Slot 8, 2 istirahat per round.

R1 — undian R1: Andi, Budi, Citra, Dewi, Eko, Fajar, Gita, Hadi, Indra, Joko. Semua 0 main → prioritas = undian:
**Indra, Joko istirahat**. Yang main dan skornya sama dengan R1 14A.

R2 — undian R2: Budi, Gita, Andi, Eko, Indra, Dewi, Fajar, Joko, Citra, Hadi.
- Prioritas (3.4): Indra, Joko (0 main) lebih dulu; lalu 8 pemain 1 main, semua terakhir main di R1 → urut undian:
  Budi, Gita, Andi, Eko, Dewi, Fajar, Citra, Hadi. Slot 8 → **Citra dan Hadi istirahat** (walau Citra #1 Klasemen).
- Yang main, urutan Mexicano: Andi 15 (+9), Fajar 12 (+3), Gita 9 (−3), Eko 9 (−3), Budi 6 (−9), Dewi 6 (−9), Indra
  0 (0), Joko 0 (0). Seri diurut undian R2: Gita sebelum Eko, Budi sebelum Dewi, Indra sebelum Joko. Indra dan Joko di
  bawah Budi/Dewi karena 0 < 6, walau selisih mereka lebih baik.

| Court | Posisi 1–4 | Susunan | Match |
|-------|------------|---------|-------|
| Court 1 | Andi, Fajar, Gita, Eko | A (beban 0) | Andi · Gita vs Fajar · Eko |
| Court 2 | Budi, Dewi, Indra, Joko | A (beban 0) | Budi · Indra vs Dewi · Joko |

- R3: Citra, Hadi (1 main, terakhir R1) lalu Indra, Joko (1 main, terakhir R2) pasti main; 4 dari 6 pemain lain (2
  main) menurut undian R3.
- Setelah R5: semua pemain tepat 4 match (5 × 8 slot = 40 = 10 × 4).
- Akibat keputusan 25 yang terlihat di sini: yang baru istirahat poinnya tertinggal satu match, jadi sementara main di
  court bawah (Indra, Joko di R2). Diterima; kompensasi poin istirahat ada di 14.10.

**Contoh 14C — 4 pemain, 1 court** (Andi, Budi, Citra, Dewi): semua susunan habis.

| Round | Urutan Mexicano | Beban A / B / C | Match | Skor |
|-------|-----------------|-----------------|-------|------|
| R1 | Andi, Budi, Citra, Dewi (undian R1) | 0 / 0 / 0 | A: Andi · Citra vs Budi · Dewi | 12–9 |
| R2 | Andi 12 (+3), Citra 12 (+3), Budi 9 (−3), Dewi 9 (−3); undian R2: Andi di atas Citra, Budi di atas Dewi | 0 / 0 / 2 | A: Andi · Budi vs Citra · Dewi | 10–11 |
| R3 | Citra 23 (+4), Andi 22 (+2), Dewi 20 (−2), Budi 19 (−4) | 2 / 0 / 2 | B: Citra · Budi vs Andi · Dewi | 14–7 |
| R4 | Citra 37 (+11), Budi 33 (+3), Andi 29 (−5), Dewi 27 (−9) | 2 / 2 / 2 | A (sama, yang pertama): Citra · Andi vs Budi · Dewi | — |

Total setelah R3 = 126 = 3 × 21 × 2. R4 mengulang pasangan R1 dengan sisi atas Citra · Andi.

### 14.7 Interaksi dengan fitur yang ada

| Fitur | Perilaku di Mexicano |
|-------|----------------------|
| Prioritas main, Istirahat (3.4) | Sama dengan Mixed. Daftar "Istirahat · Prioritas main di R(n+1)" tetap sama persis dengan hasil Buat R(n+1), karena siapa yang istirahat tidak tergantung skor. Yang tergantung skor hanya siapa lawan siapa. |
| Pemain telat menyusul (3.4) | Tidak berlaku: pemain tidak bisa ditambah (keputusan 27). Jeda pemain telat tidak pernah aktif. |
| Kelola pemain (Pemain (n)) | **Tambah tidak ada.** **Keluarkan** tersedia selama aktif > 4 (nama, skor, dan Klasemennya tetap, seperti Mixed). **Kembalikan** hanya untuk pemain yang belum melewatkan round, yaitu dikeluarkan setelah round terakhir dibuat (membetulkan salah ketuk); begitu ada round dibuat tanpa dia, Kembalikan tidak ada (U5). Contoh 14A: Gita dikeluarkan setelah R2 dibuat → masih bisa dikembalikan sampai Buat R3; R3 dibuat tanpa Gita → Gita tidak bisa kembali. |
| Batalkan Rn | Sama dengan Mixed (round terakhir tanpa skor, bukan R1). Batalkan lalu Buat lagi tanpa perubahan → round yang sama persis (14.3). Kegunaan di Mexicano: pemain pulang sebelum round mulai (Batalkan R3 → Keluarkan → Buat R3), atau skor round sebelumnya baru dikoreksi. |
| Koreksi skor | Mengubah skor round lama memperbarui Klasemen, tapi **tidak** membuat ulang round yang sudah dibuat (seperti Mixed, tidak ada pembuatan ulang otomatis) (U6). Round berikutnya memakai angka yang sudah dikoreksi. Contoh 14A: R3 sudah dibuat, skor R2 Court 2 dikoreksi 8–13 → 10–11: R3 tetap; kalau R3 belum ada skor, host bisa Batalkan R3 lalu Buat R3. |
| Kosongkan skor / Hapus WO (§17, 3.9.0) | Sama dengan Mixed: hanya round terakhir (keputusan 114). Round lama hanya bisa dikoreksi; kalau round terakhir belum ada skor, Batalkan Rn lalu round sebelumnya bisa dikosongkan (17C). |
| WO (4.4) | Sama dengan Americano: pemenang WO = rata-rata poin match yang dia mainkan, minimal ⌊N ÷ 2⌋ + 1; pasangan WO 0; selisih tidak berubah. Nilai WO ikut Total Point, jadi ikut urutan Mexicano. Contoh 14A, R2 Court 2 WO (Gita · Budi absen): Eko 9 + 11 = 20 (−3), Dewi 6 + 11 = 17 (−9), Gita 9 (−3), Budi 6 (−9). Pemain yang absen tetap dijadwalkan sampai dikeluarkan, seperti Mixed. |
| Kelola court | Sama dengan Mixed (`logic.md` §10): court ditambah saat round berjalan dan istirahat ≥ 4 → 4 teratas prioritas yang istirahat langsung main, disusun dengan 14.5 dari urutan Mexicano saat itu (skor round berjalan yang sudah masuk ikut dihitung). Round berikutnya court baru ikut urutan nomor (14.4). Hapus court: sama. |
| Waktu booking, Tambah jam, Lanjutkan turnamen, Akhiri | Sama dengan Mixed. Lanjutkan (dari Jadwal atau Beranda) meneruskan Klasemen; round berikutnya dipasangkan dari Klasemen itu. Match Tidak dimainkan kembali Belum. |
| Status Sementara/Final (4.6) | Sama dengan Mixed. |
| Klasemen (4.2, 4.3, 5.7) | Satu baris per pemain seperti Mixed. Default **Total Point** (Americano, keputusan 21); sejak 3.9.0 default **Point %** (keputusan 123), tiga tab. Tab lain tidak mengubah pasangan (14.3). |
| Detail pemain | Seperti Mixed (partner tampil, beda partner/lawan). |
| Beranda | "Padel · Mexicano · 8 pemain" (nama turnamen menggantikannya kalau ada). Turnamen terakhir Mexicano tampil sebagai baris riwayat → sheet Lanjutkan, seperti Mixed. |
| Bagikan | Seperti Mixed: per pemain, nilai metode (default Total Point; sejak 3.9.0 Point %) + selisih, baris kecil "Padel · Mexicano · tanggal". Caption sama dengan Mixed. |
| Live score | Seperti Mixed. Penonton melihat Jadwal, Klasemen, Detail; nama mode "Mexicano". Web/app versi lama tidak boleh menampilkan Mexicano sebagai Mixed (14.8). |
| Sparing | Tidak menawarkan Mexicano (keputusan 27). Turnamen Sparing tidak berubah. |
| Fixed (round tambahan, Atur pasangan) | Tidak berlaku. |

### 14.8 Data & versi

- Mode baru `mexicano` di config. Tanpa kunci simpanan lain: urutan Mexicano dihitung ulang dari match yang tersimpan,
  undian dari `drawSeed` yang sudah ada.
- Simpanan 3.3.x (Fixed/Mixed/Sparing) terbaca apa adanya. `schemaVersion` tetap 2.
- App versi lama (≤ 3.3.x, masih ter-cache di PWA) **tidak boleh** membaca turnamen Mexicano sebagai Mixed: simpanan dan
  payload live Mexicano membawa penanda yang membuat versi lama menolaknya, sama dengan K13 Sparing (U7; rincian dba di
  `docs/data.md`). Penonton versi lama melihat "Live tidak bisa dibuka" sampai web-nya ter-update.
- Kategori: **MINOR → 3.4.0** (mode baru, data lama kompatibel, Fixed/Mixed/Sparing tidak berubah). Mengandaikan
  3.3.0–3.3.2 sudah masuk `main` lebih dulu; kalau tidak, 3.4.0 tetap karena kategori tertinggi MINOR.
- Relay live tidak perlu diubah (menyimpan JSON codec apa adanya).

### 14.9 Kriteria penerimaan

- **AC-M1** Konfigurasi (bukan Sparing): Mode berisi Fixed, Mixed, Mexicano. Mexicano → Race to dan Best of tidak bisa
  dipilih; dari Race to 6 → Americano 21; dari Americano 24 → tetap 24; kembali ke Mixed → tetap Americano.
- **AC-M2** Sparing dipilih di layar Pemain → Konfigurasi hanya Fixed dan Mixed.
- **AC-M3** Mexicano + Lanjut → Jadwal dengan R1, tanpa layar Pasangan. Estimasi tombol sama dengan Mixed untuk ukuran
  yang sama.
- **AC-M4** Contoh 14A dengan undian R1–R3 di atas: R1, R2, R3 (dua varian undian R3) sama persis dengan tabel 14.6,
  termasuk sisi atas dan urutan nama di tim.
- **AC-M5** 14A setelah R2: Klasemen Total Point Citra 26 (+10) #1 … Budi 14 (−14) #7, Hadi dan Eko sama-sama #4.
- **AC-M6** Contoh 14B: R1 Indra dan Joko istirahat; R2 Citra dan Hadi istirahat, match R2 sama persis dengan tabel;
  R3 Citra, Hadi, Indra, Joko main; setelah R5 semua pemain 4 match.
- **AC-M7** Contoh 14C: R2 susunan A, R3 susunan B, R4 susunan A (semua beban 2) dengan Citra · Andi vs Budi · Dewi.
- **AC-M8** Test properti 30 round untuk 4/1, 5/1, 7/2, 8/2, 9/2, 10/2, 12/3, 16/4, 30/10 (pemain/court), skor acak
  sah: (a) selisih main antar pemain ≤ 1 setelah tiap round; (b) di tiap court kelompok = 4 pemain berurutan di urutan
  Mexicano dari pemain yang main, kelompok teratas di court bernomor terkecil yang dipakai; (c) susunan terpilih punya
  beban ulang terkecil dari ketiganya, dan seri → yang lebih dulu di A, B, C.
- **AC-M9** Ukuran: 4/1 tanpa istirahat; 5/1 satu istirahat per round, setelah R5 semua 4 match; 7/2 hanya Court 1
  dipakai, 3 istirahat; 30/10 Court 1–7 dipakai, Court 8–10 kosong, 2 istirahat per round.
- **AC-M10** Tab Klasemen Win % lalu Buat R(n+1) → round sama persis dengan saat tab Total Point (sejak 3.9.0: ketiga
  tab memberi round yang sama, dari urutan Point %, AC-RP11).
- **AC-M11** Sebelum skor round terakhir lengkap, daftar "Istirahat · Prioritas main di R(n+1)" dan "Istirahat lagi di
  R(n+1)" sudah tampil, dan setelah semua skor masuk, hasil Buat R(n+1) sama persis: semua dari daftar Prioritas main
  ikut main, semua dari "Istirahat lagi" istirahat, apa pun skornya.
- **AC-M12** Batalkan R3 lalu Buat R3 tanpa perubahan → match R3 sama persis. Batalkan R3, keluarkan Gita, Buat R3 →
  R3 tanpa Gita, dipasangkan ulang dari urutan Mexicano.
- **AC-M13** Koreksi skor R2 setelah R3 dibuat: Klasemen berubah, match R3 tidak berubah; R4 memakai angka baru.
- **AC-M14** App di-kill setelah semua skor R2 masuk → dibuka lagi → Buat R3 sama persis dengan tanpa kill. Live
  melanjutkan kode yang sama.
- **AC-M15** WO 14A R2 Court 2 (Gita · Budi): Eko 20, Dewi 17, Gita 9, Budi 6; selisih keempatnya sama dengan setelah R1;
  urutan R3 memakai angka ini. Sejak 3.9.0 urutan R3 memakai Point %: Eko 20 ÷ 32 = 63%, Dewi 17 ÷ 32 = 53% (nilai WO
  11 – 0), Gita 9 ÷ 32 = 28%, Budi 6 ÷ 32 = 19% (kalah 11 dari WO).
- **AC-M16** Kelola pemain Mexicano: tidak ada tambah pemain; Keluarkan mati saat aktif 4; Kembalikan ada untuk pemain
  yang dikeluarkan setelah round terakhir dibuat dan hilang setelah round berikutnya dibuat tanpa dia.
- **AC-M17** Kelola court: 12 pemain / 2 court, R1 berjalan → tambah Court 3 → match baru berisi 4 pemain istirahat
  teratas prioritas, disusun 14.5 dari urutan Mexicano saat itu; R2 memakai 3 court, kelompok teratas di Court 1.
- **AC-M18** Court 1 habis lebih dulu dari Court 2 → round berikutnya kelompok teratas di Court 2.
- **AC-M19** Beranda "Padel · Mexicano · 8 pemain"; turnamen terakhir Mexicano → Lanjutkan; poster "Padel · Mexicano ·
  tanggal"; Klasemen, Detail, Bagikan, caption, dan Live memakai nomor yang sama, default Total Point (sejak 3.9.0
  Point %, keputusan 123).
- **AC-M20** Simpanan 3.3.x Fixed/Mixed/Sparing dimuat tanpa perubahan; semua test dan golden yang ada lulus tanpa
  diubah, kecuali golden frame yang digambar ulang di hi-fi (03a–03e, 13h–13j, 14f, 14g, komponen kartu mode), yang
  mengikuti frame baru. Simpanan atau payload Mexicano dibuka versi ≤ 3.3.x → ditolak, tidak tampil sebagai Mixed, dan HP host versi
  lama tidak menimpanya.
- **AC-M21** Semua kriteria di atas jalan offline (kecuali Live).

### 14.10 Belum sekarang

- Mexicano di Sparing (keputusan 27).
- Menambah pemain / pemain telat di tengah turnamen Mexicano (keputusan 27).
- Race to / Best of di Mexicano (keputusan 24).
- Kompensasi poin untuk yang istirahat (mis. rata-rata poinnya), supaya pemain yang baru istirahat tidak turun ke court
  bawah.
- ~~Urutan Mexicano dari poin per match (rata-rata) alih-alih Total Point.~~ Dikerjakan 3.9.0 lewat Point %
  (keputusan 124, §18).
- Menghindari ulang lawan atau ulang match persis.
- Varian lain: Mexicano pasangan tetap ("Team Mexicano"), round final khusus (mis. 1+4 vs 2+3 di round terakhir),
  King of the Court (pemenang naik court).
- Menentukan court mana yang jadi "court atas" secara manual.

### 14.11 Keputusan & usulan

Keputusan host 2026-11-11: 23–32 di §10 (jangan dibuka ulang). U2, U5, U1, U6 sudah menjadi keputusan 30, 29, 31, 32.
U9 disetujui apa adanya (keputusan 34). Konfigurasi diringkas mengikuti keputusan 33, 35–37. U3, U4, U7, U8 disetujui
host 2026-11-12 (keputusan 44–47). Semua usulan di bawah sudah menjadi keputusan.

**Usulan PM (semuanya disetujui host):**

- **U1.** Urutan Mexicano selalu Total Point → selisih, apa pun tab Klasemen (14.3). Diubah keputusan 124 (2026-11-20):
  Point % → selisih, tetap apa pun tab.
- **U2.** Seri di urutan Mexicano diundi terkunci per round, bukan diurut nama (14.3).
- **U3.** Beban ulang = jumlah kali berpasangan; susunan dengan beban terkecil, seri → A, B, C (14.5).
- **U4.** Kelompok teratas di court bernomor terkecil yang dipakai (14.4).
- **U5.** Kelola pemain Mexicano: Keluarkan ada; Kembalikan hanya sebelum pemain itu melewatkan round (14.7).
- **U6.** Koreksi skor tidak membuat ulang round yang sudah dibuat; host memakai Batalkan + Buat (14.7).
- **U7.** Versi lama menolak simpanan/payload Mexicano, seperti K13 (14.8).
- **U8.** Pemain belum main dihitung 0 / 0 di urutan Mexicano (14.3).
- **U9.** Memilih Mexicano mengganti Race to/Best of ke Americano 21, Americano yang sudah ada tetap N-nya (14.2).

### 14.12 Pertanyaan terbuka untuk host

Q1–Q3 disetujui host 2026-11-11 sesuai rekomendasi (keputusan 28–30).

- **Q1.** Pemain yang datang telat tidak bisa ikut sama sekali di turnamen Mexicano (keputusan 27), juga di R1, karena
  R1 tidak bisa dibatalkan. Rekomendasi: terima untuk 3.4.0; host yang pemainnya telat sebelum ada skor memulai turnamen
  baru dari Beranda.
- **Q2.** Pemain yang dikeluarkan (pulang) di Mexicano tidak bisa kembali setelah melewatkan satu round, karena
  kembali sama dengan pemain telat (U5). Rekomendasi: setujui; Kembalikan tetap ada untuk membetulkan salah ketuk.
- **Q3.** Pemain bernomor sama di Klasemen (paling sering partner di round sebelumnya) diurutkan dengan undian untuk
  menentukan siapa posisi 1 dan siapa ke court atas, sehingga Jadwal tidak selalu cocok dengan urutan nama di Klasemen
  (U2). Rekomendasi: undian, karena urut nama memberi pemain berawalan "A" partner yang lebih kuat tiap kali seri.

---

## 15. Tukar Pemain (Mixed)

> **Diputuskan host 2026-11-12** ("setuju semua", keputusan 48–57, §10, termasuk usulan PM TU1–TU4), dirilis
> **3.5.0 (MINOR)** 2026-11-12. Tampilan disetujui host 2026-11-12 (keputusan 58–59): ikon di kolom bola baris match → sheet "Tukar
> pemain", hi-fi 17a–17r. Fixed dan Mexicano tidak berubah.

Tukar pemain = host mengganti satu pemain di match round terakhir yang belum diisi dengan satu pemain yang sedang
istirahat, tanpa membuat ulang round.

### 15.0 Situasi nyata

- Mabar Mixed 8–20 orang di 2–4 court, satu HP host, offline. Round dibuat dari prioritas main (3.4), lalu orang baru
  bergerak ke court setelah melihat Jadwal.
- Yang sering terjadi tepat setelah Buat Rn: pemain yang terpilih belum datang, baru selesai main dan minta istirahat,
  kakinya kram, atau pulang lebih dulu; sementara ada yang istirahat dan siap main. Sekarang host hanya punya WO
  (match terbuang, partnernya ikut kalah) atau Batalkan Rn + Buat, yang memilih pemain yang sama lagi (prioritas
  terkunci) dan hanya mengacak ulang pasangan semua court; R1 bahkan tidak bisa dibatalkan.
- Host butuh satu ketukan yang mengganti orangnya saja, court lain tidak terganggu, dan giliran main tetap adil di round
  berikutnya tanpa dia menghitung sendiri.

### 15.1 Aturan inti

- **T1.** Hanya turnamen **Mixed** (termasuk Mixed sparing) yang belum diakhiri. Fixed tidak berlaku (keputusan 53);
  Mexicano tidak punya tukar (keputusan 52).
- **T2.** Hanya match di **round terakhir** (`roundCount`) yang statusnya **Belum** (keputusan 48). Match Selesai, WO,
  Tidak dimainkan, dan semua match round sebelumnya tidak bisa ditukar. Round yang sebagian match-nya sudah diisi:
  match yang masih Belum tetap bisa ditukar.
- **T3.** Satu lawan satu (keputusan 49): pemain keluar **P** dari match M, pemain masuk **Q**. Q mengambil posisi
  persis P (sisi yang sama, tempat yang sama di tim); partner, lawan, court, nomor match, dan id match tetap. Tidak ada
  undi ulang, court lain tidak berubah.
- **T4.** Q = pemain aktif yang tidak main di round terakhir, yaitu semua nama di daftar Istirahat round terakhir yang
  tampil di Jadwal ("Istirahat · Prioritas main di R(n+1)" maupun "Istirahat lagi di R(n+1)"). Sparing: Q harus
  **sesama klub** P (keputusan 51). Tidak ada Q → P tidak bisa ditukar.
- **T5.** Setelah tukar, P **tercatat istirahat** di round itu (`restingPlayerIdsByRound[n]` ditambah P, Q dihapus
  kalau ada). P hadir di round itu, jadi tidak pernah menjadi pemain telat karena tukar (3.4).
- **T6.** Fairness tanpa aturan baru (keputusan 50). Jumlah main dihitung dari match yang terjadwal (termasuk yang
  Belum), jadi saat tukar disimpan P langsung −1 match dan Q +1. Daftar Istirahat round terakhir dan pembagian
  "Prioritas main" / "Istirahat lagi" dihitung ulang, dan tetap sama persis dengan hasil Buat R(n+1).
- **T7.** Tukar bisa membuat selisih jumlah main antar pemain menjadi 2 (pilihan host, 15B). Tidak dicegah, tidak ada
  peringatan; prioritas main memulihkannya sendiri dalam beberapa round.
- **T8.** Partner atau lawan berulang hasil tukar tidak menghalangi tukar. Setelah disimpan, match itu masuk riwayat
  seperti match lain dan ikut penalti pasangan round berikutnya (3.4).
- **T9.** Tukar bisa diulang di match yang sama, termasuk menukar balik (Q ↔ P); hasilnya sama dengan sebelum tukar
  pertama. Tidak ada Urungkan khusus.
- **T10.** Wording ikut `CLAUDE.md`: pemain, court, round, match; tanpa kalimat penjelas di layar (Prinsip "Tanpa
  Petunjuk", 7). Kata "tukar" dipakai di PRD; label di layar "Tukar pemain" / "Tukar" (keputusan 59).

### 15.2 Perilaku minimal (bukan desain layar)

- Host memilih P (dari match Belum di round terakhir) dan Q (kandidat T4). Sebelum menyimpan, host melihat siapa
  keluar dan siapa masuk, dan bisa membatalkan pilihan tanpa perubahan apa pun.
- Menyimpan = satu perubahan turnamen; simpanan lokal dan live ikut otomatis (tanpa panggilan simpan/kirim manual).
- App ditutup sebelum menyimpan → tidak ada yang berubah. Setelah menyimpan → tukar tetap ada saat dibuka lagi.
- Penonton live tidak bisa menukar. Titik masuk dan teks: keputusan 58–59, hi-fi 17a–17r.

### 15.3 Contoh hitung

Data dasar (dipakai 15A dan 15B): Mixed, Padel, Americano 21, 15 menit, 2 court × 2 jam, 10 pemain (Andi, Budi, Citra,
Dewi, Eko, Fajar, Gita, Hadi, Indra, Joko). Slot 8, 2 istirahat per round. "n main" = jumlah match terjadwal.

| Round | Court 1 | Court 2 | Istirahat |
|-------|---------|---------|-----------|
| R1 | Andi · Citra vs Budi · Dewi | Eko · Gita vs Fajar · Hadi | Indra, Joko |
| R2 | Andi · Gita vs Fajar · Eko | Budi · Indra vs Dewi · Joko | Citra, Hadi |
| R3 | Citra · Indra vs Hadi · Joko | Dewi · Eko vs Fajar · Gita | Andi, Budi |

R3: Citra, Hadi, Indra, Joko (1 main) pasti main; undian R3 menaruh Andi dan Budi paling bawah dari enam pemain 2 main.
Undian R4 (fixture): Gita, Fajar, Andi, Joko, Eko, Citra, Budi, Hadi, Dewi, Indra.

**Contoh 15A — tukar biasa, selisih tetap ≤ 1.** R3 Court 1 sudah selesai 12–9, Court 2 Belum. Dewi minta istirahat;
host menukar **Dewi ↔ Budi** di R3 Court 2. Court 1 tidak bisa ditukar (sudah ada skor).

| | Sebelum tukar | Sesudah tukar |
|---|---|---|
| R3 Court 2 | Dewi · Eko vs Fajar · Gita | **Budi** · Eko vs Fajar · Gita |
| Istirahat R3 | Andi, Budi | Andi, **Dewi** |
| Jumlah main | Andi 2, Budi 2, Dewi 3; Citra, Hadi, Indra, Joko 2; Eko, Fajar, Gita 3 | Andi 2, **Budi 3, Dewi 2**; lainnya sama |
| Prioritas R4 (urut) | Andi, Budi · Joko, Citra, Hadi, Indra · Gita, Fajar \| Eko, Dewi | Andi, Dewi · Joko, Citra, Hadi, Indra · Gita, Fajar \| Eko, Budi |
| Jadwal: Istirahat · Prioritas main di R4 | Andi, Budi | Andi, Dewi |
| Buat R4 → istirahat | Eko, Dewi | Eko, **Budi** |

- Urutan prioritas: 2 main terakhir R2 (Andi, Dewi) → 2 main terakhir R3 → 3 main; seri diurut undian R4. "\|" = batas
  slot 8. Semua yang istirahat di R3 masuk slot, jadi daftar "Istirahat lagi di R4" tidak tampil.
- Setelah R4 (kedua versi): Gita, Fajar 4 main, delapan lainnya 3. Selisih ≤ 1 terus.
- Dewi tetap tercatat hadir di R3 (istirahat), jadi bukan pemain telat. Budi (main R1–R3) bukan pemain telat, jadi tidak
  kena jeda.
- Tukar balik Budi ↔ Dewi sebelum Buat R4 → semua baris kembali ke kolom "Sebelum".

**Contoh 15B — tukar membuat selisih 2.** Data dasar, R3 belum ada skor. Citra baru datang dari parkiran dan belum siap;
host menukar **Citra ↔ Budi** di R3 Court 1 → **Budi** · Indra vs Hadi · Joko.

- Budi · Indra pernah berpasangan di R2. Tukar tetap boleh (T8); R4 dan seterusnya menghitung pasangan itu dua kali.
- Jumlah main setelah tukar: Citra 1; Andi, Hadi, Indra, Joko 2; Budi, Dewi, Eko, Fajar, Gita 3 → **selisih 2**.
- Istirahat R3: Andi, Citra → "Istirahat · Prioritas main di R4": Andi, Citra (keduanya pasti main di R4; nama urut daftar pemain).
- Buat R4 (undian R4 di atas): main Citra, Andi, Joko, Hadi, Indra, Gita, Fajar, Eko; **istirahat Budi, Dewi**.

| Setelah | Paling sedikit | Paling banyak | Selisih |
|---------|----------------|---------------|---------|
| R3 (tukar) | Citra 1 | 3 (lima pemain) | 2 |
| R4 | Citra 2 | 4 (Gita, Fajar, Eko) | 2 |
| R5 | Citra 3 | 5 (satu pemain) | 2 |
| R6 | 4 (Citra + satu pemain) | 5 (delapan pemain) | 1 |

- Baris R5–R6 tidak tergantung undian (yang tergantung undian hanya siapa di antara yang jumlahnya sama). Citra main
  R4–R6 beruntun; dia bukan pemain telat, jadi tanpa jeda (3.4).

**Contoh 15C — Sparing Mixed** (pemain 13.2, Contoh 13B: Garuda 8, Matcha 6, 2 court; susunan generator, hi-fi
15a/15b/17k). R4 Belum: Court 1 Budi · Hadi (Garuda) vs Lina · Nanda (Matcha), Court 2 Andi · Dewi vs Indra · Kiki.
Istirahat R4: Garuda Citra, Eko, Fajar, Gita; Matcha Joko, Maya.
- Kiki hanya bisa ditukar dengan **Joko atau Maya**; Andi hanya dengan **Citra, Eko, Fajar, atau Gita**.
- Kiki ↔ Maya → Andi · Dewi vs Indra · Maya; Kiki masuk daftar Istirahat Matcha (Joko, Kiki), daftar Garuda tidak
  berubah.
- Garuda 4 / Matcha 6 di 2 court: court aktif `min(2, 2, 3) = 2`, semua pemain Garuda main tiap round → pemain Garuda
  tidak pernah bisa ditukar; pemain Matcha bisa.

### 15.4 Interaksi dengan fitur yang ada

| Fitur | Perilaku dengan tukar pemain |
|-------|------------------------------|
| Prioritas main, daftar Istirahat (3.4) | Dihitung ulang dari riwayat setelah tukar (T6). Daftar yang tampil tetap sama persis dengan hasil Buat R(n+1). Undian terkunci tidak berubah (undian dibagikan ke pemain aktif, bukan ke match). |
| Properti fairness ≤ 1 (3.4, 13.4) | Tetap berlaku untuk round yang dibuat app; tukar oleh host bisa membuatnya 2 sementara (T7, 15B). Test properti fairness yang ada tidak memakai tukar, jadi tetap lulus. |
| Pemain telat & jeda (`latePlayerIds`, 3.4) | P tercatat istirahat di round n (T5), jadi tidak absen dan tidak masuk `latePlayerIds`. Q yang memang pemain telat tetap telat; match hasil tukar ikut dihitung di "main k round beruntun", jadi jedanya bisa datang satu round lebih cepat. |
| Batalkan Rn | Tetap boleh selama round itu tanpa skor; tukar ikut terhapus bersama round. Buat Rn lagi memilih pemain dari riwayat R1..R(n−1), jadi siapa main dan istirahat **sama dengan sebelum tukar** (kalau pemain aktif, court, dan jam sama), tapi **pasangan diacak ulang** (Mixed tidak mengunci pasangan). Contoh 15A sebelum skor Court 1: Batalkan R3 → Buat R3 → Andi, Budi istirahat lagi, Dewi main; host menukar lagi kalau perlu. R1 tidak bisa dibatalkan, jadi di R1 tukar adalah satu-satunya cara. |
| Kelola court — tambah saat round berjalan (`logic.md` §10) | Court baru langsung main kalau istirahat ≥ 4: 4 teratas prioritas di antara yang istirahat, dihitung setelah tukar, jadi P yang baru ditukar keluar biasanya ikut terambil. 15A: istirahat R3 hanya 2 → tidak langsung main, court baru mulai R4. |
| Kelola court — hapus court | Match Belum di court itu dihapus dan pemainnya kembali ke istirahat round n (aturan sekarang), termasuk Q hasil tukar. P tetap istirahat. |
| Kelola pemain — Keluarkan | Seperti sekarang: P yang dikeluarkan tetap di match round terakhir sampai host menandai WO, atau menukarnya keluar (keputusan 54). Q yang dikeluarkan hilang dari daftar Istirahat, jadi bukan kandidat. Pemain yang dikeluarkan tidak pernah jadi kandidat Q. |
| Kelola pemain — Kembalikan / Tambah | P yang dikeluarkan, ditukar keluar, lalu dikembalikan sebelum Buat R(n+1) → tidak telat (hadir di round n sebagai istirahat). Pemain yang baru ditambah setelah Rn dibuat tampil di daftar Istirahat; ditukar masuk (keputusan 55) → hadir di round n; kalau Rn = R1 dia hadir di semua round, jadi bukan pemain telat. |
| WO (4.4) | Match WO tidak bisa ditukar, dan WO tidak bisa dikembalikan ke Belum (tidak ada aksinya). Tukar dipakai **sebelum** WO: pemain absen ditukar keluar, partnernya tetap main. |
| Skor sebagian | Skor satu match diisi sekaligus; "sebagian" = sebagian match round terakhir sudah diisi. Match yang sudah diisi terkunci, sisanya bisa ditukar (15A). Begitu semua match round terakhir terisi, tidak ada yang bisa ditukar. |
| Waktu booking habis, Tambah jam | Match Belum di round terakhir tetap bisa ditukar walau waktu habis. Daftar prioritas memakai slot semua court (3.4). |
| Akhiri, Lanjutkan turnamen | Setelah diakhiri tidak ada tukar (match Belum jadi Tidak dimainkan). Lanjutkan → match itu kembali Belum dan bisa ditukar lagi. |
| Klasemen, Detail, Status (4.2–4.6, 5.7, 5.8) | Tidak berubah sampai match hasil tukar diisi; lalu dihitung untuk Q, bukan P. Tidak ada catatan "ditukar" di Jadwal, Detail, poster, atau caption. "Beda partner/lawan" di Detail ikut match apa adanya. |
| Live score (5.11) | Penonton melihat match hasil tukar dan daftar Istirahat baru lewat pembaruan biasa; bentuk payload tidak berubah, penonton versi ≤ 3.4.x tetap bisa membaca. |
| Sparing Mixed (13.4) | Hanya sesama klub (keputusan 51, 15C). Daftar Istirahat per klub dihitung ulang; fairness per klub sama dengan T7. |
| Mexicano (§14) | Tidak ada tukar (keputusan 52): pasangan Mexicano disusun dari Klasemen, tukar akan mengubah susunan itu. Pemain yang belum siap: Batalkan Rn → Keluarkan → Buat (14.7). |
| Fixed (3.3, 3.3a) | Tidak berlaku (keputusan 53). Mengganti pemain Fixed lewat Atur pasangan sebelum round tambahan. |

### 15.5 Data & versi

- **Tanpa bentuk data baru.** Tukar hanya mengubah dua kunci yang sudah ada: pemain di pasangan match itu, dan
  `restingPlayerIdsByRound[n]`. Id match, court, nomor match, status tetap. `schemaVersion` tetap 2.
- Simpanan 3.4.x terbaca apa adanya (belum pernah ada tukar). Simpanan atau payload live 3.5.0 berisi tukar terbaca
  benar oleh 3.4.x karena bentuknya sama; tidak perlu penanda penolak seperti K13/U7.
- Perlu dicek tech lead/dba: codec atau invariant yang menganggap daftar istirahat round n = pemain aktif di luar match
  saat round dibuat, atau yang menolak pemain yang dikeluarkan di daftar istirahat (TU1). Hapus court sudah memindahkan
  pemain ke daftar istirahat, jadi kemungkinan aman.
- Kategori: **MINOR → 3.5.0** (perilaku baru, data lama kompatibel, turnamen tanpa tukar persis seperti 3.4.0).
  Perkiraan brief dikonfirmasi. Relay live tidak perlu diubah.

### 15.6 Kriteria penerimaan

- **AC-T1** Tukar tersedia hanya untuk pemain di match Belum di round terakhir turnamen Mixed (biasa atau sparing) yang
  belum diakhiri dan punya kandidat. Tidak tersedia untuk: match Selesai/WO, round sebelumnya, turnamen diakhiri,
  Mexicano, Fixed, penonton live, dan round tanpa pemain istirahat (8 pemain / 2 court).
- **AC-T2** Contoh 15A: R3 Court 2 menjadi Budi · Eko vs Fajar · Gita dengan Budi di tempat Dewi; id, court, dan nomor
  match sama; Court 1 tidak berubah dan tidak bisa ditukar.
- **AC-T3** 15A setelah tukar: Istirahat R3 = Andi, Dewi; "Istirahat · Prioritas main di R4" = Andi, Dewi tanpa
  "Istirahat lagi"; Buat R4 (undian 15A) → Eko dan Budi istirahat, Andi dan Dewi main.
- **AC-T4** Pilihan dibatalkan sebelum disimpan → turnamen tidak berubah (match, daftar istirahat, simpanan, live).
- **AC-T5** 15A tukar balik Budi ↔ Dewi → match R3 dan daftar istirahat R3 sama dengan sebelum tukar pertama, Buat R4
  sama dengan tanpa tukar (Eko, Dewi istirahat).
- **AC-T6** Setelah tukar, `latePlayerIds` tidak berubah (15A, 15B: kosong); P yang ditukar keluar di R1 lalu Buat R2 →
  tidak kena jeda pemain telat.
- **AC-T7** Contoh 15B: jumlah main dan selisih setelah R3–R6 sama dengan tabel 15B; istirahat R4 = Budi, Dewi;
  selisih ≤ 1 lagi setelah R6.
- **AC-T8** Contoh 15C: kandidat untuk Kiki hanya Joko dan Maya; untuk Andi hanya Citra, Eko, Fajar, Gita. Garuda 4 /
  Matcha 6, 2 court → pemain Garuda tidak bisa ditukar.
- **AC-T9** Batalkan R3 setelah tukar 15A (sebelum skor Court 1) lalu Buat R3 → istirahat R3 = Andi, Budi, Dewi main;
  tukar hilang.
- **AC-T10** Kelola court: 12 pemain / 2 court, R2 berjalan, tukar satu pemain keluar, tambah Court 3 → match baru
  berisi 4 teratas prioritas di antara yang istirahat, dihitung setelah tukar. Hapus court yang match-nya berisi Q →
  Q kembali ke daftar Istirahat, P tetap di sana.
- **AC-T11** Pemain di match Belum round terakhir dikeluarkan lalu ditukar keluar → tidak tampil
  di daftar Istirahat, Q main di tempatnya; dikembalikan sebelum Buat R(n+1) → tidak masuk `latePlayerIds`.
- **AC-T12** 9 pemain / 2 court, R1 dibuat, pemain ke-10 ditambah lalu ditukar masuk ke R1
  menggantikan pemain yang belum datang → pemain baru tidak masuk `latePlayerIds`; yang ditukar keluar diprioritaskan di R2.
- **AC-T13** App di-kill setelah tukar → dibuka lagi → match dan daftar Istirahat hasil tukar; Buat R(n+1) sama dengan
  tanpa kill. Akhiri lalu Lanjutkan → match R terakhir yang Belum bisa ditukar lagi.
- **AC-T14** Live: penonton melihat match hasil tukar dan daftar Istirahat baru tanpa membuka ulang; penonton tidak
  punya aksi tukar.
- **AC-T15** Match hasil tukar diisi → Klasemen, Detail, Bagikan menghitungnya untuk Q, tidak untuk P; tidak ada tanda
  "ditukar" di mana pun.
- **AC-T16** Simpanan 3.4.x dimuat tanpa perubahan; simpanan 3.5.0 dengan tukar dibuka 3.4.x → tampil benar. Semua test
  dan golden yang ada lulus tanpa diubah, kecuali golden frame Jadwal yang digambar ulang dengan ikon tukar (keputusan
  58; 06f–06u, 08e–08k, 12a–12g, 13m, 15b–15p, daftar persis di hi-fi → Cakupan).
- **AC-T17** Semua kriteria di atas jalan offline (kecuali Live).

### 15.7 Belum sekarang

- Tukar di round lama atau di match yang sudah ada skor/WO (keputusan 48); mengosongkan skor/WO kembali ke Belum.
- Tukar dua pemain yang sama-sama main (pindah match/court, ganti partner di satu match).
- Tukar beberapa pemain sekaligus, atau undi ulang satu match/court saja.
- Tukar di Mexicano (keputusan 52) atau di Fixed (keputusan 53).
- Sparing: tukar dengan pemain klub lain (keputusan 51).
- Peringatan saat tukar membuat selisih main 2; penanda atau riwayat "ditukar" di Jadwal/Detail/poster; Urungkan khusus.
- Pemain yang ditukar keluar tidak diprioritaskan di round berikutnya (mis. minta istirahat dua round).

### 15.8 Keputusan & usulan

Keputusan host 2026-11-12: 48–53 di §10 (jangan dibuka ulang). TU1–TU4 dan Q1–Q2 disetujui host 2026-11-12
("setuju kesemuanya") menjadi keputusan 54–57.

**Usulan PM (semuanya disetujui host):**

- **TU1.** Pemain yang sudah dikeluarkan (Keluarkan) tapi masih di match Belum round terakhir boleh ditukar keluar; dia
  dicatat istirahat di round itu (T5) dan tidak tampil di daftar Istirahat karena tidak aktif (15.9 Q1).
- **TU2.** Pemain yang ditambah setelah round terakhir dibuat boleh ditukar masuk ke round itu (15.9 Q2).
- **TU3.** Kandidat Q = seluruh daftar Istirahat round terakhir, termasuk "Istirahat lagi", tidak dibatasi yang paling
  sedikit main: keputusan 50 tidak menambah aturan, dan host yang paling tahu siapa siap main.
- **TU4.** Batalkan Rn menghapus tukar bersama round-nya tanpa teks tambahan di dialog Batalkan (Prinsip "Tanpa
  Petunjuk"); host menukar lagi setelah Buat.

### 15.9 Pertanyaan terbuka untuk host

Q1–Q2 disetujui sesuai rekomendasi (keputusan 54–55).

- **Q1.** Saya pahami tukar dipakai saat pemain cedera atau pulang setelah round dibuat; pemain itu biasanya juga
  dikeluarkan lewat Pemain (n), padahal namanya masih di match. Rekomendasi: tetap boleh ditukar keluar walau sudah
  dikeluarkan (TU1), karena tanpa itu satu-satunya jalan adalah WO dan partnernya ikut kalah.
- **Q2.** Pemain yang datang setelah round dibuat dan ditambah lewat Pemain (n) langsung tampil di daftar Istirahat,
  tapi belum jelas apakah dia boleh ditukar masuk ke round yang sedang berjalan. Rekomendasi: boleh (TU2); kalau itu R1,
  dia dihitung hadir sejak awal (bukan "pemain telat", yaitu pemain yang menyusul dengan jeda istirahat), dan ini satu-satunya
  cara karena R1 tidak bisa dibatalkan.

---

## 16. Grup + Gugur (Fixed)

> **Arah diputuskan host 2026-11-17** (keputusan 93–102, §10), rencana rilis **3.8.0 (MINOR)**. Usulan PM GU1–GU16
> (16.13) dan rekomendasi 16.14 **disetujui host 2026-11-17** (keputusan 102); hi-fi 19a–22r disetujui (keputusan 103).
> Spec `design/spec/logic.md` §18, bentuk data `docs/data.md` → Grup + Gugur, task GG-n di `docs/tasks.md`; pertanyaan
> lanjutan dijawab host 2026-11-17 (keputusan 104–108). Round-robin Fixed, Mixed, Mexicano, dan Sparing tidak berubah.
> PATCH 3.8.1 (keputusan 112, jawaban host 2026-11-18): dialog Akhiri per fase (frame 20r, 21z; 16.9), diselaraskan
> dengan catatan hi-fi dan app 3.8.1.

Grup + Gugur = turnamen Fixed dua fase: **fase grup** (round-robin di dalam tiap grup, 3.3) lalu **fase gugur** (bagan
dengan 2 besar tiap grup; kalah langsung tersingkir) sampai final.

### 16.0 Situasi nyata

- Turnamen klub yang "serius": 12–30 pemain datang dengan pasangan yang sudah didaftarkan, 1–4 court dibooking 2–4 jam,
  satu HP host, offline. Round-robin penuh terlalu panjang (15 pasangan = 105 match, 8), dan semua menunggu satu
  momen: **final** dan siapa juaranya.
- Host biasanya sudah tahu siapa berpasangan dengan siapa dan ingin menyebar pasangan kuat ke grup berbeda, jadi
  pasangan dan grup diatur sendiri (keputusan 95), bukan diundi.
- Satu grup memakai satu court supaya pemain grup itu berkumpul di pinggir court yang sama dan tahu kapan gilirannya
  (keputusan 96). Court sering lebih sedikit dari grup.
- Di akhir hari yang dibagikan ke grup WhatsApp: juara 1–3 (podium) dan bagannya; bagan di poster belum sekarang
  (keputusan 101).

### 16.1 Aturan inti

- **G1.** Hanya mode **Fixed** (keputusan 93), turnamen biasa (Sparing: GU14). Format turnamen Fixed: **Round-robin**
  (seperti sekarang) atau **Grup + Gugur**.
- **G2.** Jumlah grup **2 atau 4** (keputusan 94). Tiap grup minimal 3 pasangan, ukuran antar grup selisih ≤ 1
  (keputusan 95), jadi ukuran grup = ⌊P ÷ G⌋ atau ⌈P ÷ G⌉ (P = jumlah pasangan, G = jumlah grup).
  - 2 grup: 6–15 pasangan (12–30 pemain). 4 grup: 12–15 pasangan (24–30 pemain). Di bawah 6 pasangan Grup + Gugur
    tidak tersedia.
  - Contoh: 7 pasangan / 2 grup → 4 + 3; 13 / 4 → 4 + 3 + 3 + 3; 15 / 4 → 4 + 4 + 4 + 3. Grup ditulis A, B, C, D;
    ukuran tiap grup ditetapkan app, yang lebih besar mendapat huruf lebih awal (GU2); host mengisi anggotanya.
- **G3.** Pasangan dibentuk host secara **manual** sebagai default (keputusan 95): layar Pasangan dibuka dalam mode
  Manual, bukan acak otomatis seperti round-robin (3.2 A). Acak tetap bisa dipilih. Pemain ganjil tetap menahan "Buat
  jadwal" (04c).
- **G4.** Host **menempatkan tiap pasangan ke grup** secara manual (keputusan 95). Buat jadwal aktif hanya kalau semua
  pasangan sudah punya grup dan ukuran grup memenuhi G2. Pasangan dan grup dikunci saat jadwal dibuat (dialog seperti
  keputusan 1).
- **G5.** Fase grup = round-robin penuh **di dalam tiap grup** (circle method 3.3, bye kalau pasangan ganjil). Tidak ada
  match antar grup di fase grup.
- **G6.** Court dikunci per grup (keputusan 96): semua match satu grup dimainkan di court yang sama (atau kumpulan
  court yang sama, GU3). Grup lebih banyak dari court → beberapa grup bergantian di satu court (GU4).
- **G7.** Klasemen grup: per grup, metode Klasemen yang ada (nilai metode → selisih, nomor sama kalau keduanya sama,
  4.3, keputusan 98). Hanya match grup itu yang dihitung. Nomor di tabel tetap aturan 4.3 (keputusan 17); head-to-head
  hanya dipakai untuk menentukan **siapa lolos dan urutannya** (G8), bukan nomor.
- **G8.** Lolos = 2 besar tiap grup (keputusan 94). Kalau nomor grup tidak memastikan siapa peringkat 1 dan 2 grup itu
  (seri di batas 2 vs 3, keputusan 98; seri di #1 untuk urutan A1/A2, GU7): **head-to-head** di antara pasangan yang
  seri → masih seri → **host memilih**.
- **G9.** Bagan silang (keputusan 97):
  - 2 grup → **Semifinal**: SF1 = A1 vs B2, SF2 = B1 vs A2.
  - 4 grup → **Perempat final**: PF1 = A1 vs B2, PF2 = C1 vs D2, PF3 = B1 vs A2, PF4 = D1 vs C2; SF1 = pemenang PF1 vs
    pemenang PF2, SF2 = pemenang PF3 vs pemenang PF4. A1, B2, C1, D2 di paruh atas; B1, A2, D1, C2 di paruh bawah, jadi
    pasangan dari grup yang sama paling cepat bertemu di final.
  - **Final** = pemenang SF1 vs pemenang SF2. **Perebutan juara 3** = kalah SF1 vs kalah SF2 (opsi, default nyala,
    keputusan 100).
  - A1 = peringkat 1 Grup A, A2 = peringkat 2 Grup A, dst.
- **G10.** Gugur **tidak ada seri** dan tidak ada round tambahan: tiap match gugur punya pemenang (skor atau WO).
- **G11.** Format skor per babak (keputusan 99): fase grup satu format; Perempat final, Semifinal, Perebutan juara 3,
  dan Final masing-masing Race to / Best of / Americano + N sendiri (GU9).
- **G12.** Pemenang maju otomatis ke slot berikutnya di bagan begitu skor/WO match gugur disimpan (keputusan 101).
- **G13.** Wording ikut `CLAUDE.md`: pemain, court, round, match; nama babak dan label lain di GU1.

### 16.2 Konfigurasi & alur

```
[Pemain] → [Konfigurasi] Fixed · Grup + Gugur, jumlah grup, format grup, format per babak gugur, juara 3, court
        → [Pasangan] (Manual) → [Grup] (tempatkan pasangan) → dialog kunci → [Jadwal fase grup]
        → semua match grup terisi → Buat bagan (+ pilih yang lolos kalau seri) → dialog kunci → [Jadwal gugur + bagan]
        → Final terisi → Final → [Klasemen] → [Bagikan]
```

- Konfigurasi (5.3): di bawah mode Fixed ada pilihan format turnamen (Round-robin / Grup + Gugur), hanya tampil mulai
  12 pemain (19a), dan jumlah grup (2 / 4; 4 hanya mulai 12 pasangan). Format skor yang ada = format fase grup. Format babak gugur + juara 3 diatur di
  Konfigurasi (GU9); mengubahnya setelah jadwal dibuat ditunda ke 3.8.x (keputusan 104), sekarang direncanakan 3.10.0
  (keputusan 120).
- Estimasi di tombol Lanjut **pasti** (seperti Fixed sparing, keputusan 19): round fase grup (16.3) + round gugur
  (GU10), dan "lewat booking hh:mm" kalau melewati booking terpendek.
- Grup + Gugur tidak memakai "Tambah round" (3.3a) maupun Atur pasangan (04f–04h): turnamen selesai di Final.

### 16.3 Jadwal fase grup (court dikunci)

Rumus per grup: g pasangan → g(g−1)/2 match; putaran circle r = g − 1 (g genap) atau g (g ganjil, satu pasangan bye
tiap putaran); match per putaran m = ⌊g ÷ 2⌋. Grup dengan k court → **r × ⌈m ÷ k⌉ round** (invariant 3.3: putaran circle
dipotong per k court, dua putaran tidak digabung). k = 1 → round = jumlah match grup.

**Round** tetap = satu batch court dipakai paralel sekali (3.0), bernomor terus R1, R2, … lintas fase. Jumlah round fase
grup = round terbanyak di antara court. Court yang grupnya sudah habis kosong sampai fase grup selesai.

Pembagian court (GU3) dan urutan di court bersama (GU4):
- **Court ≥ grup:** Court 1 → Grup A, Court 2 → Grup B, dst. Court sisanya, urut nomor, masing-masing diberikan ke grup
  yang roundnya paling banyak **dan** berkurang kalau mendapat court itu (seri → huruf lebih awal). Tidak ada grup yang
  berkurang → court itu tidak dipakai di fase grup.
- **Court < grup:** grup urut huruf, masing-masing ke court yang jumlah match grupnya paling sedikit sejauh ini (seri →
  nomor court terkecil).
- Satu court dipakai beberapa grup → **bergantian satu match per round**, urut huruf (A, C, A, C, …); grup yang habis
  dilewati, grup lain lanjut. Urutan match di dalam satu grup = urutan round-robin 3.3.

**Contoh 16A — 2 grup, 2 court (satu grup satu court).** Padel, 15 menit, 2 court × 2 jam (18.00–20.00), 16 pemain.
Format grup Race to 6 (Win %); Semifinal Race to 6, Perebutan juara 3 Race to 4, Final Race to 9.

| Grup | Pasangan | Court |
|------|----------|-------|
| A | Andi · Budi, Citra · Dewi, Eko · Fajar, Gita · Hadi | Court 1 |
| B | Indra · Joko, Kiki · Lina, Maya · Nanda, Oki · Putri | Court 2 |

- Tiap grup 4 pasangan → 6 match (r = 3, m = 2, k = 1 → 6 round). Fase grup **R1–R6**: tiap round Court 1 satu match
  Grup A, Court 2 satu match Grup B. Tiap pasangan 3 match.
- Gugur: R7 = SF1 (Court 1) + SF2 (Court 2); R8 = Final (Court 1) + Perebutan juara 3 (Court 2). Total **8 round ×
  15 menit = 120 menit**, pas booking (selesai 20.00).
- Varian 1 court (2 jam): Court 1 bergantian A, B, A, B, … → fase grup R1–R12; R13 SF1, R14 SF2, R15 Perebutan juara 3,
  R16 Final → 16 round = 240 menit, "lewat booking 02:00".

**Contoh 16B — 4 grup, 2 court (bergantian).** Tennis, 20 menit, 2 court × 3 jam, 24 pemain = 12 pasangan → 4 grup ×
3 pasangan (3 match per grup, tiap pasangan 2 match).

- Pembagian: A → Court 1, B → Court 2, C → Court 1 (keduanya 3 match, seri → court terkecil), D → Court 2.

| Round | Court 1 | Court 2 |
|-------|---------|---------|
| R1, R3, R5 | Grup A (match 1, 2, 3) | Grup B (match 1, 2, 3) |
| R2, R4, R6 | Grup C (match 1, 2, 3) | Grup D (match 1, 2, 3) |

- Tidak ada pasangan yang main di dua round beruntun (main di R1/R3/R5 atau R2/R4/R6).
- Gugur: R7 = PF1 (A1–B2, Court 1) + PF2 (C1–D2, Court 2); R8 = PF3 (B1–A2) + PF4 (D1–C2); R9 = SF1 + SF2; R10 = Final
  (Court 1) + Perebutan juara 3 (Court 2). Total **10 round × 20 menit = 200 menit** → "lewat booking 00:20".
- Varian 3 court, 13 pasangan (A 4, B 3, C 3, D 3): A (6 match) → Court 1, B → Court 2, C → Court 3, D → Court 2 (Court 2
  dan 3 sama-sama 3 match, seri → Court 2). Court 1: A 6 round; Court 2: B, D bergantian 6 round; Court 3: C 3 round
  lalu kosong. Fase grup **6 round**.

**Contoh 16C — court lebih banyak dari grup (GU3).**
- 30 pemain = 15 pasangan → A 8, B 7; Padel 15 menit, 4 court. Awal: Court 1 → A (r 7 × m 4 = 28 round), Court 2 → B
  (7 × 3 = 21). Court 3 → A (paling banyak, 28 → 7 × ⌈4/2⌉ = 14). Court 4 → B (21 → 7 × ⌈3/2⌉ = 14). Fase grup
  **14 round**: Grup A di Court 1 + 3 (2 match tiap round), Grup B di Court 2 + 4 (putaran 3 match dipotong 2 + 1, jadi
  Court 4 kosong selang satu round). Gugur: R15 SF1 + SF2 (Court 1–2), R16 Final + Perebutan juara 3 → **16 round =
  240 menit**.
- 12 pemain = 6 pasangan → 2 grup × 3, 3 court: tiap putaran grup 3 pasangan hanya 1 match, court tambahan tidak
  mengurangi round → **Court 3 tidak dipakai di fase grup**. Fase grup R1–R3, R4 SF1 + SF2, R5 Final + Perebutan juara 3
  (Court 1–2). Court 3 tidak dipakai sama sekali.

### 16.4 Batas & kasus ekstrem

| Kasus | Hasil |
|-------|-------|
| 10 pemain (5 pasangan) | Grup + Gugur tidak tersedia (2 grup × 3 butuh 6 pasangan) |
| 12 pemain, 2 grup | 3 + 3; 3 match per grup; tiap pasangan 2 match grup |
| 22 pemain, 4 grup | Tidak tersedia (11 pasangan < 12); 2 grup → 6 + 5 |
| 14 pemain, 2 grup | 4 + 3; Grup B ganjil → bye tiap putaran |
| 30 pemain, 2 grup, 1 court | A 28 + B 21 match bergantian → B habis di R42, A lanjut R43–R49; R50–R51 SF, R52 Perebutan juara 3, R53 Final |
| 30 pemain, 4 grup, 1 court | 4 + 4 + 4 + 3 → 6 + 6 + 6 + 3 = 21 round grup; R22–R25 PF, R26–R27 SF, R28–R29 → 29 round |
| Host menempatkan 5 + 2 (7 pasangan) | Buat jadwal mati: grup < 3 pasangan dan selisih > 1 |

### 16.5 Transisi grup → gugur (GU6–GU8)

- **Kapan:** begitu **semua** match grup Selesai atau WO dan turnamen belum diakhiri, Jadwal menampilkan "Buat bagan".
  Satu match grup masih Belum → tidak ada Buat bagan. Tidak ada gugur yang dimulai per grup. Sejak 3.9.0 (keputusan
  119, 17.11) selama itu action bar = ikon Klasemen + tombol mati "Buat bagan · tunggu N match", N = match grup Belum di
  semua round grup (20b: "tunggu 7 match").
- **Kosongkan skor / Hapus WO di fase grup** (3.9.0, keputusan 114): boleh di semua match grup selama bagan belum dibuat;
  sesudah Buat bagan tidak ada (skor grup terkunci). Contoh 17D.
- **Seri di lolos:** untuk tiap grup, kalau nomor grup tidak memastikan siapa peringkat 1 dan 2 (G8):
  1. Head-to-head = jumlah menang (seri ½, WO = menang) **hanya dari match di antara pasangan yang seri**. Satu kali,
     tidak diulang untuk sisa yang masih seri.
  2. Masih belum pasti → host memilih pasangan yang lolos (dan siapa peringkat 1 kalau itu juga belum pasti) di langkah
     Buat bagan.
- **Metode yang menentukan lolos** = default format grup (keputusan 21: Race to / Best of → Win %, Americano → Total
  Point); Klasemen grup tanpa toggle metode (GU8, pertanyaan Q1). Sejak 3.9.0 default Americano = Point % (keputusan
  123), jadi grup Americano lolos dari Point % → selisih (U-RP6, keputusan 129).
- **Dikunci** (dialog konfirmasi, seperti kunci pasangan): siapa lolos, A1/A2 dst., dan **skor fase grup** (tidak bisa
  diubah lagi, GU6, pertanyaan Q2). Pilihan host disimpan; app ditutup sebelum konfirmasi → belum ada yang berubah.
- Setelah dikunci, round gugur ditambahkan ke Jadwal dan bagan tampil.

**Contoh 16D — seri di Grup A** (data 16A, Race to 6, Win %, 6 match).

*16D-i, seri di batas 2 vs 3 (dua pasangan):* Andi · Budi – Citra · Dewi 6–4, Andi · Budi – Eko · Fajar 6–3, Andi ·
Budi – Gita · Hadi 6–3, Citra · Dewi – Eko · Fajar 6–4, Eko · Fajar – Gita · Hadi 6–3, Gita · Hadi – Citra · Dewi 6–4.

| # | Pasangan | W–L | +/− | Win % |
|---|----------|-----|-----|-------|
| 1 | Andi · Budi | 3–0 | +8 | 100% |
| 2 | Citra · Dewi | 1–2 | −2 | 33% |
| 2 | Eko · Fajar | 1–2 | −2 | 33% |
| 3 | Gita · Hadi | 1–2 | −4 | 33% |

→ Head-to-head Citra · Dewi menang 6–4 atas Eko · Fajar → **A1 Andi · Budi, A2 Citra · Dewi**. Nomor di tabel tetap
1, 2, 2, 3.

*16D-ii, seri di #1 (urutan A1/A2):* Andi · Budi – Citra · Dewi 6–4, Andi · Budi – Eko · Fajar 6–3, Gita · Hadi – Andi ·
Budi 6–4, Citra · Dewi – Eko · Fajar 6–3, Citra · Dewi – Gita · Hadi 6–4, Eko · Fajar – Gita · Hadi 6–2.

| # | Pasangan | W–L | +/− | Win % |
|---|----------|-----|-----|-------|
| 1 | Andi · Budi | 2–1 | +3 | 67% |
| 1 | Citra · Dewi | 2–1 | +3 | 67% |
| 2 | Eko · Fajar | 1–2 | −2 | 33% |
| 3 | Gita · Hadi | 1–2 | −4 | 33% |

→ Keduanya lolos; head-to-head Andi · Budi menang → **A1 Andi · Budi, A2 Citra · Dewi**. (Data ini dipakai 16E.)

*16D-iii, seri tiga pasangan berputar:* Andi · Budi menang 6–3 atas ketiganya; Citra · Dewi – Eko · Fajar 6–4, Eko ·
Fajar – Gita · Hadi 6–4, Gita · Hadi – Citra · Dewi 6–4. Citra · Dewi, Eko · Fajar, Gita · Hadi: 1–2, −3, 33% → nomor
2, 2, 2. Head-to-head di antara ketiganya 1–1 semua → **host memilih** satu sebagai A2.

### 16.6 Bagan, babak gugur & pemenang maju

- **Court & round gugur (GU10):** match satu babak diisi ke round baru urut bagan (PF1, PF2, PF3, PF4 / SF1, SF2) di
  Court 1, 2, … (court kunci grup tidak berlaku lagi). Babak berikutnya selalu di round sesudahnya. Round terakhir:
  Final di Court 1 + Perebutan juara 3 di Court 2; 1 court → Perebutan juara 3 satu round lebih dulu, Final terakhir.
- **Kunci round** sama dengan Fixed (3.2 A): round berikutnya terbuka setelah semua match round sebelumnya terisi.
- **Tab round gugur (GU5, 21b, 21s, 21v):** round berisi Final → "Final"; satu babak utuh di satu round → nama pendek
  ("Semifinal", "Juara 3"); babak yang terpecah ke beberapa round → kode match ("SF1", "PF1–2"). Judul layar = nama
  babak lengkap. Fase gugur juga tanpa baris Istirahat.
- **Slot belum diketahui:** match gugur yang salah satu sisinya belum punya pemenang tidak bisa dibuka ke Input Skor;
  sisinya ditulis dari asalnya: "Pemenang SF1" / "Kalah SF1" (21a).
- **Bagan tampil di Jadwal** selama fase gugur (keputusan 101) sebagai tab "Bagan" paling kanan, setelah round terakhir:
  semua babak, nama pasangan, skor yang terisi, pemenang maju otomatis. Setelah Buat bagan dikonfirmasi Jadwal terbuka
  di tab Bagan (21a). Bentuk visual di hi-fi 21.
- **Ubah skor gugur (GU11):** skor yang tidak membalik pemenang selalu boleh diubah, tanpa dialog. Yang membalik
  pemenang hanya boleh selama **semua match yang diisi oleh match itu** (babak berikutnya, juga Perebutan juara 3 untuk
  SF) masih Belum: dialog "Ganti pemenang SF1?" berisi susunan baru (mis. "Final: Maya · Nanda vs Citra · Dewi"),
  tombol "Ganti" → skor tersimpan dan slot di sana langsung berganti (21k). Final dan Juara 3 tidak mengisi match lain,
  jadi pemenangnya selalu boleh diganti tanpa dialog. Sudah ada skor → ditolak: pesan "Final sudah ada skor · pemenang
  SF1 tetap …" (dua babak: "Final dan Juara 3 sudah ada skor · …"), tombol simpan mati (21l). Aturan yang sama berlaku
  untuk WO yang membalik pemenang.
- **Kosongkan skor / Hapus WO gugur** (3.9.0, keputusan 114): diperlakukan seperti membalik pemenang (GU11) karena
  pemenangnya hilang dari match lanjutan. Match lanjutan masih Belum (atau Tidak dimainkan) → satu dialog dengan
  susunan baru ("Final: Pemenang SF1 vs Citra · Dewi"); sudah ada skor/WO → ditolak dengan pesan 21l. Final dan Juara 3
  selalu boleh. Jalan untuk SF yang salah setelah Final berskor: kosongkan Final (dan Juara 3), lalu ubah SF sesuai
  GU11 (contoh 17E). Aturan GU11 tidak berubah.
- **Format per babak (GU9):** validasi Input Skor (4.1) memakai format babak match itu. Di gugur, Best of dan Americano
  hanya N ganjil, jadi skor penuh tidak pernah seri; Race to memang tidak bisa seri.

**Contoh 16E — bagan 16A** (Grup A = 16D-ii; Grup B: Indra · Joko – Maya · Nanda 6–4, Indra · Joko – Kiki · Lina 6–2,
Indra · Joko – Oki · Putri 6–1, Maya · Nanda – Kiki · Lina 6–3, Maya · Nanda – Oki · Putri 6–2, Kiki · Lina – Oki ·
Putri 6–4 → B1 Indra · Joko 3–0, B2 Maya · Nanda 2–1, Kiki · Lina 1–2, Oki · Putri 0–3).

| Round | Court 1 | Court 2 |
|-------|---------|---------|
| R7 Semifinal (Race to 6) | SF1 Andi · Budi (A1) **6**–4 Maya · Nanda (B2) | SF2 Indra · Joko (B1) 4–**6** Citra · Dewi (A2) |
| R8 | Final (Race to 9): Andi · Budi 7–**9** Citra · Dewi | Perebutan juara 3 (Race to 4): Maya · Nanda **4**–2 Indra · Joko |

- Simpan SF1 6–4 → slot Final atas = Andi · Budi, slot juara 3 atas = Maya · Nanda, langsung.
- Andi · Budi dan Citra · Dewi (sama-sama Grup A) baru bertemu di Final.
- Ubah SF1 jadi 4–6 **sebelum** R8 ada skor → Final: Maya · Nanda vs Citra · Dewi; Perebutan juara 3: Andi · Budi vs
  Indra · Joko. **Sesudah** Final 7–9 disimpan → ditolak. Ubah SF1 jadi 6–5 → boleh (pemenang sama).
- Skor 6–6 di SF tidak bisa disimpan (Race to); Americano 21 di gugur: total 21 tidak bisa dibagi sama.

### 16.7 WO di gugur

- Alur WO sama (4.4): pasangan yang tidak bisa main kalah, lawannya **maju** seperti menang skor (G12).
- Nilai WO (Total Point) tidak berpengaruh di gugur, karena peringkat gugur dari babak, bukan poin (16.8).
- Dua pasangan sama-sama tidak datang: tidak ada aksi khusus; host memilih salah satu sebagai WO (belum sekarang: WO
  ganda).
- WO di fase grup: aturan 4.4 apa adanya, ikut Klasemen grup dan head-to-head (WO = menang).
- Hapus WO (3.9.0): fase grup seperti 16.5, gugur seperti 16.6 (Kosongkan skor / Hapus WO gugur). Skor lama yang
  kembali dengan pemenang lain = membalik pemenang (GU11).

### 16.8 Klasemen & peringkat akhir (GU12, GU13, GU16)

- **Klasemen grup:** satu tabel per grup (kolom 5.7), metode tetap (GU8); setelah bagan dibuat slot lolos (A1, A2, B1,
  B2) tertulis di kanan nama (22b).
- **Tab Klasemen:** sebelum bagan dan belum diakhiri hanya tabel grup tanpa tab (20d). Setelah bagan dibuat **atau**
  turnamen diakhiri: dua tab "Peringkat" (peringkat akhir, terbuka pertama) dan "Fase grup" (tabel grup) (22a, 22b, 22g).
- **Peringkat akhir** (dipakai tab Peringkat, poster podium/Lengkap, caption, penonton live). Tingkat dari atas:
  1. Menang Final · 2. Kalah Final · 3. Menang Perebutan juara 3 · 4. Kalah Perebutan juara 3 (tanpa match juara 3:
     kedua kalah SF satu tingkat) · 5. Kalah Perempat final · 6. Tidak lolos, per **posisi grup** 3, 4, ….
  - Posisi grup pasangan tidak lolos = 3 + jumlah pasangan tidak lolos di grupnya yang nomornya lebih kecil; posisi sama
    di grup mana pun = tingkat sama.
  - Satu tingkat = nomor sama; nomor rapat seperti 4.3 (#1, #2, #2, #3). Tingkat kosong tidak memakan nomor.
  - Pasangan yang masih di babak tanpa hasil (Sementara, atau diakhiri) ada di tingkat tepat di atas yang kalah di babak
    itu, bernomor sama satu sama lain.
  - Sebelum bagan dibuat: urut posisi grup = 1 + jumlah pasangan di grupnya yang nomornya lebih kecil (semua posisi 1
    lintas grup satu tingkat, dst.). Pasangan yang belum main: tanpa nomor dan tanpa babak, di bawah.
- Nomor akhir ditentukan babak, bukan nilai metode, jadi baris peringkat akhir menulis **babak yang dicapai** ("Juara",
  "Final", "Juara 3", "Semifinal", "Perempat final", "Grup A · 3"; sebelum bagan "Grup A · 1") sebagai alasan nomornya,
  bukan "nilai · selisih" (GU16, pertanyaan Q3). Pasangan yang match-nya belum ada hasil menulis babak yang sedang
  dijalani, nama lengkap ("Final", "Semifinal", "Perebutan juara 3", 22e). Diakhiri: finalis Final yang Tidak dimainkan
  tetap "Final"; Perebutan juara 3 yang Tidak dimainkan tidak dihitung, kedua pasangannya tetap "Semifinal" (22f).
  Keputusan 17 (nomor dari angka yang tampil) tetap berlaku di Klasemen grup.
- **Status (4.6):** Final setelah Final (dan Perebutan juara 3 kalau nyala) terisi, atau setelah diakhiri. Selain itu
  Sementara.

**Contoh 16F — peringkat akhir 16E:**

| # | Pasangan | Babak |
|---|----------|-------|
| 1 | Citra · Dewi | Juara |
| 2 | Andi · Budi | Final |
| 3 | Maya · Nanda | Juara 3 |
| 4 | Indra · Joko | Semifinal |
| 5 | Eko · Fajar, Kiki · Lina | Grup A · 3, Grup B · 3 |
| 6 | Gita · Hadi, Oki · Putri | Grup A · 4, Grup B · 4 |

- Tanpa Perebutan juara 3: #1 Citra · Dewi, #2 Andi · Budi, #3 Maya · Nanda + Indra · Joko, #4 posisi 3, #5 posisi 4.
  Podium: #1, #2, #3, #3 (4 anak tangga, keputusan 65).
- Diakhiri setelah R7 (R8 Tidak dimainkan): #1 Andi · Budi + Citra · Dewi, #2 Maya · Nanda + Indra · Joko, #3 posisi 3,
  #4 posisi 4.
- Diakhiri setelah R3 (fase grup): urut posisi grup Sementara saat itu; tidak ada bagan.
- 4 grup: kalah perempat final berempat di satu nomor (#5 dengan Perebutan juara 3).

### 16.9 Interaksi dengan fitur yang ada

| Fitur | Perilaku di Grup + Gugur |
|-------|--------------------------|
| Pasangan Acak/Manual (3.2 A, 04a–04e) | Dibuka Manual (G3, keputusan 95); Acak tetap ada. Ditambah langkah penempatan grup (G4). |
| Round tambahan + Atur pasangan (3.3a) | Tidak ada. Pemain pulang di tengah turnamen → WO (fase grup: 4.4; gugur: lawan maju). |
| Sparing (§13) | Tidak menawarkan Grup + Gugur (GU14). |
| Mixed, Mexicano, Tukar pemain (§14, §15) | Tidak berlaku (keputusan 93). |
| Akhiri | Boleh kapan saja; match Belum → Tidak dimainkan; bagan tidak dibuat kalau masih fase grup; peringkat akhir 16.8; tidak bisa dilanjutkan. Dialog "Akhiri turnamen?" (Batal / Akhiri, seperti 06e) menulis akibat per fase (PATCH 3.8.1): lihat di bawah tabel. |
| Lanjutkan turnamen | Tidak ada, seperti Fixed (3.2 A); tidak tampil di riwayat Beranda. |
| Resume (5.10) | App ditutup di fase grup, saat memilih yang lolos (belum konfirmasi), atau di gugur → dibuka lagi di keadaan tersimpan terakhir. |
| Klasemen toggle (4.2) | Tidak ada di Grup + Gugur (GU8, Q1). Kolom nilai tabel grup = metode default format grup; sejak 3.9.0 Americano → Point % (U-RP6). |
| Detail Pemain (5.8) | Subjudul "Peringkat n · babak · olahraga · Grup + Gugur" (mis. "Peringkat 1 · Juara · Padel · Grup + Gugur"), tanpa metode dan format skor: metode tetap (GU8) dan format beda per babak (22j). Baris statistik = fase grup saja (format bisa beda per babak, poin dan game tidak dijumlah); riwayat semua match dengan nama babak (GU13). |
| Live score (5.11) | Penonton melihat match gugur sebagai daftar round dengan nama babak, tanpa bagan (keputusan 101); Klasemen grup + peringkat akhir seperti host. Relay tidak berubah. |
| Bagikan (5.9) | Podium dan Lengkap dari peringkat akhir; aturan podium 64–65, 68–69 tetap. Kolom kanan poster dan baris caption menulis babak, bukan nilai · selisih (GU16, hi-fi 22l–22r, keputusan 103), mis. caption "1. Citra + Dewi — Juara", "5. Eko + Fajar — Grup A · 3". Bagan di poster belum sekarang. |
| Kelola court | Tidak ada (sama seperti Fixed). |

**Dialog Akhiri per fase (PATCH 3.8.1, frame 20r dan 21z).** Judul "Akhiri turnamen?", tombol "Batal" / "Akhiri"; isinya:
- **Fase grup** (bagan belum dibuat, juga saat "Buat bagan" sudah tersedia): "Match yang belum main tidak dihitung.
  Bagan tidak dibuat; peringkat dari posisi grup." (20r, latar 20b).
- **Fase gugur:** babak yang punya match Belum, urut Perempat final, Semifinal, Final, Juara 3, ditulis "… tidak
  dimainkan.". Kalau kedua Semifinal sudah ada pemenang dan Final masih Belum, ditambah pemenang SF1 dan SF2 yang
  berbagi #1 (16.8). Contoh:
  - Data 16E, R7 lengkap (SF2 WO atau 4–6), R8 Belum: "Final dan Juara 3 tidak dimainkan. Andi · Budi dan Citra · Dewi
    sama-sama #1." (21z, latar 21o).
  - Semifinal belum lengkap (16E, SF1 6–4, SF2 Belum): "Semifinal, Final, dan Juara 3 tidak dimainkan." tanpa kalimat
    #1 (jawaban host 2026-11-18). 4 grup di Perempat final: "Perempat final, Semifinal, Final, dan Juara 3 tidak
    dimainkan."
  - Tanpa Perebutan juara 3 (atau 1 court dan Juara 3 sudah terisi), 16E dengan SF2 Indra · Joko 6–2 Citra · Dewi:
    "Final tidak dimainkan. Andi · Budi dan Indra · Joko sama-sama #1."
  - Final terisi, Juara 3 Belum: "Juara 3 tidak dimainkan."

### 16.10 Data & versi

Kebutuhan data (bentuknya diputuskan dba/tech lead):
- Format turnamen Fixed (round-robin / grup + gugur), jumlah grup, anggota tiap grup (urutan), court per grup (disimpan
  supaya jadwal tidak bergeser kalau aturan GU3 berubah).
- Tiap match: fase (grup + huruf, atau babak + nomor slot bagan).
- Format skor per babak gugur + juara 3 nyala/mati.
- Hasil Buat bagan: yang lolos per grup dan urutannya (termasuk pilihan host), penanda skor grup terkunci.
- Decode menolak data tidak konsisten (pasangan di dua grup, ukuran grup di luar G2, slot bagan berisi pasangan yang
  tidak lolos) → masuk `docs/security.md`.

Versi:
- **MINOR → 3.8.0.** Turnamen round-robin Fixed, Mixed, Mexicano, Sparing persis seperti 3.7.x; simpanan 3.7.x terbaca
  sebagai round-robin.
- Simpanan dan payload live Grup + Gugur **ditolak** app ≤ 3.7.x (GU15, seperti keputusan 46). `schemaVersion` tetap 2
  kalau kolom baru opsional; kalau dba perlu menaikkannya, kategorinya MAJOR dan harus kembali ke host.

### 16.11 Kriteria penerimaan

- **AC-G1** Grup + Gugur hanya ada di Fixed biasa: 2 grup mulai 12 pemain, 4 grup mulai 24 pemain; 10 pemain → tidak
  tersedia; 22 pemain → hanya 2 grup; Sparing, Mixed, Mexicano tidak menawarkan.
- **AC-G2** Layar Pasangan dibuka Manual; Acak bisa dipilih. Buat jadwal mati selama ada pasangan tanpa grup atau
  ukuran grup di luar G2 (7 pasangan 5 + 2 ditolak, 4 + 3 diterima; 13 pasangan 4 grup hanya 4 + 3 + 3 + 3).
- **AC-G3** 16A: R1–R6 Court 1 hanya Grup A, Court 2 hanya Grup B; tiap pasangan 3 match grup; estimasi 8 round, tidak
  lewat booking. Varian 1 court: 16 round, "lewat booking 02:00".
- **AC-G4** 16B: Court 1 A/C bergantian, Court 2 B/D; fase grup 6 round, total 10, "lewat booking 00:20"; tidak ada
  pasangan main di dua round beruntun. Varian 3 court 13 pasangan: Court 2 = B + D, fase grup 6 round.
- **AC-G5** 16C: Grup A di Court 1 + 3, Grup B di Court 2 + 4, fase grup 14 round, total 16. 6 pasangan 3 court: Court 3
  tanpa match.
- **AC-G6** Buat bagan tidak bisa ditekan selama satu match grup masih Belum (sejak 3.9.0 tampil sebagai tombol mati
  "Buat bagan · tunggu N match", AC-B1); aktif setelah semua Selesai/WO.
- **AC-G7** 16D-i → A2 Citra · Dewi lewat head-to-head, nomor tabel 1, 2, 2, 3. 16D-ii → A1 Andi · Budi. 16D-iii → host
  diminta memilih A2 dari tiga pasangan; tanpa pilihan bagan tidak bisa dibuat; app ditutup sebelum konfirmasi →
  pilihan tidak tersimpan.
- **AC-G8** Bagan 2 grup = A1–B2, B1–A2; 4 grup = A1–B2, C1–D2, B1–A2, D1–C2 dengan SF1 dari PF1/PF2. Untuk setiap
  huruf, peringkat 1 dan 2 grup itu ada di paruh berbeda.
- **AC-G9** 16E: pemenang maju begitu skor disimpan; match Final tidak bisa dibuka sebelum kedua SF terisi; ubah SF1 jadi
  4–6 sebelum R8 ada skor → Final dan juara 3 berganti sesuai 16E; sesudah Final terisi → ditolak; 6–5 → diterima.
- **AC-G10** Format per babak: Input Skor Final 16E menerima 9–7 (Race to 9), Perebutan juara 3 menolak 6–2 (Race to 4).
  Gugur Best of/Americano hanya menawarkan N ganjil.
- **AC-G11** WO di SF → lawan masuk Final; Klasemen grup tidak berubah.
- **AC-G12** Skor fase grup tidak bisa diubah setelah bagan dibuat (GU6), juga tidak bisa dikosongkan dan WO-nya tidak
  bisa dihapus (3.9.0, AC-K8).
- **AC-G13** 16F: peringkat akhir persis tabel 16F dan ketiga variannya (tanpa juara 3, diakhiri setelah R7, 4 grup).
- **AC-G14** Status Final setelah Final + Perebutan juara 3 terisi (atau Final saja kalau juara 3 mati); Sementara
  sebelumnya.
- **AC-G15** App di-kill di fase grup, setelah Buat bagan, dan di tengah gugur → dibuka lagi sama persis.
- **AC-G16** Simpanan 3.7.x dimuat sebagai round-robin; simpanan dan payload Grup + Gugur ditolak app 3.7.x tanpa crash.
  Semua test dan golden yang ada lulus tanpa diubah.
- **AC-G17** Live: penonton melihat match gugur dengan nama babak dan peringkat akhir, tanpa bagan dan tanpa aksi.
- **AC-G18** Bagikan: podium 16F = Citra · Dewi, Andi · Budi, Maya · Nanda; tanpa juara 3 = 4 anak tangga (#3 kembar).
- **AC-G19** Semua kriteria jalan offline (kecuali live).
- **AC-G20** (PATCH 3.8.1) Dialog Akhiri: 16A di R3 (data 20b) → "Match yang belum main tidak dihitung. Bagan tidak
  dibuat; peringkat dari posisi grup."; 16E R7 lengkap → "Final dan Juara 3 tidak dimainkan. Andi · Budi dan Citra ·
  Dewi sama-sama #1."; 16E hanya SF1 terisi → "Semifinal, Final, dan Juara 3 tidak dimainkan."; Final terisi, Juara 3
  Belum → "Juara 3 tidak dimainkan.".

### 16.12 Belum sekarang

- Grup + Gugur di Mixed, Mexicano, atau Sparing (keputusan 93, GU14).
- 3, 8, atau jumlah grup lain; bye di bagan; lebih dari 2 lolos per grup; peringkat 3 terbaik lintas grup.
- Unggulan (seed) otomatis; undi grup sebagai default (keputusan 95).
- Host memilih court per grup sendiri; urutan match yang menjamin tidak ada round beruntun di grup satu court.
- Gugur mulai per grup sebelum semua grup selesai; match gugur terbuka per match, bukan per round.
- Membuka lagi fase grup setelah bagan dibuat (GU6).
- Mengubah format babak gugur dan Perebutan juara 3 setelah jadwal dibuat (GU9, ditunda 3.8.x, keputusan 104;
  direncanakan 3.10.0, keputusan 120).
- Durasi match berbeda per babak (estimasi memakai satu durasi).
- Bagan di poster Bagikan dan di live score (keputusan 101).
- Seri di gugur (tiebreak/golden point dengan N genap); WO ganda.
- Round tambahan, Atur pasangan, pemain pengganti, Lanjutkan turnamen.
- Round-robin ganda di grup; grup + gugur tanpa court terkunci.

### 16.13 Keputusan & usulan

Keputusan host 2026-11-17: 93–101 di §10 (jangan dibuka ulang).

**Usulan PM — disetujui host 2026-11-17 (keputusan 102):**

- **GU1. Istilah:** format "Round-robin" / "Grup + Gugur"; fase "Fase grup" / "Gugur"; babak "Perempat final",
  "Semifinal", "Final", "Perebutan juara 3" (pendek "Juara 3"); grup "Grup A–D"; slot "A1", "B2"; bracket = "Bagan";
  tombol transisi "Buat bagan".
- **GU2.** Grup urut ukuran (yang lebih besar huruf lebih awal). Penempatan grup juga punya Acak (opsional, bukan
  default).
- **GU3.** Pembagian court 16.3: court ≥ grup → court sisa ke grup yang paling lama dan berkurang roundnya; tidak ada →
  court itu kosong di fase grup. Court < grup → grup ke court yang match-nya paling sedikit.
- **GU4.** Grup yang berbagi court bergantian satu match per round, urut huruf.
- **GU5.** Round bernomor terus lintas fase dengan kunci round Fixed; tab round gugur memakai nama babak; fase grup tanpa
  baris Istirahat (banyak pasangan memang menunggu); grup tiap match terbaca di Jadwal (bentuk oleh designer).
- **GU6.** Gugur dibuat lewat "Buat bagan" setelah semua match grup terisi, dengan dialog kunci; skor grup terkunci
  sesudahnya (Q2).
- **GU7.** Head-to-head satu kali, jumlah menang di antara yang seri saja; berlaku juga untuk seri di #1 (penentu A1/A2),
  bukan hanya batas 2 vs 3.
- **GU8.** Metode lolos = default format grup (keputusan 21), Klasemen grup tanpa toggle (Q1). Sejak 3.9.0 default
  Americano = Point % (keputusan 123, U-RP6).
- **GU9.** Format babak gugur default = format grup; N genap (Best of/Americano) jadi N + 1; gugur hanya N ganjil.
  Format babak dan juara 3 bisa diubah sampai babak itu punya skor — **ditunda ke 3.8.x** (keputusan 104): di 3.8.0
  format babak dan juara 3 hanya diatur di Konfigurasi.
- **GU10.** Court & round gugur 16.6: urut bagan di Court 1, 2, …; Final di Court 1, juara 3 di Court 2; 1 court →
  juara 3 dulu.
- **GU11.** Ubah skor gugur yang membalik pemenang hanya kalau match lanjutannya masih Belum.
- **GU12.** Peringkat akhir per tingkat babak, sisanya per posisi grup (16.8, Q3).
- **GU13.** Detail: statistik fase grup saja; riwayat semua match dengan nama babak.
- **GU14.** Sparing tidak menawarkan Grup + Gugur.
- **GU15.** App ≤ 3.7.x menolak simpanan/payload Grup + Gugur.
- **GU16.** Baris peringkat akhir (Klasemen, poster, caption) menulis babak yang dicapai, bukan nilai · selisih (Q3).

### 16.14 Pertanyaan untuk host (dijawab 2026-11-17: rekomendasi disetujui, keputusan 102)

- **Q1.** Saya pahami 2 besar grup ditentukan metode Klasemen, tapi sekarang host bisa mengganti tab Total Point / Win %
  dan urutan grup bisa berubah karenanya. Rekomendasi: lolos selalu memakai default format grup (Race to/Best of → Win
  %, Americano → Total Point) dan tab metode tidak ditampilkan di Klasemen grup, supaya yang tampil = yang lolos (GU8).
- **Q2.** Kalau skor grup diubah setelah bagan dibuat, yang lolos atau lawan di bagan bisa berubah padahal match gugur
  mungkin sudah jalan. Rekomendasi: skor grup dikunci saat Buat bagan dengan dialog konfirmasi; salah ketik ditemukan
  sebelum menekan Buat bagan (GU6).
- **Q3.** Juara 1–4 jelas dari bagan; yang belum jelas pasangan sisanya dan apa yang ditulis di barisnya. Rekomendasi:
  kalah perempat final satu nomor bersama, yang tidak lolos dikelompokkan per posisi grup (semua peringkat 3 grup satu
  nomor, dst.), dan tiap baris menulis babaknya ("Juara", "Semifinal", "Grup A · 3"), bukan poin (GU12, GU16).
- **Q4.** Kalau court lebih banyak dari grup (mis. 2 grup, 4 court), aturan "satu grup satu court" membuat court sisa
  menganggur. Rekomendasi: court sisa diberikan ke grup yang paling lama selesai, sehingga satu grup bisa memakai dua
  court tetap miliknya; kalau tidak mempercepat, court itu kosong di fase grup (GU3, 16C).

---

## 17. Rilis 3.9.0 — Kosongkan skor / Hapus WO + perilaku kecil

> **Diputuskan host 2026-11-18** (keputusan 113–121, §10), rilis **3.9.0 (MINOR)**. Isi: Kosongkan skor / Hapus WO
> (paket P7, temuan B-2 dan C-9, 17.1–17.9), empat perilaku kecil (paket P5: A-8, A-9, B-10, B-21, 17.10), dan tombol
> mati "Buat bagan" (C-17, 17.11). P6 visual (C-7, C-18, C-15) dan P4 (frame/catatan) ikut rilis ini tapi tidak
> mengubah aturan PRD. Sumber temuan: `design/review/ux-review*.md`. Aturan yang ditandai **U-n** adalah usulan PM yang
> disetujui host 2026-11-18 (17.8, keputusan 121).

### 17.0 Situasi nyata

- Host mengisi skor di HP sambil berdiri di pinggir lapangan, sering di sela-sela main, dengan dua sampai sepuluh court
  berjalan bersamaan. Salah ketuk court atau round terjadi: skor Court 1 masuk ke Court 2 yang masih main, atau WO
  ditandai di match yang akhirnya dimainkan karena pasangannya datang terlambat.
- Sampai 3.8.1, skor tersimpan hanya bisa **diganti** skor lain, dan WO hanya bisa **ditimpa** skor. Match yang salah
  terisi tetap "Selesai", jadi ikut menentukan Buat R(n+1), status Final, urutan Mexicano, Buat bagan, dan bagan gugur
  (B-2). Di gugur, pemenang Semifinal yang salah dan baru ketahuan setelah Final diisi tidak bisa dibetulkan sama
  sekali: Klasemen, poster, dan caption salah selamanya (C-9).
- Kesalahan biasanya ketahuan dalam hitungan menit (pemain protes melihat Jadwal atau live score), kadang baru di
  Klasemen/Bagikan setelah turnamen diakhiri.

### 17.1 Aturan inti

- **K1. Kosongkan skor:** match **Selesai** → **Belum**. Skornya dibuang (tidak disimpan sebagai skor lama). Hanya dari
  Input Skor mode ubah (17.2).
- **K2. Hapus WO:** match **WO** → **Selesai dengan skor lama** kalau match itu punya skor sebelum dijadikan WO (4.4:
  skor lama memang disimpan), selain itu → **Belum**. Pasangan WO dan alasannya dibuang.
- **K3.** Match WO tidak punya "Kosongkan skor" (U-3): di Input Skor match WO, mengosongkan kedua kotak membuat
  "Perbarui skor" mati seperti sekarang. Jalan untuk match WO = Hapus WO (sesudah itu, kalau kembali ke skor lama,
  skornya bisa dikosongkan).
- **K4.** Tiap aksi lewat satu dialog konfirmasi (17.2). Tidak ada urungkan; skor yang dikosongkan diketik ulang.
- **K5.** Tersedia atau tidaknya per mode: 17.3. Kalau tidak tersedia, Input Skor dan sheet WO tampil seperti 3.8.1
  ("Perbarui skor" mati saat kedua kotak kosong; tanpa "Hapus WO"), tanpa teks baru. Pengecualian gugur yang ditolak
  GU11: pesan 21l (17.2).
- **K6. Turnamen sudah diakhiri (U-1):** boleh, dengan batas 17.3 yang sama. Hasilnya **Tidak dimainkan**, bukan Belum,
  karena turnamen yang diakhiri tidak punya match Belum (4.5). Mixed dan Mexicano: Lanjutkan turnamen mengembalikannya
  ke Belum seperti match Tidak dimainkan lain. Fixed dan Grup + Gugur: tidak bisa dilanjutkan, jadi match itu tetap
  Tidak dimainkan.
- **K7.** Tidak ada aturan hitung baru: Klasemen, skor klub, status, Buat R(n+1), Buat bagan, bagan, poster, caption,
  Detail, dan live semuanya turunan dari match, jadi ikut berubah begitu match berubah (17.4).
- **K8.** Hanya HP host. Penonton live tidak punya aksi (5.11).

### 17.2 Tampilan & teks (bentuk final di hi-fi, frame baru dari designer)

**Input Skor, mode ubah (07i), match Selesai:**
- Angka dan ⌫ tetap mati sampai satu kotak diketuk (4.1). Kedua kotak dikosongkan dengan ⌫ → tombol "Perbarui skor"
  berubah jadi **"Kosongkan skor"** (sekunder, tinta clay), aktif. Hanya satu kotak kosong → "Perbarui skor" mati
  seperti sekarang. Satu angka diketik lagi → kembali "Perbarui skor".
- Best of dan Americano: mengosongkan satu kotak tidak mengisi atau mengosongkan kotak lain, karena skor tersimpan
  dihitung sebagai ketikan (4.1).
- Ketuk "Kosongkan skor" → dialog:
  - Judul **"Kosongkan skor Court 1?"** (nama court match itu, sama dengan judul Input Skor). Match gugur memakai kode
    match: "Kosongkan skor SF1?", "Kosongkan skor Final?", "Kosongkan skor Juara 3?" (seperti usulan C-9).
  - Isi **"Match kembali belum dimainkan."**; setelah diakhiri **"Match jadi tidak dimainkan."** (U-1). Match gugur
    yang mengisi match lain (PF, SF) menambah baris susunan baru seperti 21k ("Final: Pemenang SF1 vs Citra · Dewi").
  - Tombol **Batal** / **Kosongkan** (bahaya). Batal → kembali ke papan, kotak tetap kosong. Kosongkan → tersimpan,
    Input Skor tertutup ke Jadwal (seperti Simpan skor).
- Gugur yang ditolak (GU11, match lanjutannya sudah ada skor/WO): "Kosongkan skor" tampil tapi mati, dengan pesan 21l
  ("Final dan Juara 3 sudah ada skor · pemenang SF1 tetap Andi & Budi").

**Sheet WO (07j) dibuka dari match WO:**
- Aksi teks clay **"Hapus WO"** di kanan kepala sheet (pola "Hentikan" 12c / "Hapus" 08h). Tidak ada di sheet yang
  dibuka dari match Belum/Selesai, dan tidak ada kalau 17.3 tidak mengizinkan.
- Hapus WO berlaku untuk WO yang tersimpan, apa pun pilihan yang sedang diubah di sheet.
- Ketuk → dialog judul **"Hapus WO Court 2?"** (gugur: "Hapus WO SF2?"), isi: tanpa skor lama "Match kembali belum
  dimainkan."; dengan skor lama "Match kembali ke skor 6–4." (urut sisi atas–bawah seperti papan skor); diakhiri tanpa
  skor lama "Match jadi tidak dimainkan."; gugur yang mengisi match lain + baris susunan baru (21k). Tombol **Batal** /
  **Hapus** (bahaya). Hapus → sheet dan Input Skor tertutup ke Jadwal.
- Gugur yang ditolak GU11: "Hapus WO" mati, pesan 21l di sheet (seperti WO yang membalik pemenang sekarang).

Teks di atas usulan reviewer + PM; tidak ada kalimat penjelas lain (Prinsip "Tanpa Petunjuk", 7).

### 17.3 Kapan tersedia (per mode)

| Mode | Tersedia | Tidak tersedia |
|------|----------|----------------|
| Fixed round-robin, **Sparing Fixed** | Semua round, termasuk round tambahan (3.3a); sebelum dan sesudah diakhiri (K6) | — |
| **Mixed**, **Sparing Mixed** (U-2), **Mexicano** | Hanya match di **round terakhir** (`roundCount`); juga setelah diakhiri (K6) | Semua round sebelumnya |
| Grup + Gugur, **fase grup** | Semua match grup selama **bagan belum dibuat** (juga diakhiri di fase grup, K6) | Semua match grup **setelah Buat bagan** (GU6, keputusan 114) |
| Grup + Gugur, **gugur** | Match gugur Selesai/WO kalau tiap match yang diisinya (16.6) masih Belum atau Tidak dimainkan; Final dan Juara 3 selalu | PF/SF yang match lanjutannya sudah ada skor/WO → pesan 21l |

- Selalu tidak tersedia: match Tidak dimainkan (tidak bisa dibuka, tetap), match gugur bersisi "Pemenang SF1" (tidak
  bisa dibuka, tetap), halaman penonton.
- **Mixed/Mexicano, round lama — apa adanya (keputusan 114 tidak menambah jalan baru):** skor di round sebelum round
  terakhir hanya bisa **diganti** (Perbarui skor) atau **ditimpa WO**, tidak bisa dikosongkan. Satu-satunya jalan:
  kalau round terakhir belum ada skor sama sekali (dan bukan R1, belum diakhiri), **Batalkan Rn** membuat round
  sebelumnya jadi round terakhir, lalu match di sana bisa dikosongkan. Jalan ini hanya **satu round ke belakang**:
  round itu sudah ada skor, jadi tidak bisa dibatalkan lagi. Round terakhir yang sudah punya satu skor: round
  sebelumnya tidak bisa dikosongkan sama sekali. Celah ini masuk 17.7 dan pertanyaan 17.9.
- Grup + Gugur setelah bagan: match grup memang masih bisa dibuka ke Input Skor (3.8.1), tapi tidak bisa diubah
  (AC-G12); Kosongkan skor dan Hapus WO juga tidak muncul di sana.

### 17.4 Dampak (semua turunan, K7)

| Bagian | Setelah Kosongkan skor / Hapus WO |
|--------|-----------------------------------|
| Status match | Selesai/WO → Belum (diakhiri: Tidak dimainkan). Hapus WO dengan skor lama → Selesai. Baris Jadwal menulis status itu; alasan WO hilang. |
| Klasemen (4.2–4.3, 5.7) | Dihitung ulang tanpa match itu: Main, W–L–D, +/−, nilai metode, nomor. Pemain/pasangan yang tidak punya match Selesai/WO lagi pindah ke "Belum main" tanpa nomor. Hapus WO tanpa skor lama: nilai WO pemenang hilang (selisih memang tidak berubah, 4.4). |
| Skor klub Sparing (13.5) | Hasil match itu (1, ½, atau WO) dan Total Point klub/selisihnya hilang; papan Jadwal, Klasemen, Beranda, poster, caption, live ikut. |
| Kunci round Fixed / fase grup / gugur (3.2 A) | Round match itu jadi round berjalan lagi. Round sesudahnya **terkunci lagi**: tetap terlihat pudar dengan skornya (skor itu tetap dihitung), tidak bisa dibuka ke Input Skor sampai match itu terisi. Catatan kunci menyebut **round paling akhir yang belum lengkap sebelum round yang dilihat** ("Terbuka setelah semua skor R3 terisi"); tanpa match yang dikosongkan hasilnya sama dengan sekarang (R(n−1)). Hitung mundur sisa booking pindah ke round berjalan. |
| Buat R(n+1) (Mixed, Mexicano) | Round terakhir tidak lengkap → "Buat R4 · tunggu 1 match" (pola 13m). |
| Batalkan Rn (Mixed, Mexicano) | Semua match round terakhir jadi Belum → Batalkan Rn tersedia (kalau bukan R1). |
| Tukar pemain (Mixed, §15) | Match yang jadi Belum di round terakhir bisa ditukar (T2). Mexicano tetap tanpa tukar. |
| Kelola court (Mixed) | Court bernomor terakhir yang tidak punya skor/WO lagi bisa dihapus (aturan 08h tetap). |
| Tambah round (Fixed, 3.3a) | Hanya ada selama semua match terisi → hilang lagi sampai match itu terisi. Round tambahan yang sudah dibuat tidak berubah. |
| Buat bagan (Grup + Gugur) | Kembali jadi tombol mati "Buat bagan · tunggu N match" (17.11). |
| Bagan gugur (16.6) | Sisi match lanjutan kembali "Pemenang SF1" / "Kalah SF1" (pemenang maju dihitung ulang, `KnockoutBracket.resolve`). |
| Peringkat akhir Grup + Gugur (16.8) | Dihitung ulang: pasangan di babak tanpa hasil di tingkat tepat di atas yang kalah di babak itu. |
| Urutan Mexicano (14.3) | Round yang sudah dibuat tidak dibuat ulang (14.7, U6); round berikutnya memakai Klasemen saat Buat ditekan. Kelola court saat round berjalan memakai Klasemen saat itu (tanpa match yang dikosongkan). |
| Sementara / Final (4.6) | Fixed: semua match terisi → Final; dikosongkan → **Sementara** lagi (kecuali sudah diakhiri). Mixed/Mexicano: round terakhir tidak lengkap → Sementara. Grup + Gugur: Final/Juara 3 dikosongkan → Sementara. Diakhiri → tetap Final. |
| Live score (5.11) | Ikut terkirim seperti perubahan lain. Penonton melihat match Belum; tag "Live" muncul lagi kalau status kembali Sementara (dicek tiap menit setelah Final, jadi sampai satu menit). |
| Bagikan & caption (5.9) | Dibuat ulang saat dibuka: "Klasemen sementara" kalau status Sementara; podium dan baris dari Klasemen baru. |
| Detail pemain (5.8) | Match itu hilang dari riwayat; statistik, Beda partner/Beda lawan (17.10 B-21), dan peringkat dihitung ulang. |
| Beranda | Info round dan skor klub sparing mengikuti. |
| Simpanan | Tidak ada kolom baru; auto-save seperti mutasi lain (5.10). |

### 17.5 Contoh hitung

**Contoh 17A — Sparing Fixed, data 13C** (Padel, Race to 6; Final, PB Garuda 7 – 5 Matcha Club).

*17A-i, Kosongkan R6 Court 2* (Gita · Hadi 5–6 Maya · Nanda, skor diketik padahal match belum dimainkan):
- Dialog "Kosongkan skor Court 2?" · "Match kembali belum dimainkan." → Kosongkan.
- Skor klub **PB Garuda 7 – 4 Matcha Club**. Total Point klub: Garuda 56 − 5 = **51 · +14**, Matcha 49 − 6 = **43 ·
  −14**. 11 dari 12 match → **Sementara** ("R6 · 11 dari 12 match"); "Tambah round" hilang.
- Klasemen Garuda (Total Point): #1 Eko · Fajar 18 (+11) · #2 Andi · Budi 14 (+1) · #3 Citra · Dewi 10 (+3) · #4 Gita
  · Hadi 9 (−1) (dulu #3 dengan 14, −2). Matcha: #1 Maya · Nanda 17 (+3, 2 menang termasuk 1 WO) · #2 Kiki · Lina 16
  (−3) · #3 Indra · Joko 10 (−14).
- Caption "🏆 PB Garuda 7–4 Matcha Club · Padel", poster "Klasemen sementara"; penonton melihat R6 Court 2 Belum dan
  tag Live.

*17A-ii, Hapus WO R3 Court 2* (round lama, Fixed boleh; WO Citra · Dewi absen, tanpa skor lama; dari data 13C utuh):
- Sheet WO → "Hapus WO" → dialog "Hapus WO Court 2?" · "Match kembali belum dimainkan." → Hapus → R3 Court 2 Belum.
- Skor klub **PB Garuda 7 – 4 Matcha Club**; Total Point Matcha 49 − 6 (nilai WO) = **43**, selisih tetap −13; Garuda
  56 · +13.
- R3 jadi round berjalan; R4–R6 terkunci lagi tapi skornya tetap dihitung. Catatan di R4, R5, dan R6 sama-sama
  "Terbuka setelah semua skor R3 terisi" (R4 dan R5 lengkap). Hitung mundur sisa booking tampil di R3.
- Detail Maya · Nanda: riwayat tanpa R3; Main 4 → 3; Total Point 23 → 17; Beda lawan 8 / 8 → **6 / 8** (Citra · Dewi
  hanya dilawan di R3, B-21).

*17A-iii, diakhiri (K6):* 13C diakhiri setelah R6 lengkap, lalu R6 Court 2 dikosongkan → dialog "Match jadi tidak
dimainkan." → Tidak dimainkan; status tetap **Final**; skor klub 7 – 4; catatan Klasemen "tidak dimainkan" seperti
match lain yang tidak dimainkan.

**Contoh 17B — Mixed** (8 pemain Andi, Budi, Citra, Dewi, Eko, Fajar, Gita, Hadi; 2 court; Americano 21; R3 round
terakhir). R3 Court 1 Andi · Eko 13–8 Budi · Fajar; R3 Court 2 Citra · Gita 11–10 Dewi · Hadi diketik padahal Court 2
masih main. "Buat R4" sudah aktif.
- Kosongkan R3 Court 2 → "Buat R4 · tunggu 1 match"; Citra dan Gita −11 poin dan +/− turun 1, Dewi dan Hadi −10 poin dan
  +/− naik 1. Ikon tukar muncul di Court 2 (Mixed, §15). Batalkan R3 tidak tersedia (Court 1 sudah ada skor).
- Seandainya R4 sudah dibuat dan **belum ada skor**: Batalkan R4 → R3 round terakhir → Kosongkan R3 Court 2 → tunggu
  hasil → Buat R4 (round dibuat dari riwayat terbaru).
- Seandainya R4 Court 1 **sudah ada skor**: R3 Court 2 hanya bisa diganti (Perbarui skor) atau dijadikan WO.
- Sparing Mixed: sama, ditambah skor klub seperti 17A.

**Contoh 17C — Mexicano, data 14A.** R2 round terakhir, R2 Court 2 terisi 8–13. Kosongkan → "Buat R3 · tunggu 1
match"; Klasemen dan urutan Mexicano tanpa R2 Court 2. Setelah R3 dibuat: R2 Court 2 hanya bisa dikoreksi (14.7). R3
belum ada skor: Batalkan R3 → R2 Court 2 bisa dikosongkan atau dikoreksi → Buat R3 memakai urutan yang baru.

**Contoh 17D — Grup + Gugur fase grup, data 16A / 20b** (R1–R2 lengkap, R3 Court 1 terisi, R3 Court 2 Belum; 5 dari
12 match grup).
- Kosongkan R1 Court 1 (Andi · Budi 4–6 Gita · Hadi) → R1 round berjalan, R2 dan R3 terkunci (R3 Court 1 tetap 6–3 dan
  dihitung); tombol "Buat bagan · tunggu 8 match".
- Semua 12 match terisi ("Buat bagan" aktif) → Kosongkan R6 Court 2 → "Buat bagan · tunggu 1 match".
- Setelah Buat bagan: R1–R6 tanpa "Kosongkan skor" dan tanpa "Hapus WO".

**Contoh 17E — gugur, data 16E** (SF1 Andi · Budi 6–4 Maya · Nanda; SF2 Indra · Joko 4–6 Citra · Dewi).
- *R8 masih Belum:* Kosongkan SF1 → dialog "Kosongkan skor SF1?" · "Match kembali belum dimainkan." · "Final: Pemenang
  SF1 vs Citra · Dewi" · "Juara 3: Kalah SF1 vs Indra · Joko" → Kosongkan → SF1 Belum, R8 terkunci lagi, Final dan
  Juara 3 tidak bisa dibuka.
- *Final 7–9 dan Juara 3 4–2 sudah tersimpan (Final), lalu ketahuan SF1 sebenarnya 4–6 (C-9):* di SF1, mengosongkan
  kedua kotak → "Kosongkan skor" mati + "Final dan Juara 3 sudah ada skor · pemenang SF1 tetap Andi & Budi".
  Jalannya:
  1. Kosongkan Final → "Kosongkan skor Final?" · "Match kembali belum dimainkan." → **Sementara**; peringkat: #1 Andi ·
     Budi + Citra · Dewi ("Final"), #2 Maya · Nanda ("Juara 3"), #3 Indra · Joko ("Semifinal"), #4 Eko · Fajar + Kiki ·
     Lina, #5 Gita · Hadi + Oki · Putri.
  2. Kosongkan Juara 3 → #1 Andi · Budi + Citra · Dewi, #2 Maya · Nanda + Indra · Joko ("Perebutan juara 3"), #3
     posisi 3, #4 posisi 4 (sama dengan varian 16F "diakhiri setelah R7").
  3. SF1 Perbarui skor 4–6 → dialog GU11 "Ganti pemenang SF1?" → Final: Maya · Nanda vs Citra · Dewi; Juara 3: Andi ·
     Budi vs Indra · Joko (16E). Aturan GU11 tidak berubah.
  4. Final dan Juara 3 diisi lagi → Final.
- *WO:* SF2 WO (Indra · Joko absen, tanpa skor lama), R8 Belum → "Hapus WO SF2?" · "Match kembali belum dimainkan." ·
  "Final: Andi · Budi vs Pemenang SF2" · "Juara 3: Maya · Nanda vs Kalah SF2". SF2 yang dulu 4–6 lalu dijadikan WO
  dengan Citra · Dewi absen: Hapus WO mengembalikan 4–6, pemenang berganti ke Citra · Dewi → susunan baru di dialog
  kalau R8 Belum; kalau R8 sudah ada skor → "Hapus WO" mati + pesan 21l.

### 17.6 Kriteria penerimaan (Kosongkan skor / Hapus WO)

- **AC-K1** Input Skor match Selesai: setelah kotak diketuk dan kedua kotak dikosongkan dengan ⌫, tombol berbunyi
  "Kosongkan skor" (sekunder, clay) dan aktif; satu kotak saja kosong → "Perbarui skor" mati; mengetik satu angka →
  "Perbarui skor". Match Belum (Simpan skor) dan match WO tidak pernah menampilkan "Kosongkan skor".
- **AC-K2** Dialog "Kosongkan skor Court 2?" · "Match kembali belum dimainkan." · Batal / Kosongkan. Batal → papan,
  tidak ada yang tersimpan. Kosongkan → Jadwal, match Belum tanpa skor.
- **AC-K3** Sheet WO dari match WO punya "Hapus WO" di kanan kepala; dari match Belum/Selesai tidak. Hapus WO tanpa skor
  lama → Belum; dengan skor lama 6–4 → Selesai 6–4, dialog "Match kembali ke skor 6–4."; alasan WO hilang dari baris
  Jadwal.
- **AC-K4** 17A-i: skor klub 7 – 4, Total Point klub 51 · +14 dan 43 · −14, Sementara "11 dari 12 match", Klasemen
  Garuda persis 17A-i, caption "🏆 PB Garuda 7–4 Matcha Club · Padel".
- **AC-K5** 17A-ii: Fixed round lama boleh; R4–R6 terkunci dengan skor tetap dihitung; catatan "Terbuka setelah semua
  skor R3 terisi" di R4, R5, dan R6; Detail Maya · Nanda Beda lawan 6 / 8.
- **AC-K6** Mixed dan Mexicano: Kosongkan skor dan Hapus WO hanya muncul di round terakhir; di round sebelumnya
  mengosongkan kedua kotak membuat "Perbarui skor" mati dan sheet WO tanpa "Hapus WO". 17B: "Buat R4 · tunggu 1
  match", ikon tukar di Court 2 (bukan Mexicano); Batalkan R4 tanpa skor membuat R3 bisa dikosongkan.
- **AC-K7** Semua match round terakhir Mixed dikosongkan (bukan R1) → Batalkan Rn tersedia.
- **AC-K8** Grup + Gugur: 17D persis ("tunggu 8 match", "tunggu 1 match"); setelah Buat bagan tidak ada Kosongkan skor /
  Hapus WO di match grup.
- **AC-K9** 17E: Kosongkan SF1 dengan R8 Belum → dialog dengan dua baris susunan baru, sisi Final kembali "Pemenang
  SF1"; dengan Final berskor → tombol mati + pesan 21l; urutan Final → Juara 3 → SF1 4–6 menghasilkan peringkat dan
  susunan persis 17E.
- **AC-K10** Fixed semua match terisi (Final, Tambah round tampil) → Kosongkan satu match → Sementara, Tambah round
  hilang; diisi lagi → Final dan Tambah round kembali.
- **AC-K11** Diakhiri (K6): Fixed → match Tidak dimainkan, status tetap Final, dialog "Match jadi tidak dimainkan.";
  Mixed → Tidak dimainkan, lalu Lanjutkan turnamen → Belum.
- **AC-K12** Live: penonton melihat perubahan pada kiriman berikutnya; tag Live muncul lagi kalau status kembali
  Sementara. Penonton tidak punya aksi.
- **AC-K13** App ditutup sesudah Kosongkan / Hapus WO → dibuka lagi dengan match Belum (atau skor lama). Simpanan dibaca
  app 3.8.1 tanpa ditolak (tidak ada kolom baru).
- **AC-K14** Semua kriteria jalan offline.

### 17.7 Belum sekarang

- Mengosongkan skor/WO di round lama Mixed/Mexicano selain lewat Batalkan Rn satu round (keputusan 114; pertanyaan
  17.9 Q1).
- Mengosongkan match grup setelah bagan dibuat (GU6).
- Urungkan setelah Kosongkan/Hapus WO; riwayat perubahan skor.
- Kosongkan banyak match sekaligus atau satu round penuh dari Jadwal.
- Kosongkan dari baris Jadwal (geser/tekan lama) tanpa membuka Input Skor.
- Membuat ulang round Mixed/Mexicano yang sudah dibuat setelah skor dikoreksi (14.7, U6).

### 17.8 Usulan PM (disetujui host 2026-11-18, keputusan 121)

- **U-1.** Setelah diakhiri: boleh, hasilnya Tidak dimainkan, isi dialog "Match jadi tidak dimainkan." (K6). Alasan:
  kesalahan sering baru terlihat di Klasemen/Bagikan, dan Fixed tidak bisa dilanjutkan.
- **U-2.** Sparing Mixed ikut batas Mixed (round terakhir), karena keputusan 114 menyebut mode, dan Sparing Mixed memakai
  mesin Mixed.
- **U-3.** Match WO tidak punya Kosongkan skor; jalannya Hapus WO (K3), supaya satu aksi = satu akibat.
- **U-4.** Judul dialog gugur memakai kode match ("SF1", "Final"), selain itu nama court; dialog Hapus WO "Hapus WO
  Court 2?" · Batal / Hapus dengan isi akibatnya (17.2).
- **U-5.** Catatan kunci round menyebut round paling akhir yang belum lengkap sebelum round yang dilihat (17.4).

### 17.9 Pertanyaan untuk host (dijawab 2026-11-18: rekomendasi disetujui, keputusan 121)

- **Q1.** Sebelumnya disampaikan bahwa round lama Mixed tetap bisa dibetulkan lewat "Batalkan Rn"; setelah dicek, itu
  hanya berlaku satu round ke belakang dan hanya kalau round terbaru belum ada skor sama sekali. Selain itu, skor round
  lama Mixed/Mexicano hanya bisa diganti atau dijadikan WO. Rekomendasi: terima apa adanya untuk 3.9.0 (batas
  keputusan 114 tetap) dan lihat dulu apakah host benar butuh lebih.
- **Q2.** Kalau turnamen sudah diakhiri, saya usulkan Kosongkan skor/Hapus WO tetap boleh dan match jadi "Tidak
  dimainkan" (U-1), karena salah skor sering baru terlihat saat membagikan hasil. Rekomendasi: setujui.
- **Q3.** Di Fixed, mengosongkan match di round lama membuat round sesudahnya terkunci lagi sampai match itu diisi
  (skornya tetap dihitung, hanya tidak bisa dibuka). Rekomendasi: terima, karena itu aturan kunci round yang sudah ada
  dan host memang akan mengisi ulang match itu.

### 17.10 Perilaku kecil (P5)

**A-8 "Hapus semua" tanpa dialog, dengan Urungkan (Pemain 02b, keputusan 115).**
- Toolbar tetap dua tombol. Kotak kosong: "Tempel · Contoh". Kotak berisi: "Tempel" … "Hapus semua" (clay). Hapus semua
  langsung mengosongkan kotak, tanpa dialog; toolbar jadi **"Tempel · Urungkan"** (ikon `arrow-counter-clockwise` di
  tempat Contoh).
- Urungkan mengembalikan teks persis seperti sebelum Hapus semua (termasuk baris duplikat yang dibuang parser), lalu
  toolbar kembali "Tempel" … "Hapus semua".
- Urungkan hilang begitu isi kotak berubah dengan cara lain (ketikan, Tempel). Kotak kembali kosong sesudah itu →
  "Tempel · Contoh". Hanya Hapus semua terakhir yang bisa diurungkan; keluar dari layar membuangnya.
- Sparing: berlaku per kotak klub.
- Contoh: 12 nama → Hapus semua → kotak kosong, daftar hilang, Lanjut mati, "Tempel · Urungkan" → Urungkan → 12 nama
  kembali, Lanjut aktif. Hapus semua → ketik "R" → toolbar "Tempel" … "Hapus semua", Urungkan tidak ada lagi.

**A-9 Dialog buang pasangan (Pasangan 04b, Atur pasangan 04f–04g, keputusan 116).**
- Manual → Acak saat ada **N ≥ 1 pasangan manual yang sudah jadi**: dialog **"Buang N pasangan manual?"** · Batal /
  Buang (bahaya). Batal → tetap Manual, pasangan dan pilihan yang sedang berjalan utuh. Buang → Acak (pasangan acak
  baru). Belum ada pasangan jadi (paling banyak satu pemain terpilih) → langsung Acak tanpa dialog.
- Acak → Manual: **tanpa dialog** (pasangan acak bisa dibuat lagi); daftar kosong seperti sekarang.
- Atur pasangan (sebelum round tambahan): ← (tombol, back HP, back browser) saat susunan pasangan atau nama pengganti
  berbeda dari saat layar dibuka → dialog **"Buang perubahan pasangan?"** · Batal / Buang (bahaya). Batal → tetap di
  layar. Buang → keluar tanpa perubahan. Tidak ada perubahan → keluar tanpa dialog.
- Berlaku juga di layar Pasangan Sparing Fixed (N = jumlah pasangan manual kedua klub) dan layar Pasangan Grup + Gugur
  (dibuka Manual, keputusan 95). Layar **Grup** (penempatan pasangan ke grup, 19-an) **tanpa dialog**, sesuai Cakupan
  hi-fi (keputusan 103).
- Contoh: 10 pemain, Manual, Andi · Budi, Citra · Dewi, Eko · Fajar jadi, Gita terpilih → ketuk Acak → "Buang 3
  pasangan manual?" → Batal → tiga pasangan + Gita terpilih tetap. Hanya Gita terpilih → Acak langsung. Atur pasangan:
  "Ubah" Andi P · Budi S, ketik Rizky H → ← → "Buang perubahan pasangan?".

**B-10 Bagikan gagal → unduh dua gambar + salin hasil (Bagikan, keputusan 117; mengubah aturan 2026-10-22).**
- Share sheet sistem gagal/tidak ada (desktop, browser tertentu): kedua PNG **diunduh** dengan nama yang sudah ada
  (`match-addict-feed-1080x1080.png`, `match-addict-story-1080x1920.png`), caption **disalin**, toast **"Gambar
  diunduh · hasil disalin"**. Tidak ada tombol baru (tetap tanpa tombol salin terpisah).
- Host menutup share sheet tanpa memilih aplikasi = bukan gagal: tidak ada unduhan dan tidak ada toast.
- Gambar gagal dibuat (render): tidak ada yang diunduh; caption disalin + "Hasil disalin" seperti sekarang.
- Android/iOS app: share sheet sistem selalu ada; kalau tetap gagal, perilaku sama hanya kalau gambar bisa disimpan
  tanpa izin atau dependensi baru, selain itu tetap "Hasil disalin" (dicek tech lead, cek web dengan
  `tool/build_web.sh` + Chrome).

**B-21 Lawan dan partner WO dihitung di Detail (keputusan 118, kode tidak berubah).**
- "Beda partner" dan "Beda lawan" di Detail dihitung dari match **Selesai dan WO**, kedua sisi WO ikut (sama dengan
  kolom Main). Match Belum dan Tidak dimainkan tidak dihitung.
- Contoh 13C: Maya · Nanda melawan Eko · Fajar (R2), Citra · Dewi (R3, WO), Andi · Budi (R5), Gita · Hadi (R6) →
  Beda lawan **8 / 8**, bukan 6 / 8. Hi-fi 10b (Citra L · Dewant R dari WO R2) juga 8 / 8.

**Kriteria penerimaan P5:**
- **AC-P1** Hapus semua tanpa dialog; toolbar "Tempel · Urungkan"; Urungkan mengembalikan teks persis; ketikan atau
  Tempel menghapus Urungkan; kotak kosong lagi → "Tempel · Contoh".
- **AC-P2** Manual → Acak dengan 3 pasangan → "Buang 3 pasangan manual?"; Batal tidak mengubah apa pun; Buang → Acak.
  0 pasangan → tanpa dialog. Acak → Manual tanpa dialog. Layar Grup tanpa dialog.
- **AC-P3** Atur pasangan: ← / back HP / back browser dengan perubahan → "Buang perubahan pasangan?"; tanpa perubahan →
  langsung keluar.
- **AC-P4** Web tanpa share sheet: dua file dengan nama di atas terunduh, clipboard berisi caption, toast "Gambar
  diunduh · hasil disalin". Share sheet ditutup → tidak ada unduhan dan toast.
- **AC-P5** Detail Maya · Nanda (13C) Beda lawan 8 / 8.

### 17.11 Tombol mati "Buat bagan" (C-17, keputusan 119)

- Grup + Gugur fase grup, belum diakhiri, bagan belum dibuat, masih ada match grup **Belum**: action bar = ikon
  Klasemen + tombol mati **"Buat bagan · tunggu N match"** (pola "Buat R4 · tunggu 1 match", 13m).
- **N = jumlah match grup Belum di semua round grup**, bukan hanya round berjalan.
- N = 0 → "Buat bagan" aktif (20e, tetap). Diakhiri → tidak ada Buat bagan (tetap). Penonton live → tanpa tombol.
- Beda dengan Fixed 06v yang menyembunyikan "Tambah round": Tambah round opsional, Buat bagan langkah wajib.
- Contoh 20b (5 dari 12 match grup): "Buat bagan · tunggu 7 match"; R3 Court 2 diisi → "tunggu 6 match"; 12 terisi →
  "Buat bagan" aktif; satu dikosongkan (17D) → "tunggu 1 match".
- **AC-B1** 20b menampilkan ikon Klasemen + "Buat bagan · tunggu 7 match" mati; hitungannya turun tiap match grup diisi
  dan naik tiap match grup dikosongkan; tidak tampil setelah diakhiri dan di halaman penonton.

### 17.12 Data & versi

- **MINOR → 3.9.0.** Tidak ada kolom simpanan baru; `schemaVersion` tetap 2. Kosongkan = status Belum tanpa skor; Hapus
  WO = status Selesai/Belum tanpa pasangan WO dan alasan (bentuk yang sudah ada).
- Keadaan baru yang belum pernah ada: Fixed/fase grup dengan round lama Belum sementara round sesudahnya berskor, dan
  match gugur Belum dengan match lanjutan berisi sisi "Pemenang …". Simpanan dan payload live seperti ini harus tetap
  terbaca oleh app 3.9.0, app 3.8.x, dan halaman penonton (cek decoder, `docs/data.md`, `docs/security.md`).
- Turnamen 3.8.x terbuka di 3.9.0 tanpa perubahan; semua test dan golden lama lulus kecuali frame yang memang berubah
  (02b, 04b, 04g, 07i, 07j, 11c, 20b).

---

## 18. Point % — metode peringkat ketiga (3.9.0)

> **Diputuskan host 2026-11-20** (keputusan 122–126, §10; "setuju 4 usulan. tapi gw mau Total Point tetap ada sebagai
> pilihan"), ikut rilis **3.9.0 (MINOR)** sebagai jalur terpisah (task RP-n). Aturan bertanda **U-RPn** adalah usulan
> PM yang disetujui host 2026-11-20 (keputusan 129, 18.8).
> Desain layar menyusul dari designer; hi-fi diubah setelah frame disetujui.

### 18.0 Situasi nyata

- Mixed dan Mexicano di klub hampir selalu punya pemain lebih banyak dari slot court (10 pemain di 2 court → 2
  istirahat per round), ada yang datang telat (menyusul, 3.4) dan ada yang pulang duluan. Jumlah main antar pemain
  berbeda sampai beberapa match sepanjang turnamen.
- Total Point menjumlah poin, jadi pemain yang mainnya lebih sedikit tertinggal karena kurang main, bukan karena kalah.
  Simulasi main session (2026-11-20, 600 turnamen per skenario): rata-rata 0,7–1,3 posisi di bawah kemampuannya.
  Di Mexicano akibatnya terasa langsung: yang baru istirahat turun ke court bawah (14B).
- Win % adil terhadap jumlah main tapi kasar di Americano, tempat tiap poin memang tujuannya: menang 11–10 dan 21–0
  sama nilainya, dan nilai kembar 7–19% baris (nomor sama atau hanya dipisah selisih).
- Host bertanya apakah "persen poin terhadap jumlah main" bisa menangani jumlah main yang tidak sama, dan ingin Total
  Point tetap bisa dipilih (kebiasaan klub: "siapa paling banyak poin malam ini").
- Semua tetap di satu HP host, offline; penonton live memilih metode sendiri.

### 18.1 Aturan inti

- **RP1. Rumus.** Point % = Σ game/poin didapat ÷ Σ game/poin dimainkan × 100, dengan dimainkan = didapat + kalah,
  dijumlah dari semua match **Selesai** dan **WO** pemain itu (Belum dan Tidak dimainkan tidak dihitung, 4.5). Satuan
  ikut format skor: Race to/Best of = game, Americano = poin. Contoh: 12–9 dan 10–11 → (12 + 10) ÷ (21 + 21) = 52%.
- **RP2. Seri** dihitung apa adanya dari poin: 10–10 → 50%. W–L–D tidak dipakai Point %.
- **RP3. WO** = skor "nilai WO – 0" (keputusan 125, 18.3).
- **RP4. Pemisah dan nomor** sama dengan 4.3: Point % (angka bulat yang tampil, 18.2) → selisih → nomor sama, baris
  diurutkan nama; nomor rapat #1, #2, #2, #3. Total Point dan Win % tidak dipakai sebagai pemisah.
- **RP5. Belum main** (0 match Selesai/WO): tetap di grup "Belum main" tanpa nomor, seperti 4.3. Tidak ada pembagian
  dengan nol: setiap match Selesai punya total ≥ 1 (pemenang minimal ⌊N ÷ 2⌋ + 1, Race to minimal N) dan setiap nilai
  WO ≥ 1, jadi pemain yang punya match selalu punya dimainkan ≥ 1. Urutan Mexicano memakai 0% untuk yang belum main
  (14.3, U-RP4).
- **RP6. Default** (keputusan 123): Race to dan Best of → Win %; Americano → Point % (Fixed, Mixed, Mexicano, Sparing
  per klub, penonton live). Pilihan tab tetap tidak disimpan (4.2).
- **RP7. Tab** (U-RP1): **Total Point · Point % · Win %** di Klasemen host, Klasemen per klub Sparing, dan Klasemen
  penonton. Grup + Gugur tetap tanpa tab (GU8).
- **RP8. Urutan Mexicano** (keputusan 124): Point % → selisih → undian terkunci, apa pun tab (14.3).
- **RP9.** Point % hanya turunan dari match yang tersimpan, seperti Total Point dan Win % (K7 §17): Kosongkan skor,
  Hapus WO, koreksi skor, Tukar pemain, dan Batalkan Rn langsung mengubah Point % tanpa aturan tambahan.

### 18.2 Angka yang tampil dan pembanding (U-RP2)

- Point % tampil **bulat tanpa desimal**, ,5 ke atas, di semua tempat: Klasemen, Detail, poster, caption, penonton
  live. Sama dengan Win % di app (Detail Win % juga bulat, rekomendasi B-18 2026-11-20).
- Hitungan bulat memakai bilangan bulat, bukan pecahan desimal, supaya semua HP dan web sama:
  `bulat = (200 × didapat + dimainkan) ÷ (2 × dimainkan)`, sisa dibuang. 5 ÷ 8 = 62,5% → **63%**; 44 ÷ 84 = 52,38% →
  **52%**.
- **Nomor dibandingkan dari angka bulat ini**, lalu selisih (keputusan 17: nomor hanya dari angka yang tampil). Kalau
  dibandingkan dari nilai persis, dua baris "52%" dengan selisih sama bisa bernomor beda tanpa alasan terlihat, dan
  baris "52% · +1" bisa di atas "52% · +5". Akibatnya nomor sama sedikit lebih sering daripada di simulasi (0,3–2%,
  nilai persis), tapi selalu terbaca.
- Di Americano dengan jumlah main sama dan semua match sampai total N, selisih naik bersama poin, jadi urutan tetap
  sama dengan Total Point walaupun dua persen bulat sama.
- Win % tidak berubah: dibandingkan dari nilai persis seperti sebelum 3.9.0.

### 18.3 WO (keputusan 125)

- Pemenang WO: didapat + **nilai WO dia sendiri** (4.4: Race to N → N; Best of/Americano → rata-rata skor match yang dia
  mainkan, bulat ,5 ke atas, minimal ⌊N ÷ 2⌋ + 1; belum pernah main → ⌊N ÷ 2⌋ + 1), kalah + 0.
- Pasangan WO: didapat + 0, kalah + **nilai WO pasangan lawan**. Fixed dan Race to: satu angka (kedua pemenang selalu
  sama). Mixed/Mexicano/Sparing Mixed dengan Best of/Americano: rata-rata nilai kedua pemenang, bulat ,5 ke atas (rumus
  K11, 13.5).
- Selisih tetap tidak berubah oleh WO (4.4), dan Total Point tetap seperti sekarang.
- Akibat yang terlihat: menang WO menaikkan Point % ke arah 100%, kalah WO menurunkannya; pemain yang hanya punya WO =
  100% (menang) atau 0% (kalah). Nilai WO pemenang ikut berubah tiap dia main lagi (4.4), jadi Point %-nya juga.

### 18.4 Contoh hitung

**Contoh 18A — Americano 21, jumlah main tidak sama** (Padel, Mixed, 5 pemain, 1 court, 4 round; tiap round satu
istirahat menurut prioritas 3.4: R1 Eko, R2 Dewi, R3 Citra, R4 Budi).

| Round | Match | Skor |
|-------|-------|------|
| R1 | Andi · Budi vs Citra · Dewi | 12–9 |
| R2 | Andi · Citra vs Budi · Eko | 10–11 |
| R3 | Andi · Eko vs Budi · Dewi | 8–13 |
| R4 | Andi · Dewi vs Citra · Eko | 11–10 |

| Pemain | Main | W–L | Didapat / kalah | +/− | Total Point | Point % | Win % |
|--------|------|-----|-----------------|-----|-------------|---------|-------|
| Andi | 4 | 2–2 | 41 / 43 | −2 | 41 | 41 ÷ 84 = 48,8 → **49%** | 50% |
| Budi | 3 | 3–0 | 36 / 27 | +9 | 36 | 36 ÷ 63 = 57,1 → **57%** | 100% |
| Citra | 3 | 0–3 | 29 / 34 | −5 | 29 | 29 ÷ 63 = 46,0 → **46%** | 0% |
| Dewi | 3 | 2–1 | 33 / 30 | +3 | 33 | 33 ÷ 63 = 52,4 → **52%** | 67% |
| Eko | 3 | 1–2 | 29 / 34 | −5 | 29 | 29 ÷ 63 = 46,0 → **46%** | 33% |

- **Point % (default):** #1 Budi 57% · #2 Dewi 52% · #3 Andi 49% · #4 Citra 46% (−5) · #4 Eko 46% (−5).
- Total Point: #1 Andi 41 · #2 Budi 36 · #3 Dewi 33 · #4 Citra, Eko 29 (−5). Andi #1 hanya karena main sekali lebih
  banyak, padahal 2–2 dan selisihnya −2.
- Win %: #1 Budi 100% · #2 Dewi 67% · #3 Andi 50% · #4 Eko 33% · #5 Citra 0%.
- Jumlah poin didapat 168 = 4 match × 21 × 2.

**Contoh 18B — Race to 6, 1W–2L di atas 2W–1L** (Tennis, Fixed, 4 pasangan, round-robin 3 round; data A/B 4.2).

| Round | Court 1 | Court 2 |
|-------|---------|---------|
| R1 | Andi · Budi 5–6 Citra · Dewi | Eko · Fajar 6–2 Gita · Hadi |
| R2 | Andi · Budi 5–6 Eko · Fajar | Citra · Dewi 6–5 Gita · Hadi |
| R3 | Andi · Budi 6–0 Gita · Hadi | Citra · Dewi 0–6 Eko · Fajar |

| Pasangan | W–L | Game didapat / kalah | +/− | Win % | Point % | Total Point |
|----------|-----|----------------------|-----|-------|---------|-------------|
| Eko · Fajar | 3–0 | 18 / 7 | +11 | 100% | 72% | 18 |
| Citra · Dewi | 2–1 | 12 / 16 | −4 | 67% | 43% | 12 |
| Andi · Budi | 1–2 | 16 / 12 | +4 | 33% | 57% | 16 |
| Gita · Hadi | 0–3 | 7 / 18 | −11 | 0% | 28% | 7 |

- **Win % (default Race to):** #1 Eko · Fajar · #2 Citra · Dewi · #3 Andi · Budi · #4 Gita · Hadi.
- Point %: #1 Eko · Fajar 72% · #2 Andi · Budi 57% · #3 Citra · Dewi 43% · #4 Gita · Hadi 28%. Andi · Budi kalah dua
  kali tapi di atas Citra · Dewi yang menang dua kali: inilah alasan Point % tidak menggantikan Win % dan tidak jadi
  default Race to/Best of (keputusan 122–123). Jumlah main sama, jadi urutan Point % = Total Point.

**Contoh 18C — WO di Mixed Americano 21** (Padel, 8 pemain, 2 court; nilai WO beda antar pemenang).

| Round | Court 1 | Court 2 |
|-------|---------|---------|
| R1 | Andi · Eko 13–8 Citra · Fajar | Budi · Gita 16–5 Dewi · Hadi |
| R2 | Andi · Fajar 15–6 Dewi · Gita | Budi · Hadi 18–3 Citra · Eko |
| R3 | Andi · Budi **WO** (Citra · Dewi absen) | Eko · Gita 11–10 Fajar · Hadi |

- Nilai WO (4.4): Andi (13 + 15) ÷ 2 = **14**; Budi (16 + 18) ÷ 2 = **17**. Kalah untuk Citra dan Dewi masing-masing =
  (14 + 17) ÷ 2 = 15,5 → **16**.

| Pemain | Didapat / kalah | Point % | +/− | Total Point | Win % |
|--------|-----------------|---------|-----|-------------|-------|
| Budi | 34 + 17 = 51 / 8 | 51 ÷ 59 = 86,4 → **86%** | +26 | 51 | 100% |
| Andi | 28 + 14 = 42 / 14 | 42 ÷ 56 = **75%** | +14 | 42 | 100% |
| Fajar | 33 / 30 | 33 ÷ 63 = 52,4 → **52%** | +3 | 33 | 33% |
| Gita | 33 / 30 | **52%** | +3 | 33 | 67% |
| Hadi | 33 / 30 | **52%** | +3 | 33 | 33% |
| Eko | 27 / 36 | 27 ÷ 63 = 42,9 → **43%** | −9 | 27 | 67% |
| Citra | 11 / 31 + 16 = 47 | 11 ÷ 58 = 19,0 → **19%** | −20 | 11 | 0% |
| Dewi | 11 / 31 + 16 = 47 | **19%** | −20 | 11 | 0% |

- **Point % (default):** #1 Budi 86% · #2 Andi 75% · #3 Fajar, Gita, Hadi 52% (+3) · #4 Eko 43% · #5 Citra, Dewi 19%.
- Selisih tidak berubah oleh WO: Andi +14 dan Citra −20 sama dengan setelah R2.
- Tanpa WO (Hapus WO, match R3 Court 1 kembali Belum): Andi 28 ÷ 42 = 67%, Budi 34 ÷ 42 = 81%, Citra dan Dewi
  11 ÷ 42 = 26%.
- Race to 6 dan Fixed: data 13C (13.6) — Citra · Dewi kalah WO dari Maya · Nanda = 0–6: Citra · Dewi 10 ÷ 23 = 43%,
  Maya · Nanda 23 ÷ 36 = 64%.

**Contoh 18D — urutan Mexicano setelah istirahat** (lanjutan 14B, 10 pemain, 2 court; skor R2 sama dengan data
designer 16-mexicano: Andi · Gita 12–9 Fajar · Eko, Budi · Indra 10–11 Dewi · Joko).

| Pemain | Main | Didapat / dimainkan | Point % | +/− | Total Point |
|--------|------|---------------------|---------|-----|-------------|
| Citra | 1 (istirahat R2) | 15 / 21 | **71%** | +9 | 15 |
| Andi | 2 | 27 / 42 | **64%** | +12 | 27 |
| Hadi | 1 (istirahat R2) | 12 / 21 | **57%** | +3 | 12 |
| Joko | 1 | 11 / 21 | **52%** | +1 | 11 |
| Fajar | 2 | 21 / 42 | **50%** | 0 | 21 |
| Gita | 2 | 21 / 42 | **50%** | 0 | 21 |
| Indra | 1 | 10 / 21 | **48%** | −1 | 10 |
| Eko | 2 | 18 / 42 | **43%** | −6 | 18 |
| Dewi | 2 | 17 / 42 | **40%** | −8 | 17 |
| Budi | 2 | 16 / 42 | **38%** | −10 | 16 |

- R3 (14B): Citra, Hadi, Indra, Joko pasti main; anggap undian R3 membuat Budi dan Dewi istirahat.
- **Point % (sejak 3.9.0):** Court 1 = Citra, Andi, Hadi, Joko (susunan A, beban 0: Citra · Hadi vs Andi · Joko);
  Court 2 = Fajar dan Gita (urutan keduanya dari undian R3, 50% dan 0 sama), Indra, Eko.
- Total Point (sampai 3.8.x): Court 1 = Andi, Fajar, Gita, Eko; Court 2 = Citra, Hadi, Joko, Indra. Citra, #1 di Point %,
  turun ke court bawah hanya karena istirahat.

**Contoh 18E — pembulatan dan nomor** (Americano 21, semua match sampai total 21; angka per pemain, untuk test
`compare`).

| Pemain | Main | Didapat / kalah | Persis | Tampil | +/− | Nomor |
|--------|------|-----------------|--------|--------|-----|-------|
| Sari | 6 | 66 / 60 | 52,38% | 52% | +6 | #1 |
| Qori | 4 | 44 / 40 | 52,38% | 52% | +4 | #2 |
| Rani | 6 | 65 / 61 | 51,59% | 52% | +4 | #2 |
| Tono | 6 | 64 / 62 | 50,79% | 51% | +2 | #3 |

- Qori dan Rani: nilai persis beda, angka tampil dan selisih sama → **nomor sama**, baris diurutkan nama.
- Best of 5, satu pemain menang 3–0 dan kalah 2–3: 5 ÷ 8 = 62,5% → **63%** (,5 ke atas).

### 18.5 Per layar dan interaksi fitur

| Layar / fitur | Perilaku Point % |
|---------------|------------------|
| Klasemen (5.7, 09a–09h) | Tiga tab Total Point · Point % · Win % (U-RP1). Tab Point %: kolom nilai "57%", judul kolom "Point %", pemisah +/− seperti sekarang. Dibuka di default format (RP6). |
| Detail (5.8, 10a–10e) | Subjudul ikut tab: "Peringkat 1 · Point % · Padel · Mixed · Americano 21". Baris statistik menampilkan Point % di semua tab (U-RP5), bulat, "–" kalau belum main. Riwayat match tidak berubah. Sparing dan Grup + Gugur tetap tanpa metode di subjudul (§13.7, §16.9). |
| Bagikan, poster (5.9, 11a–11m, 18a–18t) | Nilai metode = Point %: "57% poin · +9" (Race to/Best of "57% game · +9") di tempat Total Point menulis satuan (Ringkas, Lengkap Feed satu kolom); "57% · +9" di tempat tanpa satuan (Lengkap dua kolom, Story) (U-RP3). Podium dan nomor dari aturan 18.2. |
| Caption | Baris peringkat untuk tab Point %: `{n}. {nama} — {Total Point} {satuan} · {Point %}% {satuan} ({W-L[-D]}, {selisih} {satuan})`, Point % menggantikan Win %, contoh 18A "1. Budi — 36 poin · 57% poin (3-0, +9 poin)". Tab Total Point dan Win % tidak berubah (U-RP3). |
| Penonton live (5.11, 12-an) | Tiga tab, default sama dengan host, dihitung di halaman penonton dari match di payload. Payload dan relay tidak berubah. |
| Sparing (§13.6) | Klasemen per klub tiga tab, default per format; data 13C 13.6. **Skor klub (K2) tidak berubah** (match menang → Total Point klub); papan dan kepala klub poster tetap "56 game · +13" di semua tab. |
| Mexicano (§14) | Default Point %; urutan memasangkan Point % → selisih → undian (14.3, 18D). |
| Grup + Gugur (§16) | Klasemen grup tanpa tab; kolom nilai = default format grup; grup Americano → Point % dan lolos dari Point % → selisih (U-RP6). Peringkat akhir tetap dari babak (16.8). |
| Pemain telat, Kelola pemain, Tukar pemain, Kelola court | Tidak ada aturan baru; jumlah main yang beda memang yang ditangani Point %. |
| Kosongkan skor / Hapus WO (§17), koreksi skor | Point % ikut berubah dari match (RP9, contoh 18C tanpa WO). |
| Estimasi, Jadwal, Beranda | Tidak berubah. |

### 18.6 Kriteria penerimaan

- **AC-RP1** Klasemen host (Fixed, Mixed, Mexicano) menampilkan tiga tab berurutan Total Point · Point % · Win %; ganti tab
  mengurutkan ulang dan mengubah kolom nilai; pilihan bertahan selama turnamen itu; app dibuka ulang atau turnamen
  berganti → kembali ke default.
- **AC-RP2** Klasemen dibuka pertama kali: Race to 6 → Win %; Best of 5 → Win %; Americano 21 dan 24 → Point %; Mexicano →
  Point %; Sparing Americano → Point % di kedua klub; Sparing Race to → Win %.
- **AC-RP3** Data 18A, tab Point %: #1 Budi 57% +9 · #2 Dewi 52% +3 · #3 Andi 49% −2 · #4 Citra 46% −5 · #4 Eko 46% −5;
  tab Total Point dan Win % sama dengan 18A.
- **AC-RP4** Data 18B, default Win %: Citra · Dewi #2, Andi · Budi #3; tab Point %: Andi · Budi 57% #2, Citra · Dewi 43% #3.
- **AC-RP5** Data 18C, tab Point %: Budi 86%, Andi 75%, Fajar/Gita/Hadi 52% sama-sama #3, Eko 43% #4, Citra/Dewi 19% sama-sama
  #5; selisih Andi +14, Citra −20. Hapus WO R3 Court 1 → Andi 67%, Budi 81%, Citra dan Dewi 26%.
- **AC-RP6** Data 18E: Sari #1, Qori dan Rani #2, Tono #3; 3–0 + 2–3 di Best of 5 tampil 63%. Hitungan bulat sama di
  Android, iOS, dan web.
- **AC-RP7** Pemain belum main tetap di "Belum main" tanpa nomor dan tanpa Point %; Detail-nya "–"; tidak ada error atau
  "NaN" di Klasemen, Detail, poster, caption, maupun halaman penonton.
- **AC-RP8** Seri Americano 20 10–10 → kedua sisi 50% untuk match itu; pemain yang hanya punya match itu tampil 50%.
- **AC-RP9** Detail pemain dari tab Point %: subjudul "Peringkat n · Point % · …"; baris statistik menampilkan Point % juga saat
  dibuka dari tab Total Point atau Win %.
- **AC-RP10** Bagikan dari tab Point %: poster Ringkas/Lengkap menulis Point % + selisih dengan aturan satuan 18.5; nomor dan
  yang naik podium sama dengan Klasemen tab Point %; caption 18A baris pertama "1. Budi — 36 poin · 57% poin (3-0, +9
  poin)". Bagikan dari tab Total Point / Win %: poster dan caption sama persis dengan 3.8.1.
- **AC-RP11** Mexicano data 18D: Buat R3 dengan undian Budi dan Dewi istirahat → Court 1 Citra, Andi, Hadi, Joko. Tab
  Total Point, Point %, atau Win % saat Buat R3 → round sama persis. Contoh 14A–14C (AC-M4, AC-M7) tetap lulus tanpa
  diubah.
- **AC-RP12** Sparing data 13C, tab Point %: angka 13.6; skor klub 7 – 5 dan "56 game · +13" sama di ketiga tab.
- **AC-RP13** Grup + Gugur dengan format grup Americano: tabel grup kolom Point %, tanpa tab; yang lolos ke bagan = 2 teratas
  tabel itu (U-RP6). Grup Race to/Best of tidak berubah.
- **AC-RP14** Penonton live: tiga tab, default sama dengan host, angka dan nomor sama dengan HP host untuk tab yang sama;
  payload tidak berisi metode; HP host 3.8.x yang mengirim ke halaman penonton 3.9.0 tetap tampil benar.
- **AC-RP15** Simpanan dari 3.8.x dimuat di 3.9.0 tanpa migrasi: turnamen Americano yang tadinya terbuka di Total Point kini
  terbuka di Point %; Mexicano yang sedang berjalan membuat round berikutnya dari Point % (round yang sudah dibuat tidak
  berubah); test dan golden lama lulus kecuali yang memang berubah (tab Klasemen, default Americano/Mexicano, statline
  Detail).
- **AC-RP16** Semua kriteria di atas jalan offline (kecuali live).

### 18.7 Data uji untuk tech lead

- **18A** (Mixed Americano 21, 5 pemain, 1 court, 4 match di tabel): Point % 49 / 57 / 46 / 52 / 46 (Andi, Budi, Citra,
  Dewi, Eko); Total Point 41 / 36 / 29 / 33 / 29; selisih −2 / +9 / −5 / +3 / −5; jumlah didapat 168.
- **18B** (Fixed Race to 6, 4 pasangan, 6 match): Point % Eko · Fajar 72, Citra · Dewi 43, Andi · Budi 57, Gita · Hadi 28;
  jumlah game didapat 53.
- **18C** (Mixed Americano 21, 8 pemain, 5 match + 1 WO): nilai WO Andi 14, Budi 17, kalah WO 16; didapat/dimainkan per
  pemain di tabel; jumlah didapat 241 = 5 × 42 + 14 + 17.
- **18D** (Mexicano 14B setelah R2): Point % per pemain di tabel; urutan R3 dengan undian disuntik (seperti 14.6).
- **18E** (`compare` + pembulatan): empat baris di tabel, ditambah 5 ÷ 8 → 63, 44 ÷ 84 → 52, 65 ÷ 126 → 52, 64 ÷ 126 → 51.
- **13C** (Sparing Race to 6): Point % 13.6.
- **AC-M15** (14A dengan WO R2 Court 2): Eko 63%, Dewi 53%, Gita 28%, Budi 19% (62,5 → 63 menguji ,5 ke atas).

### 18.8 Usulan PM (disetujui host 2026-11-20, keputusan 129)

- **U-RP1. Urutan tab Total Point · Point % · Win %.** Dua metode berbasis poin bersebelahan, Win % (berbasis menang)
  di ujung; posisi Total Point dan Win % yang sudah dikenal host tidak berpindah ujung.
- **U-RP2. Bulat tanpa desimal, nomor dari angka bulat** (18.2). Alasan: keputusan 17, dan Win % di app juga bulat.
- **U-RP3. Satuan di poster dan caption** (18.5): "57% poin" membedakan Point % dari Win % ("57%") di tempat yang
  menulis satuan; caption menulis Point % menggantikan Win % hanya saat tab Point %, supaya caption Total Point / Win %
  lama tidak berubah.
- **U-RP4. Belum main = 0% di urutan Mexicano** (U8 tetap). Alasan: satu-satunya kasus adalah pemain yang istirahat di
  R1 (pemain tidak bisa ditambah di Mexicano, keputusan 27), dan contoh 14B tetap berlaku. Nilai netral (50%) di
  "Belum sekarang".
- **U-RP5. Detail menampilkan Point % di semua tab** (angka pemain tidak tergantung tab, seperti Total Point dan Win %
  di statline sekarang); designer menentukan letak supaya muat di 390.
- **U-RP6. Grup + Gugur grup Americano lolos dari Point %** (GU8 menunjuk default keputusan 21, yang diubah keputusan 123).
  Turnamen Grup + Gugur Americano yang sedang di fase gugur saat update: slot A1/A2 dan bagan tetap terkunci (GU6), tapi
  tabel "Fase grup" diurutkan Point %, jadi label slot bisa jatuh di baris yang bukan 1–2. Diterima karena jarang
  (turnamen harus melintasi update).

### 18.9 Data & versi (keputusan 126)

- **MINOR, ikut 3.9.0.** Tidak ada kolom simpanan baru; `schemaVersion` tetap 2; metode tidak disimpan dan tidak ada di
  payload live (Point % dihitung ulang dari match). App 3.8.x membuka simpanan 3.9.0 dan payload 3.9.0 seperti biasa
  (tanpa tab Point %).
- Perilaku yang berubah untuk data lama (diterima, sama seperti 3.3.0 mengganti default): Klasemen Americano terbuka di
  Point %, sehingga nomor bisa beda dari poster yang dibagikan sebelum update; Mexicano yang berjalan memasangkan round
  berikutnya dari Point %, jadi Batalkan Rn + Buat Rn melintasi update bisa memberi round lain; grup Americano yang belum
  dibuat bagannya bisa berganti 2 teratas (U-RP6).
- Task RP-n (`docs/tasks.md`, ditulis main session/tech lead): spec `logic.md`, frame designer, kode
  `services/ranking/**` + test, golden.

### 18.10 Belum sekarang

- Point % sebagai default Race to/Best of, atau menggantikan Win % (keputusan 122).
- Satu tabel gabungan Sparing (dua klub) dengan Point %; skor klub dari Point %.
- Point % satu desimal; Win % dibandingkan dari angka bulat.
- Nilai netral (50%) untuk pemain yang belum main di urutan Mexicano.
- Memilih atau menyimpan metode di Konfigurasi / per turnamen; metode host dikirim ke penonton.
- Point % di babak gugur (peringkat akhir tetap dari babak).
- Kompensasi lain untuk yang istirahat (14.10) selain yang sudah diberi Point %.

### 18.11 Pertanyaan untuk host (dijawab "setuju" 2026-11-20, keputusan 129)

- **Q1 (U-RP2).** Point % saya tampilkan bulat ("52%") seperti Win %, dan nomor dibandingkan dari angka bulat itu,
  supaya dua baris "52% · +4" selalu bernomor sama; akibatnya pemain 52,4% dan 51,6% dengan selisih sama berbagi nomor.
  Rekomendasi: setujui.
- **Q2 (U-RP6).** Grup + Gugur menentukan 2 besar grup dari metode default format grup, jadi grup Americano sekarang
  lolos dari Point %, bukan Total Point; di grup semua pasangan main sama banyak, jadi bedanya kecil (hanya match yang
  berhenti lebih awal dan WO). Rekomendasi: ikut Point %, supaya satu aturan default berlaku di semua mode.
- **Q3 (U-RP1, U-RP3–U-RP5).** Urutan tab Total Point · Point % · Win %, satuan "57% poin" di poster/caption, pemain belum
  main 0% di urutan Mexicano, dan Point % selalu tampil di Detail. Rekomendasi: setujui semuanya; bentuk final di frame
  designer.
