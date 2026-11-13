import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../models/models.dart';
import '../../../services/share/lengkap.dart';
import '../podium_theme.dart';
import 'podium_poster.dart';

/// Satu baris poster Lengkap. [names] satu nama, atau dua nama pasangan Fixed (digabung "A + B", ditumpuk di Story).
/// [value] = nilai metode ("42", "75%"); sesudahnya teks kecil "[detail] · [diff]" ("game · +12") hanya di susunan
/// bersatuan (feed1), selain itu "· [diff]". Selisih selalu ada: dialah yang menjelaskan nomor berbeda untuk nilai yang
/// sama (logic.md §4, keputusan 77).
class SharePosterRow {
  final int position;
  final List<String> names;
  final String value;
  final String? detail;
  final String diff;

  const SharePosterRow({
    required this.position,
    required this.names,
    required this.value,
    this.detail,
    required this.diff,
  });
}

/// Satu klub poster Lengkap sparing: kepala `.lclub` (nama + "56 game · +13", tanpa angka skor, keputusan 83) lalu
/// barisnya, nomor mulai #1 di tiap klub.
class SharePosterClub {
  final String name;
  final String detail;
  final List<SharePosterRow> rows;

  const SharePosterClub({required this.name, required this.detail, required this.rows});
}

/// Isi poster Lengkap yang sudah jadi teks (logic.md §17.9): widget hanya menata dan menggambar, tidak menghitung siapa
/// naik podium, nomor, atau fakta. Kosong (keputusan 87, 89) = [blocks], [rows] kosong dan [clubs] null.
class SharePosterData {
  final SportType sport;

  /// Kepala = kepala poster podium: nama turnamen atau "Klasemen akhir|sementara".
  final String title;
  final String subtitle;

  /// Podium mini kiri → kanan (pemetaan yang sama dengan Ringkas); [wide] = Kerumunan.
  final List<PodiumBlockData> blocks;
  final bool wide;

  /// Bola pasangan (`PodiumSteps.pairSize`): ukuran bola podium mini.
  final bool pairBalls;

  /// `config.mode.isEndless` (Mixed, Mexicano): gerbang dua kolom (keputusan 81), bukan "tidak ada baris pasangan".
  final bool endless;

  /// Semua baris bernomor, urut Klasemen. Kosong untuk Sparing (barisnya di [clubs]).
  final List<SharePosterRow> rows;

  /// Sparing: dua klub, klub pertama dulu. Null untuk turnamen biasa dan Sparing 0 – 0.
  final List<SharePosterClub>? clubs;

  /// Baris fakta kaki (`podiumFacts`), sama persis dengan poster podium.
  final String facts;

  const SharePosterData({
    required this.sport,
    required this.title,
    required this.subtitle,
    this.blocks = const [],
    this.wide = false,
    this.pairBalls = false,
    required this.endless,
    this.rows = const [],
    this.clubs,
    required this.facts,
  });

  /// Jumlah baris per kolom sumber untuk [lengkapGrid]: `[n]`, atau `[n1, n2]` untuk Sparing.
  List<int> get rowCounts => clubs == null ? [rows.length] : [for (final c in clubs!) c.rows.length];

  SharePosterRow rowAt(int club, int row) => clubs == null ? rows[row] : clubs![club].rows[row];

  Iterable<SharePosterRow> get allRows => clubs?.expand((c) => c.rows) ?? rows;
}

/// Ukuran baris satu susunan (`tokens.json → posterLengkap.density`), sebelum dikali skala s.
class _Sizes {
  final double rankCol, gap, rank, name, value, rest;

  /// Satuan ditulis di nilai ("52 game · +18"); hanya feed1 (jebakan §17.12 #10).
  final bool unit;

  const _Sizes(this.rankCol, this.gap, this.rank, this.name, this.value, this.rest, {this.unit = false});
}

const _sizes = <LengkapSizing, _Sizes>{
  LengkapSizing.feed1: _Sizes(30, 8, 15, 13.5, 16, 10.5, unit: true),
  LengkapSizing.feed2: _Sizes(22, 5, 13, 12, 13.5, 10),
  LengkapSizing.story1: _Sizes(30, 8, 14, 13.5, 15, 10.5),
  LengkapSizing.story2: _Sizes(22, 5, 13, 12, 13.5, 10),
};

/// Nama dikecilkan bersama (kn, `posterLengkap.name`): turun per 0,02 sampai semua muat, paling kecil 0,82.
const _knStep = 2, _knMinPercent = 82;

/// `.lk` — poster Lengkap arah B "Podium mini" (PRD §5.9, keputusan 76–90, logic.md §17): `.scene`
/// ([PodiumScenePainter]: latar, lantai, garis belakang, podium mini), `.lhead` (judul + baris kecil) di kiri atas,
/// `.lpanel` (baris `.prow`, kepala klub `.lclub`, lalu kaki `.psig`) di bawah. Urutan hitung terbalik dari Ringkas:
/// kepala → garis belakang → podium mini dan ruang panel → kepadatan. Ukuran tetap [PodiumPosterTarget.designSize];
/// teks tidak mengikuti skala teks sistem (ini gambar).
class SharePoster extends StatelessWidget {
  final SharePosterData data;
  final PodiumTheme theme;
  final PodiumPosterTarget target;

  const SharePoster({super.key, required this.data, required this.theme, required this.target});

  @override
  Widget build(BuildContext context) {
    final story = target == PodiumPosterTarget.story;
    final size = target.designSize;

    // Kepala diukur di sini (bukan di provider) supaya font yang mengukur = font yang menggambar.
    final head = lengkapHead(
      target: target,
      title: data.title,
      subtitle: data.subtitle,
      blocks: data.blocks,
      wide: data.wide,
    );
    final layout = miniPodiumLayout(
      target: target,
      head: head,
      blocks: data.blocks,
      wide: data.wide,
      pairSize: data.pairBalls,
    );

    final grid = lengkapGrid(
      story: story,
      endless: data.endless,
      rowCounts: data.rowCounts,
      pairs: data.allRows.any((r) => r.names.length > 1),
    );

    // Panel (§17.4, 17.7): bawahPanel = H − 14 (Story 84); jarak dari garis belakang 9 (Story 10); kaki 26 (Story 34).
    final foot = story ? 34.0 : 26.0;
    final panelBottom = size.height - (story ? 84.0 : 14.0);
    final space = panelBottom - (head.backLine + (story ? 10 : 9)) - 6 - foot;
    final density = lengkapDensity(sizing: grid.sizing, units: grid.units, space: space);
    final insetX = target == PodiumPosterTarget.card ? 13.0 : 14.0;
    final panel = Rect.fromLTRB(
      insetX,
      panelBottom - (6 + grid.units * density.rowHeight + foot),
      size.width - insetX,
      panelBottom,
    );

    final base = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(
      data: base.copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: ClipRect(
          child: DefaultTextStyle(
            style: _ts(size: 14, color: theme.panelText),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PodiumScenePainter(layout: layout, theme: theme),
                  ),
                ),
                Positioned(
                  left: 22,
                  top: head.top,
                  width: head.width,
                  child: PodiumHead(
                    title: data.title,
                    subtitle: data.subtitle,
                    titleSize: head.titleSize,
                    titleLines: head.titleLines,
                    subSize: head.subSize,
                    subGap: head.subGap,
                    color: theme.headText,
                  ),
                ),
                Positioned.fromRect(
                  rect: panel,
                  child: _LengkapPanel(
                    data: data,
                    theme: theme,
                    grid: grid,
                    density: density,
                    story: story,
                    width: panel.width,
                    foot: foot,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.lpanel` — kolom baris (satu kolom, atau `.lcols` dua kolom dengan garis tengah) lalu kaki `.psig`.
class _LengkapPanel extends StatelessWidget {
  final SharePosterData data;
  final PodiumTheme theme;
  final LengkapGrid grid;
  final LengkapDensity density;
  final bool story;
  final double width, foot;

  const _LengkapPanel({
    required this.data,
    required this.theme,
    required this.grid,
    required this.density,
    required this.story,
    required this.width,
    required this.foot,
  });

  bool get _two => grid.columns.length == 2;

  @override
  Widget build(BuildContext context) {
    final sz = _sizes[grid.sizing]!;
    final s = density.scale, rowH = density.rowHeight;
    final padX = _two ? 10.0 : 12.0;
    final inner = width - 2 * padX;
    const columnGap = 14.0;
    final colW = _two ? (inner - columnGap) / 2 : inner;
    final kn = _nameScale(sz, s, colW);

    Widget cell(LengkapCell c) => switch (c) {
      LengkapClubCell(:final club) => _ClubHead(
        club: data.clubs![club],
        height: 2 * rowH,
        sizes: sz,
        s: s,
        theme: theme,
      ),
      LengkapRowCell(:final club, :final row, :final units) => _Row(
        row: data.rowAt(club, row),
        height: units * rowH,
        stacked: units == 2,
        sizes: sz,
        s: s,
        kn: kn,
        theme: theme,
      ),
    };

    Widget column(List<LengkapCell> cells) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [for (final c in cells) cell(c)],
    );

    final gridHeight = grid.units * rowH;
    final Widget rows = _two
        ? SizedBox(
            height: gridHeight,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: column(grid.columns[0])),
                    const SizedBox(width: columnGap),
                    Expanded(child: column(grid.columns[1])),
                  ],
                ),
                // `.lcols::after`: garis 1 di 50% lebar, 3 dari atas dan bawah.
                Positioned(
                  left: inner / 2,
                  top: 3,
                  bottom: 3,
                  width: 1,
                  child: ColoredBox(color: theme.panelLine),
                ),
              ],
            ),
          )
        : column(grid.columns.single);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: PodiumTheme.panelAlpha),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(padX, 6, padX, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (grid.units > 0) rows,
            PodiumSignature(facts: data.facts, theme: theme, height: foot),
          ],
        ),
      ),
    );
  }

  /// kn (§17.7): satu pengali nama untuk seluruh poster target ini, dari 1 turun 0,02 sampai setiap nama muat di sel
  /// namanya (diukur dengan bobot barisnya; #1 800), paling kecil 0,82; sesudah itu elipsis per nama.
  double _nameScale(_Sizes sz, double s, double colW) {
    final cells = [
      for (final col in grid.columns)
        for (final c in col)
          if (c is LengkapRowCell) c,
    ];
    if (cells.isEmpty) return 1;
    final valueStyle = _valueStyle(sz, s, theme), restStyle = _restStyle(sz, s, theme);
    final fixed = (sz.rankCol + 2 * sz.gap) * s;
    // Lebar sel nama tiap baris tidak bergantung pada kn: hitung sekali.
    final checks = [
      for (final c in cells)
        () {
          final r = data.rowAt(c.club, c.row);
          final value = _width(r.value, valueStyle) + 3 * s + _width(_rest(r, sz), restStyle);
          final names = c.units == 2 && r.names.length > 1 ? r.names : [r.names.join(' + ')];
          return (avail: colW - fixed - value, names: names, gold: r.position == 1);
        }(),
    ];
    bool fits(double kn) =>
        checks.every((c) => c.names.every((n) => _width(n, _nameStyle(sz.name * s * kn, c.gold, theme)) <= c.avail));
    var percent = 100;
    while (percent > _knMinPercent && !fits(percent / 100)) {
      percent -= _knStep;
    }
    return percent / 100;
  }
}

/// `.prow` — [kolom nomor] [nama] [nilai]; garis bawah 1 di dalam tinggi baris. [stacked] = `.duo` (Story Fixed):
/// dua satuan; dua nama ditumpuk, satu nama tetap satu baris di tengah (keputusan 90).
class _Row extends StatelessWidget {
  final SharePosterRow row;
  final double height;
  final bool stacked;
  final _Sizes sizes;
  final double s, kn;
  final PodiumTheme theme;

  const _Row({
    required this.row,
    required this.height,
    required this.stacked,
    required this.sizes,
    required this.s,
    required this.kn,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final gold = row.position == 1;
    final name = _nameStyle(sizes.name * s * kn, gold, theme);
    final Widget names = stacked && row.names.length > 1
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in row.names)
                Text(
                  n,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: name.copyWith(height: 1.16),
                ),
            ],
          )
        : Text(row.names.join(' + '), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: name);
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.panelLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: sizes.rankCol * s,
            child: PodiumRank(rank: '${row.position}', gold: gold, fontSize: sizes.rank * s, theme: theme),
          ),
          SizedBox(width: sizes.gap * s),
          Expanded(child: names),
          SizedBox(width: sizes.gap * s),
          // Nilai tidak pernah dipotong (§17.7).
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(row.value, maxLines: 1, softWrap: false, style: _valueStyle(sizes, s, theme)),
              SizedBox(width: 3 * s),
              Text(_rest(row, sizes), maxLines: 1, softWrap: false, style: _restStyle(sizes, s, theme)),
            ],
          ),
        ],
      ),
    );
  }
}

/// `.lclub` — kepala klub sparing setinggi dua baris: nama (nama × 1,06 × s, 800, w95, elipsis) + "56 game · +13"
/// (sisa × s, teks kedua), jarak 2s, tanpa angka skor (keputusan 83).
class _ClubHead extends StatelessWidget {
  final SharePosterClub club;
  final double height;
  final _Sizes sizes;
  final double s;
  final PodiumTheme theme;

  const _ClubHead({
    required this.club,
    required this.height,
    required this.sizes,
    required this.s,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: theme.panelLine)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          club.name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: _ts(
            size: sizes.name * 1.06 * s,
            weight: FontWeight.w800,
            stretch: 95,
            height: 1.1,
            color: theme.panelText,
          ),
        ),
        SizedBox(height: 2 * s),
        Text(
          club.detail,
          maxLines: 1,
          softWrap: false,
          style: _ts(size: sizes.rest * s, weight: FontWeight.w600, height: 1.1, color: theme.panelText2),
        ),
      ],
    ),
  );
}

/// Teks kecil sesudah nilai: feed1 bersatuan "game · +18" (Win %: "· +8"), susunan lain "· +31".
String _rest(SharePosterRow r, _Sizes sz) => sz.unit && r.detail != null ? '${r.detail} · ${r.diff}' : '· ${r.diff}';

TextStyle _nameStyle(double size, bool gold, PodiumTheme theme) =>
    _ts(size: size, weight: gold ? FontWeight.w800 : FontWeight.w600, stretch: 88, height: 1.2, color: theme.panelText);

TextStyle _valueStyle(_Sizes sz, double s, PodiumTheme theme) =>
    _ts(size: sz.value * s, weight: FontWeight.w800, stretch: 72, height: 1, color: theme.panelText);

TextStyle _restStyle(_Sizes sz, double s, PodiumTheme theme) =>
    _ts(size: sz.rest * s, weight: FontWeight.w600, height: 1, color: theme.panelText2);

TextStyle _ts({
  required double size,
  FontWeight weight = FontWeight.w400,
  double? stretch,
  double height = 1.2,
  Color? color,
}) => TextStyle(
  fontFamily: MabarType.family,
  fontSize: size,
  fontWeight: weight,
  height: height,
  leadingDistribution: TextLeadingDistribution.even,
  fontFeatures: MabarType.tabular,
  fontVariations: stretch == null ? null : [FontVariation('wdth', stretch)],
  color: color,
  decoration: TextDecoration.none,
);

double _width(String text, TextStyle style) => (TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  textScaler: TextScaler.noScaling,
  maxLines: 1,
)..layout()).width;
