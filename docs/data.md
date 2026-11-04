# Data — persistensi lokal

Pemilik: dba. Baca kalau mengubah bentuk simpanan, `services/storage/`, resume, Lanjutkan turnamen, atau slot
`active`/`lastFinished`. Produk: `PRD.md` §5.10. Seluruh MVP PRD sudah jalan, termasuk bagian 5 (Penyimpanan Data).

## Codec & store

- `services/storage/tournament_codec.dart` — `ActiveTournament` ↔ JSON, Dart murni, ter-test. Sengaja **bukan**
  TypeAdapter Hive: model domain jadi bebas anotasi/codegen dan tidak perlu mengelola nomor `typeId`.
- `schemaVersion` dinaikkan kalau bentuk JSON berubah tidak kompatibel (sekarang 2 = app v2), dan tiap simpanan
  membawa `appVersion` (`lib/core/app_version.dart`, harus sama dengan `version` di pubspec — dijaga test; tidak
  tampil di Beranda v2).
- Simpanan app lama (skema 1, tanpa `appVersion`, skor per set) sengaja tidak dimuat: turnamen dari app lama tidak
  dimuat di app v2 (keputusan host 2026-10-22), format per set sudah dihapus dari kode. Payload beda versi atau rusak
  (app di-kill di tengah tulis) di-`decode` jadi `null`, bukan melempar — turnamennya saja yang hilang, app tetap bisa
  dibuka.
- Kunci simpanan opsional (simpanan lama tetap terbaca) dan kunci lama yang diabaikan ditulis bersama aturannya di
  `docs/architecture.md` (cari "kunci simpanan").
- `services/storage/tournament_store.dart` — box Hive `tournament` berisi 3 key: `active`, `lastFinished`, dan `live`
  (sesi live score, `docs/live.md`). `TournamentStore.memory()` dipakai test dan sebagai penyelamat kalau box gagal
  dibuka (disk penuh, browser mode private).

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
