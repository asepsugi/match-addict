# Task — Mexicano + Konfigurasi diringkas 3.4.0

Pemilik: tech-lead. Sumber: PRD §14 + keputusan 23–40 (§10), `design/spec/logic.md` §14 (aturan, data test, jebakan),
`design/spec/screens/03-konfigurasi.md`, `16-mexicano.md`, perubahan 13h–13j/14f–14g (`13-sparing.md`,
`14-sparing-fixed.md`), `components.md`. Daftar task Sparing 3.2.0 (SP-0…SP-19, selesai) ada di riwayat git:
`git show 8af509b:docs/tasks.md`.

Aturan untuk semua task:
- Kerja di branch `mexicano` (worktree per agen), **bukan** `main`: tiap push ke `main` = deploy. Rilis 3.4.0 = satu
  merge (MX-3) atas perintah host.
- Fixed, Mixed, dan Sparing tidak berubah: semua test dan golden yang ada tetap lolos tanpa diubah, **kecuali** golden
  Konfigurasi yang frame-nya digambar ulang di ec1943c: 03a–03q, 13h–13j, 14f–14g, dan golden komponen
  `test/hifi/components/config_test.dart`. Di branch ini sekarang 13 golden itu merah (dicek 2026-11-11); KF-1 yang
  menghijaukannya.
- Logika hanya di `lib/services/**` / model, dengan test; widget tidak menghitung urutan, susunan, format, atau
  estimasi. Jebakan yang wajib dibaca sebelum mulai: `logic.md` §14.7.
- Nama test memakai ID AC PRD (`AC-M4 …`) dan id frame golden. Konfigurasi tidak punya AC di PRD selain AC-M1–M3:
  pakai id frame + nomor keputusan (`03q keputusan 38 …`).
- Golden: data persis frame, `clockProvider` di-override; teks kecil yang lolos toleransi 2% walau salah (angka
  estimasi, "menit", nama mode) dicek juga dengan `find.text`.
- Engineer dan reviewer hanya menjalankan test yang disentuh perubahannya; `flutter test` penuh sekali per merge di
  main session. Paling banyak 3 agen paralel.
- Kategori semua task: MINOR (bagian dari 3.4.0); versi dinaikkan di MX-3 saja.

## Peta urutan

| Gelombang | Task (paralel di dalam gelombang) | Agen |
|---|---|---|
| 1 | MX-0 (dba), MX-1 (fondasi, kuat), KF-1 bagian 1 (Konfigurasi tanpa Mexicano) | 3 |
| 2 | setelah MX-1 di-merge: MX-2 (layar Mexicano), KF-1 bagian 2 (kartu Mexicano, 03c/03e/03q) | 2 |
| 3 | MX-3 rilis (main session + QA) | 1 |

Urutan merge: MX-0 (kapan saja, sebelum review MX-1) → MX-1 → KF-1 dan MX-2 bebas urutannya → MX-3.

Bentrok berkas yang diketahui:
- MX-1 ↔ KF-1: `tournament_controller.dart` (MX-1: `startIfNeeded` membuat R1 untuk `isEndless`, `generateNextRound`,
  `resume`, `reinstatePlayer`; KF-1: satu panggilan simpan pengaturan di `startIfNeeded` setelah state dibuat) dan
  `models.dart` (KF-1 **tidak** mengubahnya; `PartnerMode.mexicano` dan `ScoreFormat.forMexicano` dari MX-1). KF-1
  rebase setelah MX-1 di-merge.
- MX-1 ↔ MX-2: tidak ada berkas bersama. MX-2 baru mulai setelah MX-1 di-merge (butuh enum, `canReinstate`, generator
  untuk fixture).
- KF-1 ↔ MX-2: tidak ada berkas bersama (KF-1 di `features/konfigurasi/`, `services/storage/`; MX-2 di
  `features/schedule/`, `home/`, `share/`).

---

## MX-0 · Bentuk simpanan Mexicano + pengaturan terakhir (dba)
- **Goal:** memfinalkan draf `logic.md` §14.6 dan menuliskannya di `docs/data.md` (bagian baru "Mexicano (3.4.0)" +
  baris di tabel "Riwayat bentuk simpanan").
- **Baca:** `logic.md` §14.1, §14.5, §14.6; `docs/data.md` (Codec & store, Sparing → Risiko app lama);
  `lib/services/storage/tournament_codec.dart`, `tournament_store.dart`.
- **Ubah:** `docs/data.md`; koreksi `logic.md` §14.6 kalau ada keputusan yang berbeda.
- **Acceptance:** tertulis dengan bukti baris: versi ≤ 3.3.x menolak `mode: "mexicano"` (penonton → "Live tidak bisa
  dibuka", host → null dan simpanan tidak ditimpa sampai turnamen baru); `schemaVersion` tetap 2; aturan baca baru
  (mexicano + `clubs`, mexicano + bukan Americano → null); kunci pengaturan terakhir: nama kunci, bentuk JSON,
  validasi per field, kapan ditulis, perlakuan tak terbaca (default, tidak melempar), versi lama mengabaikannya.
- **Dependensi:** tidak ada. **Paralel:** dengan MX-1, KF-1 (keduanya mengikuti draf §14.6; kalau dba mengubah sesuatu,
  engineer menyesuaikan sebelum review). **Model:** dba, sonnet / medium. **Review:** main session membaca.

## MX-1 · Fondasi Mexicano: model, codec, generator, controller — kuat
- **Goal:** semua aturan `logic.md` §14.1–§14.3 dan aturan baca §14.6, dengan test data §14.4.
- **Baca:** `logic.md` §5, §10, §14; PRD 14.3–14.7; `models.dart` (`PartnerMode`, `ScoreFormat`, `ActiveTournament`
  dari `canWithdraw` sampai `copyWith`); `endless_round_generator.dart`; `ranking_calculator.dart` (`compare`,
  `_standings`); `tournament_codec.dart`; `tournament_controller.dart`; test `mixed_priority_test.dart`,
  `court_manage_test.dart` (pola fixture).
- **Ubah:** `lib/models/models.dart` (enum, `isEndless`, turunan 14.1, `forMexicano`, `canReinstate`, hapus
  `PartnerModeX.assetPath`), `lib/services/storage/tournament_codec.dart` (aturan baca + `canEncode`),
  `lib/services/schedule/endless_round_generator.dart` (`lockedDraw`, parameter `draw`, `generateMexicanoRound`,
  `mexicanoOrder`, `mexicanoArrangement`, cabang Mexicano di `courtMatch`), `lib/features/schedule/tournament_controller.dart`
  (`startIfNeeded`, `generateNextRound`, `resume`, `reinstatePlayer`; `addPlayer` tetap Mixed saja).
- **Test baru:** `test/services/mexicano_test.dart` (AC-M4–M7, M10, M12–M18, `forMexicano`, `lockedDraw` identik
  dengan undian `priorityOrder` lama, undian urutan Mexicano = undian prioritas), `mexicano_property_test.dart` (AC-M8,
  AC-M9; suite biasa, bukan `slow`), `mexicano_codec_test.dart` (AC-M20: fixture literal 3.3.x Fixed/Mixed/Sparing
  terbaca dan ter-encode byte-sama; round trip Mexicano dengan pemain keluar; tiap aturan baca → null; `mode: "zzz"` →
  null).
- **Acceptance:** AC-M4–M18 dan AC-M20 (bagian codec) di level service/controller; semua test lama lolos tanpa
  diubah (terutama `mixed_priority_test`, `court_manage_test`, `mixed_roster_test`, `sparing_*`); `flutter analyze`
  tanpa peringatan baru. Jalankan juga `flutter test --tags slow --run-skipped` sekali **hanya** kalau `priorityOrder`
  berubah di luar ekstraksi `lockedDraw` (sweep sparing memakainya).
- **Dependensi:** tidak ada (MX-0 paralel). **Model:** kuat, opus / medium (fondasi yang dipakai semua task).
- **Review:** tech-lead **fresh**, opus / high, dengan `logic.md` §14.7 sebagai daftar periksa. Re-review diff
  perbaikan: main session.

## KF-1 · Konfigurasi diringkas + pengaturan terakhir per olahraga
- **Goal:** keputusan 33, 35–38 dan AC-M1–M3: satu layar (Nama, Pasangan, baris Skor, baris Court) + sheet Skor dan
  Court, kartu tanpa deskripsi (3 kolom biasa, 2 kolom sparing), "menit" di baris Skor, pengaturan terakhir per
  olahraga (`logic.md` §14.5).
- **Baca:** `screens/03-konfigurasi.md` + frame 03a–03q; catatan 13h–13j, 14f–14g; `components.md` (`ModePicker`,
  `.modes.m3`, `MabarGroup / MabarRow`, `showMabarSheet`, `MabarStepper`); `logic.md` §14.5–§14.6;
  `konfigurasi_screen.dart`, `widgets/config_pickers.dart`, `tournament_store.dart`; golden yang ada
  `konfigurasi_test.dart`, `sparing_konfigurasi_test.dart`, `components/config_test.dart`.
- **Ubah:** `lib/features/konfigurasi/konfigurasi_screen.dart` (jadi `ConsumerStatefulWidget` untuk membaca store),
  `lib/features/konfigurasi/widgets/` (ModePicker + sheet Skor/Court, berkas baru boleh),
  `lib/services/storage/last_settings.dart` (baru: model + codec + `forSparing` + `fromConfig`, Dart murni),
  `lib/services/storage/tournament_store.dart` (load/save per olahraga), `tournament_controller.dart` (satu panggilan
  simpan di `startIfNeeded`). Golden: tulis ulang test frame 03a–03q, 13h–13j, 14f–14g, komponen `config_test.dart`.
- **Urutan di dalam task:** bagian 1 (paralel dengan MX-1): tata letak, sheet, teks baris, pengaturan terakhir untuk
  Fixed/Mixed, golden 03a, 03b, 03d, 03f–03p, 13h–13j, 14f–14g. Bagian 2 (setelah MX-1 di-merge, rebase): kartu
  Mexicano, `forMexicano`, sheet Skor Mexicano, tombol "Mulai Round 1" untuk `isEndless`, Sparing + simpanan Mexicano →
  Mixed, golden 03c, 03e, 03q.
- **Test baru:** `test/services/last_settings_test.dart` (data §14.5: 03q tersimpan dan terbaca, Tennis terpisah,
  Sparing → Mixed, nama turnamen tidak ikut, "Court n" → null, JSON rusak/di luar batas → default, id court baru);
  widget test AC-M1 (Race to 6 → Americano 21, Americano 24 tetap, kembali Mixed tetap Americano), AC-M2, AC-M3
  (estimasi Mexicano = Mixed untuk ukuran yang sama).
- **Acceptance:** semua golden di atas lolos; golden lain tidak berubah; `flutter analyze` tanpa peringatan baru.
- **Dependensi:** bagian 2 setelah MX-1. **Model:** sonnet / medium (layar + persistensi kecil).
- **Review:** layar = main session (diff + golden terkait). `last_settings.dart` + diff store/controller = tech-lead
  fresh kecil (opus / high, hanya berkas itu); boleh digabung dengan review MX-1 kalau siap bersamaan.

## MX-2 · Layar Mexicano: Jadwal, Cara kerja, Batalkan, Kelola pemain, Beranda/Bagikan
- **Goal:** frame 16a–16g; AC-M11 (daftar Istirahat di layar), AC-M16 (UI), AC-M19.
- **Baca:** `screens/16-mexicano.md` + frame 16a–16g; keputusan 39–40; Cakupan hi-fi baris "Baru: Mexicano" (frame
  Mixed yang berlaku apa adanya); `schedule_mixed_screen.dart`, `mixed/mixed_guide_sheet.dart`,
  `mixed/manage_players_sheet.dart`; `test/hifi/screens/jadwal_mixed_test.dart` + `kelola_lanjutkan_test.dart` (pola).
- **Ubah:** `lib/features/schedule/schedule_mixed_screen.dart` (menu "Cara kerja Mexicano", sheet muncul sekali saat
  R1, dialog Batalkan 16e dengan teks keputusan 40), `lib/features/schedule/mixed/mexicano_guide_sheet.dart` (baru,
  16c, estimasi = rumus Mixed yang sudah ada), `mixed/manage_players_sheet.dart` (Mexicano: tanpa kotak nama dan
  Tambah; Kembalikan hanya kalau `canReinstate`), `lib/features/home/home_screen.dart` (baris turnamen terakhir →
  Lanjutkan untuk `isEndless`), `lib/features/share/share_content.dart` (`shareRowNoun` "pemain" untuk `isEndless`).
  Fixture `test/hifi/screens/mexicano_fixture.dart` dibangun dengan `generateMexicanoRound` + undian disuntik
  (`logic.md` §14.4 14B + 16g), golden `test/hifi/screens/mexicano_test.dart`.
- **Acceptance:** golden 16a–16g lolos; `find.text`: Beranda "Padel · Mexicano · 8 pemain" dan Lanjutkan dari
  turnamen terakhir Mexicano, Detail "Padel · Mexicano · Americano 21", Bagikan "Padel · Mexicano · …", Klasemen default
  Total Point; 16g Kembalikan hilang setelah R3, muncul lagi setelah Batalkan R3; Kelola pemain Mexicano tanpa Tambah.
  Golden Mixed/Sparing tidak berubah.
- **Dependensi:** MX-1 di-merge. **Paralel:** dengan KF-1 bagian 2. **Model:** sonnet / medium.
- **Review:** main session (diff + golden terkait); tidak ada logika baru di sini.

## MX-3 · Rilis 3.4.0 (main session)
- **Goal:** `pubspec.yaml` 3.4.0+18, `appVersion` 3.4.0; docs: `CLAUDE.md` (status, riwayat versi, baris `docs/tasks.md`
  di Area docs), `docs/architecture.md` (hapus "spec — belum diimplementasi"), `logic.md` §14 status, `docs/ui-v2.md`
  (daftar golden), `docs/data.md` sudah oleh MX-0. PRD §5.3 dan header §14 ("Belum ada di hi-fi") diperbarui PM.
- **Acceptance:** `flutter analyze` tanpa peringatan baru; `flutter test` penuh lulus (semua golden 01–16); `slow`
  hanya kalau MX-1 mengubah `priorityOrder` di luar ekstraksi; `tool/build_web.sh` sukses + precache 200. QA (sonnet /
  medium): AC-M21 offline di Chrome; AC-M20 nyata — link live Mexicano dari build 3.4.0 dibuka di web produksi 3.3.2 →
  "Live tidak bisa dibuka". Merge `mexicano` → `main` hanya atas perintah host.
- **Security:** tidak perlu agen terpisah: tidak ada jalur input baru (pengaturan terakhir hanya Hive lokal, decode
  hanya menambah satu nilai enum dan dua aturan tolak); review MX-1 memeriksa decode.
- **Dependensi:** semua.
