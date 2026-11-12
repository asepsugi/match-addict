import 'package:flutter/material.dart';

import '../../core/theme/mabar_theme.dart';

/// Sepuluh tema latar kartu/poster Bagikan (tokens.json → posterThemes); default biru. Semua warna teks,
/// garis, piala, dan watermark diturunkan dari [ink] — jangan menaruh `Colors.white` langsung di poster.
enum ShareTheme {
  // Gelap — tinta putih.
  hijau(Color(0xFF14532D), Color(0xFF15803D)),
  biru(Color(0xFF172554), Color(0xFF2563EB)),
  ungu(Color(0xFF3B0764), Color(0xFF9333EA)),
  jingga(Color(0xFF7C2D12), Color(0xFFC2410C)),
  teal(Color(0xFF042F2E), Color(0xFF0F766E)),
  malam(Color(0xFF0B1220), Color(0xFF334155)),

  // Lembut — tintanya gelap supaya tetap terbaca.
  peach(Color(0xFFF6BE9C), Color(0xFFFDE3D0), ink: Color(0xFF6B3A22)),
  nude(Color(0xFFE2CDB6), Color(0xFFF8EFE5), ink: Color(0xFF4F3D2C)),
  sage(Color(0xFFBFD4C1), Color(0xFFEDF4EA), ink: Color(0xFF2C4133)),
  lilac(Color(0xFFD3C7EA), Color(0xFFF3EEFA), ink: Color(0xFF3E3457));

  /// Warna kiri-atas dan kanan-bawah gradien.
  final Color start;
  final Color end;

  /// Warna teks/garis di atas gradien ini.
  final Color ink;

  const ShareTheme(this.start, this.end, {this.ink = Colors.white});

  LinearGradient get gradient =>
      LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// `linear-gradient(135deg, …)` untuk kotak [size]. Di CSS sudutnya tetap 135° dan panjang garisnya
  /// menjangkau kedua pojok, jadi untuk kotak tidak persegi titik awal/akhirnya bukan pojok persis
  /// (berbeda dengan [gradient]).
  LinearGradient gradientFor(Size size) {
    final x = (size.width + size.height) / (2 * size.width), y = (size.width + size.height) / (2 * size.height);
    return LinearGradient(colors: [start, end], begin: Alignment(-x, -y), end: Alignment(x, y));
  }

  Color inkAlpha(double alpha) => ink.withValues(alpha: alpha);

  /// Garis pemisah & watermark: tipis di tema gelap, sedikit lebih tegas di
  /// tema lembut supaya tidak hilang di latar terang.
  bool get isLight => ink != Colors.white;

  Color get divider => inkAlpha(isLight ? 0.22 : 0.15);

  /// Piala: bola di tema gelap, tinta tema di tema lembut (bola hilang di latar terang).
  Color get trophy => isLight ? ink : MabarColors.ball;
  Color get watermark => inkAlpha(isLight ? 0.22 : 0.18);
}
