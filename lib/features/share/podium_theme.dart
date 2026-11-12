import 'package:flutter/material.dart';

import '../../core/theme/mabar_theme.dart';
import '../../models/models.dart';
import 'share_theme.dart';

/// Warna poster podium Ringkas (tokens.json → posterPodium): bawaan = lapangan yang ikut olahraga, atau salah satu
/// dari sepuluh gradien [ShareTheme] dengan turunan warna dari token (`gradientThemes`), dipakai apa adanya — bukan
/// diturunkan ulang dengan rumus. Blok #1 selalu emas ([goldFront], [goldTop], [goldSide], [goldNumber]).
class PodiumTheme {
  /// Latar: warna rata (lapangan) atau gradien 135° [ShareTheme] (kartu/gambar menghitung ukurannya sendiri).
  final Color? background;
  final ShareTheme? gradient;

  /// Lantai, garis lapangan, dan warna teks kepala (judul + baris kecil).
  final Color floor, line, headText;

  /// Blok #2/#3 dan angkanya.
  final Color blockFront, blockTop, blockSide, blockNumber;

  /// Panel nama: warna dasar (dipakai dengan [panelAlpha]), teks utama, teks kedua ("#", satuan, fakta), garis baris.
  final Color panel, panelText, panelText2, panelLine;

  const PodiumTheme._({
    this.background,
    this.gradient,
    required this.floor,
    required this.line,
    required this.headText,
    required this.blockFront,
    required this.blockTop,
    required this.blockSide,
    required this.blockNumber,
    required this.panel,
    required this.panelText,
    required this.panelText2,
    required this.panelLine,
  });

  /// Keputusan 67: panel 86%, lantai tembus 14%.
  static const panelAlpha = 0.86;

  /// `goldBlock` — sama di semua tema.
  static const goldFront = MabarColors.gold;
  static const goldTop = Color(0xFFF1D27C);
  static const goldSide = Color(0xFFB58A26);
  static const goldNumber = MabarColors.ink;

  static const _lineOnCourt = Color(0xB8FFFFFF); // putih 72%
  static const _panelInk = MabarColors.ink;
  static const _panelText2 = Color(0xFFB8C4CF);
  static const _courtBlockTop = Color(0xFF2B4257);
  static const _courtBlockSide = Color(0xFF08131D);

  /// `courtThemes`: padel lantai `padel`, tennis lantai `court`, latar `courtDeep`.
  factory PodiumTheme.court(SportType sport) => PodiumTheme._(
    background: MabarColors.courtDeep,
    floor: sport == SportType.padel ? MabarColors.padel : MabarColors.court,
    line: _lineOnCourt,
    headText: const Color(0xFFFFFFFF),
    blockFront: _panelInk,
    blockTop: _courtBlockTop,
    blockSide: _courtBlockSide,
    blockNumber: const Color(0xFFFFFFFF),
    panel: _panelInk,
    panelText: const Color(0xFFFFFFFF),
    panelText2: _panelText2,
    panelLine: const Color(0x29FFFFFF), // putih 16%
  );

  /// `gradientThemes`: gelap = lantai putih 10%, blok terang, panel `ink`; lembut = tinta tema.
  factory PodiumTheme.gradient(ShareTheme theme) {
    if (!theme.isLight) {
      return PodiumTheme._(
        gradient: theme,
        floor: const Color(0x1AFFFFFF),
        line: const Color(0x8CFFFFFF), // putih 55%
        headText: theme.ink,
        blockFront: const Color(0xFFE3E9EE),
        blockTop: const Color(0xFFFFFFFF),
        blockSide: const Color(0xFFA9B8CC),
        blockNumber: theme.start,
        panel: _panelInk,
        panelText: const Color(0xFFFFFFFF),
        panelText2: _panelText2,
        panelLine: const Color(0x29FFFFFF),
      );
    }
    final (top, side, light) = switch (theme) {
      ShareTheme.peach => (const Color(0xFF91664F), const Color(0xFF462616), const Color(0xFFFDE3D0)),
      ShareTheme.nude => (const Color(0xFF7B6B5C), const Color(0xFF33281D), const Color(0xFFF8EFE5)),
      ShareTheme.sage => (const Color(0xFF5E7063), const Color(0xFF1D2A21), const Color(0xFFEDF4EA)),
      _ => (const Color(0xFF6D6481), const Color(0xFF282239), const Color(0xFFF3EEFA)), // lilac
    };
    return PodiumTheme._(
      gradient: theme,
      floor: theme.ink.withValues(alpha: 0.13),
      line: theme.ink.withValues(alpha: 0.5),
      headText: theme.ink,
      blockFront: theme.ink,
      blockTop: top,
      blockSide: side,
      blockNumber: light,
      panel: theme.ink,
      panelText: light,
      panelText2: light,
      panelLine: light.withValues(alpha: 0.2),
    );
  }

  /// Latar seukuran [size] (gradien CSS 135° untuk kotak tidak persegi, sama dengan poster Lengkap).
  Paint backgroundPaint(Size size) {
    final paint = Paint();
    final g = gradient;
    if (g != null) {
      paint.shader = g.gradientFor(size).createShader(Offset.zero & size);
    } else {
      paint.color = background!;
    }
    return paint;
  }
}
