# Data — persistensi lokal

Pemilik: dba. Baca kalau mengubah bentuk simpanan, `services/storage/`, resume, Lanjutkan turnamen, atau slot
`active`/`lastFinished`. Produk: `PRD.md` §5.10. Seluruh MVP PRD sudah jalan, termasuk bagian 5 (Penyimpanan Data).

## Codec & store

- `services/storage/tournament_codec.dart` — `ActiveTournament` ↔ JSON, Dart murni, ter-test. Sengaja **bukan**
  TypeAdapter Hive: model domain jadi bebas anotasi/codegen dan tidak perlu mengelola nomor `typeId`.
- `schemaVersion` dinaikkan kalau bentuk JSON berubah tidak kompatibel (sekarang 2 = app v2), dan tiap simpanan
  membawa `appVersion` (`lib/core/app_version.dart`, harus sama dengan `version` di pubspec — dijaga test; tidak
  tampil di Beranda v2; tampil lagi di 3.2.0, keputusan 20).
- Simpanan app lama (skema 1, tanpa `appVersion`, skor per set) sengaja tidak dimuat: turnamen dari app lama tidak
  dimuat di app v2 (keputusan host 2026-10-22), format per set sudah dihapus dari kode. Payload beda versi atau rusak
  (app di-kill di tengah tulis) di-`decode` jadi `null`, bukan melempar — turnamennya saja yang hilang, app tetap bisa
  dibuka.
- Kunci simpanan opsional (simpanan lama tetap terbaca) dan kunci lama yang diabaikan ditulis bersama aturannya di
  `docs/architecture.md` (cari "kunci simpanan").
- `services/storage/tournament_store.dart` — box Hive `tournament` berisi 3 key: `active`, `lastFinished`, dan `live`
  (sesi live score, `docs/live.md`). `TournamentStore.memory()` dipakai test dan sebagai penyelamat kalau box gagal
  dibuka (disk penuh, browser mode private).

## Riwayat bentuk simpanan

Semua rilis memakai `schemaVersion` 2 sejak 2.0.0; yang bertambah hanya kunci opsional, jadi simpanan lama tetap terbaca
tanpa migrasi. Fixture literal tiap bentuk ada di test (SP-1 menambahkan yang belum ada, lihat "Test wajib").

| Bentuk | Sejak | Kunci | Perlakuan decoder sekarang |
|---|---|---|---|
| skema 1 (skor per set, tanpa `appVersion`) | app lama | — | ditolak (null), keputusan host 2026-10-22 |
| skema 2 | 2.0.0 | `schema`, `appVersion`, `tournament`, `bye`, `resting` | dasar |
| `startMinute` di court | 2.2.0 | opsional | tanpa kunci = 0 |
| `name` di config | 2.3.0 | opsional | tanpa kunci = tanpa nama |
| `withdrawn` | 2.x (Kelola pemain) | opsional | tanpa kunci = kosong |
| `credits` | sampai 2.6 | — | dibuang, tidak dibaca |
| `extraPutaran` | 3.1.0 | opsional | tanpa kunci = 0 |
| sparing: `config.clubs`, `players[].club`, `restingPairs`, penanda di `bye` | 3.2.0 | opsional, satu paket | tanpa `config.clubs` = turnamen biasa (lihat di bawah) |

## Sparing (3.2.0, MINOR)

Keputusan host: `schemaVersion` tetap 2, simpanan 3.1.0 terbaca sebagai turnamen biasa apa adanya (AC-S19). Aturan
produknya: PRD §13, `design/spec/logic.md` §13. Di sini hanya bentuk simpanannya. Semua kunci baru opsional dan ditulis
**hanya** untuk turnamen sparing: encode turnamen biasa menghasilkan byte yang sama dengan 3.1.0 (test lama tidak berubah).

### Bentuk

```json
{ "schema": 2, "appVersion": "3.2.0",
  "tournament": { "id": "...", "createdAt": "...", "isFinished": false,
    "config": { "sport": "padel", "mode": "fixed", "...": "...",
      "clubs": [ {"id": "club-1", "name": "PB Garuda"}, {"id": "club-2", "name": "Matcha Club"} ],
      "players": [ {"id": "p1", "name": "Andi", "club": "club-1"}, "..." ],
      "fixedPairs": [ "..." ] },
    "matches": [ "..." ] },
  "bye": { "sparing": "1" },
  "resting": { },
  "restingPairs": { "1": ["pair-g3", "pair-g4", "pair-m3"] },
  "withdrawn": [ ],
  "extraPutaran": 0 }
```

- **`config.clubs`**: daftar tepat dua `{id, name}`; urutan = klub pertama (blok atas layar Pemain), klub kedua. Id string
  tak kosong dan berbeda (SP-8 memberi `club-1`/`club-2`; decoder hanya menuntut berbeda), nama string tak kosong.
  Batas 20 huruf dan keunikan tidak peka huruf besar adalah aturan layar Pemain, **tidak** diperiksa saat membaca
  (membaca tidak menolak data yang masih bisa ditampilkan). Tidak ditulis untuk turnamen biasa; `isSparing` =
  `clubs != null`. Klub tidak berubah selama turnamen: tidak ada migrasi klub, tidak ada hapus klub.
- **`players[].club`**: id klub, ditulis di **setiap** pemain turnamen sparing: asli, pengganti dari Atur pasangan, baru
  dari Kelola pemain, dan yang sudah keluar (tetap di `config.players`, tetap membawa klubnya). Pemain tidak pernah
  pindah klub (K8): kunci ini tidak pernah ditulis ulang dengan nilai lain. Pemain turnamen biasa tidak punya kunci ini.
- **`restingPairs`**: `{"<round>": ["<pairId>", ...]}`, semua pasangan yang tidak main di round itu (klub pertama dulu).
  Hanya Fixed sparing, karena Fixed sparing bisa mengistirahatkan beberapa pasangan per round; `bye` (satu pasangan
  per round) tetap milik Fixed biasa dan di sparing tidak berisi nomor round. Ditulis hanya kalau tidak kosong.
  Mixed sparing tidak memakainya: istirahatnya tetap `resting` (id pemain), klubnya dari `players[].club`.
- **`extraPutaran`** dipakai ulang tanpa kunci baru: di Fixed sparing artinya **jumlah satuan** (blok `L` match,
  `logic.md` §13.3) yang sudah dibuat, `u` di rumus blok `K = g + u`; di Fixed biasa tetap jumlah putaran. Tafsir ikut
  `isSparing`, jadi tidak ambigu. Di sparing nilainya ≥ 0; Mixed sparing selalu 0. Tetap naik walau Atur pasangan mengubah
  jumlah pasangan (`g`, `L` dihitung ulang dari jumlah baru).
- **Encode menolak sparing yang tidak sah** (review SP-1): `encode` punya `assert` dengan aturan baca yang sama, jadi
  mutator yang membuat pemain sparing tanpa `clubId` atau match dengan `pair1` dari klub kedua langsung gagal di test,
  bukan diam-diam menghasilkan simpanan yang terbaca null saat resume (turnamen hilang).
- **Penanda di `bye`**: payload sparing menulis `"bye": {"sparing": "1"}` (tambahan atas nomor round, yang kosong).
  Ini sengaja: decoder 3.1.0 melakukan `int.parse` pada tiap kunci `bye`, jadi kunci "sparing" membuatnya melempar dan
  `decode` jadi null di app lama (lihat "Risiko app lama"). Decoder 3.2.0 membuang kunci persis `sparing` sebelum
  membaca nomor round; kunci non-angka lain tetap membuat payload rusak. Nilai "1" = revisi bentuk sparing; nilai lain
  → null (revisi sparing berikutnya yang tidak kompatibel menaikkannya dan app lama menolak dengan cara yang sama).

### Aturan baca (satu fungsi decode, Dart murni; semua pelanggaran = `decode` mengembalikan null, bukan melempar)

Pembaca membedakan dua keadaan: **turnamen biasa** (tidak ada `config.clubs`) dan **sparing** (ada). Kunci sparing
di salah satu keadaan yang salah berarti payload rusak, karena tidak ada penulis yang bisa menghasilkannya.

| Kondisi | Hasil |
|---|---|
| Tanpa `config.clubs`, tanpa `club` di pemain, tanpa `restingPairs`, `bye` tanpa "sparing" | turnamen biasa (semua simpanan ≤ 3.1.0, dan turnamen biasa 3.2.0) |
| Tanpa `config.clubs` tapi ada `club` di pemain, `restingPairs`, atau `bye.sparing` | null |
| `clubs` bukan list tepat 2, elemen bukan `{id: String, name: String}`, id kosong/sama, nama kosong | null |
| `bye.sparing` tidak ada atau bukan "1" padahal ada `clubs` | null |
| Ada pemain di `config.players` tanpa `club`, atau `club` bukan salah satu id klub | null |
| `fixedPairs` / `pair1` / `pair2` di match: anggota tidak ada di `config.players`, atau dua anggota beda klub | null |
| Match: `pair1` bukan klub pertama atau `pair2` bukan klub kedua (invarian S4) | null |
| `restingPairs` bukan `{angka: [String]}` | null |
| `extraPutaran` bukan int (turnamen biasa maupun sparing, sama dengan 3.1.0) | null |
| `extraPutaran` negatif, hanya kalau ada `config.clubs` (turnamen biasa tetap menerimanya seperti 3.1.0, AC-S19) | null |
| `extraPutaran`, `withdrawn`, `resting` untuk turnamen biasa | seperti sekarang |
| `bye` bernomor round di payload sparing | diterima apa adanya: sparing memang tidak menulisnya, tapi itu keadaan data, bukan bentuk yang ditolak |

Alasan memeriksa S2 dan S4 saat baca: layar sparing menurunkan klub pasangan dari klub anggotanya dan menaruh `pair1` di
atas tanpa penjagaan sendiri; payload yang melanggarnya akan membuat widget melempar, sedangkan kontraknya "membaca data
rusak tidak pernah merusak app". Yang **tidak** diperiksa: id pasangan di `restingPairs` yang tidak ketemu, jumlah pemain
aktif per klub, jumlah pasangan per klub. Itu keadaan, bukan bentuk; helper klub di model (SP-1) harus **total** (id tak
dikenal → dilewati / null, tidak pernah melempar).

Penulisan: `encode(decode(x)) == x` untuk payload sparing yang sah (urutan kunci tetap, `clubs` setelah `name`, `club`
setelah `name` pemain). Kunci opsional sparing tidak ditulis kalau kosong/tidak berlaku.

### Risiko app lama dan mitigasinya

Simpanan sparing ada di dua tempat: Hive di device host (`active`, `lastFinished`) dan salinan di relay live, yang
dibaca penonton lewat `TournamentCodec.decode` yang sama. App 3.1.0 yang masih ter-cache di PWA (versi baru baru aktif di
reload ke-2, `docs/infra.md`) tanpa penjagaan akan **membaca payload sparing sebagai turnamen biasa**: kunci baru
diabaikan.

| Pembaca | Tanpa penanda | Dengan penanda `bye.sparing` (keputusan ini) |
|---|---|---|
| Penonton web 3.1.0 buka link live sparing | Jadwal tanpa Istirahat per klub, Klasemen satu tabel campur dua klub, tanpa skor klub; kelihatan benar tapi salah | `decode` null → layar "Live tidak bisa dibuka" (`LiveViewStatus.unreadable`, sudah ada di 3.1.0). Pembukaan berikutnya memuat 3.2.0 |
| Host dengan tab/instalasi 3.1.0 tersisa membaca `active` sparing di box yang sama | Turnamen terbuka sebagai biasa; skor yang diinput disimpan ulang **tanpa** klub (klub hilang permanen); Tambah round Fixed membuat pasangan sesama klub; Buat R Mixed mencampur klub | null → Beranda kosong, **simpanan tidak ditimpa** sampai host memulai turnamen baru; app 3.2.0 membacanya lagi |

Jalur host jarang terjadi (Hive per origin, app native tidak bisa di-downgrade tanpa uninstall yang menghapus data),
penonton yang baru sekali membuka sebelum update adalah jalur yang realistis. Tidak ada jalan membuat app 3.1.0 yang sudah
terpasang memahami sparing; menolak dengan layar yang sudah ada adalah pilihan paling aman yang bisa dibuat dari sisi 3.2.0.
Konsekuensi yang diterima: selama versi lama masih aktif di HP penonton, ia melihat "Live tidak bisa dibuka" untuk live
sparing (bukan data salah), dan perlu membuka link sekali lagi setelah update tertarik. Relay tidak diubah (hanya
memeriksa `schema` angka + `tournament` objek), jadi tidak ada deploy relay.

Penanda ini harus dipertahankan oleh siapa pun yang menyentuh codec: menghapusnya menghidupkan kembali baris "Tanpa
penanda". Kalau suatu hari app 3.1.0 sudah tidak mungkin beredar, penanda tetap berguna sebagai revisi bentuk sparing.

### Test wajib (SP-1)

`test/services/sparing_codec_test.dart` (nama test memakai ID AC):
- AC-S19 simpanan 3.1.0: fixture literal JSON (Fixed dengan `extraPutaran`, Mixed dengan `withdrawn`, skema 2 minimal
  tanpa `name`/`startMinute`/`extraPutaran`) terbaca sebagai turnamen biasa (`isSparing` false, `clubId` null semua); encode
  turnamen biasa tidak memuat kunci `clubs`, `club`, `restingPairs`, `sparing`.
- AC-S20 round trip: 13A setelah R3 + R6 diakhiri (istirahat per round, `extraPutaran`), Mixed sparing dengan pemain keluar
  dan pemain baru berklub, pemain pengganti Atur pasangan (Gilang, Oki); `encode(decode(x)) == x`.
- Rusak → null untuk tiap baris tabel aturan baca (satu test per baris), termasuk payload terpotong.
- Penanda: JSON sparing berisi `bye` dengan kunci yang tidak bisa di-`int.parse` (menjaga perilaku yang dibutuhkan decoder
  3.1.0); decoder 3.2.0 membacanya tanpa menjadikannya nomor round.
- Ukuran: 7/8 pasangan (30 pemain, terbesar per satuan: 56 match) + 2 satuan tambahan, encode < 256 KB (`MAX_BYTES`
  relay). Perkiraan ±660 B per match (id pemain UUID) = ±37 KB per satuan, jadi masih jauh; tulis angka sebenarnya di
  komentar test.

## Auto-save & resume

- Auto-save-nya satu `listenSelf` di `TournamentController.build()`. Semua mutasi controller berakhir di `state =`,
  jadi tidak ada call site yang bisa lupa menyimpan.
- Resume: `build()` mengembalikan `_store.loadActive()`. Kartu "Lanjutkan turnamen" di Home adalah satu-satunya jalan
  masuknya, dan dia mengoper `active.config` apa adanya karena `startIfNeeded` membandingkan config dengan `identical`
  — kalau config-nya disalin, jadwalnya akan diregenerate. Karena menambah pemain mengganti `state.config`, controller
  juga mengingat `_startedFrom` (config awal yang masih dipegang layar Konfigurasi di belakang jadwal); dua-duanya
  dianggap turnamen yang sama.
- `close()` (tombol "Selesai" di layar Share) memindahkan turnamen ke slot `lastFinished`, tidak menghapusnya, sesuai
  PRD. Future-nya dikembalikan supaya test bisa menunggu tulisannya.
- Belum ikut disimpan: `rankingMethodProvider` — setelah resume, metode peringkat kembali ke default Total Point.

## Lanjutkan Turnamen (Mixed saja)

Fixed sengaja tidak — keputusan host. `TournamentController.resume` + sheet
`features/schedule/mixed/resume_tournament_sheet.dart`, tes di `test/services/resume_tournament_test.dart`.

- Muncul kalau `ActiveTournament.canResume(now)` (sudah "Akhiri" atau waktu booking semua court habis) di layar Jadwal,
  dan dari kartu "Turnamen terakhir" di Beranda untuk slot `lastFinished` (`lastFinishedProvider`, diset sinkron oleh
  `close()` supaya Beranda tidak menunggu tulisan ke device).
- Jam ditambah **per court** karena sering cuma sebagian court yang bisa diperpanjang, dan dihitung dari sekarang:
  `max(ujung booking, sekarang) + tambahan` (`ActiveTournament.extendedBy`; court yang habis dipesan ulang,
  `startMinute` = sekarang) — court yang waktunya sudah lama habis tetap dapat jam penuh.
- Match `cancelled` (hanya dibuat oleh "Akhiri") kembali `pending`.
- Estimasi di sheet = `ActiveTournament.capacityAhead` dalam **jumlah match** (bukan round: round jalan selama masih ada
  satu court, jadi cuma mengikuti court terpanjang dan tambahan di court lain tidak kelihatan).

## Slot aktif

- Slot aktif cuma satu, jadi memilih jenis permainan di Home saat ada turnamen berjalan memunculkan konfirmasi dulu
  ("Buang & Mulai Baru").
- Turnamen di slot aktif yang sudah **diakhiri** (belum "Selesai") bukan turnamen berjalan: Beranda menampilkannya
  sebagai turnamen terakhir (baris riwayat Mixed, 01c), dan Mulai turnamen memanggil `close()` dulu tanpa dialog
  (keputusan host 2026-10-25).
