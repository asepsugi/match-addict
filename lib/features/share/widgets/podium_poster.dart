import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../models/models.dart';
import '../podium_theme.dart';

/// Di mana poster podium tampil (tokens.json → posterPodium). Gambar dirancang di [designSize] (skala 1:3 dari
/// 1080 px) lalu dirender ×[exportPixelRatio]; kartu pratinjau memakai ukuran Feed di kanvas 358 × 372. Story podium
/// 360 × 640 **bukan** kanvas 203 × 360 poster Lengkap ([SharePosterTarget.story]).
enum PodiumPosterTarget {
  card,
  feed,
  story;

  Size get designSize => switch (this) {
    PodiumPosterTarget.card => const Size(358, 372),
    PodiumPosterTarget.feed => const Size(360, 360),
    PodiumPosterTarget.story => const Size(360, 640),
  };

  /// Feed 1080 × 1080, Story 1080 × 1920. Kartu tidak diekspor; angkanya sama supaya tidak ada cabang.
  double get exportPixelRatio => 3;
}

/// Satu blok podium kiri → kanan (urutan slot sudah ditentukan pemanggil). [level] 1–3 menentukan tinggi dan warna
/// (1 = emas); [face] = angka di muka blok; [balls] = bola di atasnya (0 untuk Sparing dan Kerumunan).
class PodiumBlockData {
  final int level;
  final String face;
  final int balls;

  const PodiumBlockData({required this.level, required this.face, this.balls = 0});

  bool get gold => level == 1;
}

/// Satu baris panel. [badge] = nomor/skor ("1", "6½"); [hash] = tulis "#" di depannya (tidak untuk Sparing);
/// [names] satu atau dua nama (dua = `.who2` bertumpuk); [value] nilai metode ("80"); [detail] keterangan kecil
/// sesudahnya, sudah lengkap ("poin · +34", "· +19", "game · −4").
class PodiumRowData {
  final String badge;
  final bool hash;
  final bool gold;
  final List<String> names;
  final String value;
  final String detail;

  const PodiumRowData({
    required this.badge,
    this.hash = true,
    required this.gold,
    required this.names,
    required this.value,
    required this.detail,
  });
}

/// Isi poster podium yang sudah jadi teks: widget hanya menggambar, tidak menghitung siapa naik, nomor, atau fakta.
/// Kosong (keputusan 69) = [blocks] dan [rows] kosong; Kerumunan (68) = satu blok [wide] tanpa bola dan satu baris.
class PodiumPosterData {
  final SportType sport;

  /// Nama turnamen, atau "Klasemen akhir|sementara" kalau tanpa nama.
  final String title;

  /// "Klasemen akhir · 6 Nov 2026", atau "Padel · Mixed · 6 Nov 2026" kalau tanpa nama.
  final String subtitle;
  final List<PodiumBlockData> blocks;
  final bool wide;
  final List<PodiumRowData> rows;

  /// Ada baris berisi dua nama (`.duo`): baris panel, blok, dan bola memakai ukuran pasangan untuk semua baris.
  final bool pairSize;

  /// Baris fakta kaki panel ("Padel · 12 pemain · 6 round · 18 match").
  final String facts;

  const PodiumPosterData({
    required this.sport,
    required this.title,
    required this.subtitle,
    this.blocks = const [],
    this.wide = false,
    this.rows = const [],
    this.pairSize = false,
    required this.facts,
  });
}

// ---------------------------------------------------------------------------------------------------------------
// Tata letak (logic.md §16.6): fungsi murni, tidak mengukur teks.
// ---------------------------------------------------------------------------------------------------------------

/// Konstanta satu target (`posterPodium`). Kartu memakai angka Feed.
class _Spec {
  final double insetX, insetBottom, row, rowPair, foot, headTop, title, titleTwo, subSize, subGap;
  final List<double> heights, heightsPair;
  final Map<int, double> widths;
  final Offset depth;
  final double ball, ballPair, cornerX, lineWidth, lineDrop;

  const _Spec({
    required this.insetX,
    required this.insetBottom,
    required this.row,
    required this.rowPair,
    required this.foot,
    required this.headTop,
    required this.title,
    required this.titleTwo,
    required this.subSize,
    required this.subGap,
    required this.heights,
    required this.heightsPair,
    required this.widths,
    required this.depth,
    required this.ball,
    required this.ballPair,
    required this.cornerX,
    required this.lineWidth,
    required this.lineDrop,
  });
}

const _feedSpec = _Spec(
  insetX: 14,
  insetBottom: 14,
  row: 26,
  rowPair: 36,
  foot: 26,
  headTop: 22,
  title: 22,
  titleTwo: 18.5,
  subSize: 12.5,
  subGap: 4,
  heights: [96, 68, 46],
  heightsPair: [78, 56, 38],
  widths: {1: 101, 2: 101, 3: 78, 4: 64},
  depth: Offset(16, -10),
  ball: 22,
  ballPair: 19,
  cornerX: 40,
  lineWidth: 4.5,
  lineDrop: 31.2,
);

const _storySpec = _Spec(
  insetX: 14,
  insetBottom: 84,
  row: 42,
  rowPair: 54,
  foot: 34,
  headTop: 98,
  title: 27,
  titleTwo: 23,
  subSize: 15,
  subGap: 6,
  heights: [178, 128, 86],
  heightsPair: [144, 104, 70],
  widths: {1: 124, 2: 124, 3: 96, 4: 78},
  depth: Offset(22, -13),
  ball: 30,
  ballPair: 26,
  cornerX: 44,
  lineWidth: 5.5,
  lineDrop: 31.9,
);

/// Ukuran angka di muka blok = 0,656 × tinggi blok.
const _faceRatio = 0.656;

/// Angka lebih dari satu karakter ("6½") dikecilkan sampai ±70% lebar blok (18p). Lebar diperkirakan 0,54 em per
/// karakter, bukan diukur: angka ini satu-satunya yang cocok dengan frame (Feed 101 tetap 63, Story 124 jadi 80), dan
/// menjaga tata letak murni.
const _faceCharEm = 0.54;

double _faceSizeFor(String face, double height, double blockWidth) {
  final size = (_faceRatio * height).roundToDouble();
  if (face.length < 2 || size * _faceCharEm * face.length <= 0.7 * blockWidth) return size;
  return (0.7 * blockWidth / (_faceCharEm * face.length)).roundToDouble();
}

_Spec _specFor(PodiumPosterTarget target) => target == PodiumPosterTarget.story ? _storySpec : _feedSpec;

/// Satu blok yang sudah ditempatkan (koordinat poster, pt).
class PodiumBlockGeom {
  final Rect rect;
  final int level;
  final String face;

  /// Ukuran angka di muka = round(0,656 × tinggi), dikecilkan kalau lebih dari satu karakter ([_faceSizeFor]).
  final double faceSize;

  const PodiumBlockGeom({required this.rect, required this.level, required this.face, required this.faceSize});

  bool get gold => level == 1;
}

/// Satu bola + bayangan elipsnya.
class PodiumBallGeom {
  final Rect rect;
  final Offset shadowCenter;
  final double shadowRx, shadowRy;

  const PodiumBallGeom({
    required this.rect,
    required this.shadowCenter,
    required this.shadowRx,
    required this.shadowRy,
  });
}

class PodiumLayout {
  final Size size;

  /// Panel nama (kosong tetap punya baris kaki).
  final Rect panel;

  /// Dasar blok = atas panel − 10 (Kosong: dihitung seperti panel tiga baris).
  final double base;

  /// y garis belakang lapangan = dasar − (tinggi #3 baku + 6).
  final double backLine;

  /// Bawah kepala (judul + baris kecil) menurut line-height CSS.
  final double headBottom;
  final Offset depth;
  final double cornerX, lineWidth, lineDrop;
  final List<PodiumBlockGeom> blocks;
  final List<PodiumBallGeom> balls;

  const PodiumLayout({
    required this.size,
    required this.panel,
    required this.base,
    required this.backLine,
    required this.headBottom,
    required this.depth,
    required this.cornerX,
    required this.lineWidth,
    required this.lineDrop,
    required this.blocks,
    required this.balls,
  });
}

/// Menempatkan blok, bola, panel, dan garis lapangan. [panelRows] = jumlah baris panel; [titleLines] = baris judul
/// yang terpakai (1–2, menentukan bawah kepala dan batas tinggi blok di Story).
PodiumLayout podiumLayout({
  required PodiumPosterTarget target,
  required List<PodiumBlockData> blocks,
  bool wide = false,
  bool pairSize = false,
  required int panelRows,
  int titleLines = 1,
}) {
  final s = _specFor(target);
  final size = target.designSize;
  final rowH = pairSize ? s.rowPair : s.row;
  final panelH = 6 + panelRows * rowH + s.foot;
  final panelTop = size.height - s.insetBottom - panelH;
  final insetX = target == PodiumPosterTarget.card ? 13.0 : s.insetX;
  final panel = Rect.fromLTWH(insetX, panelTop, size.width - 2 * insetX, panelH);

  // Kosong: tidak ada panel nama, tapi garis belakang tetap di tempat poster tiga baris (18t = 18c).
  final baseH = blocks.isEmpty ? 6 + 3 * s.row + s.foot : panelH;
  final base = size.height - s.insetBottom - baseH - 10;

  final headBottom =
      s.headTop + titleLines * (titleLines == 1 ? s.title : s.titleTwo) * 1.1 + s.subGap + s.subSize * 1.2;

  // Batas tinggi (hanya menekan Story): h1' = min(h1, ⌊dasar − bawah kepala − 12 − tinggi bola di atas blok⌋);
  // tinggi lain mengikuti skala yang sama.
  final std = pairSize ? s.heightsPair : s.heights;
  final ballSize = pairSize ? s.ballPair : s.ball;
  final rise = ballSize + s.depth.dy.abs() / 2 - 2;
  final h1 = min(std[0], (base - headBottom - 12 - rise).floorToDouble());
  final scale = h1 / std[0];
  double heightOf(int level) => (std[level - 1] * scale).roundToDouble();

  final slots = wide ? 3 : blocks.length;
  final slotW = s.widths[slots] ?? s.widths[4]!;
  final x0 = slots == 0 ? 0.0 : ((size.width - (slots * slotW + s.depth.dx)) / 2).floorToDouble();
  final geoms = <PodiumBlockGeom>[];
  final balls = <PodiumBallGeom>[];
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final h = heightOf(b.level);
    final rect = Rect.fromLTWH(x0 + (wide ? 0 : i * slotW), base - h, wide ? slotW * 3 : slotW, h);
    geoms.add(PodiumBlockGeom(rect: rect, level: b.level, face: b.face, faceSize: _faceSizeFor(b.face, h, rect.width)));
    // Bola: tengah blok digeser dx/2 (muka atas), bawah bola 2 pt di bawah tepi atas bergeser; berjajar jarak 2.
    final bottom = rect.top + s.depth.dy / 2 + 2;
    final cx = rect.center.dx + s.depth.dx / 2;
    final total = b.balls * ballSize + (b.balls - 1) * 2;
    for (var k = 0; k < b.balls; k++) {
      final bx = cx - total / 2 + ballSize / 2 + k * (ballSize + 2);
      balls.add(
        PodiumBallGeom(
          rect: Rect.fromCenter(center: Offset(bx, bottom - ballSize / 2), width: ballSize, height: ballSize),
          shadowCenter: Offset(bx, bottom - 0.5),
          shadowRx: 0.41 * ballSize,
          shadowRy: 0.13 * ballSize,
        ),
      );
    }
  }

  return PodiumLayout(
    size: size,
    panel: panel,
    base: base,
    backLine: base - ((std[2] * scale).roundToDouble() + 6),
    headBottom: headBottom,
    depth: s.depth,
    cornerX: s.cornerX,
    lineWidth: s.lineWidth,
    lineDrop: s.lineDrop,
    blocks: geoms,
    balls: balls,
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Painter lapangan + podium
// ---------------------------------------------------------------------------------------------------------------

TextStyle _style({
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

TextPainter _measure(String text, TextStyle style, {double maxWidth = double.infinity, int maxLines = 1}) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: maxLines,
      ellipsis: maxLines > 1 ? '…' : null,
    )..layout(maxWidth: maxWidth);

double _width(String text, TextStyle style) => _measure(text, style).width;

/// `.podium .scene` — latar, lantai + garis lapangan, blok (muka atas, samping, depan, angka), lalu bola. Urutan
/// gambar sama dengan SVG hi-fi: blok yang berdampingan dan sama tinggi berbagi satu muka atas; muka samping hanya di
/// kanan blok yang tetangga kanannya lebih rendah atau tidak ada.
class PodiumScenePainter extends CustomPainter {
  final PodiumLayout layout;
  final PodiumTheme theme;

  const PodiumScenePainter({required this.layout, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    canvas.drawRect(Offset.zero & size, theme.backgroundPaint(size));

    // Lantai menerus sampai tepi bawah/kanan; garis dari sudut (cornerX) ke kiri-bawah.
    final y = l.backLine;
    final floor = Path()
      ..moveTo(l.cornerX, y)
      ..lineTo(size.width + 10, y)
      ..lineTo(size.width + 10, size.height + 10)
      ..lineTo(-10, size.height + 10)
      ..lineTo(-10, y + l.lineDrop)
      ..close();
    canvas.drawPath(floor, Paint()..color = theme.floor);
    canvas.drawPath(
      Path()
        ..moveTo(size.width + 10, y)
        ..lineTo(l.cornerX, y)
        ..lineTo(-10, y + l.lineDrop),
      Paint()
        ..color = theme.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.lineWidth
        ..strokeJoin = StrokeJoin.miter,
    );

    final d = l.depth, blocks = l.blocks;
    Color front(PodiumBlockGeom b) => b.gold ? PodiumTheme.goldFront : theme.blockFront;
    Path poly(List<Offset> p) => Path()..addPolygon(p, true);

    // Muka atas: satu poligon per deret blok berdampingan setinggi sama.
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0 && blocks[i - 1].rect.top == blocks[i].rect.top) continue;
      var j = i;
      while (j + 1 < blocks.length && blocks[j + 1].rect.top == blocks[i].rect.top) {
        j++;
      }
      final top = blocks[i].rect.top, left = blocks[i].rect.left, right = blocks[j].rect.right;
      canvas.drawPath(
        poly([
          Offset(left, top),
          Offset(right, top),
          Offset(right + d.dx, top + d.dy),
          Offset(left + d.dx, top + d.dy),
        ]),
        Paint()..color = blocks[i].gold ? PodiumTheme.goldTop : theme.blockTop,
      );
    }
    // Muka samping: dari tepi atas blok sampai tepi atas tetangga yang lebih rendah (atau dasar).
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i].rect;
      final next = i + 1 < blocks.length ? blocks[i + 1].rect : null;
      if (next != null && next.top <= b.top) continue;
      final lower = next?.top ?? l.base;
      canvas.drawPath(
        poly([
          Offset(b.right, b.top),
          Offset(b.right + d.dx, b.top + d.dy),
          Offset(b.right + d.dx, lower + d.dy),
          Offset(b.right, lower),
        ]),
        Paint()..color = blocks[i].gold ? PodiumTheme.goldSide : theme.blockSide,
      );
    }
    // Muka depan + angka.
    for (final b in blocks) {
      canvas.drawRect(b.rect, Paint()..color = front(b));
      _paintFace(canvas, b);
    }
    for (final ball in l.balls) {
      canvas.drawOval(
        Rect.fromCenter(center: ball.shadowCenter, width: 2 * ball.shadowRx, height: 2 * ball.shadowRy),
        Paint()..color = const Color(0x470F1E2C), // ball.shadow 28%
      );
      MabarBall.paint(canvas, ball.rect);
    }
  }

  void _paintFace(Canvas canvas, PodiumBlockGeom b) {
    TextPainter at(double size) => _measure(
      b.face,
      _style(
        size: size,
        weight: FontWeight.w800,
        stretch: 72,
        height: 1,
        color: b.gold ? PodiumTheme.goldNumber : theme.blockNumber,
      ),
    );
    final size = b.faceSize;
    final tp = at(size);
    final baseline = b.rect.center.dy + 0.344 * size;
    tp.paint(
      canvas,
      Offset(b.rect.center.dx - tp.width / 2, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)),
    );
  }

  @override
  bool shouldRepaint(PodiumScenePainter old) => old.layout != layout || old.theme != theme;
}

// ---------------------------------------------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------------------------------------------

/// `.podium` — poster Ringkas: ilustrasi podium sudut lapangan ([PodiumScenePainter]) + kepala + panel nama.
/// Ukuran tetap [PodiumPosterTarget.designSize]; yang membungkus yang mengatur skala/ekspor. Semua teks tidak
/// mengikuti skala teks sistem (ini gambar).
class PodiumPoster extends StatelessWidget {
  final PodiumPosterData data;
  final PodiumTheme theme;
  final PodiumPosterTarget target;

  const PodiumPoster({super.key, required this.data, required this.theme, required this.target});

  bool get _story => target == PodiumPosterTarget.story;

  @override
  Widget build(BuildContext context) {
    final s = _specFor(target);
    final size = target.designSize;

    // Judul: satu baris di ukuran biasa; kalau tidak muat → ukuran kecil, maksimal dua baris (`.ptitle.two`).
    final titleW = size.width - 44;
    TextStyle titleStyle(double fs) =>
        _style(size: fs, weight: FontWeight.w800, stretch: 95, height: 1.1, color: theme.headText);
    final fitsOne = _width(data.title, titleStyle(s.title)) <= titleW;
    final titleSize = fitsOne ? s.title : s.titleTwo;
    final titleLines = fitsOne
        ? 1
        : _measure(data.title, titleStyle(titleSize), maxWidth: titleW, maxLines: 2).computeLineMetrics().length;

    final layout = podiumLayout(
      target: target,
      blocks: data.blocks,
      wide: data.wide,
      pairSize: data.pairSize,
      panelRows: data.rows.length,
      titleLines: titleLines,
    );

    final head = Positioned(
      left: 22,
      top: s.headTop,
      width: titleW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: titleLines * titleSize * 1.1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(data.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle(titleSize)),
            ),
          ),
          SizedBox(height: s.subGap),
          SizedBox(
            height: s.subSize * 1.2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(size: s.subSize, weight: FontWeight.w700, color: theme.headText),
              ),
            ),
          ),
        ],
      ),
    );

    final base = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(
      data: base.copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: ClipRect(
          child: DefaultTextStyle(
            style: _style(color: theme.panelText, size: 14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PodiumScenePainter(layout: layout, theme: theme),
                  ),
                ),
                head,
                Positioned.fromRect(
                  rect: layout.panel,
                  child: _Panel(data: data, theme: theme, story: _story, size: layout.panel.size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.ppanel` — baris nama (`.prank`) + kaki (`.psig`: wordmark dan fakta).
class _Panel extends StatelessWidget {
  final PodiumPosterData data;
  final PodiumTheme theme;
  final bool story;
  final Size size;

  const _Panel({required this.data, required this.theme, required this.story, required this.size});

  @override
  Widget build(BuildContext context) {
    final inner = size.width - 24;
    final posCol = story ? 38.0 : 30.0, gap = story ? 10.0 : 8.0;
    final rowH = data.pairSize ? (story ? 54.0 : 36.0) : (story ? 42.0 : 26.0);
    final footH = story ? 34.0 : 26.0;
    final valB = story ? 24.0 : 18.0, valSmall = story ? 12.5 : 10.5;

    TextStyle bStyle() => _style(size: valB, weight: FontWeight.w800, stretch: 72, height: 1, color: theme.panelText);
    TextStyle smallStyle() => _style(size: valSmall, weight: FontWeight.w600, color: theme.panelText2);
    double valWidth(PodiumRowData r) =>
        _width(r.value, bStyle()) + (r.detail.isEmpty ? 0 : 4 + _width(r.detail, smallStyle()));

    // Nama mengecil bersama (langkah 0,5) sampai semua muat di kolomnya; batas bawah 11,5, lalu elipsis per nama.
    final duo = data.pairSize;
    final baseName = duo ? (story ? 17.0 : 13.0) : (story ? 18.0 : 14.0);
    TextStyle nameStyle(double fs, bool gold) => _style(
      size: fs,
      weight: gold ? FontWeight.w800 : FontWeight.w600,
      height: duo ? 1.18 : 1.2,
      color: theme.panelText,
    );
    bool fits(double fs) => data.rows.every((r) {
      final col = inner - posCol - 2 * gap - valWidth(r);
      return r.names.every((n) => _width(n, nameStyle(fs, r.gold)) <= col);
    });
    var nameSize = baseName;
    while (nameSize > 11.5 && !fits(nameSize)) {
      nameSize = max(11.5, nameSize - 0.5);
    }

    // Fakta mengecil dari 10,5 sampai muat, tidak pernah terpotong.
    const wmkSize = 11.5;
    final wmkStyle = _style(size: wmkSize, weight: FontWeight.w800, stretch: 125, height: 1, color: theme.panelText);
    final wmkW = 13 + 5 + _width('Match Addict', wmkStyle);
    final factsAvail = inner - wmkW - 10;
    var factsSize = 10.5;
    TextStyle factsStyle(double fs) => _style(size: fs, weight: FontWeight.w500, color: theme.panelText2);
    while (factsSize > 6 && _width(data.facts, factsStyle(factsSize)) > factsAvail) {
      factsSize = ((factsSize - 0.1) * 10).round() / 10;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: PodiumTheme.panelAlpha),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Column(
          children: [
            for (final r in data.rows)
              Container(
                height: rowH,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.panelLine)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: posCol,
                      child: _Badge(row: r, theme: theme, story: story),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: duo
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final n in r.names)
                                  Text(
                                    n,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: nameStyle(nameSize, r.gold),
                                  ),
                              ],
                            )
                          : Text(
                              r.names.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: nameStyle(nameSize, r.gold),
                            ),
                    ),
                    SizedBox(width: gap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(r.value, style: bStyle()),
                        if (r.detail.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(r.detail, style: smallStyle(), maxLines: 1, softWrap: false),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: footH,
              child: Row(
                children: [
                  const MabarBall(size: 13),
                  const SizedBox(width: 5),
                  Text('Match Addict', style: wmkStyle, maxLines: 1, softWrap: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        data.facts,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: factsStyle(factsSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.pos` — nomor/skor baris: "#" warna teks kedua, lencana emas (tulisan tinta) untuk #1.
class _Badge extends StatelessWidget {
  final PodiumRowData row;
  final PodiumTheme theme;
  final bool story;

  const _Badge({required this.row, required this.theme, required this.story});

  @override
  Widget build(BuildContext context) {
    final fs = story ? 21.0 : 16.0;
    final ink = PodiumTheme.goldNumber;
    TextStyle st(Color c) => _style(size: fs, weight: FontWeight.w800, stretch: 72, height: 1, color: c);
    final text = Text.rich(
      TextSpan(
        children: [
          if (row.hash) TextSpan(text: '#', style: st(row.gold ? ink.withValues(alpha: 0.75) : theme.panelText2)),
          TextSpan(text: row.badge, style: st(row.gold ? ink : theme.panelText)),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
    if (!row.gold) return Align(alignment: Alignment.centerLeft, child: text);
    // margin-left −.3em supaya angkanya sejajar dengan baris tanpa lencana.
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(-0.3 * fs, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(color: PodiumTheme.goldFront, borderRadius: BorderRadius.circular(0.35 * fs)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 0.3 * fs, vertical: 0.08 * fs),
            child: text,
          ),
        ),
      ),
    );
  }
}
