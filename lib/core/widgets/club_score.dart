import 'package:flutter/material.dart';

import '../theme/mabar_theme.dart';

/// Satu baris klub di [ClubScore]. Semua teks sudah jadi: widget tidak menghitung skor, selisih, maupun
/// siapa yang unggul (itu tugas service skor klub).
class ClubScoreRow {
  const ClubScoreRow({required this.name, required this.detail, required this.score, required this.lead});

  final String name;

  /// Total Point klub · selisih + satuan, mis. "56 game · +13" atau "50 game · 0".
  final String detail;

  /// Match menang, dengan "½" untuk match seri, mis. "7" atau "6½".
  final String score;

  /// Klub yang unggul memegang bola; Seri = bola di kedua baris.
  final bool lead;
}

/// `.clubscore`: papan tinta skor klub Sparing, satu baris per klub. [first] (klub pertama) selalu di atas,
/// sama dengan baris atas setiap match, jadi papan ini sekaligus penanda sisi klub di Jadwal.
class ClubScore extends StatelessWidget {
  const ClubScore({super.key, required this.first, required this.second});

  final ClubScoreRow first;
  final ClubScoreRow second;

  /// `.w`: dipakai test untuk menghitung bola.
  static const ballKey = ValueKey('club-score-ball');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: MabarSpacing.x4),
      decoration: BoxDecoration(color: MabarColors.ink, borderRadius: BorderRadius.circular(MabarRadius.group)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Line(row: first, height: 40),
          // `.cs + .cs`: garis putih 10% di antara dua baris. Di CSS `border-top: 1px` ada di dalam
          // `height: 40px` (border-box), jadi isi baris kedua 39 supaya total tetap 2 + 40 + 40 + 2 = 84.
          Container(height: 1, color: const Color(0x1AFFFFFF)),
          _Line(row: second, height: 39),
        ],
      ),
    );
  }
}

/// `.cs`: grid bola 10 · nama · detail · skor 44, tinggi 40.
class _Line extends StatelessWidget {
  const _Line({required this.row, required this.height});

  final ClubScoreRow row;
  final double height;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 10);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          // `.w`: bola hanya di klub yang unggul, ruangnya tetap supaya nama sejajar.
          SizedBox(
            width: 10,
            height: 10,
            child: row.lead
                ? const DecoratedBox(
                    key: ClubScore.ballKey,
                    decoration: BoxDecoration(color: MabarColors.ball, shape: BoxShape.circle),
                  )
                : null,
          ),
          gap,
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MabarType.body.copyWith(
                fontSize: 17, // .nm 17px
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          gap,
          Text(
            row.detail,
            maxLines: 1,
            // Putih 66%: 7,9:1 di atas tinta.
            style: MabarType.caption.copyWith(
              color: const Color(0xA8FFFFFF), // .tp rgba(255,255,255,.66)
              fontFeatures: MabarType.tabular,
            ),
          ),
          gap,
          SizedBox(
            width: 44,
            child: Text(
              row.score,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: MabarType.family,
                leadingDistribution: TextLeadingDistribution.even,
                fontSize: 30, // .sc 30px
                fontWeight: FontWeight.w800,
                fontVariations: MabarType.numVariations,
                fontFeatures: MabarType.tabular,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
