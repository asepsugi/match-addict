import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../models/models.dart';
import '../../../services/schedule/knockout_bracket.dart';

/// Isi tab "Bagan" Jadwal Grup + Gugur (`.bagan`, frame 21a, 21d, 21j, 21p, 21r, 21t, 21u, 21w–21y). Topologi, sisi
/// yang belum diketahui, dan kode slot dari [KnockoutBracket]; di sini hanya tata letak.
///
/// Kolom per babak (Final dan Juara 3 satu kolom): 2 babak = kolom 172, muat di body 358 tanpa digeser; 3 babak = kolom
/// 160 dan bagan digeser horizontal per kolom, kolom ketiga mengintip 10 pt (21u).
class BaganView extends StatefulWidget {
  final ActiveTournament active;

  /// Ketuk kartu yang bisa diisi → buka Input Skor (sama dengan baris di tab round). Null = baca saja (penonton live).
  final void Function(MatchGame match)? onOpenMatch;

  const BaganView({super.key, required this.active, this.onOpenMatch});

  @override
  State<BaganView> createState() => _BaganViewState();
}

/// Ukuran `.bagan` (hi-fi): kartu `.m` 116 (kepala 24 + dua baris 46), label kolom `.ch` 18 + 8 di atas kartu.
const _cardHeight = 116.0, _columnGap = 14.0, _firstTop = 26.0;

class _BaganViewState extends State<BaganView> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _BaganLayout.of(widget.active);
    if (layout == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final board = _board(layout);
          final overflow = layout.width - constraints.maxWidth;
          if (overflow <= 0) return Align(alignment: Alignment.topLeft, child: board);
          // Henti geser per kolom: tepi kiri tiap kolom, dibatasi ujung kanan (21x: Semifinal rata kiri = ujung kanan).
          final stops = {for (var c = 0; c < layout.columns; c++) (c * layout.step).clamp(0.0, overflow)}.toList()
            ..sort();
          // Posisi awal (21u, 21w, 21x): kolom babak pertama yang masih ada match kosong; semua terisi = ujung kanan.
          final column = layout.firstOpenColumn(widget.active);
          _scroll ??= ScrollController(
            initialScrollOffset: column == null ? overflow : (column * layout.step).clamp(0.0, overflow),
          );
          return Semantics(
            // Pembaca layar tidak bisa menggeser per kolom: sediakan loncat ke kolom terakhir (Final).
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Geser ke Final'): () => _scroll!.animateTo(
                overflow,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              ),
            },
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _scroll,
              physics: _ColumnSnap(stops),
              child: board,
            ),
          );
        },
      ),
    );
  }

  Widget _board(_BaganLayout layout) {
    final active = widget.active;
    final finished = active.tournament.isFinished;
    final current = active.currentRound;
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ExcludeSemantics(child: CustomPaint(painter: _LinesPainter(layout.lines)))),
          for (final h in layout.headers)
            Positioned(
              left: h.left,
              top: h.top,
              width: layout.columnWidth - 12,
              height: 18,
              child: _ColumnHeader(babak: h.babak, format: h.format),
            ),
          for (final card in layout.cards)
            Positioned(
              left: card.left,
              top: card.top,
              width: layout.columnWidth,
              height: _cardHeight,
              child: _BaganCard(
                active: active,
                match: card.match,
                // Titik bola = match di round berjalan yang belum ada skor (makna sama dengan titik di tab round).
                live: !finished && card.match.roundNumber == current && card.match.status == MatchStatus.pending,
                // Bisa diisi = aturan yang sama dengan baris di tab round (`canOpenScore`).
                onTap: widget.onOpenMatch == null || !active.canOpenScore(card.match)
                    ? null
                    : () => widget.onOpenMatch!(card.match),
              ),
            ),
        ],
      ),
    );
  }
}

typedef _Card = ({MatchGame match, double left, double top});
typedef _Header = ({String babak, String format, double left, double top});
typedef _Line = ({Offset from, double midX, Offset to, bool on});

/// Posisi kartu, label, dan garis bagan. Tengah kartu babak berikutnya = tengah dua kartu asalnya (pemenang); Juara 3
/// di bawah Final di kolom terakhir tanpa garis (yang masuk = yang kalah).
class _BaganLayout {
  final int columns;
  final double columnWidth;
  final List<_Card> cards;
  final List<_Header> headers;
  final List<_Line> lines;
  final double height;

  /// Babak per kolom, kiri ke kanan (Final mewakili kolom terakhir).
  final List<KnockoutRound> babak;

  const _BaganLayout({
    required this.columns,
    required this.columnWidth,
    required this.cards,
    required this.headers,
    required this.lines,
    required this.height,
    required this.babak,
  });

  double get step => columnWidth + _columnGap;
  double get width => columns * columnWidth + (columns - 1) * _columnGap;

  /// Kolom babak pertama yang masih ada match kosong (Juara 3 ikut kolom Final); null = semua terisi/diakhiri.
  int? firstOpenColumn(ActiveTournament active) {
    for (final (c, round) in babak.indexed) {
      final open = active.matches.any((m) {
        final p = m.phase;
        if (p is! KnockoutPhase || m.status != MatchStatus.pending) return false;
        return p.round == round || (round == KnockoutRound.finalRound && p.round == KnockoutRound.thirdPlace);
      });
      if (open) return c;
    }
    return null;
  }

  static _BaganLayout? of(ActiveTournament active) {
    final gk = active.config.groupKnockout;
    if (gk == null) return null;
    final byPhase = <KnockoutPhase, MatchGame>{
      for (final m in active.matches)
        if (m.phase case final KnockoutPhase p) p: m,
    };
    if (byPhase.isEmpty) return null;

    final four = gk.groupCount == 4;
    final babak = [if (four) KnockoutRound.quarterfinal, KnockoutRound.semifinal, KnockoutRound.finalRound];
    final columnWidth = babak.length <= 2 ? 172.0 : 160.0;
    final step = columnWidth + _columnGap;
    int columnOf(KnockoutRound r) => r == KnockoutRound.thirdPlace ? babak.length - 1 : babak.indexOf(r);

    final top = <KnockoutPhase, double>{};
    double center(KnockoutPhase p) => top[p]! + _cardHeight / 2;
    final phases = KnockoutBracket.phases(groupCount: gk.groupCount, thirdPlace: gk.thirdPlace);
    // Babak pertama: kartu bertumpuk (hi-fi: jarak 60 untuk dua SF, 12 untuk empat PF).
    final firstStep = four ? 128.0 : 176.0;
    final lines = <_Line>[];
    for (final p in phases) {
      if (p.round == babak.first) {
        top[p] = _firstTop + (p.slot - 1) * firstStep;
        continue;
      }
      if (p.round == KnockoutRound.thirdPlace) continue;
      final (s1, s2) = KnockoutBracket.sources(p, groupCount: gk.groupCount);
      final from = [
        for (final s in [s1, s2])
          if (s case ResultSource(:final match, winner: true) when top.containsKey(match)) match,
      ];
      if (from.length != 2) continue;
      top[p] = (center(from[0]) + center(from[1])) / 2 - _cardHeight / 2;
      final x = columnOf(p.round) * step;
      for (final src in from) {
        lines.add((
          from: Offset(x - _columnGap, center(src)),
          midX: x - _columnGap / 2,
          to: Offset(x, center(p)),
          // Tinta begitu match asal punya pemenang, abu-abu selama belum.
          on: byPhase[src]?.winnerPairId != null,
        ));
      }
    }
    const finalPhase = KnockoutPhase(KnockoutRound.finalRound, 1);
    const thirdPhase = KnockoutPhase(KnockoutRound.thirdPlace, 1);
    // Label Juara 3 (hi-fi): 2 grup di 340 (di bawah SF2), 4 grup 30 pt di bawah kartu Final.
    final thirdLabelTop = four ? top[finalPhase]! + _cardHeight + 30 : 340.0;
    if (gk.thirdPlace) top[thirdPhase] = thirdLabelTop + _firstTop;

    final cards = <_Card>[
      for (final p in phases)
        if (byPhase[p] case final m? when top.containsKey(p)) (match: m, left: columnOf(p.round) * step, top: top[p]!),
    ];
    String formatOf(KnockoutRound r) {
      final m = byPhase.entries.where((e) => e.key.round == r).firstOrNull?.value;
      return m == null ? '' : active.config.formatFor(m).label;
    }

    final headers = <_Header>[
      for (final (c, r) in babak.indexed) (babak: r.shortLabel, format: formatOf(r), left: c * step, top: 0.0),
      if (gk.thirdPlace)
        (
          babak: KnockoutRound.thirdPlace.shortLabel,
          format: formatOf(KnockoutRound.thirdPlace),
          left: (babak.length - 1) * step,
          top: thirdLabelTop,
        ),
    ];
    final height = cards.fold(0.0, (h, c) => c.top + _cardHeight > h ? c.top + _cardHeight : h);
    return _BaganLayout(
      columns: babak.length,
      columnWidth: columnWidth,
      cards: cards,
      headers: headers,
      lines: lines,
      height: height,
      babak: babak,
    );
  }
}

/// `.bagan .lines`: garis penghubung 1,5 pt di tengah jarak kolom, urut seperti di hi-fi (yang belakangan di atas).
class _LinesPainter extends CustomPainter {
  final List<_Line> lines;
  const _LinesPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = l.on ? MabarColors.ink : MabarColors.off;
      final path = Path()
        ..moveTo(l.from.dx, l.from.dy)
        ..lineTo(l.midX, l.from.dy)
        ..lineTo(l.midX, l.to.dy)
        ..lineTo(l.to.dx, l.to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter oldDelegate) => oldDelegate.lines != lines;
}

/// `.bagan .ch` — nama babak tinta + format tinta-3, menjorok 12 pt.
class _ColumnHeader extends StatelessWidget {
  final String babak;
  final String format;
  const _ColumnHeader({required this.babak, required this.format});

  static const _style = TextStyle(
    fontFamily: MabarType.family,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wdth', 90)],
    color: MabarColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12),
    child: Text.rich(
      TextSpan(
        text: '$babak ',
        children: [
          TextSpan(
            text: '· $format',
            style: _style.copyWith(fontWeight: FontWeight.w500, color: MabarColors.ink3),
          ),
        ],
      ),
      style: _style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    ),
  );
}

/// `.bagan .m` — kartu satu match: kepala (kode · round · court; Final dan Juara 3 tanpa kode), dua baris tim dengan
/// kode slot, nama dua pemain bertumpuk, dan skor/WO. `.m.off` = diakhiri, "Tidak dimainkan".
class _BaganCard extends StatelessWidget {
  final ActiveTournament active;
  final MatchGame match;
  final bool live;
  final VoidCallback? onTap;

  const _BaganCard({required this.active, required this.match, required this.live, this.onTap});

  static const _head = TextStyle(
    fontFamily: MabarType.family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: MabarColors.ink3,
    leadingDistribution: TextLeadingDistribution.even,
  );

  @override
  Widget build(BuildContext context) {
    final phase = match.phase! as KnockoutPhase;
    final (s1, s2) = KnockoutBracket.sourcesOf(active.config, match)!;
    final off = match.status == MatchStatus.cancelled;
    final code = phase.round.codePrefix == null ? null : KnockoutBracket.code(phase);
    final court = active.config.courts.indexWhere((c) => c.id == match.courtId) + 1;
    final info = off ? 'Tidak dimainkan' : 'R${match.roundNumber} · Court $court';
    final head = SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 10),
        child: Row(
          children: [
            if (code != null) ...[
              Text(
                code,
                style: _head.copyWith(fontWeight: FontWeight.w800, color: MabarColors.ink),
              ),
              const SizedBox(width: 6),
            ],
            if (live) ...[const LiveDot(), const SizedBox(width: 6)],
            Expanded(
              child: Text(
                info,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: code == null ? TextAlign.left : TextAlign.right,
                style: _head,
              ),
            ),
          ],
        ),
      ),
    );
    final locked = match.pair1.isTbd || match.pair2.isTbd;
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: !locked,
      label: _label(code, court, off, s1, s2),
      excludeSemantics: true,
      child: Material(
        color: MabarColors.card,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              head,
              _team(match.pair1, s1, match.pair1TotalGames, off),
              _team(match.pair2, s2, match.pair2TotalGames, off),
            ],
          ),
        ),
      ),
    );
  }

  /// "SF1, Round 7, Court 1. A1 Andi dan Budi 6, menang. B2 Maya dan Nanda 4"; sisi kosong: "Pemenang SF1, belum ada".
  String _label(String? code, int court, bool off, SideSource s1, SideSource s2) {
    final head = [if (code != null) code, 'Round ${match.roundNumber}', 'Court $court'].join(', ');
    String side(Pair pair, SideSource source, int games) {
      if (pair.isTbd) return '${KnockoutBracket.sourceLabel(source)}, belum ada';
      final seed = KnockoutBracket.seedOf(active, pair.id);
      final names = [for (final id in pair.playerIds) active.playerName(id)].join(' dan ');
      final wo = match.status == MatchStatus.wo && match.woLoserPairId == pair.id;
      final text = '${seed == null ? '' : '$seed '}$names'
          '${match.status == MatchStatus.done ? ' $games' : ''}${wo ? ' WO' : ''}';
      return match.winnerPairId == pair.id ? '$text, menang' : text;
    }

    return [
      head,
      if (off) 'tidak dimainkan',
      side(match.pair1, s1, match.pair1TotalGames),
      side(match.pair2, s2, match.pair2TotalGames),
    ].join('. ');
  }

  /// `.bagan .t` — satu sisi: `.win` garis bola + nama tebal, `.tbd` asal sisi ("Pemenang SF1") tanpa kode slot.
  Widget _team(Pair pair, SideSource source, int games, bool off) {
    final tbd = pair.isTbd;
    final winner = match.winnerPairId;
    final win = !tbd && winner == pair.id;
    final wo = match.status == MatchStatus.wo && match.woLoserPairId == pair.id;
    final names = tbd
        ? [KnockoutBracket.sourceLabel(source)]
        : [for (final id in pair.playerIds) active.playerName(id)];
    final nameStyle = TextStyle(
      fontFamily: MabarType.family,
      fontSize: 14,
      height: 18 / 14,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: win && !off ? FontWeight.w700 : FontWeight.w500,
      // `.m:has(.t.win) .t:not(.win) .nm`: nama yang kalah ink-3 (C-16).
      color: off || tbd || (winner != null && !win) ? MabarColors.ink3 : (win ? MabarColors.ink : MabarColors.ink2),
      decoration: off ? TextDecoration.lineThrough : null,
      decorationColor: MabarColors.ink3,
    );
    final score = match.status == MatchStatus.done
        ? Text(
            '$games',
            textAlign: TextAlign.right,
            style: MabarType.numM.copyWith(fontSize: 20, height: 1, color: win ? MabarColors.ink : MabarColors.ink3),
          )
        : wo
        ? Text(
            'WO',
            textAlign: TextAlign.right,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: MabarType.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: 12 * 0.02,
              color: MabarColors.clay,
            ),
          )
        : null;
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MabarColors.line)),
      ),
      child: Stack(
        children: [
          if (win)
            // `.t.win::before`: 3 pt bola dengan tepi kanan 1 pt ball-edge.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: MabarColors.ball,
                  // `box-shadow: inset -1px 0 0 var(--ink)`: bertepi tinta supaya beda dari yang kalah tanpa warna (C-16).
                  border: Border(right: BorderSide(color: MabarColors.ink)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 10),
            child: Row(
              children: [
                if (!tbd) ...[
                  SizedBox(
                    width: 20,
                    child: Text(
                      KnockoutBracket.seedOf(active, pair.id) ?? '',
                      maxLines: 1,
                      softWrap: false,
                      style: MabarType.numM.copyWith(fontSize: 13, height: 1.4, color: MabarColors.ink3),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final n in names)
                        Text(n, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: nameStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: score == null ? null : Align(alignment: Alignment.centerRight, child: score),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Geser berhenti per kolom (21u–21x): lemparan ke kolom berikut/sebelumnya, lepas pelan ke kolom terdekat.
class _ColumnSnap extends ScrollPhysics {
  final List<double> stops;
  const _ColumnSnap(this.stops, {super.parent});

  @override
  _ColumnSnap applyTo(ScrollPhysics? ancestor) => _ColumnSnap(stops, parent: buildParent(ancestor));

  double _target(double pixels, double velocity, Tolerance tolerance) {
    if (velocity > tolerance.velocity) {
      return stops.firstWhere((s) => s > pixels + tolerance.distance, orElse: () => stops.last);
    }
    if (velocity < -tolerance.velocity) {
      return stops.lastWhere((s) => s < pixels - tolerance.distance, orElse: () => stops.first);
    }
    return stops.reduce((a, b) => (a - pixels).abs() <= (b - pixels).abs() ? a : b);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _target(position.pixels, velocity, tolerance);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}
