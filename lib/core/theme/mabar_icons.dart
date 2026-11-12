import 'package:flutter/widgets.dart';

/// Ikon Phosphor Bold (MIT) yang dipakai hi-fi v2 (Fondasi → Ikon). Nama = nama asli di Phosphor,
/// kebab-case jadi camelCase, supaya bisa dicari di phosphoricons.com.
///
/// Fontnya `assets/fonts/Phosphor-Bold.ttf` dari `@phosphor-icons/web@2.1.1` (versi yang sama dengan
/// SVG di hi-fi), bukan paket `phosphor_flutter`: paket itu tidak dirawat sejak 2024 dan tidak bisa
/// dikompilasi lagi karena `IconData` sekarang `final class`. Codepoint diambil dari `style.css` paket
/// yang sama. Release build memangkas font ini sampai tinggal glyph yang dipakai (tree-shake icons),
/// jadi semua ikon harus lewat konstanta di sini.
///
/// Ukuran: 24 pt mandiri (`MabarSize.icon`), 20 pt di dalam tombol berlabel; warna mengikuti teks di
/// sebelahnya. Ikon tanpa label (kembali, menu, Peringkat, Pemain) wajib punya label aksesibilitas.
class MabarIcons {
  static const _family = 'PhosphorBold';

  /// `caret-left` — Kembali.
  static const caretLeft = IconData(0xe138, fontFamily: _family);

  /// `caret-right` — Baris yang bisa dibuka.
  static const caretRight = IconData(0xe13a, fontFamily: _family);

  /// `dots-three` — Menu Jadwal.
  static const dotsThree = IconData(0xe1fe, fontFamily: _family);

  /// `ranking` — Peringkat.
  static const ranking = IconData(0xed62, fontFamily: _family);

  /// `users` — Pemain (Mixed).
  static const users = IconData(0xe4d6, fontFamily: _family);

  /// `share-network` — Bagikan.
  static const shareNetwork = IconData(0xe408, fontFamily: _family);

  /// `user` — Ilustrasi mode Fixed & Mixed (40 pt).
  static const user = IconData(0xe4c2, fontFamily: _family);

  /// `equals` — Ilustrasi Fixed: pasangan tetap.
  static const equals = IconData(0xe21c, fontFamily: _family);

  /// `shuffle` — Ilustrasi Mixed: pasangan berganti.
  static const shuffle = IconData(0xe422, fontFamily: _family);

  /// `plus` — Buat Rn, stepper.
  static const plus = IconData(0xe3d4, fontFamily: _family);

  /// `minus` — Stepper.
  static const minus = IconData(0xe32a, fontFamily: _family);

  /// `check` — Simpan skor, aturan fairness, warna terpilih.
  static const check = IconData(0xe182, fontFamily: _family);

  /// `lock-simple` — Buat jadwal, round terkunci.
  static const lockSimple = IconData(0xe308, fontFamily: _family);

  /// `play` — Lanjutkan turnamen (sheet).
  static const play = IconData(0xe3d0, fontFamily: _family);

  /// `clock` — Tambah jam, Lanjutkan turnamen.
  static const clock = IconData(0xe19a, fontFamily: _family);

  /// `arrow-counter-clockwise` — Batalkan Rn, Urungkan.
  static const arrowCounterClockwise = IconData(0xe038, fontFamily: _family);

  /// `arrow-clockwise` — Acak ulang.
  static const arrowClockwise = IconData(0xe036, fontFamily: _family);

  /// `flag` — Akhiri turnamen.
  static const flag = IconData(0xe244, fontFamily: _family);

  /// `info` — Cara kerja Mixed.
  static const info = IconData(0xe2ce, fontFamily: _family);

  /// `clipboard-text` — Tempel nama.
  static const clipboardText = IconData(0xe198, fontFamily: _family);

  /// `user-list` — Isi nama contoh.
  static const userList = IconData(0xe73c, fontFamily: _family);

  /// `trash` — Hapus semua nama.
  static const trash = IconData(0xe4a6, fontFamily: _family);

  /// `backspace` — Keypad: hapus.
  static const backspace = IconData(0xe0ae, fontFamily: _family);

  /// `arrow-right` — Keypad: kotak berikutnya.
  static const arrowRight = IconData(0xe06c, fontFamily: _family);

  /// `house` — Selesai (ke Beranda).
  static const house = IconData(0xe2c2, fontFamily: _family);

  /// `image` — Menyiapkan gambar.
  static const image = IconData(0xe2ca, fontFamily: _family);

  /// `trophy` — Judul poster Bagikan.
  static const trophy = IconData(0xe67e, fontFamily: _family);

  /// `clock-counter-clockwise` — Turnamen terakhir.
  static const clockCounterClockwise = IconData(0xe1a0, fontFamily: _family);

  /// `device-mobile` — Pasang Mabar di HP.
  static const deviceMobile = IconData(0xe1e0, fontFamily: _family);

  /// `export` — Panduan iPhone: Bagikan.
  static const export = IconData(0xeaf0, fontFamily: _family);

  /// `plus-square` — Panduan iPhone: Tambah ke Layar Utama.
  static const plusSquare = IconData(0xed4a, fontFamily: _family);

  /// `square-split-horizontal` — Kelola court (menu ⋯ Mixed): lapangan dengan net.
  static const squareSplitHorizontal = IconData(0xe870, fontFamily: _family);

  /// `broadcast` — Live score (menu ⋯ Jadwal).
  static const broadcast = IconData(0xe0f2, fontFamily: _family);

  /// `link` — link live di sheet Live score.
  static const link = IconData(0xe2e2, fontFamily: _family);

  /// `arrows-left-right` — Tukar pemain (baris match Mixed).
  static const arrowsLeftRight = IconData(0xe0a0, fontFamily: _family);

  /// `wifi-slash` — toast "Tidak ada internet".
  static const wifiSlash = IconData(0xe4f2, fontFamily: _family);
}
