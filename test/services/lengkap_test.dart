import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/services/share/lengkap.dart';

// Ruang dari logic.md §17.10; s dibandingkan dengan toleransi 0,002 (frame menulis nilai terpotong).
void _expectDensity(LengkapGrid g, double space, double row, double s) {
  final d = lengkapDensity(sizing: g.sizing, units: g.units, space: space);
  expect(d.rowHeight, closeTo(row, 0.01));
  expect(d.scale, closeTo(s, 0.002));
}

LengkapGrid _mixed(int n, {bool story = false}) =>
    lengkapGrid(story: story, endless: true, rowCounts: [n], pairs: false);
LengkapGrid _fixed(int n, {bool story = false, bool pairs = true}) =>
    lengkapGrid(story: story, endless: false, rowCounts: [n], pairs: pairs);
LengkapGrid _sparingFixed(int a, int b, {bool story = false}) =>
    lengkapGrid(story: story, endless: false, rowCounts: [a, b], pairs: true);
LengkapGrid _sparingMixed(int a, int b, {bool story = false}) =>
    lengkapGrid(story: story, endless: true, rowCounts: [a, b], pairs: false);

void main() {
  group('tabel 17.10', () {
    test('11b K81 Fixed 10 pasangan kartu', () {
      final g = _fixed(10);
      expect(g.sizing, LengkapSizing.feed1);
      expect(g.columns.length, 1);
      expect(g.units, 10);
      _expectDensity(g, 238, 23.8, 1.04);
    });

    test('11e K81 Mixed 20 bernama kartu', () {
      final g = _mixed(20);
      expect(g.sizing, LengkapSizing.feed2);
      expect(g.columns.length, 2);
      expect(g.units, 10);
      _expectDensity(g, 242, 24.2, 1);
    });

    test('11f K81 Mixed 20 Feed dan Story', () {
      final feed = _mixed(20);
      expect((feed.sizing, feed.columns.length, feed.units), (LengkapSizing.feed2, 2, 10));
      _expectDensity(feed, 230, 23, 1);
      final story = _mixed(20, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story1, 1, 20));
      _expectDensity(story, 315, 15.75, 0.926);
    });

    test('11g K81 Fixed 10 pasangan Feed dan Story', () {
      final feed = _fixed(10);
      expect((feed.sizing, feed.units), (LengkapSizing.feed1, 10));
      _expectDensity(feed, 226, 22.6, 1.027);
      final story = _fixed(10, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story1, 1, 20));
      _expectDensity(story, 336, 16.8, 0.988);
    });

    test('11h K80 Mixed 12 kartu: baris mengisi panel 238 ÷ 6 (batas 40, keputusan 92)', () {
      final g = _mixed(12);
      expect((g.sizing, g.columns.length, g.units), (LengkapSizing.feed2, 2, 6));
      _expectDensity(g, 238, 39.67, 1);
    });

    test('11i K81 Mixed 13: kolom kanan sisa satu slot kosong', () {
      final g = _mixed(13);
      expect((g.columns.length, g.units), (2, 7));
      expect(g.columns[0].length, 7);
      expect(g.columns[1].length, 6);
      _expectDensity(g, 238, 34, 1);
    });

    test('11j K80 Mixed 5 / 7 / 9 satu kolom feed1', () {
      for (final (n, row) in [(5, 30.0), (7, 30.0), (9, 26.44)]) {
        final g = _mixed(n);
        expect((g.sizing, g.columns.length, g.units), (LengkapSizing.feed1, 1, n));
        _expectDensity(g, 238, row, 1.04);
      }
    });

    test('11j K80 Mixed 11 / 13 / 15 / 17 / 19 dua kolom feed2', () {
      for (final (n, k, row) in [(11, 6, 39.67), (13, 7, 34.0), (15, 8, 29.75), (17, 9, 26.44), (19, 10, 23.8)]) {
        final g = _mixed(n);
        expect((g.sizing, g.columns.length, g.units), (LengkapSizing.feed2, 2, k));
        _expectDensity(g, 238, row, 1);
      }
    });

    test('11k K88 Fixed 15 pasangan Feed / Story / kartu', () {
      final feed = _fixed(15);
      expect((feed.sizing, feed.columns.length, feed.units), (LengkapSizing.feed1, 1, 15));
      _expectDensity(feed, 226, 15.07, 0.685);
      final story = _fixed(15, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story1, 1, 30));
      _expectDensity(story, 336, 11.2, 0.659);
      _expectDensity(_fixed(15), 238, 15.87, 0.721);
    });

    test('11l K81 Mixed 30 judul 2 baris Feed / Story / kartu', () {
      final feed = _mixed(30);
      expect((feed.sizing, feed.columns.length, feed.units), (LengkapSizing.feed2, 2, 15));
      _expectDensity(feed, 209, 13.93, 0.774);
      final story = _mixed(30, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story2, 2, 15));
      _expectDensity(story, 315, 21, 1);
      _expectDensity(feed, 221, 14.73, 0.818);
    });

    test('11m K87 belum ada match: Kosong = 0 satuan', () {
      for (final story in [false, true]) {
        final g = _mixed(0, story: story);
        expect(g.units, 0);
        expect(g.columns.expand((c) => c), isEmpty);
        final d = lengkapDensity(sizing: g.sizing, units: g.units, space: 300);
        expect((d.rowHeight, d.scale), (0, 1));
      }
      expect(_mixed(0, story: true).sizing, LengkapSizing.story1);
    });

    test('11m K80 12 baris #1 × 6 Feed', () {
      final g = _mixed(12);
      expect(g.units, 6);
      _expectDensity(g, 230, 38.33, 1);
    });

    test('13s K86 Sparing Fixed 4 + 3 kartu', () {
      final g = _sparingFixed(4, 3);
      expect((g.sizing, g.columns.length, g.units), (LengkapSizing.feed1, 1, 11));
      _expectDensity(g, 238, 21.64, 0.983);
    });

    test('13t K86 Sparing Fixed 4 + 3 Feed / Story', () {
      final feed = _sparingFixed(4, 3);
      expect(feed.units, 11);
      _expectDensity(feed, 226, 20.55, 0.934);
      final story = _sparingFixed(4, 3, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story1, 1, 18));
      _expectDensity(story, 336, 18.67, 1.098);
    });

    test('13u K86 Sparing Mixed 8 + 6 kartu: dua kolom per klub', () {
      final g = _sparingMixed(8, 6);
      expect((g.sizing, g.columns.length, g.units), (LengkapSizing.feed2, 2, 10));
      expect(g.columns[0].length, 9);
      expect(g.columns[1].length, 7);
      _expectDensity(g, 238, 23.8, 1);
    });

    test('13v K86 Sparing Mixed 8 + 6 Feed / Story', () {
      _expectDensity(_sparingMixed(8, 6), 226, 22.6, 1);
      final story = _sparingMixed(8, 6, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story1, 1, 18));
      _expectDensity(story, 336, 18.67, 1.098);
    });

    test('13w K86 Sparing Mixed 16 + 14 Feed / Story / kartu', () {
      final feed = _sparingMixed(16, 14);
      expect((feed.sizing, feed.columns.length, feed.units), (LengkapSizing.feed2, 2, 18));
      _expectDensity(feed, 226, 12.56, 0.698);
      final story = _sparingMixed(16, 14, story: true);
      expect((story.sizing, story.columns.length, story.units), (LengkapSizing.story2, 2, 18));
      _expectDensity(story, 336, 18.67, 1);
      _expectDensity(feed, 238, 13.22, 0.735);
    });
  });

  group('batas', () {
    test('11j K81 Mixed 10 Feed satu kolom, 11 dua kolom', () {
      expect(_mixed(10).columns.length, 1);
      expect(_mixed(11).columns.length, 2);
    });

    test('K81 Mixed 20 Story satu kolom, 21 dua kolom', () {
      expect(_mixed(20, story: true).columns.length, 1);
      final g = _mixed(21, story: true);
      expect((g.columns.length, g.units), (2, 11));
    });

    test('K88 Fixed 15 pasangan Story tetap satu kolom', () {
      expect(_fixed(15, story: true).columns.length, 1);
    });

    test('K86 Sparing Mixed 3 + 3 Feed dua kolom per klub, k = 5', () {
      final g = _sparingMixed(3, 3);
      expect((g.columns.length, g.units), (2, 5));
    });

    test('K86 Sparing Mixed total 20 Story satu kolom, 21 dua per klub', () {
      expect(_sparingMixed(10, 10, story: true).columns.length, 1);
      final g = _sparingMixed(11, 10, story: true);
      expect((g.columns.length, g.sizing, g.units), (2, LengkapSizing.story2, 13));
    });

    test('K81 Mexicano = Mixed: gerbang memakai flag endless yang sama', () {
      // Mexicano dan Mixed sama-sama `isEndless`; tidak ada parameter lain yang membedakan.
      expect(_mixed(11).columns.length, 2);
      expect(_mixed(10).columns.length, 1);
    });

    test('K90 Story Fixed campuran: semua baris 2 satuan; Feed tetap 1 satuan', () {
      final story = _fixed(5, story: true);
      expect(story.columns.single.every((c) => c.units == 2), isTrue);
      expect(story.units, 10);
      expect(_fixed(5).units, 5);
      // Semua tunggal (tanpa baris dua nama) tidak ditumpuk.
      expect(_fixed(5, story: true, pairs: false).units, 5);
    });

    test('K89 Sparing 0 – 0 ikut Kosong: tanpa kepala klub', () {
      for (final story in [false, true]) {
        for (final endless in [false, true]) {
          final g = lengkapGrid(story: story, endless: endless, rowCounts: [0, 0], pairs: false);
          expect(g.units, 0);
          expect(g.columns.expand((c) => c), isEmpty);
        }
      }
    });
  });

  group('invariant L1–L4', () {
    // Semua kombinasi target × mode × Sparing, n 0–30 (Sparing: n dengan beberapa ukuran klub kedua).
    final combos = <(bool, bool, List<int>, bool)>[];
    for (final story in [false, true]) {
      for (final endless in [false, true]) {
        for (var n = 0; n <= 30; n++) {
          combos.add((story, endless, [n], !endless));
          combos.add((story, endless, [n], false));
          for (final m in [0, 1, 3, 7, 14, 30]) {
            combos.add((story, endless, [n, m], !endless));
          }
        }
      }
    }

    test('L1 setiap baris tepat sekali, urut Klasemen / klub', () {
      for (final (story, endless, counts, pairs) in combos) {
        final g = lengkapGrid(story: story, endless: endless, rowCounts: counts, pairs: pairs);
        final reason = '$story $endless $counts';
        final got = [for (final c in g.columns.expand((c) => c).whereType<LengkapRowCell>()) (c.club, c.row)];
        final expected = [
          for (var club = 0; club < counts.length; club++)
            for (var i = 0; i < counts[club]; i++) (counts.length == 2 ? club : 0, i),
        ];
        expect(got, expected, reason: reason);
        final heads = g.columns.expand((c) => c).whereType<LengkapClubCell>().map((c) => c.club).toList();
        final total = counts.fold<int>(0, (a, b) => a + b);
        expect(heads, counts.length == 2 && total > 0 ? [0, 1] : isEmpty, reason: reason);
      }
    });

    test('L2 Fixed satu kolom; dua kolom per klub: satu klub per kolom, diawali kepalanya', () {
      for (final (story, endless, counts, pairs) in combos) {
        final g = lengkapGrid(story: story, endless: endless, rowCounts: counts, pairs: pairs);
        if (!endless) expect(g.columns.length, 1, reason: '$story $counts');
        if (counts.length == 2 && g.columns.length == 2) {
          for (var c = 0; c < 2; c++) {
            final col = g.columns[c];
            expect(col.first, isA<LengkapClubCell>());
            expect(col.whereType<LengkapClubCell>().length, 1);
            expect(col.map((x) => x is LengkapRowCell ? x.club : (x as LengkapClubCell).club).toSet(), {c});
          }
        }
      }
    });

    test('L3 satuan × tinggiBaris ≤ ruang, batas, s tidak naik saat satuan bertambah', () {
      for (final sizing in LengkapSizing.values) {
        final spec = lengkapSizingSpecs[sizing]!;
        for (final space in [100.0, 209.0, 238.0, 336.0]) {
          double? prevScale;
          for (var u = 1; u <= 40; u++) {
            final d = lengkapDensity(sizing: sizing, units: u, space: space);
            expect(u * d.rowHeight, lessThanOrEqualTo(space + 1e-9));
            expect(d.rowHeight, lessThanOrEqualTo(spec.maxRow));
            expect(d.scale, lessThanOrEqualTo(spec.maxScale));
            if (prevScale != null) expect(d.scale, lessThanOrEqualTo(prevScale + 1e-12));
            prevScale = d.scale;
          }
        }
      }
    });

    test('L4 deterministik: masukan sama, hasil sama', () {
      final a = _sparingMixed(16, 14);
      final b = _sparingMixed(16, 14);
      expect((a.sizing, a.units, a.columns.length), (b.sizing, b.units, b.columns.length));
      final d1 = lengkapDensity(sizing: a.sizing, units: a.units, space: 226);
      final d2 = lengkapDensity(sizing: b.sizing, units: b.units, space: 226);
      expect((d1.rowHeight, d1.scale), (d2.rowHeight, d2.scale));
    });

    test('susunan ikut target dan jumlah kolom', () {
      for (final (story, endless, counts, pairs) in combos) {
        final g = lengkapGrid(story: story, endless: endless, rowCounts: counts, pairs: pairs);
        final two = g.columns.length == 2;
        final want = story
            ? (two ? LengkapSizing.story2 : LengkapSizing.story1)
            : (two ? LengkapSizing.feed2 : LengkapSizing.feed1);
        expect(g.sizing, want);
      }
    });
  });
}
