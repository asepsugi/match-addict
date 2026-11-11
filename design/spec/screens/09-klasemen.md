# Klasemen

> Dihasilkan `tool/hifi_extract.py` dari `design/hifi.html`. Jangan diedit langsung.

Tabel rapat dengan angka rata kanan. Status ditulis di subjudul, bukan badge. Metode yang dipilih di sini juga dipakai Detail dan Bagikan.

## 09a · Mixed · Total Point · nomor sama

![09a](../../frames/09a.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Poin sama dipisah selisih (kolom +/−). Poin dan selisih sama → nomor sama, nomor berikutnya melanjutkan (1, 1, 2 … 8, 8); yang bernomor sama urut nama. Head-to-head tidak dipakai lagi: alasan urutan harus terbaca dari angka di tabel (keputusan host 2026-11-02).
- Kolom +/− = selisih poin (atau game): yang dimenangkan dikurangi yang kalah, dijumlah lintas match. Menang/kalah WO tidak mengubah selisih. Ada di kedua metode, sama dengan baris poster (11a).
- Kolom Main = jumlah match yang sudah dimainkan (selesai + WO, sama dengan W + L + D). Mixed bisa berbeda antar pemain (pemain telat, istirahat), jadi kelihatan kenapa Total Point-nya tertinggal.
- Kolom W–L–D = win–loss–draw (menang–kalah–seri), singkatan Inggris seperti Win % dan Total Point. Seri tidak lagi ditulis kecil di bawah nama, jadi tinggi semua baris sama. Kolom D hanya ada kalau format skornya bisa seri (Americano total genap, Best of genap); Race to dan format ganjil cukup W–L (09c), supaya tidak ada kolom yang isinya selalu 0.
- Subjudul: olahraga · mode · status · round · match, sama urutannya dengan Detail ("Peringkat 1 · Padel · Mixed · Americano 24"; Detail menambah format skor).
- Medali emas/perak/perunggu dihapus; peringkat 1 diberi bola. Baris bisa diketuk → Detail.
- "Belum main" = pemain tanpa match selesai/WO (pemain baru, sisa ganjil di Fixed). Pemain yang keluar tetap tampil tanpa tanda. Catatan "n match WO" di bawah tabel hanya kalau ada WO (09d).
- Baru: Mixed disebut "Final" hanya setelah diakhiri atau saat waktu booking habis dengan round terakhir lengkap (09f). Sekarang Mixed jadi FINAL tiap round lengkap padahal round masih bisa dibuat.
- Contoh dihitung dari 6 match sungguhan (Americano 24, total genap jadi bisa seri): Hana–Gina vs Eko–Fajar 12–12.

## 09b · Mixed · Win %

![09b](../../frames/09b.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Kolom Main, W–L–D, dan +/− tetap di kedua metode: ganti metode hanya mengubah urutan dan kolom terakhir. W–L–D juga yang menjelaskan Win %: seri dihitung setengah menang (1–1–1 → 50%).
- Win % dibulatkan tanpa desimal di tabel (Detail tetap 1 desimal). Win % sama dipisah selisih, sama dengan Total Point: Citra +4 di atas Hana 0 dan Joko −2. Total Point tidak lagi jadi pemisah karena tidak tampil di tabel Win %.
- Metode saat Klasemen dibuka mengikuti format skor: Race to dan Best of → Win %, Americano → Total Point (keputusan host 2026-11-11). Pilihan host bertahan selama turnamen itu, tidak disimpan; turnamen berganti atau resume → kembali ke default formatnya.

## 09c · Fixed · final

![09c](../../frames/09c.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Fixed: satu baris per pasangan (dua nama ditumpuk), posisinya mengikuti anggota terbaik. Ketuk → Detail pasangan (10b).
- Judul ikon piala dan progress bar dihapus. "Final" kalau sudah diakhiri atau semua match selesai.
- Pemain sisa (jumlah ganjil) tampil sendiri di grup "Belum main".
- Race to 6 tidak pernah seri, jadi kolomnya W–L tanpa D.
- Gina · Hana menang WO di R2 dan dapat 6 game (Race to = skor penuh), jadi totalnya 23. Citra · Dewant yang kalah WO dapat 0.

## 09d · Mixed · Total Point · peringkat 1 & 2 beda

![09d](../../frames/09d.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Hanya satu bola: Eko (43) di peringkat 1, Budi (42) di peringkat 2. Nomor 1 hanya dobel kalau poin dan selisihnya sama (09a). Dewant dan Indra sama-sama 25 poin +2 → berbagi nomor 7, Gina lanjut di 8.
- Contoh dihitung dari 7 match sungguhan R1–R4: satu seri (Budi–Indra vs Citra–Gina 12–12) dan satu WO. Budi dan Joko menang WO, jadi masing-masing dapat poin rata-rata dari match yang mereka mainkan: Budi (16 + 12) ÷ 2 = 14; Joko rata-ratanya 8,5, di bawah skor menang terkecil Americano 24 (13–11), jadi dapat 13. Tanpa aturan ini Budi hanya 28 poin dan turun ke peringkat 5 padahal tidak kalah sekali pun.

## 09e · Mixed · Win % · urutan berubah

![09e](../../frames/09e.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Data yang sama bisa memberi urutan berbeda: Indra naik dari 7 ke 3 (1–0–1 = 75%), Citra turun dari 5 ke 9, Andi dari 3 ke 4.
- Win % sama dipisah selisih: Andi dan Fajar sama-sama 67%, Andi di atas karena +10 vs −4.

## 09f · Mixed · Final (setelah diakhiri)

![09f](../../frames/09f.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Mixed jadi Final kalau (a) sudah "Akhiri turnamen" (06e), atau (b) waktu booking semua court habis dan round terakhir sudah lengkap (06l), karena tidak ada lagi yang bisa dimainkan tanpa tindakan host. Di kode: `isFinished || (courtsAvailableAt(now).isEmpty && isRoundComplete(n))` — waktu habis menurut jam sungguhan.
- Subjudul memakai pola Final yang sama dengan Fixed (09c): jumlah round dan match yang dimainkan, bukan "R4 · 7 dari 8 match", karena progres round tidak bermakna lagi setelah selesai. Contoh untuk data 09a: "Padel · Mixed · Final · 3 round · 6 match".
- Match yang belum dimainkan saat Akhiri jadi "Tidak dimainkan" dan tidak dihitung (di sini R4 Andi–Hana vs Budi–Gina); jumlahnya ditulis di catatan bawah bersama WO.
- Kalau dilanjutkan atau ditambah jam lewat "Lanjutkan turnamen" (08c), status kembali Sementara dan subjudul kembali ke pola "R… · x dari y match". Waktu habis tapi round terakhir belum lengkap: tetap Sementara sampai skornya terisi atau diakhiri.
- Bagikan dari sini menulis "Klasemen akhir" di poster (11b, 11d).

## 09g · Fixed · pasangan diatur ulang

![09g](../../frames/09g.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarSegmented`, `StandingTable`

- Data 04f–04h: R1–R14 round-robin, lalu R15–R16 dengan Andi P + Rizky H; Budi S pulang setelah R14.
- Pasangan yang selalu main bersama tetap satu baris (dua nama ditumpuk). Pemain yang pasangannya berubah, pemain yang tidak ikut lagi, dan pemain pengganti tampil sendiri dengan angkanya masing-masing (keputusan host 2026-11-03). Semua baris memakai nilai per pemain yang sama, jadi urutannya tetap sebanding.
- Budi S main 7 (tertinggal satu match) dan Rizky H baru 1: Total Point mereka tertinggal, Win % lebih adil. Itu konsekuensi yang sudah diterima host.
- Sama di Detail (10d), poster Bagikan (pasangan tetap satu baris; kalau barisnya campuran "+n lainnya" di Ringkas dan "Semua n" di catatan Lengkap, tanpa kata pasangan/pemain), caption, dan halaman live.
