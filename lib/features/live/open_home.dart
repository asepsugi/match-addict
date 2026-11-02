// "Buka Match Addict" di halaman live yang tidak ditemukan (12n): memuat ulang web tanpa `#/live/…`, karena mode
// penonton dipasang sekali di `main()` dan Beranda butuh simpanan turnamen penonton sendiri. Halaman live hanya
// ada di web, jadi stub native tidak melakukan apa-apa.
export 'open_home_stub.dart' if (dart.library.js_interop) 'open_home_web.dart';
