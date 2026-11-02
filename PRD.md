# PRD — Match Addict, Aplikasi Mabar Tennis/Padel (Klub/Komunitas)

**Versi dokumen:** 2.8 — sejalan dengan hi-fi v2 (`design/hifi.html`, disetujui host 2026-10-21; Kelola court 2026-10-22; nama turnamen dan batas 30 pemain 2026-10-23; live score 2026-10-24; nama lengkap di baris match, Akhiri di Beranda, dan pemain telat menyusul 2026-10-25; Best of/Americano berhenti lebih awal 2026-10-26; nama Match Addict dan peringkat dengan selisih 2026-11-02) dan app **3.0.0**
**Platform:** Android + iOS + Web/PWA (1 codebase — Flutter)
**Target user:** Host mabar klub/komunitas tennis & padel, 4–30 pemain per turnamen, 1 HP host, offline

Acuan visual dan perilaku per layar ada di hi-fi (frame 01a–12o + catatan perilaku) dan `design/spec/`. PRD ini
memuat aturan produk dan logika; kalau ada beda dengan hi-fi soal tampilan, hi-fi yang benar. Aturan logika rinci +
data test: `design/spec/logic.md`.

---

## 1. Ringkasan Eksekutif

Aplikasi untuk host turnamen mabar yang:

- Mengundi pasangan (mode Fixed) atau mengacak pasangan tiap round (mode Mixed)
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
   ↑ Lanjutkan            (format skor,  └ Mixed → [Jadwal Mixed] (R1 langsung dibuat, sheet Cara kerja Mixed)
   │                      court, durasi)
[Jadwal] ↔ [Input Skor] ↔ [Walkover]
[Jadwal] → [Klasemen] → [Detail Pemain]
[Klasemen] → [Bagikan] → Selesai → [Beranda]
```

### 3.2 Mode Partner

#### A. Fixed Partner (Pasangan Tetap)

- Pasangan dibuat **Acak** (otomatis saat layar dibuka, bisa acak ulang) atau **Manual** (ketuk dua pemain).
- "Buat jadwal" memunculkan dialog konfirmasi: pasangan tidak bisa diubah setelah jadwal dibuat.
- Round-robin penuh dibuat sekaligus. Pasangan ganjil → satu pasangan istirahat (bye) per round; pemain ganjil →
  satu pemain tanpa pasangan (tampil di "Belum main").
- Round dibuka berurutan: round berikutnya terkunci sampai semua skor round sebelumnya terisi.
- Fairness Fixed = fairness antar pasangan, bukan individu.
- Fixed **tidak bisa dilanjutkan** setelah diakhiri.

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
  diprioritaskan di round berikutnya.
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
| **Total Point** (default) | Jumlah game/poin yang dimenangkan lintas match (+ nilai WO, lihat 4.4) |
| **Win %** | Menang = 1, seri = 0,5, kalah = 0, dibagi jumlah match |

Metode dipilih di layar Klasemen (tidak di setup) dan dipakai juga oleh Detail & Bagikan. Tidak disimpan: setelah
app dibuka ulang kembali ke Total Point.

### 4.3 Tie-Breaker & Nomor Peringkat

1. Nilai metode (Total Point atau Win %) → 2. Selisih game/poin → nomor sama, baris diurutkan nama

- Hanya angka yang tampil di Klasemen dan poster yang menentukan nomor, supaya alasannya terbaca: kolom +/− (selisih)
  memisahkan nilai yang sama. Head-to-head tidak dipakai (di Mixed antar tiga pemain bisa berputar), begitu juga Total
  Point sebagai pemisah Win %.
- Nilai metode dan selisih sama → **nomor sama**, dan nomor berikutnya melanjutkan: #1, #2, #2, #3 (bukan 1, 2, 2, 4).
  W–L–D tidak membedakan nomor.
- Pemain yang belum main (pemain baru, sisa ganjil Fixed) dikelompokkan di "Belum main" tanpa nomor.
- Fixed: satu baris per pasangan (dua nama), posisinya mengikuti anggota terbaik.

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

- **Fixed:** Final setelah diakhiri atau semua match terisi.
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

### 5.2 Pemain (02a–02d)
- Satu kotak teks (tempel dari WhatsApp); parser membuang nomor/bullet, spasi ganda, baris kosong, dan duplikat
  (tidak peka huruf besar, yang pertama dipertahankan).
- Toolbar: Tempel, Contoh (hanya saat kosong), Hapus semua. Hasil = daftar bernomor dua kolom.
- Lanjut aktif untuk 4–30 pemain (Fixed dan Mixed).

### 5.3 Konfigurasi (03a–03e)
- Nama turnamen opsional paling atas (maks 40 karakter, dipangkas; kosong = tanpa nama). Hanya diisi di sini, tidak
  bisa diubah setelah turnamen dibuat.
- Mode Fixed/Mixed, format skor (4.1), durasi match (stepper ±5), jumlah court 1–10, per court nama/warna (10 warna
  preset)/booking. Estimasi di tombol. Fixed → Pasangan; Mixed → langsung Jadwal + R1.

### 5.4 Pasangan — Fixed (04a–04e)
- Acak / Manual (pilih, lepas pilihan, Urungkan), pemain ganjil + "Ubah pemain", dialog kunci pasangan.

### 5.5 Jadwal Fixed (06a–06e) & Mixed (06f–06o, 06u)
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

### 5.6 Input Skor & Walkover (07a–07o)
- Papan skor gelap: nama lengkap satu pemain per baris, satu angka besar per tim, keypad sendiri, pesan validasi,
  "Perbarui skor" saat mengubah.
- Subjudul menulis sisa booking court itu untuk match di round yang sedang berjalan ("· sisa 02:00").
- WO lewat sheet (4.4).

### 5.7 Klasemen (09a–09f)
- Tabel: # · nama · Main (jumlah match dimainkan, WO ikut) · W–L–D (W–L kalau format tidak bisa seri) · +/− (selisih)
  · nilai metode; peringkat 1 diberi bola.
- Toggle Total Point / Win %, status di subjudul, catatan WO / tidak dimainkan, ketuk baris → Detail. Tombol Bagikan.

### 5.8 Detail Pemain (10a–10c)
- Satu baris statistik (label mengikuti format skor: Poin/Game), beda partner/lawan, kalah WO, riwayat match terbaru
  di atas (Mixed menampilkan partner; menang WO menulis "+N").

### 5.9 Bagikan (11a–11l)
- Kartu pratinjau + 10 tema (default biru) + Ringkas (5 teratas + "+n lainnya") / Lengkap (semua; Feed > 10 pemain
  Mixed dibagi dua kolom rata, pasangan Fixed dan Story selalu satu kolom; lebih padat dari 10 baris satu kolom atau
  20 baris nama di Story → semua huruf baris dikecilkan sebanding). Nomor "#n"; peringkat 1 lencana emas, digantung ke kiri supaya "#1" sejajar dengan nomor di bawahnya.
- Tiap baris = nilai metode + selisih, sama dengan Klasemen: "42 poin · +12", "100% · +12"; dua kolom dan Story tanpa
  satuan ("42 · +12").
- Dua gambar 1080×1080 dan 1080×1920 dibagikan lewat share sheet sistem dengan caption teks hasil; gagal → caption
  disalin + toast "Hasil disalin".
- Turnamen bernama: nama menggantikan baris kecil "olahraga · mode · tanggal" di atas judul poster (maks dua baris) dan
  tanggalnya pindah ke ringkasan bawah ("4 round · 8 match · 21 Okt 2026"); caption dibuka "🏆 {nama} · Padel"
  (tanpa nama "🏆 Match Addict · Padel").
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
| Pasangan (Fixed) | 04a–04e |
| Jadwal Fixed | 06a–06e |
| Jadwal Mixed (+ sheet Cara kerja Mixed) | 06f–06t |
| Sheet Kelola pemain, Lanjutkan turnamen, Kelola court + detail court | 08a–08k |
| Input Skor + sheet Walkover | 07a–07o |
| Klasemen | 09a–09f |
| Detail Pemain | 10a–10c |
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

---

## 10. Keputusan yang Sudah Diambil

1. Fixed: pasangan dikunci sekali di awal (dialog konfirmasi).
2. Mixed: ulang lawan dihindari lewat penalti (soft), bukan larangan.
3. Double round-robin Fixed: tidak.
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
