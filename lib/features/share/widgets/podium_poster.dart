import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../models/models.dart';
import '../../../services/share/court_floor.dart';
import '../podium_theme.dart';

/// Di mana poster podium tampil (tokens.json → posterPodium). Gambar dirancang di [designSize] (skala 1:3 dari
/// 1080 px) lalu dirender ×[exportPixelRatio]; kartu pratinjau memakai ukuran Feed di kanvas 358 × 372. Dipakai
/// poster Ringkas dan Lengkap (logic.md §17.1).
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
  final double ball, ballPair, cornerX, lineWidth;

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
);

/// Bola Ringkas: jarak antarbola pasangan 2, bawah bola 2 di bawah tepi atas blok yang bergeser dy/2.
const _ballGap = 2.0, _ballLift = 2.0;

/// Jarak kiri kepala (`.phead`, `.lhead` left 22); Ringkas juga 22 di kanan.
const _headInset = 22.0;

/// Konstanta podium mini poster Lengkap satu target (`posterLengkap.miniPodium`, `.court`). Kartu memakai angka
/// Feed. Sudut, tebal, dan turunan garis lapangan sama dengan Ringkas ([_Spec]).
class _MiniSpec {
  final List<double> heights;
  final Map<int, double> widths;
  final Offset depth;
  final double ball, ballPair, backLineBelowHead, panelBelowBackLine;

  const _MiniSpec({
    required this.heights,
    required this.widths,
    required this.depth,
    required this.ball,
    required this.ballPair,
    required this.backLineBelowHead,
    required this.panelBelowBackLine,
  });
}

const _miniFeedSpec = _MiniSpec(
  heights: [34, 24, 16],
  widths: {1: 34, 2: 34, 3: 26, 4: 21},
  depth: Offset(6, -4),
  ball: 9,
  ballPair: 8,
  backLineBelowHead: 14,
  panelBelowBackLine: 9,
);

const _miniStorySpec = _MiniSpec(
  heights: [52, 37, 25],
  widths: {1: 36, 2: 36, 3: 28, 4: 22},
  depth: Offset(8, -5),
  ball: 12,
  ballPair: 10,
  backLineBelowHead: 18,
  panelBelowBackLine: 10,
);

/// Podium mini: kanan blok + dx = W − 22; kanan kepala = 22 + lebar podium + 12. Bola pasangan berjarak 1 dan
/// bawahnya +1 (Ringkas 2 / +2), sesuai SVG frame 11b, 11f, 11g.
const _miniRightInset = 22.0, _headRightGap = 12.0, _miniBallGap = 1.0, _miniBallLift = 1.0;

/// Baris kecil Lengkap mengecil per 0,5 sampai 11 lalu elipsis, tidak pernah dua baris (keputusan 84).
const _subMin = 11.0, _subStep = 0.5;

_MiniSpec _miniFor(PodiumPosterTarget target) => target == PodiumPosterTarget.story ? _miniStorySpec : _miniFeedSpec;

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

/// Kartu memakai inset 13 (bukan 14 Feed).
double _insetX(PodiumPosterTarget target, _Spec s) => target == PodiumPosterTarget.card ? 13.0 : s.insetX;

/// Padding atas panel sebelum baris pertama.
const _panelPadTop = 6.0;

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

  /// Panel nama Ringkas (kosong tetap punya baris kaki). Null di podium mini Lengkap: di sana panel ditentukan
  /// kepadatan (logic.md §17.4) sesudah garis belakang, bukan oleh podium.
  final Rect? panel;

  /// Dasar blok. Ringkas = atas panel − 10 (Kosong: dihitung seperti panel tiga baris); Lengkap = garis belakang.
  final double base;

  /// y garis belakang lapangan. Ringkas = dasar − (tinggi #3 baku + 6); Lengkap dari kepala ([LengkapHead]).
  final double backLine;

  /// Bawah kepala (judul + baris kecil) menurut line-height CSS.
  final double headBottom;
  final Offset depth;

  /// Sudut garis belakang (x) dan tebal garis tepi lapangan.
  final double cornerX, lineWidth;

  /// Target Story: garis dalam dan kisi kawat lapangan lebih besar ([courtFloor]).
  final bool story;
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
    required this.story,
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
  final panelH = _panelPadTop + panelRows * rowH + s.foot;
  final panelTop = size.height - s.insetBottom - panelH;
  final insetX = _insetX(target, s);
  final panel = Rect.fromLTWH(insetX, panelTop, size.width - 2 * insetX, panelH);

  // Kosong: tidak ada panel nama, tapi garis belakang tetap di tempat poster tiga baris (18t = 18c).
  final baseH = blocks.isEmpty ? _panelPadTop + 3 * s.row + s.foot : panelH;
  final base = size.height - s.insetBottom - baseH - 10;

  // Ringkas sengaja memakai ukuran judul besar untuk judul satu baris (perilaku 3.6.0, dijaga golden).
  final headBottom = _headBottom(s, titleLines, titleLines == 1 ? s.title : s.titleTwo, s.subSize);

  // Batas tinggi (hanya menekan Story): h1' = min(h1, ⌊dasar − bawah kepala − 12 − tinggi bola di atas blok⌋);
  // tinggi lain mengikuti skala yang sama.
  final std = pairSize ? s.heightsPair : s.heights;
  final ballSize = pairSize ? s.ballPair : s.ball;
  final rise = ballSize + s.depth.dy.abs() / 2 - _ballLift;
  final h1 = min(std[0], (base - headBottom - 12 - rise).floorToDouble());
  final scale = h1 / std[0];

  final slots = wide ? 3 : blocks.length;
  final slotW = _slotWidth(s.widths, slots);
  final x0 = slots == 0 ? 0.0 : ((size.width - (slots * slotW + s.depth.dx)) / 2).floorToDouble();
  final (geoms, balls) = _placeBlocks(
    blocks: blocks,
    wide: wide,
    x0: x0,
    base: base,
    slotW: slotW,
    heightOf: (level) => (std[level - 1] * scale).roundToDouble(),
    depth: s.depth,
    ballSize: ballSize,
    ballGap: _ballGap,
    ballLift: _ballLift,
  );

  return PodiumLayout(
    size: size,
    panel: panel,
    base: base,
    backLine: base - ((std[2] * scale).roundToDouble() + 6),
    headBottom: headBottom,
    depth: s.depth,
    cornerX: s.cornerX,
    lineWidth: s.lineWidth,
    story: target == PodiumPosterTarget.story,
    blocks: geoms,
    balls: balls,
  );
}

/// Podium mini poster Lengkap (logic.md §17.6): blok berdiri di garis belakang [head], rata kanan (kanan blok + dx
/// = W − 22), tinggi tetap per nomor (tanpa batas tinggi dan tanpa tinggi pasangan). Penempatan blok/bola, angka
/// muka, dan painter sama dengan Ringkas; yang beda hanya angkanya. Kosong = tanpa blok, garis belakang tetap.
PodiumLayout miniPodiumLayout({
  required PodiumPosterTarget target,
  required LengkapHead head,
  required List<PodiumBlockData> blocks,
  bool wide = false,
  bool pairSize = false,
}) {
  final s = _specFor(target), m = _miniFor(target);
  final size = target.designSize;
  final slots = wide ? 3 : blocks.length;
  final slotW = _slotWidth(m.widths, slots);
  final (geoms, balls) = _placeBlocks(
    blocks: blocks,
    wide: wide,
    x0: size.width - _miniRightInset - m.depth.dx - slots * slotW,
    base: head.backLine,
    slotW: slotW,
    heightOf: (level) => m.heights[level - 1],
    depth: m.depth,
    ballSize: pairSize ? m.ballPair : m.ball,
    ballGap: _miniBallGap,
    ballLift: _miniBallLift,
  );
  return PodiumLayout(
    size: size,
    panel: null,
    base: head.backLine,
    backLine: head.backLine,
    headBottom: head.bottom,
    depth: m.depth,
    cornerX: s.cornerX,
    lineWidth: s.lineWidth,
    story: target == PodiumPosterTarget.story,
    blocks: geoms,
    balls: balls,
  );
}

double _slotWidth(Map<int, double> widths, int slots) => widths[slots] ?? widths[4]!;

/// Satu-satunya penempatan blok + bola (Ringkas dan podium mini): blok ke-i di x0 + i × [slotW] berdiri di [base];
/// Kerumunan ([wide]) satu blok selebar tiga slot. Bola dipusatkan di muka atas (tengah blok + dx/2), bawahnya
/// [ballLift] di bawah tepi atas yang bergeser dy/2, berjajar dengan jarak [ballGap].
(List<PodiumBlockGeom>, List<PodiumBallGeom>) _placeBlocks({
  required List<PodiumBlockData> blocks,
  required bool wide,
  required double x0,
  required double base,
  required double slotW,
  required double Function(int level) heightOf,
  required Offset depth,
  required double ballSize,
  required double ballGap,
  required double ballLift,
}) {
  final geoms = <PodiumBlockGeom>[];
  final balls = <PodiumBallGeom>[];
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final h = heightOf(b.level);
    final rect = Rect.fromLTWH(x0 + (wide ? 0 : i * slotW), base - h, wide ? slotW * 3 : slotW, h);
    geoms.add(PodiumBlockGeom(rect: rect, level: b.level, face: b.face, faceSize: _faceSizeFor(b.face, h, rect.width)));
    final bottom = rect.top + depth.dy / 2 + ballLift;
    final cx = rect.center.dx + depth.dx / 2;
    final total = b.balls * ballSize + (b.balls - 1) * ballGap;
    for (var k = 0; k < b.balls; k++) {
      final bx = cx - total / 2 + ballSize / 2 + k * (ballSize + ballGap);
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
  return (geoms, balls);
}

// ---------------------------------------------------------------------------------------------------------------
// Kepala (judul + baris kecil): diukur dengan font, tinggi dari line-height CSS
// ---------------------------------------------------------------------------------------------------------------

/// Bawah kepala menurut line-height CSS (judul 1,1, baris kecil 1,2), bukan metrik font Flutter, supaya pembulatan
/// garis belakang/batas tinggi sama dengan frame.
double _headBottom(_Spec s, int titleLines, double titleSize, double subSize) =>
    s.headTop + podiumHeadHeight(titleLines: titleLines, titleSize: titleSize, subGap: s.subGap, subSize: subSize);

TextStyle _titleStyle(double size, {Color? color}) =>
    posterStyle(size: size, weight: FontWeight.w800, stretch: 95, height: 1.1, color: color);

TextStyle _subStyle(double size, {Color? color}) => posterStyle(size: size, weight: FontWeight.w700, color: color);

/// Judul satu baris di ukuran biasa; tidak muat di [width] → ukuran kecil (`.two`), jumlah baris 1–2 dari layout
/// sebenarnya (lebih dari dua → elipsis di baris kedua).
(double, int) _fitTitle(String title, double width, _Spec s) {
  if (posterWidth(title, _titleStyle(s.title)) <= width) return (s.title, 1);
  final lines = _lineCount(title, _titleStyle(s.titleTwo), maxWidth: width, maxLines: 2);
  return (s.titleTwo, lines);
}

/// Kepala poster Lengkap (`.lhead`, logic.md §17.5) dan garis belakang yang diturunkan darinya. Urutannya terbalik
/// dari Ringkas: kepala → garis belakang → podium mini dan panel.
class LengkapHead {
  /// Atas kepala (22; Story 98) dan lebar kolom judul = W − 22 − [right].
  final double top, width;

  /// CSS `right` kepala = 22 + lebar podium mini + 12 (kolom judul tidak menabrak podium).
  final double right;
  final double titleSize;
  final int titleLines;

  /// Ukuran baris kecil **sesudah** dikecilkan (12,5 / 15 turun per 0,5 sampai 11).
  final double subSize;
  final double subGap;

  /// bawahKepala (line-height CSS).
  final double bottom;

  /// y garis belakang = round(bawahKepala + 14) (Story + 18) = dasar podium mini.
  final double backLine;

  const LengkapHead({
    required this.top,
    required this.width,
    required this.right,
    required this.titleSize,
    required this.titleLines,
    required this.subSize,
    required this.subGap,
    required this.bottom,
    required this.backLine,
  });
}

/// Mengukur kepala Lengkap tanpa merender poster (butuh font yang sama dengan render: test pakai `loadHifiFonts`).
/// Lebar kolom judul dari jumlah slot podium, bukan dari blok yang tergambar: Kerumunan dan Kosong = 3 slot, Sparing =
/// 2 (jebakan §17.12 #4), supaya judul tidak melebar/menyempit tergantung isi podium.
LengkapHead lengkapHead({
  required PodiumPosterTarget target,
  required String title,
  required String subtitle,
  required List<PodiumBlockData> blocks,
  bool wide = false,
}) {
  final s = _specFor(target), m = _miniFor(target);
  final slots = wide || blocks.isEmpty ? 3 : blocks.length;
  final right = _miniRightInset + slots * _slotWidth(m.widths, slots) + m.depth.dx + _headRightGap;
  final width = target.designSize.width - _headInset - right;
  final (titleSize, titleLines) = _fitTitle(title, width, s);
  var subSize = s.subSize;
  while (subSize > _subMin && posterWidth(subtitle, _subStyle(subSize)) > width) {
    subSize = max(_subMin, subSize - _subStep);
  }
  final bottom = _headBottom(s, titleLines, titleSize, subSize);
  return LengkapHead(
    top: s.headTop,
    width: width,
    right: right,
    titleSize: titleSize,
    titleLines: titleLines,
    subSize: subSize,
    subGap: s.subGap,
    bottom: bottom,
    backLine: (bottom + m.backLineBelowHead).roundToDouble(),
  );
}

/// Ruang panel Lengkap (§17.4) dan kakinya; [rect] memberi kotak panel untuk tinggi isi tertentu. Membaca [_Spec] yang
/// sama dengan [podiumLayout], jadi inset, kaki, dan padding atas tidak tertulis dua kali.
class LengkapPanelBox {
  /// Ruang untuk baris = bawahPanel − (garis belakang + jarak) − padding atas − kaki.
  final double space;
  final double foot;
  final Rect Function(double contentHeight) _rect;

  const LengkapPanelBox._(this.space, this.foot, this._rect);

  /// Panel menempel ke bawah; [contentHeight] = tinggi seluruh baris (satuan × tinggi baris).
  Rect rect(double contentHeight) => _rect(contentHeight);
}

LengkapPanelBox lengkapPanel(PodiumPosterTarget target, LengkapHead head) {
  final s = _specFor(target), m = _miniFor(target);
  final size = target.designSize;
  final bottom = size.height - s.insetBottom;
  final insetX = _insetX(target, s);
  return LengkapPanelBox._(
    bottom - (head.backLine + m.panelBelowBackLine) - _panelPadTop - s.foot,
    s.foot,
    (contentHeight) =>
        Rect.fromLTRB(insetX, bottom - (_panelPadTop + contentHeight + s.foot), size.width - insetX, bottom),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Painter lapangan + podium
// ---------------------------------------------------------------------------------------------------------------

/// Gaya teks poster (satu sumber untuk Ringkas dan Lengkap; pengukur dan penggambar harus memakai gaya yang sama).
TextStyle posterStyle({
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

/// Lebar satu baris. Painter dilepas di sini: pengukuran berulang (ratusan per build) tidak boleh bocor.
double posterWidth(String text, TextStyle style) {
  final tp = _measure(text, style);
  final w = tp.width;
  tp.dispose();
  return w;
}

/// Batas ukuran nama di panel kedua poster = ukuran baris kecil kepala (Feed 12,5, Story 15; keputusan 91): nama
/// tidak boleh lebih besar dari "Tennis · Mixed · …".
double posterNameMax(PodiumPosterTarget target) => _specFor(target).subSize;

/// Lebar kolom nilai dan kolom keterangan sesudahnya = yang terpanjang di antara [rows] (nilai, keterangan); 0 kalau
/// semua keterangan kosong. Satu lebar untuk seluruh poster, termasuk dua kolom (keputusan 91).
(double, double) posterValueColumns(Iterable<(String, String)> rows, TextStyle valueStyle, TextStyle restStyle) {
  var value = 0.0, rest = 0.0;
  for (final (v, r) in rows) {
    value = max(value, posterWidth(v, valueStyle));
    if (r.isNotEmpty) rest = max(rest, posterWidth(r, restStyle));
  }
  return (value, rest);
}

/// Nilai + keterangan kecil di kolom tetap: nilai rata kanan di [valueWidth], keterangan rata kiri di [restWidth],
/// sejajar garis dasar. Tidak pernah dipotong (lebar sudah diukur dari teks terpanjang).
class PosterValue extends StatelessWidget {
  final String value, rest;
  final TextStyle valueStyle, restStyle;
  final double valueWidth, restWidth, gap;

  const PosterValue({
    super.key,
    required this.value,
    required this.rest,
    required this.valueStyle,
    required this.restStyle,
    required this.valueWidth,
    required this.restWidth,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      SizedBox(
        width: valueWidth,
        child: Text(value, maxLines: 1, softWrap: false, textAlign: TextAlign.right, style: valueStyle),
      ),
      if (restWidth > 0) ...[
        SizedBox(width: gap),
        SizedBox(
          width: restWidth,
          child: Text(rest, maxLines: 1, softWrap: false, style: restStyle),
        ),
      ],
    ],
  );
}

int _lineCount(String text, TextStyle style, {required double maxWidth, required int maxLines}) {
  final tp = _measure(text, style, maxWidth: maxWidth, maxLines: maxLines);
  final n = tp.computeLineMetrics().length;
  tp.dispose();
  return n;
}

/// `.podium .scene` — latar, lantai + garis lapangan, blok (muka atas, samping, depan, angka), lalu bola. Urutan
/// gambar sama dengan SVG hi-fi: blok yang berdampingan dan sama tinggi berbagi satu muka atas; muka samping hanya di
/// kanan blok yang tetangga kanannya lebih rendah atau tidak ada.
class PodiumScenePainter extends CustomPainter {
  final PodiumLayout layout;
  final PodiumTheme theme;
  final SportType sport;

  /// Kotak kepala (`.phead` / `.lhead`, tinggi menurut line-height CSS) untuk mask dinding padel; null = tanpa mask.
  final Rect? headRect;

  const PodiumScenePainter({required this.layout, required this.theme, required this.sport, this.headRect});

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    canvas.drawRect(Offset.zero & size, theme.backgroundPaint(size));

    _paintCourt(canvas, size);

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

  /// Lantai lapangan utuh (keputusan 91): urutan sama dengan `<g class="court">` hi-fi — dinding padel (dengan mask
  /// kepala), poligon lantai, garis dalam, lalu garis tepi. Geometri dari [courtFloor].
  void _paintCourt(Canvas canvas, Size size) {
    final l = layout;
    final court = courtFloor(
      sport: sport,
      width: size.width,
      height: size.height,
      cornerX: l.cornerX,
      backLine: l.backLine,
      k: l.depth.dx / -l.depth.dy,
      story: l.story,
    );
    Offset o(CourtPoint p) => Offset(p.x, p.y);
    final walls = court.walls;
    if (walls != null) _paintWalls(canvas, size, walls, o);

    final outline = Path()..addPolygon([for (final p in court.outline) o(p)], true);
    canvas.drawPath(outline, Paint()..color = theme.floor);
    // Garis dalam digambar satu per satu seperti `<line>` SVG: persilangan menebal sama dengan frame.
    final inner = Paint()
      ..color = theme.line
      ..strokeWidth = court.lineWidth
      ..strokeCap = StrokeCap.square;
    for (final (a, b) in court.lines) {
      canvas.drawLine(o(a), o(b), inner);
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = theme.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.lineWidth
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  /// Tiap lapis dinding = satu kelompok ber-opacity (saveLayer), bukan alpha per garis, supaya persilangan kawat sama
  /// dengan `<g opacity>` SVG. Mask kepala: saveLayer dinding, lalu dstOut berisi gradien horizontal (1 − opacity) ×
  /// ramp yang dikali gradien vertikal ramp (dstIn) — resep tokens `behindHead`.
  void _paintWalls(Canvas canvas, Size size, PadelWalls w, Offset Function(CourtPoint) o) {
    final mask = headRect == null
        ? null
        : HeadWallMask.around(
            left: headRect!.left,
            top: headRect!.top,
            right: headRect!.right,
            bottom: headRect!.bottom,
          );
    final ink = theme.line;
    void group(double opacity, void Function() draw) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
      draw();
      canvas.restore();
    }

    void lines(Iterable<CourtLine> ls, double width) {
      final paint = Paint()
        ..color = ink
        ..strokeWidth = width;
      for (final (a, b) in ls) {
        canvas.drawLine(o(a), o(b), paint);
      }
    }

    if (mask != null) canvas.saveLayer(null, Paint());
    final (gl, gt, gr, gb) = w.backGlass;
    canvas.drawRect(
      Rect.fromLTRB(gl, gt, gr, gb),
      Paint()..color = ink.withValues(alpha: ink.a * PadelWalls.backGlassOpacity),
    );
    group(PadelWalls.glassOpacity, () {
      for (final q in w.glass) {
        canvas.drawPath(Path()..addPolygon([for (final p in q) o(p)], true), Paint()..color = ink);
      }
    });
    group(PadelWalls.meshOpacity, () => lines(w.mesh, PadelWalls.meshWidth));
    group(PadelWalls.postOpacity, () => lines(w.posts, PadelWalls.postWidth));
    group(PadelWalls.cornerOpacity, () => lines([w.corner], PadelWalls.cornerWidth));

    if (mask != null) {
      final (l, t, r, b) = mask.outer;
      final rect = Rect.fromLTRB(l, t, r, b);
      Shader shader(bool horizontal, Color color) {
        final stops = HeadWallMask.stops(horizontal ? l : t, horizontal ? r : b);
        return ui.Gradient.linear(
          horizontal ? Offset(l, 0) : Offset(0, t),
          horizontal ? Offset(r, 0) : Offset(0, b),
          [for (final (_, v) in stops) color.withValues(alpha: color.a * v)],
          [for (final (off, _) in stops) off],
        );
      }

      canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstOut);
      canvas.drawRect(rect, Paint()..shader = shader(true, const Color.fromRGBO(0, 0, 0, 1 - HeadWallMask.opacity)));
      canvas.drawRect(
        rect,
        Paint()
          ..shader = shader(false, const Color(0xFF000000))
          ..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
      canvas.restore();
    }
  }

  void _paintFace(Canvas canvas, PodiumBlockGeom b) {
    TextPainter at(double size) => _measure(
      b.face,
      posterStyle(
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
  bool shouldRepaint(PodiumScenePainter old) =>
      old.layout != layout || old.theme != theme || old.sport != sport || old.headRect != headRect;
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
    final titleW = size.width - 2 * _headInset;
    final (titleSize, titleLines) = _fitTitle(data.title, titleW, s);

    final layout = podiumLayout(
      target: target,
      blocks: data.blocks,
      wide: data.wide,
      pairSize: data.pairSize,
      panelRows: data.rows.length,
      titleLines: titleLines,
    );

    final headRect = Rect.fromLTWH(
      _headInset,
      s.headTop,
      titleW,
      podiumHeadHeight(titleLines: titleLines, titleSize: titleSize, subGap: s.subGap, subSize: s.subSize),
    );
    final head = Positioned(
      left: _headInset,
      top: s.headTop,
      width: titleW,
      child: PodiumHead(
        title: data.title,
        subtitle: data.subtitle,
        titleSize: titleSize,
        titleLines: titleLines,
        subSize: s.subSize,
        subGap: s.subGap,
        color: theme.headText,
      ),
    );

    final panel = layout.panel!;
    final base = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(
      data: base.copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: ClipRect(
          child: DefaultTextStyle(
            style: posterStyle(color: theme.panelText, size: 14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PodiumScenePainter(layout: layout, theme: theme, sport: data.sport, headRect: headRect),
                  ),
                ),
                head,
                Positioned.fromRect(
                  rect: panel,
                  child: _Panel(data: data, theme: theme, story: _story, size: panel.size),
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

    TextStyle bStyle() =>
        posterStyle(size: valB, weight: FontWeight.w800, stretch: 72, height: 1, color: theme.panelText);
    TextStyle smallStyle() => posterStyle(size: valSmall, weight: FontWeight.w600, color: theme.panelText2);
    // Nilai rata kanan dan keterangan rata kiri di kolom selebar yang terpanjang, supaya angka dan "·" sejajar
    // walau jumlah digit selisih berbeda (keputusan 91).
    final (valCol, restCol) = posterValueColumns(data.rows.map((r) => (r.value, r.detail)), bStyle(), smallStyle());
    final valW = valCol + (restCol > 0 ? 4 + restCol : 0);

    // Nama mengecil bersama (langkah 0,5) sampai semua muat di kolomnya; batas bawah 11,5, lalu elipsis per nama.
    // Ukuran awal = ukuran baris kecil kepala (keputusan 91).
    final duo = data.pairSize;
    final baseName = posterNameMax(story ? PodiumPosterTarget.story : PodiumPosterTarget.feed);
    TextStyle nameStyle(double fs, bool gold) => posterStyle(
      size: fs,
      weight: gold ? FontWeight.w800 : FontWeight.w600,
      height: duo ? 1.18 : 1.2,
      color: theme.panelText,
    );
    bool fits(double fs) => data.rows.every((r) {
      final col = inner - posCol - 2 * gap - valW;
      return r.names.every((n) => posterWidth(n, nameStyle(fs, r.gold)) <= col);
    });
    var nameSize = baseName;
    while (nameSize > 11.5 && !fits(nameSize)) {
      nameSize = max(11.5, nameSize - 0.5);
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
                      child: PodiumRank(
                        rank: r.badge,
                        hash: r.hash,
                        gold: r.gold,
                        fontSize: story ? 21 : 16,
                        theme: theme,
                      ),
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
                    PosterValue(
                      value: r.value,
                      rest: r.detail,
                      valueStyle: bStyle(),
                      restStyle: smallStyle(),
                      valueWidth: valCol,
                      restWidth: restCol,
                      gap: 4,
                    ),
                  ],
                ),
              ),
            PodiumSignature(facts: data.facts, theme: theme, height: footH),
          ],
        ),
      ),
    );
  }
}

/// Tinggi kotak [PodiumHead] menurut line-height CSS (judul 1,1, baris kecil 1,2): satu rumus untuk widget kepala dan
/// kotak mask dinding padel di belakangnya.
double podiumHeadHeight({
  required int titleLines,
  required double titleSize,
  required double subGap,
  required double subSize,
}) => titleLines * titleSize * 1.1 + subGap + subSize * 1.2;

/// Kepala poster (`.phead` Ringkas, `.lhead` Lengkap): judul (1–2 baris, line-height 1,1) + baris kecil satu baris.
/// Ukuran dan jumlah baris sudah dihitung pemanggil ([lengkapHead] / [PodiumPoster]); di sini hanya menggambar,
/// tinggi kotak mengikuti line-height CSS supaya sama dengan hitungan bawah kepala.
class PodiumHead extends StatelessWidget {
  final String title, subtitle;
  final double titleSize;
  final int titleLines;
  final double subSize, subGap;
  final Color color;

  const PodiumHead({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.titleLines,
    required this.subSize,
    required this.subGap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: titleLines * titleSize * 1.1,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle(titleSize, color: color),
          ),
        ),
      ),
      SizedBox(height: subGap),
      SizedBox(
        height: subSize * 1.2,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _subStyle(subSize, color: color),
          ),
        ),
      ),
    ],
  );
}

/// `.psig` — kaki panel kedua poster: wordmark (bola 12 + "Match Addict" 10,5) kiri, fakta kanan. Fakta mengecil per
/// 0,1 dari 9,5 sampai muat di sisa lebar, tidak pernah terpotong; lebar diambil dari tempatnya (panel satu/dua kolom).
/// Semua satu tingkat di bawah 3.7.0 (keputusan 91).
class PodiumSignature extends StatelessWidget {
  final String facts;
  final PodiumTheme theme;

  /// 26 (Story 34).
  final double height;

  const PodiumSignature({super.key, required this.facts, required this.theme, required this.height});

  @override
  Widget build(BuildContext context) {
    const wmkSize = 10.5, ballSize = 12.0;
    final wmkStyle = posterStyle(
      size: wmkSize,
      weight: FontWeight.w800,
      stretch: 125,
      height: 1,
      color: theme.panelText,
    );
    TextStyle factsStyle(double fs) => posterStyle(size: fs, weight: FontWeight.w500, color: theme.panelText2);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wmkW = ballSize + 5 + posterWidth('Match Addict', wmkStyle);
          final factsAvail = constraints.maxWidth - wmkW - 10;
          var factsSize = 9.5;
          while (factsSize > 6 && posterWidth(facts, factsStyle(factsSize)) > factsAvail) {
            factsSize = ((factsSize - 0.1) * 10).round() / 10;
          }
          return Row(
            children: [
              const MabarBall(size: ballSize),
              const SizedBox(width: 5),
              Text('Match Addict', style: wmkStyle, maxLines: 1, softWrap: false),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    facts,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: factsStyle(factsSize),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `.pos` (Ringkas) / `.lk .prow .r` (Lengkap) — nomor/skor baris: "#" warna teks kedua; #1 lencana emas (tulisan
/// tinta, "#" tinta 75%). Satu widget untuk kedua poster; ukuran dari pemanggil (Ringkas 16/21, Lengkap nomor × s).
class PodiumRank extends StatelessWidget {
  /// Nomor/skor tanpa "#" ("1", "6½").
  final String rank;

  /// Tulis "#" di depannya (tidak untuk skor Sparing).
  final bool hash;
  final bool gold;
  final double fontSize;
  final PodiumTheme theme;

  const PodiumRank({
    super.key,
    required this.rank,
    this.hash = true,
    required this.gold,
    required this.fontSize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final fs = fontSize;
    final ink = PodiumTheme.goldNumber;
    TextStyle st(Color c) => posterStyle(size: fs, weight: FontWeight.w800, stretch: 72, height: 1, color: c);
    final text = Text.rich(
      TextSpan(
        children: [
          if (hash) TextSpan(text: '#', style: st(gold ? ink.withValues(alpha: 0.75) : theme.panelText2)),
          TextSpan(text: rank, style: st(gold ? ink : theme.panelText)),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
    if (!gold) return Align(alignment: Alignment.centerLeft, child: text);
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
