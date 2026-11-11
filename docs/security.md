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
| 2 | Info | Id pemain duplikat lintas klub lolos decode → tampil di dua tabel (hanya tab penonton room penyerang). | Opsional: decode menolak id duplikat. |
| 3 | Info | Nama klub tanpa batas panjang saat baca; semua tampilan `maxLines` + elipsis, caption teks biasa. | Tidak perlu. |
| 4 | Info (sejak 2.5.0) | `roundNumber` raksasa (mis. 10⁹) di payload live membuat tab penonton membeku (`latePlayerIds`, `currentRound` mengulang 1..roundCount). Tidak memengaruhi host/data. | **Selesai 3.3.2**: decode (dan encode) menolak `roundNumber` di luar 1..1000. |
