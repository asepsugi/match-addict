# Pasangan (Fixed)

> Dihasilkan `tool/hifi_extract.py` dari `design/hifi.html`. Jangan diedit langsung.

Hanya untuk mode Fixed. Satu daftar pasangan bernomor dengan dua kolom nama rata, bahasa visual yang sama dengan daftar di layar Pemain. Di Manual, pemain yang belum berpasangan ada di bawahnya sebagai chip dua kolom dan pindah ke daftar begitu dipasangkan. Pasangan diacak begitu layar dibuka; peringatan "tidak bisa diubah" ada di dialog saat menekan Buat jadwal. Setelah round-robin selesai, pasangan bisa diatur ulang sebelum round tambahan (04f–04h).

## 04a · Acak

![04a](../../frames/04a.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarSegmented`, `PairList`

- Kartu 2×2 diganti daftar bernomor: satu baris per pasangan, nama rata dalam dua kolom, jadi 10 pasangan tetap rapi dan tidak ada kartu yang lebih tinggi dari sebelahnya.
- "Acak ulang" jadi tombol teks di ujung label daftar (`.ghead`), bukan tombol yang mengambang di tengah. Jumlah pasangan pindah dari subjudul ke label.
- Jumlah pasangan ganjil (mis. 3) tetap boleh: tiap round satu pasangan istirahat. Buat jadwal → dialog 04d.

## 04b · Manual · sedang memilih

![04b](../../frames/04b.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarSegmented`, `PairList`, `MabarChip`

- Dua bagian, urutan kerja dari atas: pasangan yang sudah jadi, lalu pemain yang belum berpasangan. Pemain yang sudah dipasangkan pindah ke daftar atas, tidak lagi tampil pudar di bawah, jadi tiap nama hanya ada di satu tempat.
- Chip dua kolom rata 44 pt (`.chips.cols`), bukan chip yang membungkus tidak rata. Slot kosong bergaris putus dihapus; progres ada di label "1 dari 4 pasangan".
- Ketuk A (gelap), lalu B → baris baru di daftar atas. Ketuk A lagi melepas pilihan. Catatan di bawah chip mengikuti keadaan: "Ketuk dua pemain…" atau "Ketuk satu lagi untuk dipasangkan dengan A".
- "Urungkan" melepas pasangan terakhir dan pilihan yang menggantung; mati kalau belum ada pasangan.
- Acak → Manual mengosongkan daftar tanpa dialog (pasangan acak bisa dibuat lagi). Manual → Acak dengan pasangan yang sudah jadi → dialog "Buang N pasangan manual?" (04i; di frame ini N = 1). Belum ada pasangan jadi (paling banyak satu pemain terpilih) → langsung Acak tanpa dialog (keputusan 116).

## 04c · Jumlah pemain ganjil

![04c](../../frames/04c.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarSegmented`, `PairList`

- Pemain sisa jadi baris terakhir daftar dengan nomor "–" dan keterangan pudar, bukan kotak terpisah. Satu catatan di bawahnya dengan "Ubah pemain" → kembali ke layar Pemain dengan daftar tetap terisi.
- Di Manual, pemain terakhir yang tidak punya lawan pasangan berakhir di baris yang sama begitu chip-nya tinggal satu.

## 04d · Dialog · buat jadwal

![04d](../../frames/04d.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarSegmented`, `PairList`, `showMabarSheet`, `showMabarConfirm`

- Menggantikan kotak merah permanen "Pasangan tidak bisa diubah setelah jadwal dibuat". Memakai `showMabarConfirm` varian lanjut.
- Konfirmasi → Jadwal Fixed (round-robin penuh dibuat sekaligus).

## 04e · Manual · 30 pemain (terpadat)

![04e](../../frames/04e.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarSegmented`, `PairList`, `MabarChip`

- Kondisi terpadat Manual: 30 pemain, setengah jalan (7 pasangan + 16 chip). Daftarnya lebih panjang dari layar, jadi halaman di-scroll seperti layar Pemain; app bar dan action bar tetap. Baris pasangan 40 pt (sama dengan daftar di layar Pemain, tidak bisa diketuk) dan chip 44 pt.
- Nama panjang dipotong elipsis di kolomnya, sama seperti daftar di layar Pemain.

## 04f · Atur pasangan · sebelum round tambahan

![04f](../../frames/04f.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarRowAction`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarField`, `PairList`, `MabarChip`

- Dibuka dari baris Pasangan di sheet Tambah round (06w). Mulai dari pasangan yang sekarang; tanpa Acak, karena biasanya hanya satu-dua pasangan yang berubah. Contoh: Budi S pulang setelah R14, Rizky H datang menggantikannya.
- "Ubah" (`.rowact`, baris 52 pt) memisahkan pasangan itu: kedua pemain pindah ke "belum berpasangan". Label dipilih host (2026-11-03, dulu "Pisah"). Ketuk dua chip → pasangan baru, mengisi tempat pasangan yang dipisah (di sini nomor 1), jadi urutan pasangan lain dan lawannya di round tambahan tetap: round-robin diulang dari awal, R15 = lawan R1 dengan Andi P + Rizky H di tempat Andi P + Budi S.
- Pemain pengganti: kolom nama + Tambah, sama dengan Kelola pemain (08a): nama dibersihkan, tidak boleh sama dengan pemain mana pun di turnamen ini, maks 32 pemain. Pemain baru masuk "belum berpasangan".
- "Urungkan" membatalkan langkah terakhir (ubah, pasangkan, tambah pemain); mati kalau belum ada perubahan.
- Pemain yang masih belum berpasangan saat disimpan tidak ikut round tambahan; skor dan klasemennya tetap (Total Point tertinggal, keputusan host 2026-11-03). Jumlahnya ditulis di tombol. Pemain itu muncul lagi di "belum berpasangan" saat Atur pasangan berikutnya.

## 04g · Atur pasangan · siap disimpan

![04g](../../frames/04g.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarRowAction`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarField`, `PairList`, `MabarChip`

- Andi P + Rizky H mengisi nomor 1. Budi S tidak dipasangkan → tidak ikut round tambahan. Catatan "Ketuk dua pemain…" hilang selama tinggal satu chip.
- Simpan → kembali ke sheet Tambah round (04h); belum ada yang berubah di turnamen sampai "Buat R…" diketuk.
- ← (tombol, back HP, back browser) di keadaan ini → dialog "Buang perubahan pasangan?" (04j), karena susunan pasangan dan pemain pengganti berbeda dari saat layar dibuka. Tanpa perubahan → keluar tanpa dialog (keputusan 116).
- Tombol mati dengan alasan "· minimal 2 pasangan" kalau pasangannya kurang dari dua.

## 04h · Sheet tambah round · pasangan diatur

![04h](../../frames/04h.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarStepper`, `RoundTabs`, `MatchScoreRow`, `showMabarSheet`, `CourtColorPicker`

- Baris Pasangan menulis hasil Atur pasangan: jumlah pasangan · pasangan baru · pemain yang tidak main. Estimasi ikut daftar baru (jumlah pasangan ganjil → +2 per putaran, 06y).
- "Buat R15–R16": pemain pengganti masuk daftar pemain turnamen, pasangan baru dipakai mulai R15. Pasangan yang tidak berubah tetap satu baris di Klasemen; yang berubah tampil per pemain (09g).

## 04i · Dialog · buang pasangan manual

![04i](../../frames/04i.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarSegmented`, `PairList`, `MabarChip`, `showMabarSheet`, `showMabarConfirm`

- Ketuk Acak di Manual saat 3 pasangan sudah jadi (Andi P · Budi S, Citra L · Dewant R, Eko M · Fajar K) dan Gina R terpilih (keputusan 116, PRD 17.10 A-9). Latar = keadaan saat Acak diketuk; segmen tetap Manual selama dialog terbuka.
- N = jumlah pasangan manual yang sudah jadi; pemain terpilih yang belum berpasangan tidak dihitung.
- Batal → tetap Manual; tiga pasangan dan Gina R terpilih utuh. Buang (clay) → Acak dengan pasangan acak baru (pola 04a, 5 pasangan).
- Dialog tanpa paragraf: judul sudah menyebut akibat dan jumlahnya. `showMabarConfirm` varian bahaya.
- N = 0 (belum ada pasangan jadi, paling banyak satu pemain terpilih) → langsung Acak tanpa dialog. Acak → Manual selalu tanpa dialog.
- Sama di Pasangan sparing Fixed (14b; N = pasangan manual kedua klub) dan Pasangan Grup + Gugur (19n). Layar Grup (19r–19y) tanpa dialog (keputusan 103).

## 04j · Atur pasangan · dialog buang perubahan

![04j](../../frames/04j.png)

Komponen: `MabarAppBar`, `MabarButton`, `MabarTextButton`, `MabarIconButton`, `MabarRowAction`, `MabarActionBar`, `MabarGroup / MabarRow`, `MabarGroupHeader`, `MabarField`, `PairList`, `MabarChip`, `showMabarSheet`, `showMabarConfirm`

- Latar = 04g persis. ← (tombol app bar, back HP, back browser) saat susunan pasangan atau pemain pengganti berbeda dari saat layar dibuka (keputusan 116, PRD 17.10 A-9): di sini pasangan 1 Andi P · Budi S jadi Andi P · Rizky H, dan Rizky H ditambahkan.
- Batal → tetap di Atur pasangan; susunan dan riwayat Urungkan utuh. Buang (clay) → kembali ke sheet Tambah round tanpa perubahan dari layar ini (baris Pasangan seperti sebelum dibuka); Rizky H tidak masuk turnamen.
- Tidak ada perubahan (dibuka lalu langsung ←, atau semua langkah di-Urungkan sampai susunannya sama lagi) → keluar tanpa dialog. "Simpan pasangan" tidak memunculkan dialog.
- Dialog tanpa paragraf, varian bahaya, sama dengan 04i.
