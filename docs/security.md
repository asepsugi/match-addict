# Security — model ancaman & risiko diterima

Pemilik: temuan dari agen security, ditulis main session / tech-lead. Baca kalau menyentuh decode simpanan/payload,
live/relay, atau menambah dependensi.

## Batas kepercayaan (per 3.2.0, review 2026-11-11)

- **Relay live** (`relay/`, `docs/live.md`): tanpa database dan tanpa auth untuk membuat room (keputusan lama, payload
  ≤ 256 KB). Ubah/hapus room butuh token Bearer (di-hash). Penonton hanya GET; host tidak pernah men-decode isi relay,
  jadi penonton tidak bisa memengaruhi HP host.
- **Input tak tepercaya yang realistis**: room buatan sendiri yang link `#/live/KODE`-nya disebar. Dampaknya terbatas
  pada tab penonton itu; mode penonton tidak membuka Hive.
- **Decode** (`tournament_codec.dart`): data rusak/jahat → null tanpa crash. Review 3.2.0 menguji 20 bentuk sparing jahat
  (→ null) dan 10 bentuk janggal yang lolos decode (aman di skor klub, klasemen, istirahat per klub); test tetap di
  `test/services/sparing_codec_test.dart`.
- Assert invariant sparing (S1/S2/S4) di controller dan `club_score.dart` punya penjaga `return`/`continue` di rilis.

## Risiko diterima / tindak lanjut (bukan penahan rilis 3.2.0)

| # | Tingkat | Risiko | Tindak lanjut |
|---|---|---|---|
| 1 | Rendah | Cek bentuk sparing saat encode hanya `assert` (`tournament_codec.dart:28-31`): bug mutator di masa depan bisa menyimpan payload yang ditolak decode dan menimpa simpanan sah terakhir (turnamen "hilang" saat resume). | **Selesai 3.3.2**: `canEncode` di rilis; gagal → store/live melewati tulisan (`docs/data.md`). |
| 2 | Info | Id pemain duplikat lintas klub lolos decode → tampil di dua tabel (hanya tab penonton room penyerang). | **Selesai 3.6.1**: decode (dan encode) sparing menolak id pemain duplikat. |
| 3 | Info | Nama klub tanpa batas panjang saat baca; semua tampilan `maxLines` + elipsis, caption teks biasa. | Tidak perlu. |
| 4 | Info (sejak 2.5.0) | `roundNumber` raksasa (mis. 10⁹) di payload live membuat tab penonton membeku (`latePlayerIds`, `currentRound` mengulang 1..roundCount). Tidak memengaruhi host/data. | **Selesai 3.3.2**: decode (dan encode) menolak `roundNumber` di luar 1..1000. |

## Grup + Gugur (3.8.0 — dari GG-0 dba, dicek di rilis GG-11 2026-11-17)

Bentuk dan aturan baca GR1–GR17: `docs/data.md` → Grup + Gugur. Yang wajib dijaga di kode dan review:

| # | Butir | Penjaga |
|---|---|---|
| G1 | Permukaan decode baru: id kembar, `phase` tak dikenal, indeks grup di luar jangkauan, `null` di sisi match | GR1–GR17 → `decode` null; widget tidak pernah menerima sisi tbd di luar pending/cancelled |
| G2 | Jumlah match gugur dari payload | GR12 (≤ 8); `resolve` tanpa loop terbuka |
| G3 | Pasangan lolos tidak sesuai klasemen (pilihan host) tidak bisa diverifikasi | Diterima: sah menurut desain, dampaknya hanya salah tampil di tab penonton |
| G4 | Penonton/host app ≤ 3.7.x | Penanda `bye.gg = "1"` (GU15) wajib dipertahankan codec; app lama → null ("Live tidak bisa dibuka") |
| G5 | Downgrade host | Simpanan tidak ditimpa sampai turnamen baru dimulai |
| G6 | Satu validator | `_isValidGroupKnockout` dipakai `decode` dan `canEncode` (pola temuan #1) |
| G7 | `LastSettings` kunci `groupKnockout` | Tetap ≤ 16 KB; entri tak valid dibuang utuh |

## Group - Playoff (3.10.0 — dari GP-0 dba, review security 2026-11-23)

Bentuk dan aturan baca GR4/GR5/GR8/GR10/GR12/GR18/GR19: `docs/data.md` → Group - Playoff fleksibel. G1–G7 (3.8.0)
tetap berlaku. Verdict: aman dirilis dengan syarat W2. Yang wajib dijaga di kode dan review:

| # | Butir | Penjaga |
|---|---|---|
| W1 | Permukaan decode baru: 3 grup, `wildcards` (tipe salah, satu/tiga id, id kembar, id bukan anggota grup, dua WC segrup, WC = juara/runner-up), QF 3 grup salah susun | GR4, GR18, GR19 → `decode` null; GR18/GR19 diuji sebelum `sources`/`isResolved`/`resolve`; `seedLabel` hanya memakai indeks `wildcards` yang sudah lolos; `wildcards` dibaca di dalam `try` |
| W2 | Satu sumber topologi 3 grup: validator dan `build` berbeda soal tukar/urutan WC → `canEncode` false → simpanan dan live dilewati diam-diam sejak Buat bagan, resume kembali ke sebelum bagan (pola #1) | GR19 tidak mengkodekan ulang aturan: J1–J3 dari `QF1/QF3/QF4.pair1`, R dan grup dari `groups`, WC dari `wildcards`, lalu QF1–QF4 dibandingkan persis dengan keluaran fungsi murni yang sama dengan `build`; test properti 36 kombinasi AC-G26 × `WildcardPick` × ubah format/juara 3: `canEncode` true dan `decode(encode(x)) == x` |
| W3 | `wildcards` ada iff 3 grup dan ada bagan | Mutator menulis/membuang `wildcards` di `state =` yang sama dengan match bagan; `GroupKnockout.copyWith` membawanya (logic.md 21.12 #1) |
| W4 | Jumlah pasangan dari payload | `decodableGroupCounts(P)` = [] untuk P > 16 (tidak ada penulis yang pernah melewatinya), test P = 17 ditolak; jumlah match gugur tetap ≤ 8 (GR12) |
| W5 | Penonton/host app ≤ 3.9.x | 3 grup ditolak lewat GR5 (null, "Live tidak bisa dibuka"); 2×8 dan 4×4 (16 pasangan) tampil benar dengan label lama: diterima. Kode simpanan tetap `PF*`, `bye.gg` tetap "1" |
| W6 | `LastSettings` `groupCount: 3` | 3.10.0: `PF` iff ≥ 3, ≤ 16 KB; 3.9.x membuang entri utuh (default), tanpa crash |
| W7 | Payload live > `MAX_BYTES` (256 KB, `relay/src/index.js:14`) | Kasus dasar 32 pemain < 128 KB (AC-B9). Di atasnya (Fixed 16 pasangan ≥ 3 putaran tambahan, Mixed 32/8 court > ±52 round; 50 round = 248 KB terukur) relay menjawab 413: live berhenti diperbarui, turnamen lokal aman. Lihat #5 |

Catatan untuk review GP-4: cabang G = 3 wajib mewajibkan sisi QF tidak null sendiri (sekarang hanya kalau
`s1 is SeedSource`, `tournament_codec.dart:249`); `groupCount != 4` (`:230`) → `< 3`; cek `_seedPair` slot1 == slot2
(`:258-261`) hanya untuk 2/4 grup; `sources(…, groupCount: 3)` harus total.

| # | Tingkat | Risiko | Tindak lanjut |
|---|---|---|---|
| 5 | Rendah | 413 diperlakukan sebagai "Menunggu internet": coba lagi tiap 30 detik + tiap perubahan (`live_host_controller.dart:146-173`), HP host mengunggah ±256 KB berulang (±30 MB/jam), host diarahkan ke masalah jaringan | Tangani 413 tanpa timer (kirim lagi hanya saat berubah); teks khusus menunggu keputusan host |
| 6 | Info | `MAX_BYTES` bisa dinaikkan: DO berbasis SQLite (`relay/wrangler.toml`), batas nilai 8 MB, bukan 128 KiB | Belum: CPU paket gratis belum diukur, POST anonim jadi lebih efisien untuk penyalahgunaan penyimpanan; jurangnya tetap ada (Tambah round tidak berbatas) |
| 7 | Info (sejak 2.5.0) | Relay membaca seluruh body sebelum mengecek ukuran (`relay/src/index.js:116-118`) | Tolak berdasarkan `Content-Length` saat deploy relay berikutnya |
