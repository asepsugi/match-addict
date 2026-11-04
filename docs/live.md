# Live score (2.5.0)

Pemilik: tech-lead (deploy relay: tech-infra). Baca kalau menyentuh `relay/`, `services/live/`, `features/live/`, atau
mode baca saja penonton. Keputusan host 2026-10-24 (frame 06c/06d/06i, 12a–12o; PRD §5.11; aturan rinci
`design/spec/logic.md` §11).

Host membagikan link `asepsugi.github.io/match-addict/#/live/KODE`; pemain lain melihat Jadwal, Klasemen, Detail di
browser, baca saja, Fixed dan Mixed. Preview link WhatsApp generik "Mabar": GitHub Pages statis, tidak bisa OG tag per
turnamen.

## Relay

- **Tanpa database**: `relay/src/index.js` (Cloudflare Worker + satu Durable Object per kode, paket gratis) hanya
  memegang salinan JSON `TournamentCodec` terakhir, terhapus 3 hari setelah kiriman terakhir. Kode relay JavaScript, di
  luar app Flutter.
- Deploy dari `relay/`: `npm install`, `npx wrangler login` (akun Cloudflare host), `npm run deploy`. URL produksi
  `https://mabar-live.mabar-live.workers.dev` (subdomain workers.dev akun = `mabar-live`) = `LiveRelay.url`
  (`lib/services/live/live_relay.dart`, bisa diganti `--dart-define=LIVE_RELAY=…`).
- Uji relay: `npm run dev` (port 8790; 8787 dipakai proses lain di Mac host) lalu `npm run smoke` (`relay/smoke.sh`;
  `BASE=<url produksi>` untuk hasil deploy). Relay tidak ikut `flutter test`/CI.

## App

- `services/live/live_relay.dart` — klien HTTP (`package:http`) + `LiveSession` (kode, token rahasia, `sentAt`). Sesi
  disimpan di box Hive yang sama, kunci `live` (`TournamentStore.loadLive/saveLive`). Token tidak pernah ikut isi.
- `features/live/live_host_controller.dart` — `liveHostProvider`, didengar `MabarApp` supaya hidup sepanjang app. Live
  = sesi milik turnamen aktif; setiap perubahan `tournamentProvider` dikirim utuh, satu kiriman sekaligus (perubahan
  selama itu dikirim sesudahnya), gagal → "Menunggu internet" + coba lagi 30 detik. "Selesai" tidak menghentikan live
  (resume dari Beranda melanjutkan kode yang sama); turnamen dibuang ("Hapus & mulai baru") → DELETE. Relay 404/403 →
  sesi dibuang.
- `features/live/live_view_controller.dart` — halaman penonton. `main()` membaca `#/live/KODE` (`LiveRelay.codeIn`);
  kalau ada, `liveCodeProvider` di-override dan `tournamentProvider` = `LiveTournamentController` (salinan relay), Hive
  penonton **tidak dibuka**. Layar memakai `ref.watch(liveCodeProvider) != null` sebagai tanda baca saja (Jadwal Fixed/
  Mixed tanpa ⋯/kembali/Isi skor/Batalkan/Buat, Klasemen tanpa Bagikan); jangan pakai `liveViewProvider` untuk itu
  karena ia berubah tiap pengecekan. Cek tiap 10 detik (1 menit setelah Final), berhenti saat halaman tidak terlihat
  (`AppLifecycleListener`), dua gagal → "Offline", 404 → "Live tidak ditemukan".
- `features/live/live_score.dart` — item menu, dialog mulai, `LiveScoreSheet`, `LiveTag`; `live_screen.dart` — rute
  `/live/:code`; `open_home*.dart` — "Buka Match Addict" memuat ulang web tanpa fragment (mode penonton dipasang sekali
  di `main()`; titik sentuh platformnya di `docs/infra.md`).
- Mixed: mengetuk tab round terakhir menyimpan `null`, jadi penonton yang mengikuti round terakhir ikut pindah saat
  round baru muncul. ⋯ Fixed setelah diakhiri tetap aktif (menunya berisi Live score).

## Test

`test/services/live_score_test.dart` (relay tiruan `FakeRelay` di atas `MockClient`; timer lewat `testWidgets`),
golden `test/hifi/screens/live_test.dart` (+ 12f/12i di `jadwal_fixed_test.dart`, fixture `live_fixture.dart`).
