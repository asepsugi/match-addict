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
| `mode: "mexicano"` | 3.4.0 | nilai baru, tanpa kunci baru | ditolak kalau bersama `clubs` atau bukan Americano (lihat "Mexicano"); pembaca ≤ 3.3.x menolaknya (null) |
| `settings.<olahraga>` (pengaturan terakhir) | 3.4.0 | kunci Hive terpisah, bukan bagian payload turnamen | tak terbaca = default; ≤ 3.3.x tidak membacanya |
| tukar pemain | 3.5.0 | tanpa kunci baru | `resting[n]` round terakhir bisa berubah oleh tukar dan boleh berisi pemain yang dikeluarkan; codec tidak berubah, 3.4.x membacanya apa adanya (`logic.md` §15.1) |
| Grup + Gugur: `config.groupKnockout`, `matches[].phase`, sisi gugur belum diketahui = `null`, penanda `bye.gg` | 3.8.0 | opsional, satu paket | tanpa `config.groupKnockout` = round-robin (semua simpanan ≤ 3.7.x); satu paket utuh atau payload rusak (lihat "Grup + Gugur"); pembaca ≤ 3.7.x menolaknya (null) lewat `bye.gg` |
| `settings.<olahraga>.groupKnockout` | 3.8.0 | kunci opsional di JSON `v` 1 | tanpa kunci = round-robin; ≤ 3.7.x mengabaikannya (membaca sebagai Fixed biasa) |
| Group - Playoff fleksibel: `groups.length` 3, `formats.PF` iff G ≥ 3, `groupKnockout.wildcards`, batas 32 pemain | 3.10.0 | opsional (`wildcards`) + rentang nilai baru | 2 dan 4 grup byte-sama dengan 3.9.x; 3 grup = G ∈ `decodableGroupCounts` + `wildcards` (lihat "Group - Playoff fleksibel"); pembaca ≤ 3.9.x menolak 3 grup (null) lewat GR5 |
| `settings.<olahraga>.groupKnockout.groupCount` 3 | 3.10.0 | nilai baru di JSON `v` 1 | `groupCount` 2, 3, 4; pembaca ≤ 3.9.x membuang seluruh entri (default) |

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
- **Encode menolak bentuk yang tidak terbaca** (review SP-1, PATCH 3.3.2): `TournamentCodec.canEncode` memakai aturan baca
  yang sama (bentuk sparing, `roundNumber` 1..`maxRoundNumber` = 1000). `encode` melempar `UnreadableTournamentError`
  juga di rilis; `TournamentStore` melewati tulisan (simpanan sah terakhir tetap, `archiveActive` tidak mengosongkan slot
  aktif) dan live tidak mengirim (penonton tetap di kiriman sah terakhir). Jaring test: `assert(canEncode)` di auto-save
  `TournamentController`, jadi mutator yang merusak bentuk gagal di test, bukan baru ketahuan saat resume.
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

| Pembaca | Tanpa penanda | Dengan penanda `bye.sparing` (disetujui host 2026-11-08, PRD K13) |
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

## Mexicano (3.4.0, MINOR)

Keputusan host: `schemaVersion` tetap 2 (PRD §14, keputusan 23–41). Aturan produk: PRD §14, `design/spec/logic.md` §14. Di sini
hanya bentuk simpanannya. Perubahan payload turnamen cuma satu nilai: `config.mode = "mexicano"` (`c.mode.name`,
`tournament_codec.dart:143`). Tidak ada kunci baru; Fixed, Mixed, dan Sparing ter-encode byte-sama dengan 3.3.x (MX-1
membuktikannya dengan fixture literal). Turunan Mexicano mengikuti Mixed: istirahat di `resting` (id pemain), `bye` kosong,
tanpa `restingPairs`, `extraPutaran` 0, `withdrawn` terpakai (Kembalikan, keputusan 39).

### Kenapa `schemaVersion` tetap 2 dan tanpa penanda

Pembaca ≤ 3.3.x menolak `mode: "mexicano"` sendiri. Menaikkan skema (selalu MAJOR) akan membuang simpanan 3.3.x di app baru,
dan penanda seperti `bye.sparing` tidak perlu:

- `_readConfig` memakai `PartnerMode.values.byName(j['mode'] as String)` (`tournament_codec.dart:200`). Baris yang sama ada di
  semua rilis: bc38717:111, 3.1.0 (10817f4):122, 3.2.0 (564ea67):186, 3.3.2 (8af509b, `main`). Enum lama hanya
  `{fixed, mixed}`, jadi `byName("mexicano")` melempar `ArgumentError`.
- Pelemparnya di dalam `try { … } catch (_) { return null; }` (`tournament_codec.dart:68`, `106-110`): `decode` null. `schema` 2 dan
  `appVersion` String lolos dulu (`:70`), jadi penolakan memang karena `mode`.
- Penonton ≤ 3.3.x: `_check` menerima `null` dari `decode` sebagai `LiveViewStatus.unreadable`
  (`features/live/live_view_controller.dart:83-85`) → layar "Live tidak bisa dibuka"; pembukaan berikutnya memuat versi baru.
  Relay tidak berubah: hanya memeriksa `schema` angka dan `tournament` objek (`relay/src/*.js:121`), tidak membaca `mode`.
- Host ≤ 3.3.x (tab/instalasi tersisa di box yang sama): `loadActive` → null (`tournament_store.dart:42`), `build()` mengembalikan
  null, dan listener auto-save mengabaikan state null (`tournament_controller.dart:34`), jadi tidak ada tulisan yang menimpa
  `active`. Simpanan tertimpa **hanya** kalau host memulai turnamen baru di versi lama (risiko yang sama dengan Sparing, "Risiko
  app lama"). `lastFinished` Mexicano di versi lama juga null (kartu terakhir tidak muncul) tetapi tidak dihapus.
- Konsekuensi yang diterima, sama dengan Sparing: selama versi lama masih aktif, live Mexicano terlihat "tidak bisa dibuka",
  bukan data salah. Ini dibuktikan dengan membaca kode (versi lama tidak bisa dijalankan di sini); MX-1 menguji decoder
  menolak `mode` tak dikenal (`mode: "zzz"` → null), perilaku yang sama dengan yang dipakai versi lama.

### Aturan baca baru (semua = `decode` null, bukan melempar)

| Kondisi | Hasil |
|---|---|
| `mode` = `"mexicano"` dan ada `config.clubs` | null (Mexicano tanpa klub; kartu Mexicano tidak ada di Sparing, AC-M2) |
| `mode` = `"mexicano"` dan `scoring` ≠ `"americano"` | null (Mexicano selalu Americano, `ScoreFormat.forMexicano`) |
| `mode` = `"mexicano"` dengan kunci sparing lain (`club` di pemain, `restingPairs`, `bye.sparing`) | null lewat aturan yang sudah ada (tanpa `clubs`, kunci sparing = rusak) |
| `mode` bukan `fixed`, `mixed`, atau `mexicano` | null (`byName` melempar, ditangkap) |

`canEncode` ikut dua aturan pertama supaya `encode` melempar `UnreadableTournamentError` dan store melewati tulisannya, sama
seperti bentuk sparing yang rusak. Alasan memeriksa saat baca: layar Mexicano tidak punya cabang klub dan memakai Total Point;
payload yang melanggarnya tidak bisa ditulis penulis mana pun. Yang **tidak** diperiksa: jumlah pemain dan kehadiran per round
(keadaan, bukan bentuk; `canReinstate` harus total).

### Pengaturan terakhir (`settings.<olahraga>`)

Pengaturan Konfigurasi turnamen terakhir, supaya turnamen berikutnya tidak mengisi ulang court dan format (keputusan 33–38).
Kode: `services/storage/last_settings.dart` (KF-1), Dart murni, ter-test.

- **Kunci**: `settings.tennis` dan `settings.padel` (`SportType.name`) di box Hive `tournament`, bernilai String JSON seperti
  `active`/`lastFinished`/`live`. Dibaca dan ditulis lewat `TournamentStore` (`_read`/`_write`), jadi `TournamentStore.memory()`
  ikut berlaku. Di luar `TournamentCodec`: tanpa `schema`/`appVersion`, tidak pernah ikut payload turnamen atau relay, tidak
  disentuh `archiveActive`.
- **Bentuk**:

```json
{ "v": 1, "mode": "mexicano", "scoring": "americano", "target": 24, "duration": 15,
  "courts": [ {"name": null, "colorIndex": 0, "bookingMinutes": 120},
              {"name": "Court Timur", "colorIndex": 1, "bookingMinutes": 120} ] }
```

- **Validasi per field**. Satu pelanggaran = **seluruh entri** tak terbaca (tanpa perbaikan sebagian, supaya layar tidak terisi
  setengah rusak):

| Field | Syarat |
|---|---|
| `v` | int tepat 1 (nilai lain, termasuk versi lebih baru, = tak terbaca) |
| `mode` | nama enum `fixed`/`mixed`/`mexicano` |
| `scoring` + `target` | `scoring` nama `ScoringMethod`; `target` int dengan `ScoreFormat.isValid` (Race to 2–9, Best of 1–15, Americano 2–99); `mode` mexicano wajib `americano` (sama dengan aturan baca turnamen) |
| `duration` | int kelipatan 5 (`TournamentConfig.durationStep`) dalam 5–180 (`_maxDuration`, `konfigurasi_screen.dart:38`) |
| `courts` | list 1..`TournamentConfig.maxCourts` (10) map |
| `courts[].colorIndex` | int 0..`MabarColors.courtPalette.length - 1` (`mabar_theme.dart:64`, sekarang 0–9) |
| `courts[].bookingMinutes` | int kelipatan 60 dalam 60–720 (stepper 1–12 jam, `konfigurasi_screen.dart:283-285`) |
| `courts[].name` | null atau String; String kosong/spasi saja dibaca null. Panjang tidak diperiksa (UI tidak membatasinya) |
| Panjang String JSON | maksimal 16 KB; lebih dari itu tak terbaca (jaring untuk data rusak/raksasa) |

- **Nama court**: ditulis `null` kalau sama dengan label default "Court n" (n = urutan). Konfigurasi menulis nama default ke
  config saat kolom kosong (`_CourtDraft.label`, `konfigurasi_screen.dart:333-336`), jadi yang dibandingkan label default,
  bukan string kosong. Tanpa ini, mengubah jumlah court di turnamen berikutnya membawa "Court 3" yang salah urutan. Id court
  tidak disimpan: tiap Konfigurasi dibuka court mendapat id baru (`Uuid().v4()`, `:65`).
- **Kapan ditulis**: sekali per turnamen **baru**, di `startIfNeeded` setelah `state` dibuat (bukan di cabang `identical` yang
  kembali lebih awal, `tournament_controller.dart:48`). Resume, Lanjutkan turnamen, dan Kelola court tidak menulis. Termasuk
  turnamen Sparing (modenya fixed/mixed, tanpa klub). Tidak ikut: nama turnamen, pemain, klub, pasangan. Tulis ulang menimpa
  seluruh entri olahraga itu (satu `put` per kunci); olahraga lain tidak disentuh. Kegagalan tulis (disk penuh) ditelan:
  turnamen tetap jalan, hanya pengaturan tidak tersimpan. Satu panggilan di satu tempat dan tidak ada mutator yang menulisnya,
  jadi tidak ada call site yang bisa lupa atau menggandakan; ini juga bukan state turnamen, jadi jalur auto-save turnamen tetap satu.
- **Perlakuan tak terbaca**: kunci tidak ada, bukan JSON, bukan map, atau melanggar satu baris tabel → `LastSettings.read`
  mengembalikan null tanpa melempar (`try/catch` di sekitar `jsonDecode` dan cast, pola `TournamentCodec.decode`). Konfigurasi
  memakai default 03a (Fixed, Race to 6, durasi bawaan olahraga, 2 court × 2 jam). Entri rusak tidak dihapus atau diperbaiki;
  ditimpa pada turnamen berikutnya.
- **Turunan saat dibaca**: Sparing + entri Mexicano → mode Mixed, format dan court tetap (`LastSettings.forSparing`): penyesuaian
  di layar, bukan perubahan simpanan.
- **Versi lama**: ≤ 3.3.x tidak membaca kunci ini. Akses ke box hanya lewat `TournamentStore` dengan kunci tetap (`active`,
  `lastFinished`, `live`); tidak ada yang menghitung atau mengosongkan isi box (`.keys`/`.clear` tidak muncul di
  `lib/services` dan `main.dart`), jadi kunci tambahan diabaikan dan entri 3.4.0 tetap utuh. Bentuk berikutnya yang tidak
  kompatibel menaikkan `v`; pembaca lama menganggapnya tak terbaca (default).

### Test wajib

- MX-1 `test/services/mexicano_codec_test.dart` (AC-M20): fixture literal 3.3.x Fixed/Mixed/Sparing terbaca dan ter-encode
  byte-sama; round trip Mexicano dengan pemain keluar; tiap baris tabel aturan baca → null; `mode: "zzz"` → null.
- KF-1 `test/services/last_settings_test.dart`: satu test per baris tabel validasi (→ null, tidak melempar), JSON terpotong,
  `v: 2`, round trip (nama default → null → "Court n"), tennis dan padel terpisah, Sparing + Mexicano → Mixed, nama turnamen
  tidak tersimpan, resume tidak menulis, olahraga lain tidak berubah.

## Grup + Gugur (3.8.0, MINOR)

**Final (dba, GG-0, 2026-11-17).** `schemaVersion` tetap 2: semua kunci baru opsional dan hanya ditulis untuk turnamen Grup +
Gugur, jadi encode round-robin, Mixed, Mexicano, dan Sparing byte-sama dengan 3.7.x (AC-G16) dan simpanan 3.7.x terbaca tanpa
migrasi. Tidak ada bentuk yang memaksa kenaikan skema, jadi tidak ada keputusan MAJOR untuk host. Aturan produk: PRD §16,
`design/spec/logic.md` §18. Di sini hanya bentuk simpanan dan aturan baca.

### Bentuk

```json
{ "schema": 2, "appVersion": "3.8.0",
  "tournament": { "id": "...", "createdAt": "...", "isFinished": false,
    "config": { "sport": "padel", "mode": "fixed", "scoring": "raceTo", "target": 6, "...": "...",
      "fixedPairs": [ {"id": "pair-1", "player1Id": "p1", "player2Id": "p2"}, "..." ],
      "groupKnockout": {
        "groups": [ ["pair-1", "pair-3", "pair-5", "pair-7"], ["pair-2", "pair-4", "pair-6", "pair-8"] ],
        "formats": { "SF": {"scoring": "raceTo", "target": 6}, "J3": {"scoring": "raceTo", "target": 4},
                     "F": {"scoring": "raceTo", "target": 9} },
        "thirdPlace": true } },
    "matches": [
      { "id": "m-r1-1", "roundNumber": 1, "...": "...", "pair1": {"id": "pair-1", "...": "..."}, "phase": "A" },
      { "id": "m-r7-1", "roundNumber": 7, "...": "...", "pair1": {"id": "pair-1", "...": "..."}, "phase": "SF1" },
      { "id": "m-r8-1", "roundNumber": 8, "...": "...", "pair1": null, "pair2": null, "phase": "F" } ] },
  "bye": { "gg": "1" }, "resting": { }, "withdrawn": [ ], "extraPutaran": 0 }
```

- **`config.groupKnockout`** (ditulis hanya kalau `config.groupKnockout != null`; letaknya sesudah `fixedPairs`).
  - `groups`: list 2 atau 4 elemen (Grup A..D menurut indeks), tiap elemen list id pasangan (`fixedPairs[].id`) **urut
    round-robin** (urutan masuk di layar Grup, `logic.md` §18.1). `groupCount` **tidak** disimpan: = `groups.length`.
    Model boleh punya `groups` kosong selama Konfigurasi/layar Grup; turnamen yang disimpan selalu sesudah layar Grup, jadi
    `groups` selalu terisi saat `ActiveTournament` pertama dibuat (GG-4 menjaganya; `canEncode` menolak sisanya).
  - `formats`: peta kode babak → `{scoring, target}` (nama kunci sama dengan `config.scoring`/`target`). Kode = awalan
    `MatchPhase.code`: `PF` (perempat final, **hanya** kalau 4 grup), `SF`, `J3`, `F`. `J3` selalu ada walau `thirdPlace`
    false (format terakhir tetap diingat, keputusan 100). Urutan tulis = urutan enum `KnockoutRound` (PF, SF, J3, F).
    Format fase grup tetap `config.scoring`/`target`, tidak disalin.
  - `thirdPlace`: bool.
- **`matches[].phase`**: string `MatchPhase.code` ('A'..'D', 'PF1'..'PF4', 'SF1', 'SF2', 'F', 'J3'), ditulis hanya kalau
  `phase != null`, sesudah `woReason`. Di turnamen Grup + Gugur **setiap** match punya `phase`.
- **Sisi belum diketahui** (`Pair.tbd`, "Pemenang SF1"): `pair1`/`pair2` ditulis `null` (bukan objek berid kosong, supaya
  tidak tertukar dengan pasangan sungguhan; hanya `isTbd` yang jadi `null`). Pembaca membuatnya jadi `Pair.tbd`.
- **Hasil Buat bagan tidak disimpan terpisah** (usulan tech-lead disetujui). Cukup dari sisi babak pertama: topologi
  `logic.md` §18.8 menaruh tiap pasangan lolos di tepat satu slot (2 grup: SF1 = A1 vs B2, SF2 = B1 vs A2; 4 grup: PF1 =
  A1 vs B2, PF2 = C1 vs D2, PF3 = B1 vs A2, PF4 = D1 vs C2), jadi siapa yang lolos, urutannya (A1 atau A2), dan pilihan host
  atas seri semua terbaca dari `pair1`/`pair2` di sana. Pilihan host tidak perlu disimpan sebagai pilihan (AC-G7). "Skor grup
  terkunci" = ada match gugur (`hasBracket`); sebelum Buat bagan tidak ada match gugur sama sekali, jadi tidak ada keadaan
  setengah jadi di simpanan. Tabel grup, seed (`seedOf`), dan peringkat akhir turunan dari match, tidak disimpan.
- **Court per grup tidak disimpan**: `courtId` tiap match grup sudah menentukan jadwal, jadi jadwal tidak bergeser walau
  aturan GU3 berubah di rilis berikutnya. Decoder tidak mengulang `courtsOfGroups`/`layout`: nomor round dan court tidak
  dicocokkan dengan rumus (rumus boleh berubah di 3.8.x tanpa membuat simpanan lama ditolak).
- **Turunan lain tanpa kunci baru**: `byePairIdByRound` selalu kosong (GU5), tanpa `restingPairs`, `resting` kosong,
  `withdrawn` kosong, `extraPutaran` 0 (tanpa Tambah round, `canAddRounds` false di Grup + Gugur). Diakhiri: match `pending`
  jadi `cancelled`, tak ada kunci khusus; `isFinished` seperti biasa.

### Penanda GU15 (app ≤ 3.7.x menolak) — `bye.gg = "1"`

Payload Grup + Gugur menulis `"bye": {"gg": "1"}` (kunci pertama, sebelum nomor round — yang di sini selalu kosong). Pola sama
dengan `bye.sparing`: kunci bukan angka membuat decoder lama melempar. Bukti dari kode (tidak hanya dibaca):

- Decoder 3.7.1 (`527b0ab`, `lib/services/storage/tournament_codec.dart`): `:75` `try {`, `:83-85` hanya kunci persis `sparing`
  yang dibuang dari `bye` (`gg` tertinggal), `:96` `byePairIdByRound: {for (final e in bye.entries) int.parse(e.key): …}` →
  `int.parse('gg')` melempar `FormatException`, `:114-117` `catch (_) { return null; }`. `schema` 2 dan `appVersion` String
  lolos lebih dulu (`:77`), jadi penolakannya memang karena penanda.
- Baris `int.parse(e.key)` untuk `bye` yang sama ada di semua rilis skema 2: bc38717:33, 3.1.0 (10817f4):37, 3.2.0
  (564ea67):74, 3.3.2 (8af509b):88, 3.7.1 (527b0ab):96 (ekspresi `int.parse(e.key): e.value as String` yang sama; perubahan
  sesudah 3.3.2, yaitu 9c8f35f Mexicano dan 0336826 id duplikat sparing, tidak menyentuhnya).
- Dijalankan 2026-11-17: `git archive 527b0ab` ke folder sementara, `flutter test` memanggil `TournamentCodec.decode` 3.7.1:
  payload bersih → terbaca (kontrol); payload dengan `config.groupKnockout` + `phase` **tanpa** penanda → **terbaca** sebagai
  round-robin (bahaya yang dicegah); sama dengan `bye.gg: "1"` → `null`; `bye.gg` saja → `null`. Folder sementara dihapus.
- Penonton ≤ 3.7.x membuka live: `decode` null → `LiveViewStatus.unreadable` (`features/live/live_view_controller.dart`,
  layar "Live tidak bisa dibuka"). Relay tidak berubah (hanya memeriksa `schema` angka dan `tournament` objek, tidak membaca
  `bye`). Host ≤ 3.7.x di box yang sama: `loadActive` null, listener auto-save mengabaikan state null, simpanan tidak
  ditimpa sampai host memulai turnamen baru di versi lama (risiko yang sama dengan Sparing dan Mexicano; `lastFinished`
  Grup + Gugur di versi lama tak terbaca tapi tidak dihapus). Konsekuensi yang diterima: penonton versi lama melihat "Live
  tidak bisa dibuka" (bukan data salah) sampai membuka link sekali lagi setelah update tertarik.
- Penanda ini wajib dipertahankan oleh siapa pun yang menyentuh codec. Nilai "1" = revisi bentuk Grup + Gugur; nilai lain →
  null di 3.8.0 (revisi tak kompatibel berikutnya menaikkannya, app 3.8.0 menolak dengan cara yang sama). Decoder 3.8.0 membuang
  kunci persis `gg` (dan `sparing`) sebelum membaca nomor round; kunci non-angka lain tetap membuat payload rusak.

### Aturan baca (semua pelanggaran = `decode` null, bukan melempar; `canEncode` memakai fungsi yang sama)

Pembaca membedakan **round-robin/lainnya** (tanpa `config.groupKnockout`) dan **Grup + Gugur** (ada). Kunci Grup + Gugur di
keadaan yang salah = rusak, karena tidak ada penulis yang bisa menghasilkannya. Satu fungsi `_isValidGroupKnockout` untuk
`decode` dan `canEncode` (pola `_isValidSparing`); kegagalan `encode` = `UnreadableTournamentError`, store melewati tulisannya.

| # | Kondisi | Contoh payload yang ditolak |
|---|---|---|
| GR1 | `bye.gg` ada tapi bukan `"1"` | `bye: {gg: "2"}`, `{gg: 1}` |
| GR2 | `config.groupKnockout` ada tanpa `bye.gg` = `"1"`, atau `bye.gg` ada tanpa `config.groupKnockout` | round-robin 3.7.x + `bye.gg`; Grup + Gugur tanpa penanda |
| GR3 | `groupKnockout` bersama `mode` ≠ `fixed`, atau `config.clubs`, atau kunci sparing (`club` di pemain, `restingPairs`, `bye.sparing`) | `mode: "mixed"` + `groupKnockout`; Sparing + `groupKnockout` |
| GR4 | `groupKnockout` bukan map; `groups` bukan list berisi tepat 2 atau 4 list-of-String; `thirdPlace` bukan bool; `formats` bukan map | `groups: [["a"]]`, 3 grup, `thirdPlace: "true"` |
| GR5 | `fixedPairs` null/kosong, atau `G` ∉ `GroupStage.groupCountsFor(P)` dengan P = `fixedPairs.length` | 5 pasangan; 8 pasangan 4 grup |
| GR6 | `groups` tidak menutup `fixedPairs` tepat sekali: id di dua grup, duplikat dalam satu grup, id yang bukan `fixedPairs`, pasangan tanpa grup; id `fixedPairs` kembar | `pair-1` di Grup A dan B |
| GR7 | Ukuran grup i ≠ `GroupStage.sizes(P, G)[i]` | 7 pasangan 2 grup sebagai [3, 4] atau [5, 2] |
| GR8 | `formats` tidak persis `{SF, J3, F}` (+ `PF` iff 4 grup), atau nilai bukan `{scoring: nama ScoringMethod, target: int}` yang `isValidKnockout` | `PF` di 2 grup; `SF` tanpa `J3`; Best of 6; Americano 24; Race to 10 |
| GR9 | Id pemain kembar di `config.players`; anggota `fixedPairs` tak ada di `players`; satu pemain di dua pasangan | pemain `p1` dua kali; pasangan memakai `p99` |
| GR10 | Match tanpa `phase` di Grup + Gugur, atau `phase` di turnamen lain; `phase` bukan String, kode tak dikenal, grup di luar `groups.length`, `PF*` di 2 grup | `phase: "E"`, `"C"` di 2 grup, `"PF1"` di 2 grup, `phase` di round-robin |
| GR11 | Match `GroupPhase(g)`: sisi `null`, atau sisi ≠ (nilai) `fixedPairs` dengan id itu, atau bukan anggota `groups[g]`, atau dua sisi sama, atau dua pasangan itu bertemu dua kali di grup yang sama | match grup A berisi pasangan grup B |
| GR12 | Himpunan kode match gugur bukan kosong atau tepat susunan `layout`: 2 grup `{SF1, SF2, F}`, 4 grup `{PF1..PF4, SF1, SF2, F}`, plus `J3` iff `thirdPlace`; kode ganda | `J3` padahal `thirdPlace: false`; PF1–PF3 tanpa PF4; dua `F` |
| GR13 | Urutan round: ada round gugur ≤ round grup terbesar; round babak berikutnya ≤ round salah satu sumbernya (PF→SF, SF→F dan J3) | Final di round yang sama dengan SF |
| GR14 | Match babak pertama (PF di 4 grup, SF di 2 grup) bersisi `null`, atau sisi seed (A1, B2, …) bukan anggota grup huruf itu, atau slot 1 dan 2 satu grup berisi pasangan yang sama | `pair1: null` di SF1; A1 dan A2 pasangan yang sama |
| GR15 | Sisi babak lanjut ≠ `KnockoutBracket.resolve` (pemenang/kalah dari `winnerPairId` sumber; sumber belum punya hasil → `null`); `null` di match berstatus `done`/`walkover` | Final berisi pemenang SF yang salah; match `done` bersisi `null` |
| GR16 | Match gugur `done`/`walkover` tanpa `winnerPairId` (I9) | Final Americano 24–24 `done` |
| GR17 | Di Grup + Gugur: `bye` (selain `gg`) tidak kosong, ada `restingPairs`, `resting` tidak kosong, `withdrawn` tidak kosong, atau `extraPutaran` ≠ 0 | `bye: {gg: "1", "3": "pair-1"}`, `extraPutaran: 1` |

Yang **tidak** diperiksa (keadaan, bukan bentuk): siapa sebenarnya juara grup dan benarkah yang lolos = dua teratas (pilihan host
dan head-to-head tidak bisa diverifikasi; payload dengan lolos "salah" tetap sah), setiap pasangan grup bertemu tepat sekali
(I2; yang dijaga hanya "paling sekali" dan hanya sesama anggota, supaya penulis yang kelak menghapus match yang tak jadi
dimainkan tidak membuat simpanannya ditolak), nomor round/court tiap match, `matchNumberInRound`, `courtId` ada di `config.courts`
(sama dengan mode lain), match grup masih `pending` setelah ada bagan, pasangan di dua match pada round yang sama (I4), skor
sah per format (`withScore` sudah menolak di layar; membaca tidak menolak data yang masih bisa ditampilkan). Helper model
(`groupOfPair`, `seedOf`, `formatFor`) harus **total**: id tak dikenal → null/dilewati, tidak pernah melempar. Aturan umum yang
sudah ada tetap berlaku (`roundNumber` 1..1000, `schema`/`appVersion`).

Penulisan: `encode(decode(x)) == x` untuk payload Grup + Gugur yang sah (urutan kunci tetap: `groupKnockout` sesudah `fixedPairs`,
di dalamnya `groups`, `formats` (urutan PF, SF, J3, F), `thirdPlace`; `bye.gg` kunci pertama `bye`; `phase` sesudah `woReason`).
Turnamen lain: tidak satu pun kunci baru ditulis dan `null` hanya untuk `Pair.tbd`, jadi byte-sama dengan 3.7.x.

### Pengaturan terakhir (19i) — `settings.<olahraga>`

Diingat: Grup + Gugur atau round-robin, jumlah grup, format tiap babak, juara 3. Kunci opsional baru `groupKnockout` di JSON
**`v` tetap 1** (tidak naik: 3.7.x tetap membaca entri itu dan mengabaikan kunci yang tak dikenalnya, sehingga membacanya
sebagai Fixed biasa; menaikkan `v` hanya membuat 3.7.x membuang seluruh entri, tanpa untung):

```json
{ "v": 1, "mode": "fixed", "scoring": "raceTo", "target": 6, "duration": 15, "courts": [ "..." ],
  "groupKnockout": { "groupCount": 4, "thirdPlace": false,
    "formats": { "PF": {"scoring": "raceTo", "target": 5}, "SF": {"scoring": "raceTo", "target": 6},
                 "J3": {"scoring": "raceTo", "target": 4}, "F": {"scoring": "raceTo", "target": 9} } } }
```

- Ditulis hanya kalau turnamen yang dimulai Grup + Gugur (di `startIfNeeded`, panggilan tunggal yang sama, bukan mutator);
  kunci tidak ada = round-robin dan kunci tidak ditulis untuk turnamen lain, jadi entri 3.7.x dan entri round-robin 3.8.0
  byte-sama. Anggota grup tidak diingat (tidak pernah ikut pengaturan).
- Validasi (satu pelanggaran = seluruh entri tak terbaca, konvensi tabel di atas): `groupKnockout` map; `mode` = `fixed`;
  `groupCount` int 2 atau 4; `thirdPlace` bool; `formats` persis `{SF, J3, F}` (+ `PF` iff `groupCount` 4) dengan
  `isValidKnockout`. Batas 16 KB yang ada tetap.
- Tidak disimpan sebagai pilihan yang pasti berlaku: Konfigurasi menurunkan saat dibaca, tanpa mengubah simpanan. 4 grup tapi
  P < 12 → 2 grup dan format `PF` dibuang (19i, asumsi designer); Sparing (`LastSettings.forSparing`) membuang `groupKnockout`
  (GU14), seperti Mexicano jatuh ke Mixed; turunan itu tugas GG-5 di sisi layar, bukan di `read`.
- Versi lama: 3.7.x membaca entri ini sebagai Fixed biasa (kunci `groupKnockout` diabaikan) dan menimpanya tanpa kunci saat
  turnamen berikutnya dimulai: hilangnya pilihan Grup + Gugur saat downgrade tidak berbahaya.

### Ukuran

Terbesar: 30 pemain, 2 grup (8 + 7 pasangan, 49 match grup) + 2 SF, Final, Juara 3 = 53 match; ±660 B per match (id UUID)
≈ 35 KB, jauh di bawah `MAX_BYTES` relay 256 KB (GG-3 menulis angka sebenarnya di komentar test). Match tbd lebih kecil
(sisi `null`). Tidak ada batas baru; jumlah match gugur dibatasi aturan GR12 (≤ 8).

### Test wajib (GG-3, `test/services/group_knockout_codec_test.dart`; nama memakai id aturan/AC)

- AC-G16 fixture literal 3.7.x (round-robin Fixed dengan `extraPutaran`, Sparing, Mexicano, Mixed dengan `withdrawn`) terbaca
  dan ter-encode **byte-sama**; encode turnamen lain tanpa `groupKnockout`, `phase`, `gg`, dan tanpa `null` di `pair1`/`pair2`.
- AC-G15 round trip `encode(decode(x)) == x` di tiga keadaan (fase grup 20b, setelah Buat bagan 21a, tengah gugur 21c SF1),
  setelah diakhiri (21t, match gugur `cancelled` bersisi `null`), dan 4 grup (16B 21w–21y, PF terisi, Final + Juara 3 bersisi
  tbd), 4 grup 3 court (16B varian), tanpa juara 3 (21q), 1 court (21s), WO di SF (21o).
- Satu test ditolak per aturan **GR1–GR17**, dari payload sah yang diubah satu bagian (varian contoh di tabel), termasuk dua
  varian GR8 (`PF` di 2 grup; `Best of 6`) dan GR6 (dua grup / tanpa grup); tiap kasus: `decode` null, tidak melempar, dan
  `canEncode` false untuk model yang setara (`encode` melempar `UnreadableTournamentError`).
- Payload terpotong, `groupKnockout: null`, `groups` bertipe salah, `phase: 5`, `pair1: "x"` → null (tanpa melempar).
- **Penanda GU15**: payload Grup + Gugur sah, dibaca oleh salinan aturan decoder 3.7.1 (fungsi test yang meniru `:83-96`:
  buang kunci `sparing`, `int.parse` tiap kunci `bye`) → null; payload sama tanpa `bye.gg` → terbaca oleh salinan itu (membuktikan
  penanda yang menolaknya, bukan hal lain); decoder 3.8.0 membuang `gg` sebelum nomor round dan menolak kunci non-angka lain
  (`bye: {gg: "1", x: "1"}` → null). Pola `sparing_codec_test`.
- `bye.gg` pada round-robin dan pada Sparing → null (GR2/GR3), JSON sparing tetap memakai `sparing`, bukan `gg`.
- `LastSettings` (di `last_settings_test.dart` atau berkas codec): round trip dengan `groupKnockout` (2 dan 4 grup, juara 3
  mati); entri 3.7.x/round-robin tanpa kunci terbaca sebagai round-robin dan ter-`toJson` byte-sama; tiap baris validasi di
  atas → null (`mode` mixed, `groupCount` 3, `PF` di 2 grup, Best of 6, `thirdPlace` bukan bool); `v: 2` tetap null.
- Ukuran: 30 pemain 2 grup + bagan lengkap, encode < 256 KB (tulis angka sebenarnya).
- Properti (boleh digabung dengan GG-4): setiap state yang dihasilkan rangkaian skor/WO/ubah-skor acak `KnockoutBracket` lolos
  `canEncode` dan `decode(encode(x)) == x`.

## Kosongkan skor / Hapus WO + Point % (3.9.0, MINOR)

Tanpa kunci baru, `schemaVersion` tetap 2 (keputusan 126, 128 #9; spec `design/spec/logic.md` §19.9). Keadaan baru yang
bisa tersimpan sejak 3.9.0 tetap sah di aturan baca lama: round Fixed lama yang dikosongkan (match kembali `pending` di
tengah turnamen) dan SF gugur yang dikosongkan/dihapus WO-nya (babak sesudahnya kembali `tbd`) lolos GR13–GR16, jadi app
3.8.x membukanya. Metode Klasemen (Point %) tidak disimpan dan tidak ada di payload live.

## Group - Playoff fleksibel (3.10.0, MINOR)

**Final (dba, GP-0, 2026-11-23).** `schemaVersion` tetap 2 (keputusan 135–154; tidak ada bentuk yang memaksa naik, jadi tidak
ada keputusan MAJOR untuk host). Semua tambahan opsional atau berupa rentang nilai baru; encode round-robin, Mixed, Mexicano,
Sparing, serta Group - Playoff **2 dan 4 grup** byte-sama dengan 3.9.1 (selain `appVersion`). `bye.gg` tetap `"1"`. Aturan
produk: PRD §16 (16.10), §8.1, `design/spec/logic.md` §21 (21.9 draf). Di sini hanya bentuk simpanan dan aturan baca.

### Keputusan

| Pokok | Keputusan | Alasan |
|---|---|---|
| `schemaVersion` | tetap 2, `bye.gg` tetap `"1"` | pembaca 3.9.1 menolak 3 grup sendiri lewat GR5 (null, tanpa crash); 2 dan 4 grup tetap bentuk lama. Penanda baru (`gg: "2"`) hanya akan membuat 3.10.0 menolak data yang 3.9.1 bisa tampilkan dengan benar |
| Kode simpanan "PF" | tetap `PF1`..`PF4`, kunci `formats.PF`, kunci pengaturan terakhir `PF`; "QF" hanya teks UI | `_readPhase` 3.9.1 melempar untuk kode tak dikenal (`QF1` → seluruh turnamen 4 grup null); dua kode berarti dua jalur di decoder. `KnockoutPhase.code` punya switch sendiri, bukan `codePrefix` (GP-1) |
| `wildcards` (GR18) | **disimpan**: `config.groupKnockout.wildcards` = `[idWC1, idWC2]` | lihat di bawah |
| Pilihan host atas seri | tidak disimpan sebagai pilihan; hasilnya (siapa lolos, urutan WC) terbaca dari bagan + `wildcards` | sama dengan 3.8.0 (AC-G7) |
| J1, J2, J3, grup asal WC | diturunkan dari `pair1` QF1, QF3, QF4 dan `groups`, tidak disimpan | satu sumber kebenaran (match); GR19 memeriksa kecocokannya |
| Court per grup | tidak disimpan; `courtId` match sudah menentukan (16.10 terpenuhi) | sama dengan 3.8.0 |
| `groups.length` 3 | sah; GR5 memakai `decodableGroupCounts(P)` | data 2 × 3 dan 4 × 3 (3.8.x–3.9.x) tetap terbaca (AC-G29) |
| 2/4 grup 32 pemain (16 pasangan) di 3.9.x | **ditampilkan**, tidak ditolak | lihat "App 3.9.x" |
| 3 grup di 3.9.x | **ditolak** (null) | lihat "App 3.9.x" |

**Kenapa `wildcards` disimpan, bukan diturunkan.** (1) Urutan WC1/WC2 **tidak bisa dipulihkan dari match**: himpunan
{QF1.pair2, QF3.pair2} sama untuk bagan tanpa tukar dan dengan tukar, dan kedua pembacaan bisa sama-sama lolos aturan tukar
(mis. WC dari grup J2 dan J3: tanpa tukar WC1 = QF1.pair2; dengan tukar WC1 = QF3.pair2). Label "WC1/WC2" di Klasemen, Detail,
dan poster butuh urutannya. (2) Menurunkannya dari skor grup memanggil mesin peringkat (Win %/Point %, selisih per match,
huruf grup) dan membuat bacaan simpanan bergantung pada rumus yang boleh berubah di rilis berikutnya; prinsip 3.8.0 (court
per grup tidak dihitung ulang) berlaku sama. (3) PRD 16.10 meminta bagan tidak dihitung ulang saat dibuka. Biaya: satu kunci
opsional ±100 B, hanya di 3 grup setelah Buat bagan. Pembaca 3.9.x tidak pernah melihatnya (3 grup sudah ditolak).

### Bentuk

Hanya yang berubah dari "Grup + Gugur (3.8.0)":

```json
"groupKnockout": {
  "groups": [ ["pair-1","pair-4","..."], ["pair-2","pair-5","..."], ["pair-3","pair-6","..."] ],
  "formats": { "PF": {"scoring":"raceTo","target":5}, "SF": {"..":"."}, "J3": {"..":"."}, "F": {"..":"."} },
  "thirdPlace": true,
  "wildcards": ["pair-9", "pair-11"] }
```

- `groups`: 2, 3, atau 4 list; tiap list urut round-robin. `groupCount` tetap tidak disimpan (= `groups.length`).
- `formats`: `{SF, J3, F}` plus `PF` **iff G ≥ 3** (dulu iff G = 4). Urutan tulis PF, SF, J3, F.
- `wildcards` (kunci terakhir di `groupKnockout`, sesudah `thirdPlace`): `[WC1, WC2]` id pasangan **dalam urutan seeding
  sebelum tukar** (bukan urutan sisi di bagan). Ditulis iff `wildcards` non-kosong di model; model mengisinya hanya di 3 grup
  dan di `state =` yang sama dengan match bagan pertama (jebakan 21.12 #1: `copyWith` membawanya, ubah format/juara 3
  mempertahankannya). Tidak ada kunci `wildcards: []`.
- `matches[].phase`: `PF1`..`PF4` sah di G ≥ 3; huruf grup A..C di 3 grup. Match 3 grup memakai topologi logic.md §21.6:
  QF1 = J1 vs WC (1), QF2 = R(J2) vs R(J3), QF3 = J2 vs WC (2), QF4 = J3 vs R(J1); SF1 = W(QF1) vs W(QF2), SF2 = W(QF3) vs W(QF4);
  (1)/(2) = WC1/WC2 atau tertukar. Tidak ada kunci lain (juara 3 mati/nyala dan format babak yang diubah, G16, hanya mengubah
  `thirdPlace`, ada/tidaknya match `J3` dan `formats`).

### Aturan baca baru dan yang berubah (pelanggaran = `decode` null, bukan melempar; `canEncode` memakai fungsi yang sama)

Tabel GR1–GR17 berlaku seperti di 3.8.0 kecuali baris berikut. Satu fungsi `_isValidGroupKnockout` untuk `decode` dan `canEncode`.

| # | Perubahan / aturan | Contoh payload yang ditolak |
|---|---|---|
| GR4 | `groups` list 2, **3**, atau 4 list-of-String; `wildcards` (kalau ada) list berisi tepat 2 String | `groups` 5 list; `wildcards: ["a"]`, `wildcards: "a"` |
| GR5 | `G` ∈ `GroupStage.decodableGroupCounts(P)` (P = `fixedPairs.length`), bukan `groupCountsFor`: P 6–11 → [2]; P 12–16 → [2, 3, 4]; P > 16 → [] (security W4). G = 3 sah hanya dari P ≥ 12 (ukuran ≥ 4); 2 × 3 dan 4 × 3 lama tetap lolos | 3 grup dengan 11 pasangan; 4 grup dengan 8 pasangan |
| GR8 | `formats` persis `{SF, J3, F}` plus `PF` iff G ≥ 3 | `PF` di 2 grup; 3 grup tanpa `PF` |
| GR10 | `PF*` sah iff G ≥ 3; huruf grup < G | `PF1` di 2 grup; `"D"` di 3 grup |
| GR12 | himpunan kode gugur: 2 grup `{SF1, SF2, F}`; **3 dan 4 grup** `{PF1..PF4, SF1, SF2, F}`; plus `J3` iff `thirdPlace` | 3 grup tanpa PF4 |
| GR14 | 2 dan 4 grup tetap (sisi seed anggota grup huruf itu). **3 grup memakai GR19** | – |
| GR18 | `groupKnockout.wildcards`: ada iff G = 3 **dan** sudah ada match gugur; di 2/4 grup (termasuk `[]`) atau 3 grup tanpa bagan → ditolak; 3 grup dengan bagan tanpa `wildcards` → ditolak (label WC tak bisa dipulihkan). Dua id berbeda, anggota `groups`, dari dua grup berbeda | `wildcards` di 4 grup; WC1 = WC2; dua WC satu grup; id bukan anggota grup |
| GR19 | Babak pertama 3 grup (QF1–QF4, semua sisi non-`null`): J1 = QF1.pair1, J2 = QF3.pair1, J3 = QF4.pair1 dari **tiga grup berbeda**; QF4.pair2 segrup J1, QF2.pair1 segrup J2, QF2.pair2 segrup J3 (runner-up); delapan pasangan di QF1–QF4 berbeda semua (jadi WC bukan J atau R); tukar = `group(WC1) = group(J1)` atau `group(WC2) = group(J2)`, dan {QF1.pair2, QF3.pair2} = (tanpa tukar) `[WC1, WC2]` / (tukar) `[WC2, WC1]`; tidak ada QF yang mempertemukan dua pasangan segrup | J1 dan J2 satu grup; QF1.pair2 = WC2 padahal tidak perlu tukar; QF2 mempertemukan dua pasangan segrup; WC = R(J1) |

Total: `groupOfPair` dan helper lain tidak melempar untuk id tak dikenal (null → ditolak). GR19 diperiksa dengan `groups`, bukan
`KnockoutBracket.sources` (bentuk sumber 3 grup bebas di GP-2); GR15/GR16 tetap lewat `KnockoutBracket.isResolved`/`resolve`.

Yang **tidak** diperiksa (sama dengan 3.8.0, keadaan bukan bentuk): benarkah J1–J3 berurut menurut metode Playoff, benarkah dua WC
adalah dua peringkat 3 terbaik, dan apakah pilihan host atas seri sah. Payload dengan lolos "salah" tetap sah. Jumlah pemain
(maksimal 32) **tidak** diperiksa decoder (sekarang pun tidak): batasnya di layar dan `maxPlayers`.

### App 3.9.x terhadap simpanan/payload 3.10.0 (AC-B8, AC-G29)

Dasar: `lib/` di HEAD identik dengan commit rilis 3.9.1 (`5d2c06e`, `git diff 5d2c06e HEAD -- lib` kosong); di sana
`GroupStage.groupCountsFor` = `< 6 → []`, `< 12 → [2]`, selain itu `[2, 4]` (tanpa batas atas), dipanggil di
`tournament_codec.dart:183` (GR5), dan `_readPhase` hanya mengenal `A–D, PF1–PF4, SF1, SF2, F, J3`. Dibuktikan dengan membaca
kode (versi lama tidak dijalankan di sini); GP-4 membuktikannya dengan test (di bawah).

| Kasus di 3.10.0 | Decoder 3.9.1 | Keputusan |
|---|---|---|
| 3 grup (P 12–16), sebelum atau sesudah Buat bagan | `groupCountsFor(P)` = [2, 4] ∌ 3 → GR5 `return false` → **null** | tolak (tanpa perubahan; PRD 16.10 meminta ini) |
| 2 grup 8 + 8 atau 4 grup 4 × 4 (16 pasangan, 32 pemain) | `groupCountsFor(16)` = [2, 4], ukuran = `sizes`, `PF` iff 4 grup → **terbaca**, label lama ("PF1", "Juara") | **tampil**: tidak ada alasan menolak data yang benar; menolak butuh penanda baru yang juga memutus 3.10.0 → 3.10.0 |
| 2/4 grup ≤ 15 pasangan, ubah format/juara 3 (G16) | bentuk lama (`formats`, `thirdPlace`, ada/tidaknya `J3`) → terbaca | tampil |
| Round-robin, Mixed, Mexicano, Sparing 31–32 pemain | decoder tidak memeriksa jumlah pemain → **terbaca**; Kelola pemain 3.9.x dengan 32 aktif: Tambah mati (`limit` 30), tidak crash | tampil |
| Pengaturan terakhir `groupCount: 3` | `_readKnockout`: `count != 2 && count != 4` → melempar → `read` null | seluruh entri dibuang → default (court dan format ikut hilang sekali); tidak berbahaya, ditimpa saat turnamen berikutnya dimulai |

Konsekuensi yang diterima (pola yang sama dengan Mexicano/GU15): penonton 3.9.x di tautan live 3 grup melihat "Live tidak
bisa dibuka" (bukan data salah) sampai app diperbarui; host 3.9.x di box yang sama: `loadActive` null, listener auto-save
mengabaikan state null, simpanan tidak ditimpa sampai host memulai turnamen baru di versi lama. Kunci `wildcards` tidak pernah
sampai ke pembaca 3.9.x (hanya ada di 3 grup, sudah ditolak lebih dulu).

### Pengaturan terakhir (`settings.<olahraga>.groupKnockout`, `v` tetap 1)

- `groupCount` int 2, **3**, atau 4; `formats` persis `{SF, J3, F}` plus `PF` iff `groupCount` ≥ 3 (kunci tetap `PF`, tidak
  `QF`). Kunci lain, `thirdPlace` bool, batas 16 KB, dan "satu pelanggaran = seluruh entri tak terbaca" tidak berubah. `v`
  tidak naik: 3.9.x membuang entri 3 grup (default) tanpa crash, sedangkan menaikkan `v` membuang semua entri 3.10.0 di app
  lama tanpa untung.
- Turunan saat dibaca (bukan di `read`, yang tidak tahu P): Konfigurasi memanggil `GroupStage.fallbackGroupCount(P, groupCount)`
  (satu fungsi yang sama dengan sheet Fase grup, GP9): pilihan yang tak sah untuk P turun ke G terbesar ≤ pilihan di
  `groupCountsFor(P)` (3 grup 24 → 20 pemain = 2; 4 grup 32 → 30 = 3; 4 grup 32 → 22 = 2), daftar kosong → Round-robin.
  Menggantikan aturan lama "4 grup dan P < 12 → 2". Format `PF` dibuang bila hasilnya 2 grup; simpanan tidak diubah.
- Entri 3.9.x (`groupCount` 2/4) terbaca apa adanya dan ter-`toJson` byte-sama.

### Ukuran payload live (AC-B9)

Terukur 2026-11-23 (test sementara, dihapus): id UUID, semua match berskor, `utf8.encode(encode(active)).length`; ±540 B per
match, ±1 KB per round untuk daftar istirahat Mixed.

| Kasus (32 pemain) | Match | Ukuran |
|---|---|---|
| Group - Playoff 2 grup × 8 + bagan | 60 | 37 KB |
| Group - Playoff 3 grup [6, 5, 5] + bagan / 4 × 4 + bagan | 43 / 32 | < 30 KB (di bawah 2 × 8; ditaksir dari per-match, `wildcards` +±100 B) |
| Fixed 16 pasangan round-robin, 2 court | 120 | 69 KB |
| Mixed 32/8 court, 16 round | 128 | 71 KB |
| Mixed 32/1 court, 30 round + istirahat 28 id/round | 30 | 52 KB |
| Fixed 16 pasangan + 1 / 2 putaran tambahan | 240 / 360 | 133 / 197 KB |
| Mixed 32/8 court, 50 round | 400 | 216 KB |

Batas relay `MAX_BYTES` = 256 KB (`relay/src/index.js:14`; relay tidak berubah) ≈ 470 match. Kasus dasar semua di bawah 128 KB
(separuh batas, margin untuk id/nama lebih panjang). Di atas 128 KB: Fixed 16 pasangan dengan ≥ 1 putaran tambahan (Tambah round
tidak berbatas) dan Mixed 32 pemain > ±55 round; di atas 256 KB (≈ 3 putaran tambahan, 480 match) `push` dijawab 413, ditangkap
`LiveHostController._send` (`LiveRelayException` → `_scheduleRetry`, gagal terus: penonton berhenti melihat pembaruan, turnamen lokal tidak terganggu). Risiko yang sudah ada untuk ≤ 30 pemain dengan skala
lebih kecil; tidak diperbaiki di 3.10.0 (lihat laporan: usulan menaikkan `MAX_BYTES` setelah memeriksa batas penyimpanan Durable
Object, belum diverifikasi di sini). Komentar "30 pemain" di `relay/src/index.js:14` boleh diperbarui tanpa deploy.

### Test wajib (GP-4, `test/services/group_knockout_codec_test.dart`, `last_settings_group_knockout_test.dart`, `live_payload_size_test.dart`; nama memakai id aturan/AC)

- **AC-G29** fixture literal 3.9.x: 2 × 3 (P = 6) dan 4 × 3 (P = 12) terbaca, ter-encode byte-sama (selain `appVersion` bila ditulis
  ulang), dilanjutkan sampai Final (bagan huruf); encode 2 dan 4 grup di 3.10.0 tidak memuat `wildcards` dan tidak memuat teks "QF"
  (kode tetap `PF1`..`PF4`, `formats.PF`).
- **GR4/GR5/GR8/GR10/GR12** untuk 3 grup: satu test ditolak per baris tabel (P = 11 dengan 3 grup, 3 grup tanpa/dengan `PF` salah,
  `"D"` di 3 grup, `PF4` hilang); P = 12, 13, 14, 15, 16 dengan 3 grup terbaca (sebelum dan sesudah bagan); `canEncode` false untuk
  model yang setara (`encode` melempar `UnreadableTournamentError`).
- **GR18** `wildcards`: round trip 16G (tanpa tukar), 16G-iii (pilihan host), varian tukar WC1 segrup J1, tukar WC2 segrup J2, tukar
  keduanya, 3 grup dengan juara 3 mati, di tengah gugur dan setelah diakhiri; `encode(decode(x)) == x`. Ditolak: di 2 grup, di 4
  grup, `[]`, 3 grup dengan bagan tanpa kunci, 3 grup tanpa bagan dengan kunci, satu id, tiga id, id sama, id bukan anggota grup,
  dua WC satu grup, bertipe salah.
- **GR19** satu test ditolak per kalimat aturan (J dari grup sama, R(J) tak segrup, id ganda di QF1–QF4, urutan WC tak cocok aturan
  tukar dalam kedua arah, QF segrup, sisi `null`).
- Ubah format babak/juara 3 3 grup (G16) mempertahankan `wildcards` (21.12 #1); AC-G28 lewat decode ulang.
- **AC-B8 lintas versi**: salinan aturan decoder 3.9.1 di test (`groupCountsFor` lama = `< 6 → [], < 12 → [2], [2, 4]`, `_readPhase`
  lama) membaca payload 3.10.0: 3 grup → null; 2 × 8 dan 4 × 4 (16 pasangan) → terbaca; Mixed/round-robin 32 pemain → terbaca;
  `last_settings` `groupCount: 3` → null di aturan lama (`count != 2 && count != 4`). Sekali sebelum merge, jalankan juga decoder asli:
  `git archive 5d2c06e` ke folder sementara di dalam proyek, `flutter test` memanggil `TournamentCodec.decode` dengan fixture 3.10.0
  (pola "Penanda GU15"), lalu hapus folder.
- `last_settings`: `groupCount: 3` round trip; `PF` wajib iff ≥ 3; `groupCount: 5` / `PF` di 2 grup → null; entri 3.9.x byte-sama;
  `fallbackGroupCount` dipakai (3 grup 24 → 20 pemain = 2, 4 grup 32 → 22 = 2, daftar kosong → round-robin).
- **AC-B9 ukuran**: encode tiap baris tabel ukuran kasus dasar `< 128 * 1024`; Fixed 16 pasangan + 2 putaran tambahan dan Mixed 32/8 court 50
  round `< 256 * 1024`; tulis angka terukur di komentar test; semua `decode(encode(x)) != null`.
- Properti: state acak `KnockoutBracket` 3 grup (skor/WO/ubah-skor/kosongkan) selalu lolos `canEncode` dan `decode(encode(x)) == x`.

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
