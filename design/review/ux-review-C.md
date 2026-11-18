# Review UX/UI kelompok C: Sparing, Mexicano, Tukar pemain, Grup + Gugur

Tanggal 2026-11-18 · mode review (hi-fi, frame, tokens, kode tidak diubah) · bahan: `design/spec/screens/13–17, 19–22`,
`design/hifi.html` baris 3453–4924 + Cakupan 4925–5108, PRD §16.6–16.12, `tokens.json`, 8 lembar kontak di
`design/review/sheets/C-*.png` (56 frame), kontras dihitung dari token dengan skrip.

## 1. Ringkasan

- Sparing, Mexicano, dan Tukar pemain konsisten dengan pola alur dasar: alasan di tombol, akibat di dialog, angka di
  frame cocok satu sama lain (dicek: skor klub 13k/13l/14n, Grup B 22b, 22d/22e). Mexicano tidak punya temuan sendiri.
- Risiko terbesar ada di Grup + Gugur saat pindah fase atau saat rencana berubah. Dialog Akhiri tidak menyebut bahwa
  bagan batal dibuat (C-1). Format babak tidak bisa diubah setelah jadwal dibuat, padahal catatan 19e menjanjikannya
  (C-2). Pemenang Semifinal yang salah tidak bisa dibetulkan begitu Final sudah ada skor (C-9).
- Ada varian yang belum digambar: sheet Tukar terpadat, Beranda Grup + Gugur, dan state error Sparing tahap 2.
  Komponen baru (`.clubscore`, `.bagan`, chip grup) belum punya aturan Semantics. Teks tab terkunci kontrasnya 1,68:1.
- Cara saya membaca "keputusan": hal yang tertulis di Cakupan → "Sudah disetujui" dianggap final dan masuk daftar §3
  kalau saran bertentangan dengannya. Detail yang hanya ada di catatan frame (ikut keputusan 103 "usulan desainer
  disetujui") saya usulkan, tetapi ditandai "perlu host".

## 2. Temuan berperingkat

Level triase: 0 teks · 1 tampilan/frame · 2 aturan · 3 fitur.

### Tinggi

| id | frame / komponen | masalah (fakta) | prinsip | usulan | level | yakin |
|---|---|---|---|---|---|---|
| C-1 | Akhiri di Grup + Gugur (20q memakai 06e; hifi 4641; teks dialog "Akhiri turnamen? Match yang belum main tidak dihitung." 3729) | Di fase grup, Akhiri membuat bagan tidak pernah dibuat dan peringkat diambil dari posisi grup (16.8/16.9), dan turnamen Fixed yang diakhiri tidak bisa dilanjutkan. Di gugur sebelum Final, finalis berbagi #1 (21t/22f). Dialog tidak menyebut satu pun dari akibat ini. Host yang ingin "melewati" match grup yang tidak bisa dimain (jalan yang benar: WO) bisa mengakhiri seluruh turnamen. Dialog Akhiri khusus Grup + Gugur juga tidak punya frame. | Nielsen 5 (mencegah error); aturan host "akibat di dialog" | Fase grup: judul "Akhiri turnamen?", isi "Match yang belum main tidak dihitung. Bagan tidak dibuat; peringkat dari posisi grup.", tombol "Batal" / "Akhiri". Gugur sebelum Final: isi "Final dan Juara 3 tidak dimainkan. Andi · Budi dan Citra · Dewi sama-sama #1." Tambah frame 20r (latar 20b) dan 21z (latar 21o). | 0 + 1 | tinggi |
| C-2 | 19e (hifi 4409) → Jadwal 20/21, Input Skor 21g/21h | Catatan 19e berbunyi "Format babak bisa diubah lagi setelah jadwal dibuat … tempatnya di Jadwal (kelompok 20/21)", tetapi tidak ada frame yang menggambarnya, dan GU9 ditunda ke 3.8.x (CLAUDE.md). Keypad Race to mengikuti format babak (21h: Race to 4 → 5–9 mati). Kalau booking hampir habis (19i/19k menggambar "lewat booking" sebagai keadaan biasa) dan host memperpendek Final dari Race to 9 ke 6, skor 6–4 tidak bisa disimpan. Satu-satunya jalan adalah WO. | Nielsen 3 (kendali), 9 (pulih dari error) | Prioritaskan frame GU9 di 3.8.x: label baris babak "Final · Race to 9" di tab babak bisa diketuk selama babak itu belum ada skor → sheet babak 19f (tanpa durasi). Tambah frame 21z1 (sheet di atas tab Final) dan 21z2 (label sesudah diubah). Sampai itu ada, tulis "3.8.x, belum digambar" di catatan 19e. | 1 | sedang (asumsi: Race to tidak bisa berhenti lebih awal, sesuai 2.8.0) |

### Sedang

| id | frame / komponen | masalah (fakta) | prinsip | usulan | level | yakin |
|---|---|---|---|---|---|---|
| C-3 | Sheet Tukar 17b–17p | Kandidat paling banyak 6 (17j). Mixed 30 pemain di 2 court = 22 yang istirahat; Mixed sparing 15d = 12 PB Garuda. Chip dua kolom 44 pt × 11 baris ditambah pratinjau, Diganti, dan tombol lebih tinggi dari layar 844. Belum ada frame yang menunjukkan bagian mana yang digulir dan apakah Batal/Tukar tetap terlihat. | Matriks varian (maks); Nielsen 1 | Frame 17s "Sheet tukar · 30 pemain · 22 kandidat": sheet 92% (pola 08a), judul + pratinjau + Diganti tetap, daftar kandidat digulir, Batal/Tukar menempel di bawah. Frame 17t untuk Mixed sparing dengan 12 kandidat satu klub. | 1 | tinggi |
| C-4 | Beranda saat Grup + Gugur berjalan (tidak ada frame; tidak tercatat di Cakupan → "Belum digambar") | Pola banner 01e = "Round n" + "x dari y match". Di Grup + Gugur, y = 12 selama fase grup lalu melompat ke 16 setelah Buat bagan (22d). Judul round gugur di Jadwal = nama babak ("Semifinal", 21b), tetapi Beranda akan menulis "Round 7". Dialog mulai baru (01h/14y) juga belum punya teks untuk mode ini. | Nielsen 1, 4 (konsistensi); matriks varian | Frame 22s: fase grup, baris kecil "Padel · Grup + Gugur · 16 pemain", judul "Round 3", "5 dari 12 match". Frame 22t: gugur, judul "Semifinal" (sama dengan judul Jadwal), "12 dari 16 match". Frame 22u: dialog mulai baru dengan turnamen disebut "Grup + Gugur, Semifinal". Catat aturannya di Cakupan. | 1 | tinggi |
| C-5 | `.clubscore`, `.bagan`, chip grup A–D, `.opt` Pilih A1/A2, `.gg-seed` (components.md tidak menyebut Semantics; hanya ikon tukar yang punya label, hifi 4080) | Klub yang unggul hanya ditandai titik bola, dan "Seri" sengaja tidak ditulis. Pemenang di bagan = garis bola + huruf tebal. Kolom bagan yang tergeser tidak terlihat. Slot A1/A2 ditentukan oleh urutan ketukan. Di TalkBack/VoiceOver semua itu hilang. | WCAG 1.3.1, 1.4.1, 4.1.2 | Tambah ke components.md. ClubScore: `Semantics(label: 'PB Garuda 6, Matcha Club 4, PB Garuda unggul')`, untuk Seri "… seri". Kartu bagan: `MergeSemantics`, label "SF1, Round 7, Court 1. A1 Andi dan Budi 6, menang. B2 Maya dan Nanda 4"; slot kosong "Pemenang SF1, belum ada"; garis `ExcludeSemantics`; kartu yang bisa diisi `button: true`, yang terkunci `enabled: false`; bagan geser memakai `customSemanticsActions` "Geser ke Final". Chip grup: `Semantics(button: true, selected: …, inMutuallyExclusiveGroup: true, label: 'Andi · Budi ke Grup A')`. Pilih A1/A2: `selected` + value "A1". | 1 | tinggi |
| C-6 | Chip grup 19r–19x (`.chip` 34 pt, `.chips` gap 6; catatan "area sentuh 44" hifi 4487; baris pindah, catatan 19s hifi 4492) | Jarak antar chip 40 pt, jadi area 44 pt pasti bertumpuk dan area efektifnya paling besar 40 × 52, di bawah 48 dp. Di 19w ada empat chip berjejer, dipakai satu tangan di luar ruangan. Setiap ketukan memindah baris ke daftar grupnya, jadi daftar bergeser dan baris yang salah ketuk hilang dari pandangan (bisa ke grup di luar layar). Pembaliknya memang satu ketukan, tetapi baris itu harus dicari dulu. | Target sentuh (Material 48 dp); Nielsen 5, 3 | Chip 40 × 40 pt, gap 8 (jarak 48), area ketuk setinggi baris 52; empat chip = 184 pt, nama ±130 pt (elipsis sudah diterima di 19w). Usulan kedua (perlu host): baris tidak dipindah, urutan pasangan tetap, keanggotaan terbaca dari chip gelap, dan jumlah per grup di label atas ("Grup A · 2 dari 4"). | 1 | sedang |
| C-7 | Bagan 4 grup 21u–21y (hifi 4777: mengintip 10 pt, label kolom menjorok 12 pt) | Saat perempat final berjalan, kolom Final (yang paling dicari) tersembunyi. Yang terlihat hanya tepi kartu dan garis selebar 10 pt, tanpa nama kolom. Tanda bisa digeser terlalu lemah, apalagi di bawah silau. | Nielsen 6 (kenali, bukan ingat); keterlihatan | Tetap geser per kolom (disetujui). Lebarkan bagian yang mengintip jadi 24 pt dan biarkan label kolom ikut terlihat ("Fi…"), atau beri penanda posisi dua titik di bawah bagan (fakta posisi, tanpa teks). | 1 | sedang |
| C-8 | Tab terkunci `.tabs b.future` #B3BEC8 (hifi CSS baris 199): tab "Final" di 21a/21b/21e, round depan di 20c | Kontras 1,68:1 di paper. Tab ini masih bisa diketuk untuk melihat lawan (06b, 20c), jadi termasuk kontrol aktif yang wajib 4,5:1. Nama babak tidak terbaca di luar ruangan. Ini komponen dasar, jadi silang-cek dengan reviewer fondasi. | WCAG 1.4.3 | Tab terkunci memakai ink-3 #5F6D7A (4,72:1 di paper) + gembok 12 pt dari set ikon yang sama. Tab terbuka yang tidak terpilih tetap ink-3 tanpa gembok. | 1 | tinggi (diukur) |
| C-9 | 21l (hifi 4722) "Final sudah ada skor · pemenang SF1 tetap Andi & Budi" | Jalan buntu. Kalau pemenang SF salah ketik baru ketahuan setelah Final diisi, app tidak punya cara mengosongkan skor, jadi GU11 tidak pernah terpenuhi. Klasemen, poster, dan caption salah selamanya. | Nielsen 3, 9 | Di luar PRD, jadi perlu keputusan host/PM: tambah "Kosongkan skor" di Input Skor mode ubah untuk match gugur, dengan dialog "Kosongkan skor Final? Final kembali Belum." Sesudah itu SF1 boleh dibalik sesuai GU11. Aturan GU11 tidak berubah. | 3 | sedang |
| C-10 | Sparing tahap 2 (Cakupan "didaftar, belum digambar"), 15l (hifi 3896) | State error berikut belum punya frame, padahal 3.2.0 sudah rilis: Kelola pemain dengan nama yang sudah ada di klub lain (teks "Andi sudah ada di PB Garuda" hanya di catatan), maksimal 30, Kelola court saat pemain satu klub tidak cukup, dan halaman penonton live dengan skor klub. Di 15l, nama yang sudah terisi tetapi klubnya belum dipilih membuat Tambah mati tanpa alasan, dan state ini juga tidak digambar. | Matriks varian; aturan "alasan di tombol" | Frame 15z1–15z4 untuk state di atas. Tombol yang mati karena klub belum dipilih ditulis "Pilih klub" (muat di lebar tombol Tambah). | 1 + 0 | tinggi |

### Rendah

| id | frame / komponen | masalah (fakta) | prinsip | usulan | level | yakin |
|---|---|---|---|---|---|---|
| C-11 | Catatan 14x (hifi ±3808) vs frame 15w (3962) | Catatan 14x: "Sparing bernama: … skor klub di baris sendiri di bawahnya (belum digambar)". Frame 15w menggambar skor di samping "Round 4" dan menyebut baris tambahan akan menabrak service line. Dua catatan ini bertentangan, jadi saya tidak memilih salah satunya. | Konsistensi catatan | Tanya host. Rekomendasi: 15w yang berlaku, lalu kalimat di 14x dihapus. | 0 | tinggi |
| C-12 | Catatan berstatus lama: 13h (3564), 16c (4017), 16e (4039), 16g (4061), pembuka 19 (4378), 21a (4657), 21k (4717), 21s (4765), 14t (3772), 20q (4641) | Catatan-catatan ini masih menulis "menunggu persetujuan host", "(usulan)", "asumsi, menunggu host", atau "belum digambar", padahal Cakupan sudah mencatat keputusan 38, 39, 40, dan 103, dan 18o/22g sudah digambar. `screens/*.md` dihasilkan dari teks ini, jadi engineer bisa mengira bagian itu belum disetujui. | Konsistensi dokumen | Ganti dengan nomor keputusannya ("disetujui, keputusan 103") atau rujukan frame ("digambar di 22g"). | 0 | tinggi |
| C-13 | Layar Grup 19r/19s/19w (hifi 4486, 4492, 4516) | Hal yang sama ditulis dua cara di satu layar: label "8 belum masuk grup" dan tombol "Buat jadwal · 8 pasangan tanpa grup". | ux-copy: istilah konsisten | Label diganti "Tanpa grup · 8 pasangan" (pola "Grup A · 0 dari 4"); tombol tetap. | 0 | tinggi |
| C-14 | Subjudul tab babak 21b/21e/21s (hifi 4662, 4668, 4740) | "R7 · Padel" menaruh round di depan. Semua subjudul Jadwal lain menaruh olahraga di depan ("Padel · Fase grup · Race to 6", "Padel · 4 pasangan lolos"). | Nielsen 4 | "Padel · R7". | 0 | sedang |
| C-15 | Pratinjau sheet Tukar 17d/17g/17l (hifi 4109) | Pratinjau sudah menaruh pemain yang masuk di posisinya, tetapi namanya tidak ditandai. Host harus membandingkan empat nama sendiri. | Nielsen 1 | Hanya di pratinjau: nama yang masuk ditulis tebal ink (gaya nama pemenang). Tanpa label tambahan. | 1 | sedang |
| C-16 | Bagan `.t.win::before` (bola), `.lines path` #C3CCD4, nama kalah ink-2 | Garis pemenang 1,38:1 di card, tepi bola 2,01:1, garis yang belum ada pemenang 1,45:1 di paper, dan ink lawan ink-2 hanya 1,89:1. Di bawah silau, pembeda pemenang praktis hanya ketebalan huruf (untuk WO tanpa angka). | WCAG 1.4.11, 1.4.1 | Nama yang kalah ditulis ink-3 (5,31:1) supaya beda dengan pemenang lebih jelas. Garis pemenang bola diberi tepi ink 1 pt. Garis belum dibiarkan (pembeda tetap ada di nama "Pemenang SF1"). | 1 | sedang |
| C-17 | Fase grup 20b (hifi 4569: "tanpa Buat bagan") | Selama ada match grup yang Belum, langkah berikutnya tidak terlihat. Di Mixed, "Buat R4 · tunggu 1 match" (13m) memberi tahu sisa match. | Nielsen 1 | Action bar fase grup: ikon Klasemen + tombol mati "Buat bagan · tunggu 7 match". Perlu host karena pola Fixed 06v sengaja menyembunyikan Tambah round. | 1 | rendah |
| C-18 | Label 12 px `.grp`, `.gg-babak`, `.bagan .mh`, `.bagan .ch` | Kontrasnya lulus (5,31:1), tetapi label 12 px ini membawa info inti (grup, babak · format, round · court) dan dibaca di luar ruangan dengan satu tangan. | Beban kognitif, keterbacaan | 13 px (setara `.clubscore .tp`). Cek ulang lebar label "SF1 · Race to 6" di kartu 172 pt. | 1 | rendah |

## 3. Bertentangan dengan keputusan (tidak dijadikan usulan)

- Hindari geser horizontal (ui-ux-pro-max, ux "Horizontal Scroll") — bertentangan dengan Cakupan Gugur & Bagan
  (keputusan 103): bagan 8 tim digeser per babak. C-7 hanya memperkuat tanda geser.
- Target ≥ 48 dp untuk ikon tukar — bertentangan dengan keputusan 48–57: area ketuk 44 × 42 pt disetujui.
- Toast/snackbar "Urungkan" setelah Tukar — bertentangan dengan Cakupan Tukar: tanpa dialog dan tanpa toast.
- Sheet Tukar menampilkan keempat pemain atau bisa ganti tim — bertentangan dengan Cakupan Tukar: "Diganti" = dua pemain
  tim yang ikonnya diketuk.
- Peringatan selisih main 2 / partner berulang saat Tukar — bertentangan dengan T7/T8 (keputusan 48–57).
- Konfirmasi saat pindah Acak ↔ Manual di Pasangan/Grup, dan Urungkan di layar Grup — bertentangan dengan Cakupan Grup
  ("Acak → Manual mengosongkan grup (seperti 04b)", "tanpa Urungkan").
- Pola ux-copy error "apa + kenapa + cara memperbaiki" (13f, 13g, 19v, 21l) dan empty state yang menjelaskan (13a, 19r)
  — bertentangan dengan aturan host "tanpa kalimat penjelas".
- Kata "Seri" di papan skor klub (14t) — bertentangan dengan desain Sparing yang disetujui (keputusan 19, K2). C-5 cukup
  menambahkannya di Semantics.
- Nama mode di subjudul Jadwal Mexicano — bertentangan dengan keputusan 25 (layar = Jadwal Mixed).
- Segmented Grup + Gugur tetap terlihat (mati) di bawah 12 pemain — bertentangan dengan G2 / Cakupan Persiapan
  ("hanya Fixed ≥ 12 pemain").
- Durasi di baris sendiri, bukan di baris Fase grup — bertentangan dengan Cakupan Persiapan (baris "Fase grup" + "Gugur"
  menggantikan "Skor").
- Tab Bagan di depan (atau di action bar) supaya tidak tersembunyi di strip 4 grup (21v) — bertentangan dengan Cakupan
  "tab Bagan terakhir".
- Menghapus kalimat penjelas di Kelola pemain sparing (15l/15m "Pemain baru langsung ikut main…"): sejalan dengan aturan
  host, tetapi teksnya sama dengan 08a yang disetujui. Hanya dicatat, tidak diusulkan.
- C-17 (Buat bagan mati yang terlihat) mungkin bertentangan dengan pola Fixed 06v. Masuk temuan dengan keyakinan rendah,
  host yang memutuskan.
