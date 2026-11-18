# Review UX/UI hi-fi v2 · ringkasan gabungan

Tanggal 2026-11-18 · mode review: hi-fi, frame, token, dan kode belum diubah. Rincian per temuan (fakta, baris hi-fi,
prinsip, keyakinan) ada di `ux-review-A.md` (fondasi, komponen, alur 01–07), `ux-review-B.md` (Input Skor, Klasemen,
Detail, Bagikan, Live, Poster), dan `ux-review-C.md` (Sparing, Mexicano, Tukar, Grup + Gugur). Skill yang dipakai:
review-ux-ui, ux-copy, ui-ux-pro-max (referensi saja). Kontras dihitung dengan skrip dari token/CSS; tidak ada uji di HP.

Total 58 temuan: A 18, B 22, C 18. Setelah duplikat antar kelompok digabung, hasilnya 7 paket. Saran skill yang
bertentangan dengan keputusan host (±35 butir) tidak diusulkan; daftarnya ada di §3 tiap file.

## Keputusan yang perlu host

Status 2026-11-18: atas permintaan host, catatan disamakan dengan app (hi-fi v96). K1 dan K2 selesai: app sudah menampilkan
Live score + Cara kerja di 06m dan skor klub di samping round (15w); PRD, hi-fi, spec, dan `logic.md` sudah diperbarui.
PRD §6 menu ⋯ Fixed yang diakhiri juga diperbaiki (ikut app: tinggal Live score). K3 sudah konsisten (hi-fi = app =
rilis 2.7.0); yang tersisa hanya keputusan produk: dipertahankan atau dihapus.

Catatan dan frame yang bertentangan. Sesuai aturan proyek, tidak dipilih sendiri:

| # | Konflik | Rekomendasi reviewer |
|---|---|---|
| K1 | B-1: catatan 06m bilang menu ⋯ Mixed yang diakhiri hanya berisi "Cara kerja Mixed", sedangkan 12a, PRD 5.11, dan Cakupan bilang Live score tetap ada setelah diakhiri | Live score tetap ada; catatan 06m dikoreksi + frame menu; perilaku kode dicek |
| K2 | C-11: catatan 14x (skor klub di baris sendiri, belum digambar) vs frame 15w (skor di samping Round) | 15w yang berlaku, kalimat di 14x dihapus |
| K3 | A-10: paragraf "Pemain baru langsung ikut main dan diprioritaskan…" di 08a (dan 15l/15m). Tidak ada persetujuan teks UI di Cakupan, tapi reviewer C menganggapnya sudah disetujui | Hapus (aturan tanpa kalimat penjelas), kecuali host pernah menyetujuinya |

## Paket usulan

| Paket | Isi (id temuan) | Level · semver | Catatan |
|---|---|---|---|
| P1 Kontras luar ruangan | Alasan di tombol wait 2,37:1 → ink-3 tanpa opacity (A-1); skor tim kalah #A3AEB8 2,26:1 → ink-3 5,31:1 (A-3 = B-3; nama kalah di bagan C-16); tab terkunci 1,68:1 → ink-3 + gembok (A-4 = C-8); nomor court 15 → 19 px + nama default ink-3 (A-5); placeholder + tepi isian (A-6, mengubah aturan Fondasi "faint = placeholder"); tepi lingkaran tema lembut (B-19); offline + jam di tag penonton (B-17) | 1 · PATCH | Satu PATCH; banyak golden 06/07/08/09/10/12/19–22 ikut berubah |
| P2 Sentuh + pembaca layar | Area ketuk ≥ 48 dp tanpa mengubah tampilan: tab, stepper, `.rowact`, segmented, ikon, baris Klasemen, lingkaran tema, chip grup (A-7, B-5, C-6); tabel label Semantics di `components.md` untuk skor, keypad, Klasemen, live tag, ClubScore, bagan, chip grup (A-11, B-4, C-5); jarak Simpan–keypad 12 → 24 pt (B-11); ⌫ mati tanpa kotak aktif (B-12) | 1 · PATCH | Ikon tukar tetap 44 × 42 (keputusan 48–57) |
| P3 Teks (level 0) | Dialog Akhiri per mode: Fixed "Match yang belum main tidak dihitung. Turnamen tidak bisa dilanjutkan.", Grup + Gugur fase grup "Match yang belum main tidak dihitung. Bagan tidak dibuat; peringkat dari posisi grup." (A-2, C-1); 04d "Pasangan tidak bisa diubah sampai semua round selesai." (A-12); Detail "Peringkat 3 · Win % · …" (B-6); 10c "Belum ada match" (B-13); Bagikan "Sementara"/"Final" (B-14); feedback Americano "menang 13–8" (B-15); "Tanpa grup · 8 pasangan" (C-13); "Padel · R7" (C-14); 06l sheet "Tambah jam", 06c "Klasemen" (A-17); penjelas pasang PWA 01a/01i (A-16, boleh dianggap pengecualian); penonton diakhiri cukup "Istirahat" (B-20) | 0 · PATCH | Hi-fi + kode + golden |
| P4 Frame/varian yang belum ada | Klasemen 30 pemain nama panjang, nama terpotong di 108 pt (B-7); penonton membuka link tanpa internet (B-8); toast Hentikan offline (B-9); Detail Win % desimal (B-18); sheet Tukar 22 kandidat (C-3); Beranda Grup + Gugur + dialog mulai baru (C-4); error Sparing tahap 2 + "Pilih klub" (C-10); data uji poster ↔ Klasemen dan 12h ↔ 12j (B-16); catatan berstatus lama "menunggu host" (C-12); aturan pemisah "·" / "&" / "+" (B-22); skala teks HP 1,3 (A-15) | 1 (B-7, B-8, A-15: 2) | Sebagian besar hanya menggambar perilaku yang sudah ada |
| P5 Perilaku kecil (level 2) | "Hapus semua" → toolbar "Tempel · Urungkan" (A-8); dialog "Buang 5 pasangan manual?" saat Acak↔Manual dan ← Atur pasangan (A-9; untuk Grup bertentangan dengan Cakupan, jadi hanya Pasangan); fallback unduh poster kalau share gagal (B-10, menyentuh keputusan 11c); lawan WO dihitung di "Beda lawan"? (B-21) | 2 · MINOR | Perlu PRD |
| P6 Grup + Gugur | Frame GU9 ubah format babak, diprioritaskan di 3.8.x (C-2); tanda geser bagan 10 → 24 pt (C-7); label 12 → 13 px (C-18); tombol mati "Buat bagan · tunggu 7 match" (C-17, bertentangan dengan pola 06v, perlu host); pratinjau Tukar menebalkan pemain yang masuk (C-15) | 1 · PATCH/MINOR | GU9 memang sudah direncanakan |
| P7 Fitur: Kosongkan skor / Hapus WO | Skor/WO di match yang salah tidak bisa dikembalikan ke Belum; di gugur, SF yang salah buntu setelah Final berskor (B-2, C-9) | 3 · MINOR | Feature flow lengkap (PM → desain → tech-lead) |

## Urutan yang disarankan

1. Host memutuskan K1–K3 dan memilih paket.
2. P1 + P2 + P3 jadi satu PATCH 3.8.1: ui-ux-designer memperbarui hi-fi (per kelompok frame), lalu engineer + golden.
3. P4 + P6 diikutkan saat GU9 (3.8.x).
4. P5 dan P7 lewat PRD dulu (product-manager), satu MINOR.
