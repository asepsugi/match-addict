# Detail

> Dihasilkan `tool/hifi_extract.py` dari `design/hifi.html`. Jangan diedit langsung.

Satu baris angka menggantikan lima kotak statistik. Riwayat match memakai bentuk baris yang sama dengan Jadwal.

## 10a · Pemain · Mixed

![10a](../../frames/10a.png)

Komponen: `MabarAppBar`, `MabarIconButton`, `MabarGroup / MabarRow`, `MatchScoreRow`, `StatLine`

- Avatar inisial bergradien dihapus. Subjudul: peringkat · olahraga · mode · format skor. Angka mengikuti metode yang dipilih di Klasemen.
- Label statistik mengikuti format skor, bukan mode: "Poin" / "Selisih poin" untuk Americano, "Game" / "Selisih game" untuk Race to dan Best of; W–L–D hanya kalau format bisa seri, selain itu W–L (10b). Format di subjudul yang menjelaskan kenapa labelnya berbeda.
- "Beda partner/lawan" dibanding semua pemain lain (termasuk yang keluar). "Kalah WO" tetap.
- Riwayat: terbaru di atas. Baru: Mixed menampilkan partner di tiap match. Baris atas selalu tim pemain ini, ditulis seperti Fixed (10b): nama sendiri dulu lalu partner ("Andi P · Dewant R"), lawan di baris bawah dengan "vs". Hasil: tebal + bola = menang, pudar = kalah, "Seri", "WO" (menang/kalah). Match kosong dan tidak dimainkan tidak masuk. Tidak bisa diketuk.

## 10b · Pasangan · Fixed

![10b](../../frames/10b.png)

Komponen: `MabarAppBar`, `MabarIconButton`, `MabarGroup / MabarRow`, `MatchScoreRow`, `StatLine`

- Baru: judul berisi kedua nama pasangan. Sekarang hanya nama anggota pertama yang tampil dan anggota kedua tidak bisa dibuka.
- "Beda partner" disembunyikan di Fixed karena selalu 1.
- Pada riwayat Fixed, baris atas selalu pasangan ini (tebal kalau menang).
- Menang WO menulis tambahan game/poinnya dengan warna pudar ("+6"), supaya jumlah riwayat cocok dengan angka di atas: 5 + 6 + 6 + 6 = 23. Selisih tidak berubah (+7).

## 10c · Belum ada match

![10c](../../frames/10c.png)

Komponen: `MabarAppBar`, `MabarIconButton`, `MabarGroup / MabarRow`, `StatLine`

- Kotak info abu-abu diganti satu kalimat. Pemain tidak ditemukan / tidak ada turnamen: teks tengah "Belum ada turnamen berjalan".

## 10d · Fixed · pasangan berubah

![10d](../../frames/10d.png)

Komponen: `MabarAppBar`, `MabarIconButton`, `MabarGroup / MabarRow`, `MatchScoreRow`, `StatLine`

- Baris Klasemen per pemain di Fixed (09g) membuka Detail pemain itu saja, bukan pasangan: judul satu nama.
- "Beda partner" yang disembunyikan di Fixed (10b) muncul kalau partnernya lebih dari satu: 2 / 16 (pemain lain di turnamen, termasuk Rizky H). Beda lawan dibanding pemain lain selain partnernya sendiri: 17 − 1 − 2 = 14.
- Riwayat: baris atas tim sendiri dengan nama sendiri dulu, seperti Mixed (10a), jadi partner yang berbeda terbaca (R15 Andi P · Rizky H, R13 Andi P · Budi S).
