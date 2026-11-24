import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../core/widgets/pair_name.dart';
import '../../../models/models.dart';
import '../../../services/schedule/knockout_bracket.dart';
import '../tournament_controller.dart';

/// Isi tab "Bagan" Jadwal Group - Playoff (`.bagan`, frame 21a–21y, 23h, 23i, 23s–23w; keputusan 153–154). Topologi,
/// sisi yang belum diketahui, kode slot, kolom awal, dan warna alur dari [KnockoutBracket]; di sini hanya tata letak.
///
/// Satu kolom babak 270 pt terlihat penuh, kolom berikutnya mengintip 76 pt; geser berhenti per kolom (kolom pertama
/// rata kiri, kolom tengah di tengah layar, kolom terakhir rata kanan). Sebelum Buat bagan isinya pratinjau slot kode
/// ([bracketPreviewProvider], 23s–23u): kartu tidak bisa diketuk, label kolom tetap bisa.
class BaganView extends ConsumerStatefulWidget {
  final ActiveTournament active;

  /// Ketuk kartu yang bisa diisi → buka Input Skor (sama dengan baris di tab round). Null = baca saja (penonton live).
  final void Function(MatchGame match)? onOpenMatch;

  /// Ketuk label kolom → sheet format babak (23o, milik pemanggil). Juara 3 = [KnockoutRound.thirdPlace]. Null = label
  /// tidak bisa diketuk.
  final void Function(KnockoutRound round)? onOpenRound;

  const BaganView({super.key, required this.active, this.onOpenMatch, this.onOpenRound});

  @override
  ConsumerState<BaganView> createState() => _BaganViewState();
}

/// Ukuran `.bagan` (hi-fi): kolom `.m` 270, jarak kolom 28, viewport selebar layar dengan isi menjorok 16; kartu 104 =
/// kepala 24 + dua baris 40; kartu pertama 28 di bawah label kolom.
const _columnWidth = 270.0, _columnGap = 28.0, _inset = 16.0;
const _cardHeight = 104.0, _headHeight = 24.0, _rowHeight = 40.0, _firstTop = 28.0;

/// Palet warna alur = warna court indeks 1, 4, 2, 6 (keputusan 154), per indeks match babak pertama.
final _flowColors = [
  for (final i in const [1, 4, 2, 6]) MabarColors.courtPalette[i],
];

/// `.k0`: sisi bagan yang belum membawa warna alur (garis dan tepi baris abu-abu).
const _noFlow = MabarColors.off;

Color? _flowColor(int? index) => index == null ? null : _flowColors[index];

class _BaganViewState extends ConsumerState<BaganView> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    // Sebelum Buat bagan: match pratinjau dari susunan slot (bukan simpanan), supaya kartu dan label memakai jalur sama.
    final preview = !active.hasBracket;
    final matches = preview
        ? [for (final s in ref.watch(bracketPreviewProvider)) KnockoutBracket.matchAt(active.config, _slotOf(s))]
        : [
            for (final m in active.matches)
              if (m.phase is KnockoutPhase) m,
          ];
    final layout = _BaganLayout.of(active, matches);
    if (layout == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxWidth;
          final board = Padding(
            padding: const EdgeInsets.symmetric(horizontal: _inset),
            child: _board(layout, preview),
          );
          final overflow = layout.width + 2 * _inset - viewport;
          if (overflow <= 0) return Align(alignment: Alignment.topLeft, child: board);
          final stops = [for (var c = 0; c < layout.columns; c++) _stop(c, layout.columns, viewport, overflow)];
          // Posisi awal (21j, 21x, 23v, 23w): babak pertama yang masih ada match tanpa hasil; Juara 3 ikut kolom Final.
          final open = KnockoutBracket.firstOpenColumn(active);
          final column = layout.babak.indexOf(open == KnockoutRound.thirdPlace ? KnockoutRound.finalRound : open);
          _scroll ??= ScrollController(initialScrollOffset: stops[column < 0 ? stops.length - 1 : column]);
          return Semantics(
            // Pembaca layar tidak bisa menggeser per kolom: sediakan loncat ke kolom terakhir (Final).
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Geser ke Final'): () =>
                  _scroll!.animateTo(overflow, duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
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

  /// Henti geser kolom [c]: pertama rata kiri, terakhir rata kanan, tengah di tengah viewport (tetangga mengintip 32).
  static double _stop(int c, int columns, double viewport, double overflow) {
    if (c == 0) return 0;
    if (c == columns - 1) return overflow;
    final centered = _inset + c * (_columnWidth + _columnGap) + _columnWidth / 2 - viewport / 2;
    return centered.clamp(0.0, overflow);
  }

  static KnockoutSlot _slotOf(KnockoutPreviewSlot s) =>
      (phase: s.phase, round: s.round, matchNumber: s.matchNumber, court: s.court);

  Widget _board(_BaganLayout layout, bool preview) {
    final active = widget.active;
    final finished = active.tournament.isFinished;
    final current = active.currentRound;
    final onOpenRound = widget.onOpenRound;
    // `.bagan.wc`: kolom slot 56 begitu ada wildcard bernama ("WC2 · B3", 23h), supaya nama di semua baris sejajar.
    final wide = !preview && (active.config.groupKnockout?.wildcards.isNotEmpty ?? false);
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: _LinesPainter(layout.lines))),
          ),
          // Label sebelum kartu: area ketuk 48 boleh menindih tepi kartu, ketukan di kartu tetap milik kartu.
          for (final h in layout.headers)
            Positioned(
              left: h.left,
              top: h.top - 15,
              width: _columnWidth,
              height: 48,
              child: _ColumnHeader(
                babak: h.round == KnockoutRound.thirdPlace ? h.round.shortLabel : h.round.label,
                format: h.format,
                onTap: onOpenRound == null ? null : () => onOpenRound(h.round),
              ),
            ),
          for (final card in layout.cards)
            Positioned(
              left: card.left,
              top: card.top,
              width: _columnWidth,
              child: _BaganCard(
                active: active,
                match: card.match,
                wideSeed: wide,
                // Titik bola = match di round berjalan yang belum ada skor (makna sama dengan titik di tab round).
                live:
                    !preview &&
                    !finished &&
                    card.match.roundNumber == current &&
                    card.match.status == MatchStatus.pending,
                // Bisa diisi = aturan yang sama dengan baris di tab round (`canOpenScore`); pratinjau tidak pernah.
                onTap: preview || widget.onOpenMatch == null || !active.canOpenScore(card.match)
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
typedef _Header = ({KnockoutRound round, String format, double left, double top});
typedef _Line = ({Offset from, double midX, Offset to, Color color});

/// Posisi kartu, label, dan garis bagan. Garis keluar dari tengah dua baris kartu asal ke tengah baris slotnya; tengah
/// kartu babak berikutnya = tengah dua kartu asalnya. Juara 3 di bawah Final di kolom terakhir tanpa garis.
class _BaganLayout {
  final List<_Card> cards;
  final List<_Header> headers;
  final List<_Line> lines;
  final double height;

  /// Babak per kolom, kiri ke kanan (Final mewakili kolom terakhir, Juara 3 ikut di sana).
  final List<KnockoutRound> babak;

  const _BaganLayout({
    required this.cards,
    required this.headers,
    required this.lines,
    required this.height,
    required this.babak,
  });

  int get columns => babak.length;
  double get width => columns * _columnWidth + (columns - 1) * _columnGap;

  static _BaganLayout? of(ActiveTournament active, List<MatchGame> matches) {
    final gk = active.config.groupKnockout;
    if (gk == null) return null;
    final byPhase = <KnockoutPhase, MatchGame>{
      for (final m in matches)
        if (m.phase case final KnockoutPhase p) p: m,
    };
    if (byPhase.isEmpty) return null;

    final babak = [
      for (final r in gk.rounds)
        if (r != KnockoutRound.thirdPlace) r,
    ];
    const step = _columnWidth + _columnGap;
    double leftOf(KnockoutRound r) => (r == KnockoutRound.thirdPlace ? babak.length - 1 : babak.indexOf(r)) * step;

    final top = <KnockoutPhase, double>{};
    final phases = KnockoutBracket.phases(groupCount: gk.groupCount, thirdPlace: gk.thirdPlace);
    // Babak pertama bertumpuk (hi-fi: dua SF berjarak 172, empat QF 116).
    final firstStep = babak.length > 2 ? 116.0 : 172.0;
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
      top[p] = (top[from[0]]! + top[from[1]]!) / 2;
      final x = leftOf(p.round);
      for (final (i, src) in from.indexed) {
        final side = i + 1;
        lines.add((
          from: Offset(x - _columnGap, top[src]! + _headHeight + _rowHeight),
          midX: x - _columnGap / 2,
          to: Offset(x, top[p]! + _headHeight + _rowHeight * (side - 0.5)),
          // Warna alur sisi tujuan; abu-abu selama asal warnanya belum diketahui (21u, 21x).
          color: _flowColor(KnockoutBracket.flowIndex(active, p, side)) ?? _noFlow,
        ));
      }
    }
    const finalPhase = KnockoutPhase(KnockoutRound.finalRound, 1);
    const thirdPhase = KnockoutPhase(KnockoutRound.thirdPlace, 1);
    final finalTop = top[finalPhase];
    if (finalTop == null) return null;
    // Juara 3 (hi-fi): label 24 di bawah kartu Final, kartu 24 di bawah label.
    final thirdLabelTop = finalTop + _cardHeight + 24;
    if (gk.thirdPlace) top[thirdPhase] = thirdLabelTop + 24;

    final cards = <_Card>[
      for (final p in phases)
        if (byPhase[p] case final m? when top.containsKey(p)) (match: m, left: leftOf(p.round), top: top[p]!),
    ];
    String formatOf(KnockoutRound r) {
      final m = byPhase.entries.where((e) => e.key.round == r).firstOrNull?.value;
      return m == null ? '' : active.config.formatFor(m).label;
    }

    final headers = <_Header>[
      // Label kolom di atas kolom; kolom Final di atas kartu Final (bukan di puncak bagan).
      for (final r in babak)
        (
          round: r,
          format: formatOf(r),
          left: leftOf(r),
          top: r == KnockoutRound.finalRound && babak.length > 1 ? finalTop - _firstTop : 0.0,
        ),
      if (gk.thirdPlace)
        (
          round: KnockoutRound.thirdPlace,
          format: formatOf(KnockoutRound.thirdPlace),
          left: leftOf(KnockoutRound.thirdPlace),
          top: thirdLabelTop,
        ),
    ];
    final height = cards.fold(0.0, (h, c) => c.top + _cardHeight > h ? c.top + _cardHeight : h);
    return _BaganLayout(cards: cards, headers: headers, lines: lines, height: height, babak: babak);
  }
}

/// `.bagan .lines`: garis penghubung 2 pt di tengah jarak kolom, urut seperti di hi-fi (yang belakangan di atas).
class _LinesPainter extends CustomPainter {
  final List<_Line> lines;
  const _LinesPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = l.color;
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

/// `.bagan .ch` — nama babak tinta + format tinta-3, menjorok 14 pt; ketuk → sheet format babak (23o).
class _ColumnHeader extends StatelessWidget {
  final String babak;
  final String format;
  final VoidCallback? onTap;
  const _ColumnHeader({required this.babak, required this.format, this.onTap});

  static const _style = TextStyle(
    fontFamily: MabarType.family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wdth', 90)],
    color: MabarColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Align(
        alignment: Alignment.centerLeft,
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
      ),
    );
    return Semantics(
      button: onTap != null,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: label),
    );
  }
}

/// `.bagan .m` — kartu satu match: kepala (kode · titik bola · round · court; Final dan Juara 3 tanpa kode), dua baris
/// tim (kode slot · nama pasangan satu baris · skor/WO), tepi kiri 4 pt warna alur. `.m.off` = "Tidak dimainkan".
class _BaganCard extends StatelessWidget {
  final ActiveTournament active;
  final MatchGame match;
  final bool live;
  final bool wideSeed;
  final VoidCallback? onTap;

  const _BaganCard({required this.active, required this.match, required this.live, required this.wideSeed, this.onTap});

  static const _head = TextStyle(
    fontFamily: MabarType.family,
    fontSize: 13,
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
    final gk = active.config.groupKnockout!;
    final third = phase.round == KnockoutRound.thirdPlace;
    // Warna sisi: babak pertama = warna match-nya (kepala ikut), sisi lanjutan = warna asal pemenang atau abu `.k0`,
    // Juara 3 tanpa warna.
    Color? sideColor(int side) =>
        third ? null : (_flowColor(KnockoutBracket.flowIndex(active, phase, side)) ?? _noFlow);
    final firstRound = gk.rounds.first == phase.round;
    final head = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _headHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(border: _strip(firstRound ? sideColor(1) : null)),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 12),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              head,
              _team(match.pair1, s1, match.pair1TotalGames, off, sideColor(1)),
              _team(match.pair2, s2, match.pair2TotalGames, off, sideColor(2)),
            ],
          ),
        ),
      ),
    );
  }

  /// `box-shadow: inset 4px 0 0 var(--c)`: tepi kiri 4 pt digambar di atas isian (DecoratedBox tidak menambah jarak).
  static Border _strip(Color? color, {bool top = false}) => Border(
    left: BorderSide(width: 4, color: color ?? Colors.transparent),
    top: top ? const BorderSide(color: MabarColors.line) : BorderSide.none,
  );

  /// "SF1, Round 7, Court 1. A1 Andi dan Budi 6, menang. B2 Maya dan Nanda 4"; sisi kosong: "Pemenang SF1, belum ada".
  String _label(String? code, int court, bool off, SideSource s1, SideSource s2) {
    final head = [if (code != null) code, 'Round ${match.roundNumber}', 'Court $court'].join(', ');
    String side(Pair pair, SideSource source, int games) {
      if (pair.isTbd) return '${KnockoutBracket.sourceLabel(source)}, belum ada';
      final seed = KnockoutBracket.seedCode(active, pair.id);
      final names = [for (final id in pair.playerIds) active.playerName(id)].join(' dan ');
      final wo = match.status == MatchStatus.wo && match.woLoserPairId == pair.id;
      final text =
          '${seed == null ? '' : '$seed '}$names'
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

  /// `.bagan .t` — satu sisi: `.win` nama tebal + skor putih di bulatan warna alurnya; `.tbd` asal sisi ("Pemenang
  /// SF1", pratinjau "A1") di kolom nama tanpa kode slot.
  Widget _team(Pair pair, SideSource source, int games, bool off, Color? color) {
    final tbd = pair.isTbd;
    final winner = match.winnerPairId;
    final win = !tbd && winner == pair.id;
    final wo = match.status == MatchStatus.wo && match.woLoserPairId == pair.id;
    final nameStyle = TextStyle(
      fontFamily: MabarType.family,
      fontSize: 15,
      height: 1.4,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: win && !off ? FontWeight.w700 : FontWeight.w500,
      // `.m:has(.t.win) .t:not(.win) .nm`: nama yang kalah tinta-3 (C-16).
      color: off || tbd || (winner != null && !win) ? MabarColors.ink3 : (win ? MabarColors.ink : MabarColors.ink2),
      decoration: off ? TextDecoration.lineThrough : null,
      decorationColor: MabarColors.ink3,
    );
    final names = [for (final id in pair.playerIds) active.playerName(id)];
    final Widget name = tbd
        ? Text(
            KnockoutBracket.sourceLabel(source),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          )
        : names.length == 2
        ? PairName(first: names[0], second: names[1], style: nameStyle)
        : Text(
            names.join(PairName.separator),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          );
    final Widget? score = match.status == MatchStatus.done
        ? Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: win ? BoxDecoration(color: color ?? MabarColors.ink, shape: BoxShape.circle) : null,
            child: Text(
              '$games',
              maxLines: 1,
              softWrap: false,
              style: MabarType.numM.copyWith(fontSize: 16, height: 1, color: win ? Colors.white : MabarColors.ink3),
            ),
          )
        : wo
        ? ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 26),
            child: Text(
              'WO',
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: MabarType.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 12 * 0.02,
                color: MabarColors.clay,
              ),
            ),
          )
        : null;
    // Tinggi minimum, bukan tetap: di skala teks besar baris tumbuh, tidak overflow (A15-1).
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(border: _strip(color, top: true)),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 9),
          child: Row(
            children: [
              if (!tbd) ...[
                SizedBox(
                  width: wideSeed ? 56 : 28,
                  child: Text(
                    KnockoutBracket.seedLabel(active, pair.id) ?? '',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: MabarType.numM.copyWith(fontSize: 13, height: 1.4, color: MabarColors.ink3),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: name),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 26, child: score),
            ],
          ),
        ),
      ),
    );
  }
}

/// Geser berhenti per kolom: lemparan ke kolom berikut/sebelumnya, lepas pelan ke kolom terdekat.
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
