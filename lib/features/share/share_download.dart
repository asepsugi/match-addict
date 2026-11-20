// Ekspor bersyarat: unduhan hanya ada di web; Android/iOS tidak menyimpan gambar (butuh izin/dependensi baru).
export 'share_download_stub.dart' if (dart.library.js_interop) 'share_download_web.dart';
