import 'dart:math';

import '../../models/models.dart';

/// Lantai lapangan poster Bagikan (PRD §5.9 keputusan 91, logic.md §16.6; generator hi-fi `tool/hifi_court_floor.py`).
/// Dart murni: hanya geometri dalam pt poster, painter tinggal menggambar. Lapangan tennis/padel utuh dengan semua
/// garis resmi, dipotong kanvas; padel ditambah dinding kaca belakang + kiri dan pagar kawat. Net tidak digambar.
///
/// Titik lapangan (u m dari garis samping kiri, v m dari garis belakang ke arah penonton, t m di atas lantai) jatuh di
/// x = cornerX + S·u − k·g·v, y = garis belakang + g·v − S·t. S dipilih supaya garis samping kanan memotong tepi bawah
/// di x = W − cornerX; g supaya net 10 pt di bawah tepi bawah.
typedef CourtPoint = ({double x, double y});

/// Satu goresan lurus.
typedef CourtLine = (CourtPoint, CourtPoint);

/// Ukuran resmi (m): lebar, panjang, setengah panjang (garis belakang → net), garis servis dari garis belakang.
class _Dims {
  final double width, length, half, service;
  const _Dims(this.width, this.length, this.half, this.service);
}

const _tennis = _Dims(10.97, 23.77, 11.885, 6.4);
const _padel = _Dims(10, 20, 10, 3.05);

/// Lebar alley tennis dan panjang tanda tengah di garis belakang.
const _tennisAlley = 1.37, _tennisCenterMark = 0.15;

/// Garis tengah padel menjulur 0,2 m melewati kedua garis servis.
const _padelCenterOver = 0.2;

/// Net 10 pt di bawah tepi bawah kanvas (tokens `posterPodium.court.netBelowCanvas`).
const _netBelowCanvas = 10.0;

class CourtFloor {
  /// Empat sudut lapangan (poligon lantai sekaligus garis tepi).
  final List<CourtPoint> outline;

  /// Garis dalam (alley, servis, tengah, tanda tengah), ujung persegi.
  final List<CourtLine> lines;

  /// Tebal garis dalam: Feed 3, Story 3,5. Tebal garis tepi ikut tata letak poster (4,5 / 5,5).
  final double lineWidth;

  /// Null untuk tennis.
  final PadelWalls? walls;

  const CourtFloor({required this.outline, required this.lines, required this.lineWidth, this.walls});
}

/// Dinding padel; tiap lapis digambar sebagai satu kelompok dengan opacity-nya sendiri (SVG `<g opacity>`).
class PadelWalls {
  static const backGlassOpacity = 0.08, glassOpacity = 0.15;
  static const meshWidth = 1.0, meshOpacity = 0.24;
  static const postWidth = 2.0, postOpacity = 0.42;
  static const cornerWidth = 3.0, cornerOpacity = 0.55;

  /// Kaca belakang 0–3 m: kiri, atas, kanan, bawah.
  final (double, double, double, double) backGlass;

  /// Kaca kiri (dua poligon: 3 m di v 0–2, 2 m di v 2–4).
  final List<List<CourtPoint>> glass;

  /// Kisi kawat (tebal 1).
  final List<CourtLine> mesh;

  /// Tiang + tepi atas kaca/kawat (tebal 2).
  final List<CourtLine> posts;

  /// Tiang sudut (tebal 3).
  final CourtLine corner;

  const PadelWalls({
    required this.backGlass,
    required this.glass,
    required this.mesh,
    required this.posts,
    required this.corner,
  });
}

/// Lantai satu poster. [cornerX] dan [backLine] = sudut garis belakang (40 / 44 dan garis belakang tata letak);
/// [k] = dx ÷ |dy| muka atas blok podium poster itu (Lengkap: podium mini), dipakai juga waktu tanpa blok.
CourtFloor courtFloor({
  required SportType sport,
  required double width,
  required double height,
  required double cornerX,
  required double backLine,
  required double k,
  required bool story,
}) {
  final c = sport == SportType.padel ? _padel : _tennis;
  final ax = cornerX, ay = backLine;
  final s = (width - 2 * ax + k * (height - ay)) / c.width;
  final g = (height + _netBelowCanvas - ay) / c.half;
  CourtPoint p(double u, double v) => (x: ax + s * u - k * g * v, y: ay + g * v);
  CourtLine ln(double u1, double v1, double u2, double v2) => (p(u1, v1), p(u2, v2));

  final w = c.width, l = c.length, sv = c.service;
  final lines = switch (sport) {
    SportType.tennis => [
      ln(_tennisAlley, 0, _tennisAlley, l),
      ln(w - _tennisAlley, 0, w - _tennisAlley, l),
      ln(_tennisAlley, sv, w - _tennisAlley, sv),
      ln(_tennisAlley, l - sv, w - _tennisAlley, l - sv),
      ln(w / 2, sv, w / 2, l - sv),
      ln(w / 2, 0, w / 2, _tennisCenterMark),
      ln(w / 2, l - _tennisCenterMark, w / 2, l),
    ],
    SportType.padel => [
      ln(0, sv, w, sv),
      ln(0, l - sv, w, l - sv),
      ln(w / 2, sv - _padelCenterOver, w / 2, l - sv + _padelCenterOver),
    ],
  };
  return CourtFloor(
    outline: [p(0, 0), p(w, 0), p(w, l), p(0, l)],
    lines: lines,
    lineWidth: story ? 3.5 : 3,
    walls: sport == SportType.padel ? _walls(width, ax, ay, s, g, k, story) : null,
  );
}

/// Belakang: kaca 0–3 m, kawat 3–4 m, tiang tiap 2 m sampai min(cornerX + 10·S, W + 10). Kiri: kaca 3 m (v 0–2), kaca
/// 2 m (v 2–4) dengan kawat 1 m di atasnya, lalu pagar kawat 3 m sampai net. Kisi kawat tiap 7 pt (Story 9).
PadelWalls _walls(double width, double ax, double ay, double s, double g, double k, bool story) {
  final m = story ? 9.0 : 7.0;
  final right = min(ax + 10 * s, width + 10);
  CourtPoint p(double v, double t) => (x: ax - k * g * v, y: ay + g * v - s * t);
  CourtLine h(double x1, double y1, double x2, double y2) => ((x: x1, y: y1), (x: x2, y: y2));

  final mesh = <CourtLine>[];
  for (var x = ax + m; x < right; x += m) {
    mesh.add(h(x, ay - 4 * s, x, ay - 3 * s));
  }
  for (var y = ay - 3 * s - m; y > max(ay - 4 * s, -10); y -= m) {
    mesh.add(h(ax, y, right, y));
  }
  // Kawat kiri per bidang (v0, v1, t0, t1); 0,01 menahan sisa float supaya tidak menggambar kisi tepat di tepi.
  for (final (v0, v1, t0, t1) in const [(0.0, 2.0, 3.0, 4.0), (2.0, 4.0, 2.0, 3.0), (4.0, 10.0, 0.0, 3.0)]) {
    for (var v = v0 + m / (k * g); v < v1 - 0.01; v += m / (k * g)) {
      mesh.add((p(v, t0), p(v, t1)));
    }
    for (var t = t0 + m / s; t < t1 - 0.01; t += m / s) {
      mesh.add((p(v0, t), p(v1, t)));
    }
  }

  final posts = <CourtLine>[];
  for (var i = 1; ax + 2 * s * i < right; i++) {
    posts.add(h(ax + 2 * s * i, ay, ax + 2 * s * i, ay - 4 * s));
  }
  for (final (v, t) in const [(2.0, 4.0), (4.0, 3.0), (6.0, 3.0), (8.0, 3.0), (10.0, 3.0)]) {
    posts.add((p(v, 0), p(v, t)));
  }
  posts.addAll([
    h(ax, ay - 3 * s, right, ay - 3 * s),
    h(ax, ay - 4 * s, right, ay - 4 * s),
    for (final (v0, t0, v1, t1) in const [
      (0.0, 3.0, 2.0, 3.0),
      (2.0, 2.0, 4.0, 2.0),
      (0.0, 4.0, 2.0, 4.0),
      (2.0, 3.0, 4.0, 3.0),
      (4.0, 3.0, 10.0, 3.0),
    ])
      (p(v0, t0), p(v1, t1)),
  ]);

  return PadelWalls(
    backGlass: (ax, ay - 3 * s, right, ay),
    glass: [
      [p(0, 0), p(0, 3), p(2, 3), p(2, 0)],
      [p(2, 0), p(2, 2), p(4, 2), p(4, 0)],
    ],
    mesh: mesh,
    posts: posts,
    corner: h(ax, ay, ax, ay - 4 * s),
  );
}

/// Kontras kepala (keputusan host 2026-11-13, tokens `padel.walls.behindHead`): di dalam kotak kepala + [pad] semua
/// lapis dinding menjadi satu lapisan beropacity [opacity], lalu memudar ke opacity biasa sepanjang [fade] pt di luar
/// kotak. Alpha dinding × (1 − (1 − opacity)·gx·gy); gx/gy = 1 di dalam kotak, turun ke 0 mengikuti [ramp].
class HeadWallMask {
  static const opacity = 0.25, pad = 4.0, fade = 6.0;

  /// Smoothstep 3t² − 2t³ di t = 0, 1/6, …, 1 (dibulatkan 4 desimal seperti hi-fi). Bukan linear: ramp linear
  /// meninggalkan pita Mach yang tetap menggambar garis kotak.
  static final List<double> ramp = [
    for (var i = 0; i <= 6; i++) ((3 * pow(i / 6, 2) - 2 * pow(i / 6, 3)) * 1e4).round() / 1e4,
  ];

  /// Kotak kepala + pad, dibulatkan keluar ke pt utuh: kiri, atas, kanan, bawah.
  final (double, double, double, double) box;

  const HeadWallMask._(this.box);

  /// [left]…[bottom] = kotak `.phead` / `.lhead` (judul + baris kecil, tinggi menurut line-height CSS).
  factory HeadWallMask.around({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    // Dibulatkan ke 0,01 dulu supaya sisa float (65.2000001) tidak menggeser kotak satu pt (sama dengan generator).
    double r2(double v) => (v * 100).round() / 100;
    return HeadWallMask._((
      r2(left - pad).floorToDouble(),
      r2(top - pad).floorToDouble(),
      r2(right + pad).ceilToDouble(),
      r2(bottom + pad).ceilToDouble(),
    ));
  }

  /// Kotak + [fade] di tiap sisi: wilayah gradien.
  (double, double, double, double) get outer {
    final (l, t, r, b) = box;
    return (l - fade, t - fade, r + fade, b + fade);
  }

  /// 14 stop gradien satu sumbu di wilayah [outer] (from → to): naik 0 → 1 sepanjang [fade], datar, lalu turun.
  /// Hasil (offset 0–1, nilai 0–1); offset dari ujung [from].
  static List<(double, double)> stops(double from, double to) {
    final o = fade / (to - from);
    return [for (var i = 0; i <= 6; i++) (o * i / 6, ramp[i]), for (var i = 6; i >= 0; i--) (1 - o * i / 6, ramp[i])];
  }
}
