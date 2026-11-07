# Sparing

> Dihasilkan `tool/hifi_extract.py` dari `design/hifi.html`. Jangan diedit langsung.

Dua klub bertanding (PRD §13, keputusan host 19, 2026-11-04). Tahap 1: layar inti. Klub pertama selalu baris atas setiap match, dan skor klub (`.clubscore`) menulis klubnya dengan urutan yang sama, jadi posisi baris sudah menunjukkan klubnya. Contoh: PB Garuda 8 pemain vs Matcha Club 6, Padel, Race to 6, 15 mnt, 2 court × 2 jam. Jadwal dan klasemen Fixed = contoh PRD 13A–13C dalam susunan generator (diverifikasi tech lead, 2026-11-04).

## 13a · Pemain · Sparing · kosong

![13a](../../frames/13a.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `MabarField`, `NameListField`

- Sparing dipilih di layar Pemain (K4). Dua blok berurutan, masing-masing kotak nama klub (sama dengan kotak Nama turnamen) lalu kotak nama pemain dengan toolbar dan parser yang sama dengan Mabar (02a), termasuk buang duplikat di dalam satu klub.
- Blok atas = klub pertama: klub ini selalu sisi atas match di semua layar (S4). Urutan tidak bisa ditukar setelah jadwal dibuat.
- Nama klub wajib, maks 20 karakter (ketikan ke-21 tidak masuk, tanpa penghitung), spasi awal/akhir dibuang. Kotak nama klub tanpa label: placeholder "Nama klub pertama" / "Nama klub kedua".
- Contoh (hanya saat kotak itu kosong) mengisi nama contoh yang berbeda per blok: klub pertama 8 nama (Andi … Hadi), klub kedua 6 nama (Indra … Nanda), supaya contoh tidak pernah membuat nama yang sama di dua klub. Nama klub tidak ikut diisi.
- Tidak autofocus, sama dengan 02a. Lanjut mati sampai semua syarat terpenuhi; catatan baru muncul setelah blok itu diisi (13d–13g).

## 13b · Pemain · Sparing · terisi · siap lanjut

![13b](../../frames/13b.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarField`, `NameListField`, `RosterPreview`

- Garuda 8 + Matcha 6 = 14 pemain → Lanjut aktif (AC-S1). Jumlah ditulis sekali per klub di label daftarnya; tombol cukup "Lanjut" seperti Mabar.
- Dua blok lebih panjang dari satu layar, jadi halaman di-scroll (app bar dan action bar tetap); bawahnya di 13c.
- Daftar bernomor per klub (`.roster`, sama dengan 02b), urut ke bawah dulu, mulai 1 di tiap klub.
- Syarat Lanjut: kedua nama klub terisi dan berbeda (tidak peka huruf besar), tiap klub minimal 2 pemain, total 4–30, tidak ada nama pemain di dua klub (K6, K8).

## 13c · Pemain · Sparing · digulir ke bawah

![13c](../../frames/13c.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarField`, `NameListField`, `RosterPreview`

- Keadaan sama dengan 13b, digulir sampai bawah: blok klub kedua dan daftarnya.
- 6 nama pas 6 baris kotak teks, jadi tanpa garis scroll di dalam kotak.
- Lanjut → Atur turnamen (13h–13j) dengan olahraga, dua klub, dan anggotanya. Kembali dari Atur turnamen membuka layar ini dengan isian utuh.

## 13d · Pemain · klub kedua baru 1 pemain

![13d](../../frames/13d.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarField`, `NameListField`, `RosterPreview`

- Contoh PRD: Matcha hanya Indra → Lanjut mati (AC-S1). Kurang dari 2 di satu klub bukan error (host masih mengetik), jadi catatannya abu-abu seperti "Minimal 4 pemain" di 02c.
- Catatan jumlah ada di bawah daftar klub itu, catatan nama klub di bawah kotak nama klub (13e, 13f). Total tetap minimal 4: dua klub × 2.

## 13e · Pemain · nama klub kosong

![13e](../../frames/13e.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarField`, `NameListField`, `RosterPreview`

- Nama klub kosong → Lanjut mati (AC-S2). Catatan abu-abu "Isi nama klub" di bawah kotaknya hanya kalau blok itu sudah berisi pemain; blok yang masih kosong seluruhnya tanpa catatan (13a).
- Spasi saja dihitung kosong.

## 13f · Pemain · nama klub sama

![13f](../../frames/13f.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarField`, `NameListField`, `RosterPreview`

- "PB Garuda" dan "pb garuda" dianggap sama (tidak peka huruf besar, spasi dipangkas) → Lanjut mati (AC-S2).
- Ini salah isi, bukan sedang mengetik: tepi kotak dan catatannya clay, seperti "Maksimal 30 pemain" di 02d. Pesan selalu di kotak klub kedua, karena klub pertama yang diisi duluan.

## 13g · Pemain · pemain di dua klub

![13g](../../frames/13g.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarField`, `NameListField`, `RosterPreview`

- Nama yang sama (tidak peka huruf besar) di dua klub → Lanjut mati, pesan clay menyebut namanya (AC-S2). Pesan ini boleh karena mencegah salah langkah (Prinsip "Tanpa Petunjuk").
- Pesan di bawah daftar klub kedua. Lebih dari satu nama: "Andi, Budi ada di dua klub"; lebih dari tiga: "Andi, Budi, Citra +2 ada di dua klub". Daftarnya tidak ikut diwarnai, sama dengan 02d.
- Kotak teks sedang diketik di baris ke-7, jadi isinya bergulir: baris pertama (Indra) di atas kotak.
- Duplikat di dalam satu klub tetap dibuang diam-diam dengan catatan "Duplikat dibuang: …" seperti 02b; itu bukan error.

## 13h · Atur turnamen · Fixed sparing

![13h](../../frames/13h.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarStepper`, `MabarField`, `ModePicker`, `CourtColorPicker`

- Layar sama dengan 03a; hanya subjudul dan estimasi yang ikut sparing. Mode, format skor, durasi, court, dan nama turnamen tetap dipilih di sini; nama turnamen terpisah dari nama klub (K8).
- Subjudul: olahraga · klub pertama + jumlah pemainnya · klub kedua + jumlahnya.
- Estimasi Fixed sparing dihitung dari jadwal, bukan dari jam booking: 4 × 3 pasangan = 12 match, court aktif min(2, 4, 3) = 2, round = ⌈12 ÷ 2⌉ = 6 (contoh 13A). Karena jadwalnya pasti, tombol tanpa "±" (Fixed biasa 03a tetap "±6 round · 12 match" dari booking).
- Court aktif lebih sedikit dari jumlah court → tombol ditambah "· n court", sama dengan 13j. Contoh 8 / 4 pemain di 3 court: "Lanjut · 4 round · 8 match · 2 court" (Court 3 tidak pernah dapat match, AC-S6).
- Jadwal lebih panjang dari booking terpendek (mis. 16 / 14 pemain di 4 court × 2 jam: 14 round = 3 j 30 m): 14f.
- Lanjut → Pasangan per klub (14a–14e).

## 13i · Atur turnamen · Mixed sparing

![13i](../../frames/13i.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarStepper`, `MabarField`, `ModePicker`, `CourtColorPicker`

- Mixed: estimasi sama dengan 03b (booking terpendek ÷ durasi = 2 jam ÷ 15 mnt = ±8 round). Court aktif min(2, ⌊8 ÷ 2⌋, ⌊6 ÷ 2⌋) = 2 = semua court, jadi tanpa tambahan (contoh 13B).
- Mulai Round 1 → Jadwal Mixed + R1, lalu sheet Cara kerja Mixed versi sparing (Match/Pemain per klub; tahap 2).

## 13j · Atur turnamen · Mixed sparing · court lebih dari yang terpakai

![13j](../../frames/13j.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `MabarStepper`, `MabarField`, `ModePicker`, `CourtColorPicker`

- Matcha 3 pemain: court aktif min(2, 4, ⌊3 ÷ 2⌋) = 1 (AC-S10). Tombol menulis jumlah court yang terpakai; court yang tidak aktif = court bernomor terakhir (Court 2), tetap boleh dipesan dan dipakai begitu pemainnya cukup (Kelola pemain).
- Tidak ada peringatan atau catatan di grup Court: akibatnya cukup terbaca dari tombol.

## 13k · Jadwal Fixed sparing · round berjalan

![13k](../../frames/13k.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `RoundTabs`, `MatchScoreRow`, `RestingList`

- Contoh 13A: Garuda 4 pasangan, Matcha 3, 2 court; 12 match dalam 6 round (susunan generator), R1–R5 sudah terisi (hasil 13C). Tiap pasangan Garuda 3 match, Matcha 4; tiap pasangan bertemu tiap pasangan klub lain tepat sekali, tidak pernah sesama klub.
- Skor klub (`.clubscore`) paling atas: PB Garuda 6 – 4 Matcha Club, sama dengan Klasemen 13n. Barisnya berurutan sama dengan baris match: klub pertama di atas, jadi tiap baris atas match = pasangan PB Garuda tanpa label tambahan (S4, AC-S7). Bola = klub yang unggul; seri → bola di kedua baris.
- Di kanan nama klub: Total Point klub · selisih (pemisah kalau match menang sama, K2); satuan ikut format ("game" di Race to, "poin" di Americano).
- Istirahat bisa beberapa pasangan per round, dari kedua klub (R6: Andi · Budi, Citra · Dewi | Indra · Joko): kolom kiri klub pertama, kanan klub kedua, nama klub di atas kolomnya. Klub tanpa yang istirahat di round itu: kolomnya tetap ada dengan "–".
- Hitung mundur 00:45 = booking 2 jam − 75 menit (5 round × 15 mnt) sejak turnamen dimulai. Round dibuka berurutan, menu ⋯ dan Akhiri sama dengan 06a–06e.

## 13l · Jadwal Fixed sparing · semua match terisi

![13l](../../frames/13l.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `RoundTabs`, `MatchScoreRow`, `RestingList`

- R6 diisi: Eko · Fajar 6–0 Kiki · Lina, Gita · Hadi 5–6 Maya · Nanda. Skor klub akhir 7 – 5 (Matcha: 4 menang + 1 WO di R3, Citra · Dewi absen), Total Point 56 – 49 (Matcha 43 game + 6 nilai WO Race to 6), selisih +13 / −13 (AC-S14, AC-S15).
- Klub kedua yang menang tetap di baris bawah; bola pemenang dan angka tebal pindah ke baris itu, sama dengan baris match biasa. Pasangan WO juga tetap di sisi klubnya (R3: Citra · Dewi di atas dengan "WO · Absen").
- Action bar sama dengan 06v: Klasemen jadi ikon, "Tambah round" → sheet round tambahan per satuan KPK(4, 3) = 12 match (K5; sheet 14n). Sisa booking 00:30 = 2 round, jadi sheetnya akan menulis "lewat booking 01:00" (AC-S18).
- Skor klub Final di Klasemen (13o) sampai round tambahan dibuat.

## 13m · Jadwal Mixed sparing · round berjalan

![13m](../../frames/13m.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `RoundTabs`, `MatchScoreRow`, `RestingList`

- Contoh 13B: Garuda 8, Matcha 6, 2 court. Tiap match = 2 pemain klub pertama (baris atas, berpasangan) vs 2 pemain klub kedua. Slot per round: 4 Garuda + 4 Matcha, jadi 4 Garuda dan 2 Matcha istirahat.
- Susunan generator (2026-11-04; dulu contoh designer): R1 Eko · Gita 6–4 Nanda · Kiki, Citra · Fajar 3–6 Maya · Joko. R2 Budi · Andi 6–2 Lina · Kiki, Dewi · Hadi 6–5 Nanda · Indra. R3 Fajar · Eko 6–4 Joko · Indra, Citra · Gita vs Lina · Maya belum. Skor contoh designer: skor klub 4 – 1, Total Point 27 – 21. Prioritas R4 (generator): Andi, Budi, Dewi, Hadi · Kiki, Nanda.
- Istirahat di round terakhir dipisah per klub dengan prioritas masing-masing (`priorityOrder` per klub, slot klub itu): semua yang istirahat kebagian slot R4, jadi hanya daftar "Prioritas main di R4". Kalau yang istirahat di satu klub lebih banyak dari slotnya, klub itu mendapat daftar kedua "Istirahat lagi di R4" dengan dua kolom yang sama (seperti 06o); kolom klub yang semua kebagian berisi "–". Daftar ini sama persis dengan hasil Buat R4 (AC-S11).
- Fairness per klub: selisih main antar pemain satu klub ≤ 1. Setelah R3 Garuda 2·2·2·2·1·1·1·1 (R3 sedang dimainkan dihitung), Matcha 2 semua; antar klub boleh beda (K1).
- Pemain (14) → Kelola pemain per klub (15l). Tombol bawah, Batalkan Rn, menu ⋯, Kelola court sama dengan 06f–06t.

## 13n · Klasemen sparing · Fixed · Sementara

![13n](../../frames/13n.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `StandingTable`

- Skor klub di atas tabel dan tetap di tempat saat tabel digulir (seperti tab metode). Klub menang = match menang (seri ½, WO = menang untuk klub lawan); sama → Total Point klub; masih sama → Seri (K2). Skor klub tidak ikut metode: Total Point / Win % hanya mengurutkan tabel.
- Tabel per klub, masing-masing bernomor mulai #1 (K3): jumlah main antar klub berbeda (Garuda 2–3, Matcha 3–4), jadi satu tabel gabungan menguntungkan klub kecil. Label klub di atas tabelnya; kolom dan aturan nomor sama dengan 09c.
- Data 13C setelah R5 (10 dari 12 match): 6 – 4, Total Point 45 – 43, selisih +8 / −8 (AC-S14). Main Garuda 3·3·2·2, Matcha 4·3·3: Eko · Fajar 12 dari 2 match di atas Citra · Dewi 10 dari 3. Maya · Nanda 17 termasuk 6 nilai WO R3. "1 match WO" di bawah tabel terakhir.
- Isinya lebih panjang dari layar: tabel Matcha berlanjut di bawah action bar (bagian bawahnya di 13o). Ketuk baris → Detail (14v, 14w).

## 13o · Klasemen sparing · Fixed · Final · digulir ke bawah

![13o](../../frames/13o.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `StandingTable`

- Final: semua 12 match terisi (atau diakhiri), sama dengan 4.6. PB Garuda 7 – 5 Matcha Club, Total Point 56 – 49, selisih +13 / −13 (AC-S14).
- Digulir sampai bawah; skor klub dan tab metode tetap di atas, tabel PB Garuda bergeser ke bawah app bar.
- PB Garuda: #1 Eko · Fajar 18 (+11) · #2 Andi · Budi 14 (+1) · #3 Gita · Hadi 14 (−2) · #4 Citra · Dewi 10 (+3). Matcha Club: #1 Maya · Nanda 23 (+4, 3 menang termasuk 1 WO) · #2 Kiki · Lina 16 (−3) · #3 Indra · Joko 10 (−14) (13.6, AC-S17).
- Maya · Nanda 23 = 17 game + 6 nilai WO; WO tidak mengubah selisih. Catatan "1 match WO" di bawah tabel terakhir, seperti 09c.

## 13p · Klasemen sparing · Fixed · Final · Win %

![13p](../../frames/13p.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `StandingTable`

- Ganti metode hanya mengubah urutan dan kolom terakhir tabel; skor klub dan Total Point klub di atas tidak berubah.
- Win % data 13C: PB Garuda #1 Eko · Fajar 100 · #2 Andi · Budi 67 · #3 Citra · Dewi 33 (+3) · #4 Gita · Hadi 33 (−2); Matcha Club #1 Maya · Nanda 75 · #2 Kiki · Lina 50 · #3 Indra · Joko 0 (AC-S17).
- Posisi gulir paling atas (tabel Matcha berlanjut di bawah action bar).

## 13q · Bagikan sparing · Ringkas · tema biru

![13q](../../frames/13q.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarSegmented`, `SharePoster`

- Poster dibuka dengan skor klub (K7): di bawah judul "Klasemen akhir", dua baris klub (klub pertama di atas) dengan Total Point klub · selisih dan jumlah match menang. Tanpa bola: warna bola tidak terbaca di tema lembut; yang unggul terbaca dari angkanya.
- Ringkas = 3 teratas tiap klub (dikonfirmasi host). Tiap klub diawali label klub gaya baris kecil poster; "+n pasangan lainnya" di ujung label klub yang terpotong (Garuda 4 pasangan → +1), klub yang tampil semua tanpa tambahan. Tiap klub punya #1 sendiri, jadi dua lencana emas.
- Baris memakai ukuran huruf poster Lengkap (11b) dan berbagi tinggi yang tersisa; nilai = metode + selisih seperti 11a. Pasangan ditulis "Eko + Fajar".
- Tanpa nama turnamen: baris kecil "olahraga · mode · tanggal" seperti 11c; dengan nama: nama di baris kecil, tanggal pindah ke kaki (11a). Ringkasan kaki menulis WO seperti 11d.
- Caption (Ringkas; Lengkap menambah "Hasil per Round"): `🏆 PB Garuda 7–5 Matcha Club · Padel` `4 November 2026` `Klasemen Akhir · PB Garuda` `1. Eko + Fajar — 18 game · 100.0% (3-0, +11 game)` `2. Andi + Budi — 14 game · 66.7% (2-1, +1 game)` `3. Gita + Hadi — 14 game · 33.3% (1-2, -2 game)` `4. Citra + Dewi — 10 game · 33.3% (1-2, +3 game)` `Klasemen Akhir · Matcha Club` `1. Maya + Nanda — 23 game · 75.0% (3-1, +4 game)` `2. Kiki + Lina — 16 game · 50.0% (2-2, -3 game)` `3. Indra + Joko — 10 game · 0.0% (0-4, -14 game)` `6 round · 12 match · 1 WO · 4 Nov 2026`
- Caption: baris pertama skor klub menggantikan "🏆 {nama} · Padel"; turnamen bernama → nama di baris kedua sebelum tanggal ("Mabar Jumat"). Seri: "🏆 PB Garuda 6½–5½ Matcha Club" atau "… 6–6 … · Seri" kalau Total Point juga sama.
