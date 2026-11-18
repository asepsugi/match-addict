# Input Skor

> Dihasilkan `tool/hifi_extract.py` dari `design/hifi.html`. Jangan diedit langsung.

Papan skor gelap dengan satu angka besar per tim untuk ketiga format, dan keypad sendiri. Ketuk kotak untuk memilih, ketik angka (maksimal 2 digit), → pindah ke tim lawan. Format dan targetnya ditulis di subjudul sebagai pengingat host.

## 07a · Race to 6 · kosong

![07a](../../frames/07a.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Header: nama court sebagai judul, subjudul round · format · sisa booking court itu (07l). "ROUND 1 · MATCH 1", badge court, ikon olahraga, dan chip metode skor dihapus.
- Race to tidak mengisi otomatis: skor lawan harus diketik karena bisa berapa saja di bawah target.
- WO di kanan atas → sheet 07j.

## 07b · Race to 6 · selesai

![07b](../../frames/07b.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Pemenang ditandai bola di kolom tetap di kiri nama (10 pt), sejajar tengah dengan dua baris nama. Kolom ini ada di kedua tim (kosong kalau belum/tidak menang), jadi dua baris nama selalu rata dan nama tidak bergeser saat bola muncul. Tim yang kalah dipudarkan, seperti baris Jadwal. Nama 20/700.
- Simpan → kembali ke Jadwal tanpa toast.

## 07c · Race to 6 · selisih satu game

![07c](../../frames/07c.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Race to N murni: match langsung selesai begitu satu tim mencapai N, jadi menang selisih satu game (6–5) sah. Tidak ada 7–5 / 7–6 dan tidak ada tie-break: itu skor set standar (wajib selisih 2), format lain (keputusan host 2026-10-22).

## 07d · Race to 6 · belum selesai

![07d](../../frames/07d.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Pesan lain: "Belum ada yang sampai 6" (mis. 5–3), "Skor akhir race to 6: 6–0 sampai 6–5" (skor di atas 6, hanya dari data lama). Angka 7 ke atas tidak bisa diketik sama sekali (07k).
- Kedua tim tidak bisa sama-sama mencapai target: match sudah selesai saat tim pertama mencapainya (keputusan host 2026-10-22).
- Satu sisi terisi, sisi lain kosong: Simpan mati tanpa pesan (sedang mengetik).

## 07e · Best of 5

![07e](../../frames/07e.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Isi satu sisi; kotak lawan yang masih kosong terisi `N − x` dan tampil pudar sebagai tanda otomatis. Mengetik di kotak lawan menimpa nilai otomatis; sisi pertama tidak dihitung ulang (07m, 07o).
- Angka di atas N tidak bisa diketik: tombol 6–9 mati untuk Best of 5.

## 07f · Best of 6 · seri

![07f](../../frames/07f.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Hanya mungkin kalau N genap. Seri dihitung setengah menang di Win %. Americano dengan total genap (mis. 24 → 12–12) berperilaku sama.

## 07g · Americano

![07g](../../frames/07g.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Poin reli. Isi satu sisi, kotak lawan yang masih kosong terisi `total − x`; total boleh kurang dari 21 kalau match dihentikan lebih awal (07m). Kalimat "Isi salah satu, skor lawan terisi otomatis" dihapus.
- Kalimat hasil memakai pola yang sama dengan Race to dan Best of: nama pemenang + "menang" + skor pemenang–kalah ("menang 13–8"), bukan selisih (PATCH 3.8.1, B-15).

## 07h · Americano · batas total di keypad

![07h](../../frames/07h.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Isi kotak tidak bisa melebihi total (21). Setelah mengetik "2", hanya 0 dan 1 yang masih aktif (20, 21); tombol lain mati. Dulu angka seperti 25 bisa diketik lalu ditolak dengan pesan.
- Sisi lawan langsung terisi total − x, jadi skor selalu sah selama hanya satu sisi diketik; tombol Simpan aktif.
- Kotak lawan yang diketik sendiri dipegang apa adanya: total kurang dari 21 sah kalau pemenang sudah 11 (07m), lebih dari 21 ditolak (07n).

## 07i · Mengubah skor tersimpan

![07i](../../frames/07i.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Skor tersimpan diisi otomatis, belum ada kotak aktif sampai diketuk. Tombol jadi "Perbarui skor".
- Selama belum ada kotak aktif semua angka dan ⌫ mati; ketuk salah satu kotak (atau →) untuk mulai mengubah (keputusan host 2026-10-22; ⌫ mati sejak PATCH 3.8.1).
- Match WO dibuka di sini juga: skor lama (kalau ada) terisi; menyimpan skor mengubahnya dari WO jadi selesai.
- Best of dan Americano: skor tersimpan tidak diisi ulang otomatis; mengubah satu sisi membiarkan sisi lain (07n).

## 07j · Sheet · walkover

![07j](../../frames/07j.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarGroup / MabarRow`, `MabarChip`, `ScoreBoard / ScoreKeypad`, `showMabarSheet`

- Nilai menang WO ikut format: Race to N → pemenang N game ("…menang WO, dapat 6 game"); Best of N dan Americano → rata-rata game/poin dari match yang dia mainkan sendiri, tapi tidak pernah di bawah skor menang terkecil = ⌊total ÷ 2⌋ + 1 (Americano 21 → 11, Americano 24 → 13, Best of 5 → 3, Best of 6 → 4), supaya "menang" WO tidak bernilai skor kalah seperti yang ditolak di Input Skor ("…dapat poin rata-rata mereka, minimal 11"). Rata-rata dibulatkan ke terdekat; belum pernah main → skor menang terkecil. Yang kalah WO 0. Menang/kalah ikut W–L–D dan Win %; selisih tidak berubah untuk kedua tim. Skor penuh hanya untuk Race to karena di sana pemenang memang selalu dapat N; di Best of dan Americano skor penuh adalah hasil maksimal, jadi menang WO malah lebih untung daripada main.
- Keterangan "Tetap main" di pilihan yang tidak dipilih dihapus. Kalimat "Pilih pasangan yang tidak bisa main…" diganti label pertanyaan.
- Alasan opsional, ketuk lagi untuk melepas (baru: melepas benar-benar menghapus alasan lama). Alasan tampil di baris Jadwal (06g).
- Simpan WO mati sampai satu pasangan dipilih. Membuka WO yang sudah ada: pilihan dan alasan terisi.

## 07k · Race to 6 · batas di keypad

![07k](../../frames/07k.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Isi satu kotak paling tinggi target (6), jadi tombol 7–9 mati. Kalau tidak ada angka lagi yang mungkin (satu digit sudah penuh), kursor pindah sendiri ke kotak lawan yang masih kosong.
- Kotak yang sudah penuh (tidak ada digit lagi yang bisa ditambahkan di belakangnya) menerima ketikan berikutnya sebagai pengganti isinya, begitu juga kotak yang baru dipilih. Jadi yang mati hanya angka di atas batas: Race to 6 berisi "4" → 7–9 mati (07b), Best of 5 berisi "3" → 6–9 mati (07e), Americano 21 berisi "13" → semua aktif (07g); "2" di Americano 21 belum penuh, jadi hanya 0 dan 1 (07h). Keputusan host 2026-10-22.
- Kombinasi baru dicek setelah dua kotak terisi: 6 sah atau tidak tergantung lawan (6–5 sah, 6–6 tidak; pesannya di 07d).
- Tombol sengaja tidak dimatikan berdasarkan isi kotak lawan. Contoh: host salah ketik 6–4 padahal 4–6; kalau angka dimatikan karena isi lawan, host harus mengubah kotak lawan dulu baru bisa mengoreksi.
- Race to 9: batasnya 9, jadi semua angka satu digit dan kotak langsung penuh.

## 07l · Input Skor · sisa waktu court

![07l](../../frames/07l.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Contoh court yang baru ditambah (06q). Subjudul menulis sisa court ini dengan format yang sama dengan strip: "Round 5 · Americano 21 · sisa 02:00"; 07a–07k dan 07m–07o memakai aturan yang sama.
- Hanya untuk match di round yang sedang berjalan (Mixed: round terakhir; Fixed: round yang dibuka), termasuk saat mengubah skornya (07i), selama turnamen belum diakhiri. Match di round yang sudah lewat: subjudul tanpa sisa. Sisa kurang dari satu durasi match: "sisa 00:12" clay; sudah lewat: "waktu habis" clay. Skor tetap bisa disimpan.

## 07m · Americano · berhenti lebih awal

![07m](../../frames/07m.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Match boleh dihentikan begitu lawan tidak mungkin mengejar: pemenang sudah mencapai skor menang terkecil ⌊N ÷ 2⌋ + 1 (Americano 21 → 11, Americano 24 → 13, Best of 5 → 3, Best of 6 → 4). Total boleh kurang dari N, jadi yang kalah tidak dapat poin dari sisa yang tidak dimainkan (keputusan host 2026-10-26).
- Isi 11, kotak lawan terisi 10 otomatis; ketik 5 di kotak lawan → 11 tetap, tidak dihitung ulang jadi 16. Nilai otomatis hanya mengisi kotak yang kosong atau yang masih otomatis, dan ikut berubah selama sisi pertama diketik (1 → 20, 11 → 10).
- Best of 5 berhenti di 3–1 atau 3–0 berlaku sama.

## 07n · Americano · total lebih dari 21

![07n](../../frames/07n.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Kedua sisi diketik sendiri dan jumlahnya lebih dari N: "Total poin lebih dari 21" (Best of 5: "Total game lebih dari 5"), Simpan mati. Terjadi saat mengoreksi salah satu sisi atau mengubah skor tersimpan (07i), karena sisi lain tidak dihitung ulang.
- Tombol tidak dimatikan karena isi lawan (07k), jadi 9 tetap bisa diketik; pesannya yang menolak.

## 07o · Best of 5 · belum ada pemenang

![07o](../../frames/07o.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `ScoreBoard / ScoreKeypad`

- Total kurang dari N dan belum ada yang mencapai skor menang terkecil: "Minimal skor pemenang 3", Simpan mati. Americano 21: 10–5 atau 5–5 → "Minimal skor pemenang 11".
- Seri hanya dengan total penuh (07f), jadi tetap hanya di N genap dan kolom W–L–D Klasemen tidak berubah.
