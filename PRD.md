# PRD — Match Addict, Aplikasi Mabar Tennis/Padel (Klub/Komunitas)

**Versi dokumen:** 3.0 — sejalan dengan hi-fi v2 (`design/hifi.html`, disetujui host 2026-10-21; Kelola court 2026-10-22; nama turnamen dan batas 30 pemain 2026-10-23; live score 2026-10-24; nama lengkap di baris match, Akhiri di Beranda, dan pemain telat menyusul 2026-10-25; Best of/Americano berhenti lebih awal 2026-10-26; nama Match Addict dan peringkat dengan selisih 2026-11-02; round tambahan Fixed 2026-11-03; default metode Klasemen ikut format skor 2026-11-11) dan app **3.1.0**; Sparing (§13) disetujui host 2026-11-04, rencana app 3.2.0, belum
ada di hi-fi; Mexicano (§14) + Konfigurasi diringkas diputuskan host 2026-11-11…12 (keputusan 23–47), app 3.4.0, hi-fi 03a–03q dan 16a–16g;
Tukar pemain Mixed (§15) diputuskan host 2026-11-12 (keputusan 48–59), rencana app 3.5.0, hi-fi 17a–17r
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
- Menghitung peringkat Total Point atau Win %, termasuk walkover (WO)
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
- Istilah UI: istilah olahraga tetap Inggris (court, round, match, set, WO, Win %, Total Point); semua orang disebut
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
- Round dibuka berurutan: round berikutnya terkunci sampai semua skor round sebelumnya terisi.
- Fairness Fixed = fairness antar pasangan, bukan individu.
- **Round tambahan** (3.3a): setelah semua match terisi, host bisa menambah round supaya semua pasangan main lagi
  dengan jumlah yang sama, dari sisa booking + jam tambahan per court. Sebelumnya pasangan bisa diatur ulang dan pemain
  pengganti dimasukkan (pemain yang pulang tidak ikut, poinnya tertinggal).
- Fixed **tidak bisa dilanjutkan** setelah diakhiri; yang pulang di tengah round-robin tetap WO.

#### B. Mixed Partner (Pasangan Berganti, "endless")

- Tidak ada target match: R1 dibuat saat Konfigurasi selesai, host menekan **Buat R(n+1)** untuk round berikutnya.
- Buat R(n+1) aktif kalau round terakhir lengkap (selesai/WO) dan masih ada court yang waktunya cukup.
- **Batalkan Rn**: round terakhir yang belum ada skor sama sekali boleh dihapus (bukan R1), mis. karena ada pemain
  datang terlambat; host menambah pemain lalu Buat Rn lagi.
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
        matches = [fixed vs rotate[last]] + [rotate[i] vs rotate[n-2-i] for i in 0..n/2-2]
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
| **Win %** | Menang = 1, seri = 0,5, kalah = 0, dibagi jumlah match |

**Default mengikuti format skor** (keputusan 21): Race to dan Best of → **Win %**; Americano → **Total Point**.
- Race to dan Best of dimenangkan per match, jadi jumlah menang dulu, seperti klasemen round-robin resmi tennis,
  padel, pickleball, dan badminton (menang dulu, baru selisih). Di Americano tiap poin memang tujuannya.
- Contoh Race to 6, tiga match: Gita · Andi 2W–1L, 16 game, +1; Dewi · Citra 1W–2L, 16 game, +2. Win %: Gita · Andi
  67% di atas Dewi · Citra 33%. Total Point: 16 sama, selisih +2 menaruh Dewi · Citra di atas.
- Contoh kedua: A kalah 5–6, kalah 5–6, menang 6–0 (16 game, 1W–2L); B menang 6–5, menang 6–5, kalah 0–6 (12 game,
  2W–1L). Win %: B di atas A. Total Point: A di atas B.

Metode dipilih di layar Klasemen (tidak di setup) dan dipakai juga oleh Detail & Bagikan; urutan tab tetap
Total Point · Win %. Pilihan host bertahan selama turnamen itu, tidak disimpan: turnamen berganti atau app dibuka
ulang → kembali ke default formatnya. Berlaku sama untuk Fixed, Mixed, Sparing (klasemen per klub), dan penonton live.

### 4.3 Tie-Breaker & Nomor Peringkat

1. Nilai metode (Total Point atau Win %) → 2. Selisih game/poin → nomor sama, baris diurutkan nama

- Hanya angka yang tampil di Klasemen dan poster yang menentukan nomor, supaya alasannya terbaca: kolom +/− (selisih)
  memisahkan nilai yang sama. Head-to-head tidak dipakai (di Mixed antar tiga pemain bisa berputar), begitu juga Total
  Point sebagai pemisah Win %.
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
skor di match WO mengubahnya jadi match selesai.

**Dampak:**
- Pasangan lawan menang, pasangan WO kalah; keduanya +1 match.
- Total Point pemenang WO ikut format skor (keputusan host 2026-10-21):
  - Race to N → pemenang dapat N game.
  - Best of N & Americano → rata-rata game/poin dari match yang benar-benar dia mainkan (bulat ,5 ke atas), tapi tidak
    pernah di bawah skor menang terkecil ⌊N ÷ 2⌋ + 1 (Americano 21 → 11, 24 → 13; Best of 5 → 3); belum pernah main →
    skor menang terkecil.
- Pasangan WO 0 game/poin. Selisih game/poin tidak berubah untuk keduanya.
- Alasan WO tampil di baris Jadwal.

### 4.5 Status Match

| Status | Definisi | Dampak peringkat |
|--------|----------|------------------|
| Belum | Belum diisi | — |
| Selesai | Skor masuk | Dihitung |
| WO | Satu pasangan tidak bisa main | Menang/kalah dihitung (4.4) |
| Tidak dimainkan | Turnamen diakhiri sebelum match dimainkan | **Tidak dihitung sama sekali**; kembali "Belum" kalau Mixed dilanjutkan |

### 4.6 Status Sementara / Final

- **Fixed:** Final setelah diakhiri atau semua match terisi; kembali Sementara setelah round tambahan dibuat.
- **Mixed:** Final setelah diakhiri, atau waktu booking semua court habis (jam sungguhan) **dan** round terakhir lengkap. Kembali
  Sementara kalau dilanjutkan.
- Final: subjudul "… · Final · 5 round · 10 match"; poster menulis "Klasemen akhir". Sementara: "… · R3 · 6 dari 8 match".

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
- Web/PWA: baris "Pasang Match Addict di HP" (dialog bawaan browser, atau panduan iPhone/iPad).
- Versi app (`appVersion`) tampil di Beranda (keputusan 20, 2026-11-04; belum ada di hi-fi).

### 5.2 Pemain (02a–02d)
- Satu kotak teks (tempel dari WhatsApp); parser membuang nomor/bullet, spasi ganda, baris kosong, dan duplikat
  (tidak peka huruf besar, yang pertama dipertahankan).
- Toolbar: Tempel, Contoh (hanya saat kosong), Hapus semua. Hasil = daftar bernomor dua kolom.
- Lanjut aktif untuk 4–30 pemain (Fixed dan Mixed).

### 5.3 Konfigurasi (03a–03q)
- Nama turnamen opsional paling atas (maks 40 karakter, dipangkas; kosong = tanpa nama). Hanya diisi di sini, tidak
  bisa diubah setelah turnamen dibuat.
- Mode Fixed/Mixed (Mexicano: 14.2), format skor (4.1), durasi match (stepper ±5), jumlah court 1–10, per court nama/warna (10 warna
  preset)/booking. Estimasi di tombol. Fixed → Pasangan; Mixed → langsung Jadwal + R1.

### 5.4 Pasangan — Fixed (04a–04h)
- Acak / Manual (pilih, lepas pilihan, Urungkan), pemain ganjil + "Ubah pemain", dialog kunci pasangan.
- Atur pasangan sebelum round tambahan (04f–04h): Ubah per pasangan, pemain pengganti, "Simpan pasangan · n tidak
  main", hasilnya di baris Pasangan sheet Tambah round.

### 5.5 Jadwal Fixed (06a–06e, 06v–06z) & Mixed (06f–06o, 06u)
- Tab round yang bisa digeser (tepi dipudarkan), label kanan "x/y match" atau "Waktu habis"; ganti round hanya lewat tab.
- Baris match bergaya scorebug dengan strip court berwarna (42 pt; di round yang sedang berjalan + kotak jam sisa
  booking court itu); ketuk → Input Skor (juga untuk mengubah).
- Nama pemain ditulis lengkap ("Andi P · Budi S"), di baris match, Input Skor, WO, riwayat Detail, dan Istirahat Fixed,
  supaya pemain bernama depan sama terbedakan. Tidak muat → tiap nama dipotong elipsis sendiri; nama yang muat di
  separuh lebar tetap utuh (06u).
- Istirahat: Fixed paling banyak satu pasangan; Mixed di round terakhir dibagi "Istirahat · Prioritas main di R(n+1)"
  dan "Istirahat lagi di R(n+1)".
- Menu ⋯: Kelola court (Mixed), Cara kerja Mixed (sheet; muncul otomatis sekali saat R1 dibuat), dan Akhiri turnamen
  (dialog).
  Fixed yang sudah diakhiri tidak punya item menu lagi: ikon ⋯ tampil pudar dan tidak bisa diketuk.
- Mixed: Buat R(n+1) / Batalkan Rn / Pemain (n) / Tambah jam / Lanjutkan turnamen.
- Mixed (bukan Mexicano/Fixed): tukar pemain di match round terakhir yang belum diisi dengan pemain yang istirahat
  (§15, keputusan 48–59; rencana 3.5.0, hi-fi 17a–17r: ikon di baris match).
- Fixed setelah semua match terisi: ikon Klasemen + "Tambah round" → sheet jam booking per court, baris Pasangan,
  "n match lagi tiap pasangan" dan "Buat R15–R16" (3.3a).
- Back (tombol ‹, back HP, back browser) selalu ke Beranda, bukan ke Atur turnamen/Pasangan: dari sana "Buat jadwal"
  memulai turnamen baru dan skor yang sudah diisi hilang. Turnamen dilanjutkan dari Beranda (keputusan 22).

### 5.6 Input Skor & Walkover (07a–07o)
- Papan skor gelap: nama lengkap satu pemain per baris, satu angka besar per tim, keypad sendiri, pesan validasi,
  "Perbarui skor" saat mengubah.
- Subjudul menulis sisa booking court itu untuk match di round yang sedang berjalan ("· sisa 02:00").
- WO lewat sheet (4.4).

### 5.7 Klasemen (09a–09g)
- Tabel: # · nama · Main (jumlah match dimainkan, WO ikut) · W–L–D (W–L kalau format tidak bisa seri) · +/− (selisih)
  · nilai metode; peringkat 1 diberi bola.
- Toggle Total Point / Win %, status di subjudul, catatan WO / tidak dimainkan, ketuk baris → Detail. Tombol Bagikan.

### 5.8 Detail Pemain (10a–10d)
- Satu baris statistik (label mengikuti format skor: Poin/Game), beda partner/lawan, kalah WO, riwayat match terbaru
  di atas (Mixed menampilkan partner; menang WO menulis "+N"). Fixed menampilkan "Beda partner" hanya kalau
  pasangannya pernah diatur ulang (10d).

### 5.9 Bagikan (11a–11m, 18a–18t)
- Kartu pratinjau + deret tema (11 pilihan: lapangan ikut olahraga sebagai bawaan + 10 gradien, sama di Ringkas dan
  Lengkap; keputusan 66, 76) + Ringkas (poster podium) / Lengkap (semua yang bernomor). Nomor "#n"; peringkat 1 lencana
  emas, digantung ke kiri supaya "#1" sejajar dengan nomor di bawahnya.
- Tiap baris = nilai metode + selisih, sama dengan Klasemen: "42 poin · +12", "100% · +12". Lengkap menulis satuan hanya
  di Feed satu kolom; dua kolom dan Story tanpa satuan ("42 · +12"). Ringkas selalu dengan satuan.
- Dua gambar 1080×1080 dan 1080×1920 dibagikan lewat share sheet sistem dengan caption teks hasil; gagal → caption
  disalin + toast "Hasil disalin".
- Kepala poster (Ringkas dan Lengkap): tanpa nama → judul "Klasemen akhir|sementara" + baris kecil "olahraga · mode ·
  tanggal"; bernama → judul = nama (maks dua baris) + baris kecil "Klasemen akhir|sementara · tanggal", olahraga pindah
  ke depan baris fakta. Caption dibuka "🏆 {nama} · Padel" (tanpa nama "🏆 Match Addict · Padel").
- **Sejak 3.6.0 (keputusan 60–74, hi-fi 11a, 11c, 11d, 13q, 13r, 18a–18t): Ringkas = poster podium**, bukan daftar 5 teratas. Ilustrasi sudut lapangan + podium
  (angka di muka blok, satu bola per pemain) dan panel nama sedikit transparan berisi baris yang naik podium (nomor,
  nama, nilai metode + selisih dengan satuan di Feed dan Story) + wordmark + baris fakta turnamen. Nomor sama → tinggi
  sama; maksimal 4 anak tangga (keputusan 65). Sparing: dua blok skor klub. Tema bawaan = palet lapangan ikut olahraga,
  10 gradien tetap bisa dipilih.
- **Sejak rencana 3.7.0 (keputusan 76–88, hi-fi 11b, 11e–11m, 13s–13w): Lengkap = arah B "Podium mini"**, satu keluarga
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
  sendiri), dan Detail, baca saja. Dicek tiap 10 detik selama halaman terlihat, tiap menit setelah Final. Tag "Live" di
  Jadwal, "Offline" setelah dua kali gagal, hilang saat Final. Subjudul memakai nama turnamen kalau ada. Simpanan
  turnamen penonton sendiri tidak tersentuh.
- Relay tanpa database: satu salinan terakhir per kode, terhapus 3 hari setelah perubahan terakhir atau saat Hentikan.
  Aturan rinci: `design/spec/logic.md` §11.

---

## 6. Daftar Layar

| Layar | Frame |
|-------|-------|
| Beranda (+ dialog mulai baru, sheet pasang di iPhone, ikon app) | 01a–01j |
| Pemain | 02a–02d |
| Konfigurasi (+ sheet warna court) | 03a–03e |
| Pasangan (Fixed) + Atur pasangan sebelum round tambahan | 04a–04h |
| Jadwal Fixed + sheet Tambah round | 06a–06e, 06v–06z |
| Jadwal Mixed (+ sheet Cara kerja Mixed) | 06f–06t |
| Sheet Kelola pemain, Lanjutkan turnamen, Kelola court + detail court | 08a–08k |
| Input Skor + sheet Walkover | 07a–07o |
| Klasemen | 09a–09g |
| Detail Pemain | 10a–10d |
| Bagikan | 11a–11l |
| Live score: menu, dialog, sheet di HP host; halaman penonton (Jadwal, Klasemen, Detail) | 12a–12o |

State teks sederhana tanpa frame: "Halaman tidak ditemukan", "Belum ada turnamen berjalan", "Match tidak ditemukan",
"Pemain tidak ditemukan", spinner saat Jadwal membuat round pertama.

---

## 7. Design System (ringkas; sumber: hi-fi → Fondasi, `design/spec/tokens.json`)

- Arah: "papan skor pinggir lapangan" — tidak terkesan AI-generated.
- Warna: court `#1E6BB8`, court-deep `#164E8C`, ink `#0F1E2C`, ball `#CDE84A`, paper `#EEF2F5`, card `#FFFFFF`,
  line `#DCE3E9`, clay `#B9482A` (error/hapus/WO), padel `#BC5A33` (permukaan lapangan padel di Beranda saja),
  emas `#E3B341` (lencana #1 di Bagikan saja), 10 warna court.
- Huruf Archivo: angka besar condensed (`wdth` 72, tabular), wordmark lebar (`wdth` 125).
- Ikon Phosphor Bold 24 pt (20 di dalam tombol). Tinggi sentuh minimal 44 pt; tombol utama 52 pt.
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

---

## 9. Fase Development

| Fase | Fitur | Status |
|------|-------|--------|
| MVP (1.x) | Setup, pairing, RR & Mixed, input skor, peringkat, share teks+gambar, simpan lokal, PWA | Selesai, live di web |
| 2.0 | Redesain v2 + format skor Race to/Best of/Americano + WO per format + perbaikan logika (`logic.md`) | Sedang dikerjakan |
| Berikutnya | Rilis Play Store (keystore sendiri), history banyak turnamen, multi-device | Belum |
| Backlog | Turnamen grup + babak gugur (Fixed): pasangan dibagi n grup, tiap grup di court sendiri saling bertemu, top-n tiap grup lanjut ke perempat final / semifinal / final (host memilih babak awal). Diusulkan host 2026-11-12, ditunda | Belum |
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
    caption dibuka skor klub; poster Ringkas = 3 teratas tiap klub (dikonfirmasi host); Detail menaruh tim sendiri di
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
    (2026-11-11).
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

---

## 13. Sparing — Dua Klub Bertanding

> **Disetujui host 2026-11-04** (keputusan 19, §10), rencana rilis **3.2.0 (MINOR)**. Bagian lain PRD tidak berubah:
> turnamen biasa (bukan sparing) tetap persis seperti 3.1.0. Keputusan: 13.11 (K1–K13); verifikasi tech lead: 13.12.

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

- Layar Pemain mendapat pilihan **Mabar / Sparing** di paling atas (label final dari designer). Mabar = layar sekarang.
- Sparing: dua blok, masing-masing = nama klub + kotak nama pemain (parser sama dengan 5.2, termasuk buang duplikat di
  dalam satu klub).
- Nama klub wajib, maks 20 karakter, dipangkas. Lanjut **mati** kalau: nama klub kosong; dua nama klub sama (tidak peka
  huruf besar); satu klub < 2 pemain; total > 30; satu nama pemain ada di kedua klub (pesan validasi menyebut namanya,
  mis. "Andi ada di dua klub" — boleh karena mencegah salah langkah, Prinsip "Tanpa Petunjuk").
- Batas (K6): tiap klub **minimal 2** pemain (satu pasangan), total **4–30** (batas 30 yang sama, `maxPlayers`). Fixed
  dan Mixed sama.
- Konfigurasi tidak berubah: Mode Fixed/Mixed tetap dipilih di sana, nama turnamen tetap opsional dan terpisah dari nama
  klub. Estimasi di tombol Lanjut: Fixed sparing 13.3 (K10), Mixed sparing 13.4.
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
- Istirahat: bisa beberapa pasangan per round, dari kedua klub (turnamen biasa paling banyak satu).
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
  klub dan tetap sama persis dengan hasil Buat R(n+1).
- Estimasi Konfigurasi: Max Round = booking terpendek ÷ durasi; Court Aktif = rumus di atas; Total Match = round × court
  aktif; Match/Pemain ditulis per klub.

**Contoh 13B** — pemain 13.2 (Garuda 8, Matcha 6), Padel 15 menit, 2 court × 2 jam → ±8 round, court aktif
`min(2, 4, 3) = 2`, slot 4 Garuda + 4 Matcha per round, 2 match per round.
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
- Status Sementara/Final sama dengan 4.6. Skor klub tampil di Klasemen (di atas tabel), poster, caption, Beranda, dan
  halaman Live (penempatan oleh designer; tanpa kalimat penjelas).

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
- Klasemen, Detail, Bagikan, caption, dan Live memakai nomor yang sama (seperti `standingEntriesProvider` sekarang).

### 13.7 Interaksi dengan fitur yang ada

| Fitur | Perilaku di sparing |
|-------|-------------------------------|
| Kelola pemain (Mixed) | Tambah pemain wajib memilih klub. Keluarkan mati kalau klub itu tinggal 2 pemain aktif. Kembalikan = ke klubnya sendiri. Contoh: Nanda keluar setelah R3 → Matcha 5 aktif, court aktif tetap 2, 4 dari 5 Matcha main per round. |
| Pemain telat (Mixed) | Aturan 3.4 per klub. Contoh: Oki masuk Matcha setelah R3 → Matcha 7, slot 4, istirahat 3 → k = 2: Oki main R4 dan R5, istirahat R6 kalau masih di bawah yang paling banyak main. Garuda tidak terpengaruh. |
| Kelola court (Mixed) | Court baru langsung dipakai di round berjalan kalau **tiap klub** punya ≥ 2 pemain istirahat: 2 teratas prioritas tiap klub. Contoh 13B saat R4 berjalan: tambah Court 3 → match baru 2 Garuda + 2 Matcha yang istirahat; R5 court aktif `min(3, 4, 3) = 3`, semua 6 Matcha main. |
| Batalkan Rn, Lanjutkan turnamen, Akhiri | Tidak berubah; court aktif dihitung ulang dengan rumus 13.4. |
| Round tambahan (Fixed, 3.3a) | Satuan = paling sedikit match yang memberi tambahan sama ke semua pasangan satu klub: `L = KPK(p1, p2)` match; klub 1 +L÷p1, klub 2 +L÷p2 per pasangan. Jumlah satuan dibulatkan ke atas dan boleh lewat booking (prinsip keputusan 18). Lawan melanjutkan urutan jadwal awal. Contoh 13A setelah R6, sisa 30 menit = 2 round: satuan 12 match = 6 round (R7–R12), "lewat booking 01:00", Garuda +3, Matcha +4. 8 / 4 pemain (4 / 2 pasangan): satuan 4 match, Garuda +1, Matcha +2. 6 / 6: satuan 3 match, +1. (K5) |
| Atur pasangan (Fixed) | Pasangan baru harus sesama klub; pemain pengganti diketik ke salah satu klub. Jumlah pasangan klub boleh berubah; satuan round tambahan dihitung dari jumlah baru. |
| Bagikan (K7) | Poster: skor klub paling atas, lalu daftar per klub (Ringkas: 3 teratas tiap klub; Lengkap: semua). Caption dibuka "🏆 PB Garuda 7–5 Matcha Club · Padel" (nama turnamen, kalau ada, di baris berikutnya). Desain oleh designer. |
| Live score | Penonton melihat skor klub dan klasemen per klub, angka sama dengan HP host. |
| Beranda | Turnamen sparing tanpa nama: "PB Garuda vs Matcha Club" menggantikan "olahraga · mode · n pemain". |
| Detail pemain (K9) | Riwayat tetap menaruh tim pemain itu di baris atas (10a/10b, pengecualian S4); nama klub ditulis di subjudul Detail. "Beda partner" hanya menghitung sesama klub (memang hanya itu yang mungkin). Contoh: Detail Maya (Matcha Club, klub kedua) — di riwayat R2 baris atas "Maya · Nanda", lawan "Eko · Fajar" di bawahnya. |

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
  riwayat R2 menaruh "Maya · Nanda" di atas "Eko · Fajar", dan subjudul Detail menulis "Matcha Club".
- **AC-S7a** Estimasi tombol Lanjut Fixed sparing (Padel 15 menit, court 2 jam): 8 / 6 di 2 court → "Lanjut · 6 round ·
  12 match"; 16 / 14 di 4 court → "Lanjut · 14 round · lewat booking 01:30"; 8 / 4 di 3 court → "Lanjut · 4 round · 8
  match · 2 court"; tidak ada "±" di Fixed sparing.
- **AC-S8** Mixed 8 / 6, 2 court: tiap round 2 match, tiap match 2 Garuda vs 2 Matcha, partner sesama klub. Setelah R6
  tiap Garuda 3 match, tiap Matcha 4. Setelah R8 tiap Garuda 4, Matcha dua pemain 6 dan empat 5.
- **AC-S9** Mixed, test properti 30 round untuk 8/6, 7/6, 8/3, 15/15, 2/2: selisih main antar pemain satu klub yang
  hadir sejak awal ≤ 1 setelah setiap round; nol match sesama klub.
- **AC-S10** Mixed 8 / 3, 2 court: court aktif 1, Court 2 tidak dapat match; estimasi menulis Court Aktif 1.
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
- **AC-S17** Klasemen per klub data 13C sama persis dengan 13.6 (Total Point dan Win %); Detail, Bagikan, caption, dan
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

> **Diputuskan host 2026-11-11** (keputusan 23–27, §10), rencana rilis **3.4.0 (MINOR)**. Aturan rinci di bagian ini
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
  R(n+1)" dan "Istirahat lagi di R(n+1)", menu ⋯ (Kelola court, Akhiri, Live score). Sheet pengganti "Cara kerja Mixed":
  designer, dan isinya ikut persetujuan host.

### 14.3 Urutan Mexicano (dasar memasangkan)

Pemain diurutkan:

1. **Total Point** turun (4.2: game/poin dimenangkan + nilai WO 4.4).
2. **Selisih** turun (4.3; WO tidak mengubah selisih).
3. Masih sama → **undian terkunci per round** (`lockedDraw(drawSeed + nomor round)`, undian yang sama dengan prioritas
   main 3.4), lalu id.

- Selalu Total Point, **apa pun tab** yang dipilih host di Klasemen; memilih Win % tidak mengubah pasangan (U1).
- Dihitung dari match Selesai/WO di round yang sudah dibuat. Pemain yang belum main dihitung 0 poin, selisih 0, dan
  diurutkan dengan angka itu seperti pemain lain (di Klasemen mereka tetap di grup "Belum main").
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
| WO (4.4) | Sama dengan Americano: pemenang WO = rata-rata poin match yang dia mainkan, minimal ⌊N ÷ 2⌋ + 1; pasangan WO 0; selisih tidak berubah. Nilai WO ikut Total Point, jadi ikut urutan Mexicano. Contoh 14A, R2 Court 2 WO (Gita · Budi absen): Eko 9 + 11 = 20 (−3), Dewi 6 + 11 = 17 (−9), Gita 9 (−3), Budi 6 (−9). Pemain yang absen tetap dijadwalkan sampai dikeluarkan, seperti Mixed. |
| Kelola court | Sama dengan Mixed (`logic.md` §10): court ditambah saat round berjalan dan istirahat ≥ 4 → 4 teratas prioritas yang istirahat langsung main, disusun dengan 14.5 dari urutan Mexicano saat itu (skor round berjalan yang sudah masuk ikut dihitung). Round berikutnya court baru ikut urutan nomor (14.4). Hapus court: sama. |
| Waktu booking, Tambah jam, Lanjutkan turnamen, Akhiri | Sama dengan Mixed. Lanjutkan (dari Jadwal atau Beranda) meneruskan Klasemen; round berikutnya dipasangkan dari Klasemen itu. Match Tidak dimainkan kembali Belum. |
| Status Sementara/Final (4.6) | Sama dengan Mixed. |
| Klasemen (4.2, 4.3, 5.7) | Satu baris per pemain seperti Mixed. Default **Total Point** (Americano, keputusan 21). Tab Win % tetap ada; tidak mengubah pasangan (14.3). |
| Detail pemain | Seperti Mixed (partner tampil, beda partner/lawan). |
| Beranda | "Padel · Mexicano · 8 pemain" (nama turnamen menggantikannya kalau ada). Turnamen terakhir Mexicano tampil sebagai baris riwayat → sheet Lanjutkan, seperti Mixed. |
| Bagikan | Seperti Mixed: per pemain, nilai Total Point + selisih, baris kecil "Padel · Mexicano · tanggal". Caption sama dengan Mixed. |
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
- **AC-M10** Tab Klasemen Win % lalu Buat R(n+1) → round sama persis dengan saat tab Total Point.
- **AC-M11** Sebelum skor round terakhir lengkap, daftar "Istirahat · Prioritas main di R(n+1)" dan "Istirahat lagi di
  R(n+1)" sudah tampil, dan setelah semua skor masuk, hasil Buat R(n+1) sama persis: semua dari daftar Prioritas main
  ikut main, semua dari "Istirahat lagi" istirahat, apa pun skornya.
- **AC-M12** Batalkan R3 lalu Buat R3 tanpa perubahan → match R3 sama persis. Batalkan R3, keluarkan Gita, Buat R3 →
  R3 tanpa Gita, dipasangkan ulang dari urutan Mexicano.
- **AC-M13** Koreksi skor R2 setelah R3 dibuat: Klasemen berubah, match R3 tidak berubah; R4 memakai angka baru.
- **AC-M14** App di-kill setelah semua skor R2 masuk → dibuka lagi → Buat R3 sama persis dengan tanpa kill. Live
  melanjutkan kode yang sama.
- **AC-M15** WO 14A R2 Court 2 (Gita · Budi): Eko 20, Dewi 17, Gita 9, Budi 6; selisih keempatnya sama dengan setelah R1;
  urutan R3 memakai angka ini.
- **AC-M16** Kelola pemain Mexicano: tidak ada tambah pemain; Keluarkan mati saat aktif 4; Kembalikan ada untuk pemain
  yang dikeluarkan setelah round terakhir dibuat dan hilang setelah round berikutnya dibuat tanpa dia.
- **AC-M17** Kelola court: 12 pemain / 2 court, R1 berjalan → tambah Court 3 → match baru berisi 4 pemain istirahat
  teratas prioritas, disusun 14.5 dari urutan Mexicano saat itu; R2 memakai 3 court, kelompok teratas di Court 1.
- **AC-M18** Court 1 habis lebih dulu dari Court 2 → round berikutnya kelompok teratas di Court 2.
- **AC-M19** Beranda "Padel · Mexicano · 8 pemain"; turnamen terakhir Mexicano → Lanjutkan; poster "Padel · Mexicano ·
  tanggal"; Klasemen, Detail, Bagikan, caption, dan Live memakai nomor yang sama, default Total Point.
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
- Urutan Mexicano dari poin per match (rata-rata) alih-alih Total Point.
- Menghindari ulang lawan atau ulang match persis.
- Varian lain: Mexicano pasangan tetap ("Team Mexicano"), round final khusus (mis. 1+4 vs 2+3 di round terakhir),
  King of the Court (pemenang naik court).
- Menentukan court mana yang jadi "court atas" secara manual.

### 14.11 Keputusan & usulan

Keputusan host 2026-11-11: 23–32 di §10 (jangan dibuka ulang). U2, U5, U1, U6 sudah menjadi keputusan 30, 29, 31, 32.
U9 disetujui apa adanya (keputusan 34). Konfigurasi diringkas mengikuti keputusan 33, 35–37. U3, U4, U7, U8 disetujui
host 2026-11-12 (keputusan 44–47). Semua usulan di bawah sudah menjadi keputusan.

**Usulan PM (semuanya disetujui host):**

- **U1.** Urutan Mexicano selalu Total Point → selisih, apa pun tab Klasemen (14.3).
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

> **Diputuskan host 2026-11-12** ("setuju semua", keputusan 48–57, §10, termasuk usulan PM TU1–TU4), rencana rilis
> **3.5.0 (MINOR)**, diimplementasi 2026-11-12. Tampilan disetujui host 2026-11-12 (keputusan 58–59): ikon di kolom bola baris match → sheet "Tukar
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
