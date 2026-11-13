import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/share/court_floor.dart';

/// Lantai lapangan poster (keputusan 91, logic.md §16.6). Angka acuan = keluaran `tool/hifi_court_floor.py` untuk
/// frame yang sama (Ringkas Feed 3 baris: sudut 40,174 k 1,6; Story 44,288 k 22/13; Lengkap Feed 40,79 k 1,5).
void main() {
  void expectPoint(CourtPoint p, double x, double y) {
    expect(p.x, closeTo(x, 0.05));
    expect(p.y, closeTo(y, 0.05));
  }

  CourtFloor floor(
    SportType sport, {
    double h = 360,
    double ax = 40,
    double ay = 174,
    double k = 1.6,
    bool story = false,
  }) => courtFloor(sport: sport, width: 360, height: h, cornerX: ax, backLine: ay, k: k, story: story);

  group('courtFloor', () {
    test('padel Feed 40,174 k 1,6: sudut lapangan, garis samping kanan memotong tepi bawah di W − 40', () {
      final f = floor(SportType.padel);
      expectPoint(f.outline[0], 40, 174);
      expectPoint(f.outline[1], 617.6, 174);
      expectPoint(f.outline[2], -9.6, 566);
      expectPoint(f.outline[3], -587.2, 566);
      // Di y 360 garis samping kanan (u = 10) ada di x 320.
      final (top, bottom) = (f.outline[1], f.outline[2]);
      final x360 = top.x + (bottom.x - top.x) * (360 - top.y) / (bottom.y - top.y);
      expect(x360, closeTo(320, 1e-9));
      expect(f.lines, hasLength(3));
      // Garis servis 3,05 m dari garis belakang: y = 174 + 19,6 × 3,05.
      expect(f.lines.first.$1.y, closeTo(233.78, 1e-9));
      expect(f.lineWidth, 3);
    });

    test('padel Feed: dinding = kisi 130, tiang + tepi 14, tiang sudut 4 m, kaca belakang sampai W + 10', () {
      final w = floor(SportType.padel).walls!;
      expect(w.mesh, hasLength(130));
      expect(w.posts, hasLength(14));
      expectPoint(w.corner.$1, 40, 174);
      expectPoint(w.corner.$2, 40, 174 - 4 * 57.76);
      final (l, t, r, b) = w.backGlass;
      expect((l, r, b), (40, 370, 174));
      expect(t, closeTo(174 - 3 * 57.76, 1e-9));
      expect(w.glass, hasLength(2));
    });

    test('padel Story 44,288 k 22/13: garis dalam 3,5, kisi 152, tiang + tepi 13', () {
      final f = floor(SportType.padel, h: 640, ax: 44, ay: 288, k: 22 / 13, story: true);
      expectPoint(f.outline[1], 911.7, 288);
      expectPoint(f.outline[3], -1181.2, 1012);
      expect(f.lineWidth, 3.5);
      expect(f.walls!.mesh, hasLength(152));
      expect(f.walls!.posts, hasLength(13));
    });

    test('padel Lengkap Feed 40,79 k 1,5 (podium mini): kisi 155, tiang + tepi 14', () {
      final f = floor(SportType.padel, ay: 79, k: 1.5);
      expectPoint(f.outline[1], 741.5, 79);
      expectPoint(f.outline[2], -131.5, 661);
      expect(f.walls!.mesh, hasLength(155));
      expect(f.walls!.posts, hasLength(14));
    });

    test('tennis: tujuh garis dalam (dua alley, dua servis, tengah, dua tanda tengah), tanpa dinding', () {
      final f = floor(SportType.tennis);
      expect(f.lines, hasLength(7));
      expect(f.walls, isNull);
      expectPoint(f.outline[0], 40, 174);
      expectPoint(f.outline[1], 617.6, 174);
      // Alley kiri mulai 1,37 m dari garis samping kiri.
      expect(f.lines.first.$1.x, closeTo(40 + 57.76 / 10.97 * 10 * 1.37, 1e-9));
    });
  });

  group('HeadWallMask', () {
    test('kotak kepala + 4 dibulatkan keluar = data-head hi-fi', () {
      // Ringkas Feed: .phead 22–338, 22 → 22 + 22 × 1,1 + 4 + 12,5 × 1,2 = 65,2.
      expect(HeadWallMask.around(left: 22, top: 22, right: 338, bottom: 65.2).box, (18, 18, 342, 70));
      // Ringkas Story: 98 → 151,7.
      expect(HeadWallMask.around(left: 22, top: 98, right: 338, bottom: 151.7).box, (18, 94, 342, 156));
      // Kartu 358 lebar → kanan 336.
      expect(HeadWallMask.around(left: 22, top: 22, right: 336, bottom: 65.2).box, (18, 18, 340, 70));
      // Sisa float tidak menggeser satu pt.
      expect(HeadWallMask.around(left: 22, top: 22, right: 338, bottom: 66.0000001).box, (18, 18, 342, 70));
    });

    test('ramp smoothstep = tokens behindHead.fadeRamp; 14 stop naik sepanjang 6 pt lalu turun', () {
      expect(HeadWallMask.ramp, [0, 0.0741, 0.2593, 0.5, 0.7407, 0.9259, 1]);
      final m = HeadWallMask.around(left: 22, top: 22, right: 338, bottom: 65.2);
      expect(m.outer, (12, 12, 348, 76));
      final stops = HeadWallMask.stops(12, 348);
      expect(stops, hasLength(14));
      expect(stops.first, (0, 0));
      expect(stops[6].$1, closeTo(6 / 336, 1e-12));
      expect(stops[6].$2, 1);
      expect(stops[7].$1, closeTo(1 - 6 / 336, 1e-12));
      expect(stops.last, (1, 0));
    });
  });
}
