import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/mabar_icons.dart';
import '../theme/mabar_theme.dart';

enum MatchScoreTone {
  /// Skor biasa (pemenang, seri).
  normal,

  /// `.s.l` — skor tim yang kalah.
  lost,

  /// Tambahan nilai WO di riwayat Detail ("+6"), tinta ketiga.
  credit,
}

/// Satu tim di [MatchScoreRow]: nama lengkap pemainnya (ditulis "Andi P · Budi S", [prefix] "vs " di riwayat
/// Detail), skor per kolom (satu angka; format lama per set), penanda menang, dan tag clay ("WO · Absen").
/// [onSwap] non-null = ikon tukar pemain (`.team .w.swap`) menggantikan titik bola; komponen tidak tahu aturannya.
class MatchScoreSide {
  final List<String> names;
  final String prefix;
  final List<String> scores;
  final MatchScoreTone tone;
  final bool win;
  final String? tag;
  final VoidCallback? onSwap;

  const MatchScoreSide({
    required this.names,
    this.prefix = '',
    this.scores = const [],
    this.tone = MatchScoreTone.normal,
    this.win = false,
    this.tag,
    this.onSwap,
  });
}

/// `.bug` — satu match gaya scorebug: strip court berwarna (atau label round di riwayat Detail), dua
/// tim, dan ujung kanan ([trailing]: tombol "Isi skor", atau catatan lewat [note]). Pemenang tebal
/// dengan titik bola; [cancelled] = tidak dimainkan (dicoret, strip abu). [compact] membuang tinggi
/// minimal 84 (riwayat Detail).
class MatchScoreRow extends StatelessWidget {
  final String badge;
  final Color badgeColor;

  /// 19 untuk nomor court, 14 untuk label round ("R5") di riwayat.
  final double badgeFontSize;

  /// 42 di Jadwal (muat kotak jam), 34 di riwayat Detail.
  final double badgeWidth;

  /// `.court.timed` — hitung mundur sisa booking court ("01:15") di kotak jam tinta 22% di dasar strip; hanya di
  /// round yang sedang berjalan.
  final String? countdown;
  final MatchScoreSide top;
  final MatchScoreSide bottom;
  final Widget? trailing;

  /// `.note-r` di kanan: "Seri", "Tidak dimainkan".
  final String? note;
  final bool cancelled;
  final bool compact;
  final VoidCallback? onTap;

  /// Latar baris; kartu putih, atau paper untuk pratinjau di dalam sheet (17b).
  final Color fill;

  const MatchScoreRow({
    super.key,
    required this.badge,
    required this.badgeColor,
    this.badgeFontSize = 19,
    this.badgeWidth = 34,
    this.countdown,
    required this.top,
    required this.bottom,
    this.trailing,
    this.note,
    this.cancelled = false,
    this.compact = false,
    this.onTap,
    this.fill = MabarColors.card,
  });

  /// Area ketuk ikon tukar per tim: 44 × 42 dari tepi strip court, separuh tinggi baris minimal (84).
  static const _swapTapWidth = 44.0, _swapTapHeight = 42.0;

  /// Tinta 22% di atas warna court: teks putih 13 pt ≥ 5:1 di kesepuluh warna (langsung di warna court, 4 warna
  /// gagal 4,5:1).
  static const _clockFill = Color(0x380F1E2C);

  Widget _clock(String text) => Container(
    height: 26,
    color: _clockFill,
    alignment: Alignment.center,
    child: Text(
      text,
      style: MabarType.numM.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final number = Text(
      badge,
      style: MabarType.numM.copyWith(fontSize: badgeFontSize, color: Colors.white, height: 1.4),
    );
    final end = trailing != null
        ? Padding(padding: const EdgeInsets.only(right: 12), child: trailing)
        : note != null
        ? Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text(note!, style: MabarType.caption),
          )
        : null;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 0 : 84),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: badgeWidth,
              color: cancelled ? MabarColors.off : badgeColor,
              alignment: Alignment.center,
              child: countdown == null
                  ? number
                  : Column(children: [Expanded(child: Center(child: number)), _clock(countdown!)]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_line(top), const SizedBox(height: 8), _line(bottom)],
                ),
              ),
            ),
            if (end != null) Center(child: end),
          ],
        ),
      ),
    );
    // Area ketuk tukar ditumpuk di atas baris: ketukan di sana tidak sampai ke InkWell, sisa baris tetap Input Skor.
    Widget swapArea(MatchScoreSide side, {required bool top}) => Positioned(
      left: badgeWidth,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      width: _swapTapWidth,
      height: _swapTapHeight,
      child: Semantics(
        button: true,
        label: 'Tukar pemain ${side.names.join(' · ')}',
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: side.onSwap),
      ),
    );
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(MabarRadius.group),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            row,
            if (top.onSwap != null) swapArea(top, top: true),
            if (bottom.onSwap != null) swapArea(bottom, top: false),
          ],
        ),
      ),
    );
  }

  /// Satu baris tim setinggi baris CSS (16 × 1,4 = 22,4). Mesin teks membulatkan tinggi baris ke 22, dan di
  /// riwayat Detail (tanpa tinggi minimal) selisihnya menumpuk 0,8 pt per baris.
  Widget _line(MatchScoreSide side) => SizedBox(height: 16 * 1.4, child: _team(side));

  /// `#A3AEB8` — skor yang kalah.
  static const _lostScore = Color(0xFFA3AEB8);

  Widget _team(MatchScoreSide side) {
    final name = MabarType.body.copyWith(
      color: cancelled ? MabarColors.faint : (side.win ? MabarColors.ink : MabarColors.ink2),
      fontWeight: side.win && !cancelled ? FontWeight.w700 : FontWeight.w400,
      decoration: cancelled ? TextDecoration.lineThrough : null,
      decorationColor: MabarColors.faint,
    );
    final items = <Widget>[
      if (side.onSwap != null)
        // `.w.swap`: kolom tetap 7 pt dan ikon berpusat di titik bola, jadi nama tidak bergeser.
        SizedBox(
          width: 7,
          height: 7,
          child: OverflowBox(
            maxWidth: 16,
            maxHeight: 16,
            child: ExcludeSemantics(child: Icon(MabarIcons.arrowsLeftRight, size: 16, color: MabarColors.court)),
          ),
        )
      else
        Container(
          width: 7,
          height: 7,
          decoration: side.win && !cancelled
              ? BoxDecoration(
                  color: MabarColors.ball,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x660F1E2C), strokeAlign: BorderSide.strokeAlignOutside),
                )
              : null,
        ),
      Expanded(child: _TeamNames(side, name)),
      if (side.scores.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < side.scores.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(
                width: 20,
                child: Text(
                  side.scores[i],
                  textAlign: TextAlign.right,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: MabarType.numM.copyWith(
                    height: 1,
                    color: switch (side.tone) {
                      MatchScoreTone.normal => MabarColors.ink,
                      MatchScoreTone.lost => _lostScore,
                      MatchScoreTone.credit => MabarColors.ink3,
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      if (side.tag != null)
        Text(
          side.tag!,
          style: MabarType.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 12 * 0.02,
            color: MabarColors.clay,
          ),
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 8), items[i]],
      ],
    );
  }
}

/// `.nm` / `.nm.split` (06u) — nama tim lengkap, selalu satu baris. Muat → satu teks. Tidak muat → tiap nama dipotong
/// elipsis sendiri: nama yang muat di bagian rata tetap utuh dan sisanya untuk nama yang lebih panjang, jadi "Lia Ibun"
/// dan "Lia Ncii" tetap terbedakan meski partnernya bernama panjang. Elipsis di ujung baris saja bisa menghilangkan
/// nama kedua seluruhnya.
class _TeamNames extends StatelessWidget {
  final MatchScoreSide side;
  final TextStyle style;

  const _TeamNames(this.side, this.style);

  static const _separator = ' · ';

  @override
  Widget build(BuildContext context) {
    final names = side.names;
    final full = '${side.prefix}${names.join(_separator)}';
    Text text(String value) => Text(value, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (names.length < 2) return text(full);

    return LayoutBuilder(
      builder: (context, constraints) {
        final measured = DefaultTextStyle.of(context).style.merge(style);
        final scaler = MediaQuery.textScalerOf(context);
        double width(String value) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: measured),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          final result = painter.width;
          painter.dispose();
          return result;
        }

        if (width(full) <= constraints.maxWidth) return text(full);
        final natural = [for (final n in names) width(n)];
        final widths = _fairWidths(
          natural,
          constraints.maxWidth - width(side.prefix) - (names.length - 1) * width(_separator),
        );
        return Row(
          children: [
            if (side.prefix.isNotEmpty) Text(side.prefix, style: style),
            for (var i = 0; i < names.length; i++) ...[
              if (i > 0) Text(_separator, style: style),
              // Nama yang utuh tidak dibungkus lebar hasil hitungan: pembulatan bisa memunculkan elipsis.
              if (widths[i] < natural[i]) SizedBox(width: widths[i], child: text(names[i])) else text(names[i]),
            ],
          ],
        );
      },
    );
  }

  /// Nama terpendek dulu: tiap nama dapat lebar aslinya atau bagian rata dari sisa [room], mana yang lebih kecil
  /// (`.keep` dan `flex: 1 1 0` di CSS).
  static List<double> _fairWidths(List<double> natural, double room) {
    final order = [for (var i = 0; i < natural.length; i++) i]..sort((a, b) => natural[a].compareTo(natural[b]));
    final widths = List.filled(natural.length, 0.0);
    var left = max(0.0, room);
    for (final (k, i) in order.indexed) {
      widths[i] = min(natural[i], left / (order.length - k));
      left -= widths[i];
    }
    return widths;
  }
}
