import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/models/models.dart';

import '../hifi/hifi_golden.dart';

/// Kepala Lengkap + podium mini (logic.md §17.5, 17.6; tabel 17.10). Angka = teks dan SVG frame di
/// `design/hifi.html` (`.lhead` right, path garis belakang, rect blok, `<use href="#ball">`). Kepala diukur dengan
/// font hi-fi, jadi wajib [loadHifiFonts].
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHifiFonts();
  });

  const card = PodiumPosterTarget.card, feed = PodiumPosterTarget.feed, story = PodiumPosterTarget.story;
  const akhir = 'Klasemen akhir', garuda = 'Mabar Jumat PB Garuda', liga = 'Liga Akhir Tahun Padel Kemang';

  /// Anak tangga urutan slot (2 · 1 · 3 · 4) dengan [balls] bola per blok.
  List<PodiumBlockData> steps(List<int> levels, {int balls = 1}) => [
    for (final l in levels) PodiumBlockData(level: l, face: '$l', balls: balls),
  ];
  const kerumunan = [PodiumBlockData(level: 1, face: '1')];
  List<PodiumBlockData> klub(String a, String b, {bool firstLeads = true}) => [
    PodiumBlockData(level: firstLeads ? 1 : 2, face: a),
    PodiumBlockData(level: firstLeads ? 2 : 1, face: b),
  ];

  LengkapHead headOf(
    PodiumPosterTarget t,
    String title,
    String subtitle,
    List<PodiumBlockData> blocks, {
    bool wide = false,
  }) => lengkapHead(target: t, title: title, subtitle: subtitle, blocks: blocks, wide: wide);

  PodiumLayout miniOf(
    PodiumPosterTarget t,
    String title,
    String subtitle,
    List<PodiumBlockData> blocks, {
    bool wide = false,
    bool pairSize = false,
  }) => miniPodiumLayout(
    target: t,
    head: headOf(t, title, subtitle, blocks, wide: wide),
    blocks: blocks,
    wide: wide,
    pairSize: pairSize,
  );

  List<List<double>> rects(PodiumLayout l) => [
    for (final b in l.blocks) [b.rect.left, b.rect.top, b.rect.width, b.rect.height],
  ];
  List<double> faces(PodiumLayout l) => [for (final b in l.blocks) b.faceSize];

  group('kepala Lengkap (17.5, tabel kepala 17.10)', () {
    /// (judul, ukuran judul, baris, baris kecil, kanan, garis belakang).
    void expectHead(LengkapHead h, double titleSize, int lines, double sub, double right, double backLine) {
      expect(h.titleSize, titleSize, reason: 'ukuran judul');
      expect(h.titleLines, lines, reason: 'baris judul');
      expect(h.subSize, sub, reason: 'baris kecil');
      expect(h.right, right, reason: 'kanan kepala');
      expect(h.backLine, backLine, reason: 'garis belakang');
    }

    test('11b K82 kartu "Klasemen akhir": 22 · 1, 12,5, kanan 118, garis belakang 79', () {
      final h = headOf(card, akhir, 'Tennis · Fixed · 21 Okt 2026', steps([2, 1, 3], balls: 2));
      expectHead(h, 22, 1, 12.5, 118, 79);
      expect(h.top, 22);
      expect(h.width, 358 - 22 - 118);
    });

    test('11e/11f K82 judul bernama: kartu dan Feed 18,5 · 1 (75), Story 23 · 2 (191)', () {
      const sub = 'Klasemen akhir · 6 Nov 2026';
      expectHead(headOf(card, garuda, sub, steps([2, 1, 3])), 18.5, 1, 12.5, 118, 75);
      expectHead(headOf(feed, garuda, sub, steps([2, 1, 3])), 18.5, 1, 12.5, 118, 75);
      final s = headOf(story, garuda, sub, steps([2, 1, 3]));
      expectHead(s, 23, 2, 15, 126, 191);
      expect(s.top, 98);
    });

    test('11g/11k K82 Feed 22 · 1 (79), Story 27 · 1 (170)', () {
      const sub = 'Tennis · Fixed · 8 Nov 2026';
      expectHead(headOf(feed, akhir, sub, steps([2, 1, 3], balls: 2)), 22, 1, 12.5, 118, 79);
      expectHead(headOf(story, akhir, sub, steps([2, 1, 3], balls: 2)), 27, 1, 15, 126, 170);
    });

    test('11j K82 empat anak tangga: kanan 124, garis belakang 79', () {
      expectHead(headOf(card, akhir, 'Padel · Mixed · 21 Okt 2026', steps([2, 1, 3, 3])), 22, 1, 12.5, 124, 79);
    });

    test('11l K82 judul dua baris: Feed dan kartu 18,5 · 2 (96), Story 23 · 2 (191)', () {
      const sub = 'Klasemen akhir · 27 Des 2026';
      expectHead(headOf(feed, liga, sub, steps([2, 1, 3])), 18.5, 2, 12.5, 118, 96);
      expectHead(headOf(card, liga, sub, steps([2, 1, 3])), 18.5, 2, 12.5, 118, 96);
      expectHead(headOf(story, liga, sub, steps([2, 1, 3])), 23, 2, 15, 126, 191);
    });

    test('11m K84 baris kecil Story dikecilkan ke 13, bawah kepala pakai ukuran sesudahnya: 188 (bukan 191)', () {
      const sub = 'Klasemen sementara · 6 Nov 2026';
      expectHead(headOf(feed, garuda, sub, kerumunan, wide: true), 18.5, 1, 12.5, 118, 75);
      final s = headOf(story, garuda, sub, const []);
      expectHead(s, 23, 2, 13, 126, 188);
      expect(s.bottom, closeTo(98 + 2 * 23 * 1.1 + 6 + 13 * 1.2, 1e-9));
    });

    test('K84 baris kecil turun per 0,5 dan berhenti di 11 (lalu elipsis), tidak pernah dua baris', () {
      final h = headOf(story, garuda, 'Klasemen sementara · 6 Nov 2026 · ${'x' * 60}', steps([2, 1, 3]));
      expect(h.subSize, 11);
      expect(h.bottom, closeTo(98 + h.titleLines * h.titleSize * 1.1 + 6 + 11 * 1.2, 1e-9));
    });

    test('K82 judul lebih dari dua baris di 18,5/23: tetap dua baris (elipsis)', () {
      final h = headOf(feed, 'Turnamen Mabar Akhir Tahun Gabungan Klub Padel Se-Jabodetabek Kemang Raya', 'x', []);
      expect((h.titleSize, h.titleLines), (18.5, 2));
    });

    test('13s–13w K82 Sparing (Klub = 2 slot): kartu/Feed 108 (79), Story 114 (170)', () {
      const sub = 'Padel · Fixed · 4 Nov 2026';
      expectHead(headOf(card, akhir, sub, klub('7', '5')), 22, 1, 12.5, 108, 79);
      expectHead(headOf(feed, akhir, sub, klub('10', '6')), 22, 1, 12.5, 108, 79);
      expectHead(headOf(story, akhir, sub, klub('10', '6')), 27, 1, 15, 114, 170);
    });

    test('K89 Sparing 0 – 0 = Kosong: kolom judul selebar 3 slot (118 / 126)', () {
      expect(headOf(card, akhir, 'Padel · Fixed · 4 Nov 2026', const []).right, 118);
      expect(headOf(story, akhir, 'Padel · Fixed · 4 Nov 2026', const []).right, 126);
    });

    test(
      'K82 kanan kepala per slot: Steps 1 → 74 (78), 2 → 108 (114), 3/Kerumunan/Kosong → 118 (126), 4 → 124 (130)',
      () {
        double right(PodiumPosterTarget t, List<PodiumBlockData> b, {bool wide = false}) =>
            headOf(t, akhir, 'x', b, wide: wide).right;
        for (final (t, expected) in [
          (card, [74.0, 108.0, 118.0, 124.0, 118.0, 118.0]),
          (feed, [74.0, 108.0, 118.0, 124.0, 118.0, 118.0]),
          (story, [78.0, 114.0, 126.0, 130.0, 126.0, 126.0]),
        ]) {
          expect(
            [
              right(t, steps([1])),
              right(t, steps([2, 1])),
              right(t, steps([2, 1, 3])),
              right(t, steps([2, 1, 3, 3])),
              right(t, kerumunan, wide: true),
              right(t, const []),
            ],
            expected,
            reason: t.name,
          );
        }
      },
    );
  });

  group('podium mini (17.6, tabel podium mini 17.10)', () {
    test('11b K79 kartu Fixed: rect blok, angka 16 / 22 / 10, 6 bola 8 jarak 1', () {
      final l = miniOf(card, akhir, 'Tennis · Fixed · 21 Okt 2026', steps([2, 1, 3], balls: 2), pairSize: true);
      expect(rects(l), [
        [252, 55, 26, 24],
        [278, 45, 26, 34],
        [304, 63, 26, 16],
      ]);
      expect(faces(l), [16, 22, 10]);
      expect(l.balls, hasLength(6));
      expect(l.balls.map((b) => b.rect.width).toSet(), {8});
      expect([l.balls[0].rect.left, l.balls[1].rect.left], [259.5, 268.5]);
      expect(l.balls[0].rect.top, 46);
      // Garis belakang = dasar blok; painter dan garis lapangan sama dengan Ringkas.
      expect(l.base, 79);
      expect(l.backLine, 79);
      expect((l.cornerX, l.lineWidth), (40, 4.5));
      expect(l.depth, const Offset(6, -4));
      expect(l.panel, isNull);
    });

    test('11f K79 Feed: rect blok, 3 bola 9, blok tengah x 291,5 y 31', () {
      final l = miniOf(feed, garuda, 'Klasemen akhir · 6 Nov 2026', steps([2, 1, 3]));
      expect(rects(l), [
        [254, 51, 26, 24],
        [280, 41, 26, 34],
        [306, 59, 26, 16],
      ]);
      expect(faces(l), [16, 22, 10]);
      expect(l.balls, hasLength(3));
      expect((l.balls[1].rect.left, l.balls[1].rect.top, l.balls[1].rect.width), (291.5, 31, 9));
    });

    test('11f K79 Story: rect blok, angka 24 / 34 / 16, 3 bola 12, blok kiri x 258 y 140,5', () {
      final l = miniOf(story, garuda, 'Klasemen akhir · 6 Nov 2026', steps([2, 1, 3]));
      expect(rects(l), [
        [246, 154, 28, 37],
        [274, 139, 28, 52],
        [302, 166, 28, 25],
      ]);
      expect(faces(l), [24, 34, 16]);
      expect(l.balls, hasLength(3));
      expect((l.balls[0].rect.left, l.balls[0].rect.top, l.balls[0].rect.width), (258, 140.5, 12));
      expect((l.cornerX, l.lineWidth), (44, 5.5));
      expect(l.depth, const Offset(8, -5));
    });

    test('11g K79 Story pasangan: bola 10 jarak 1 (x 253,5 dan 264,5, y 121,5)', () {
      final l = miniOf(story, akhir, 'Tennis · Fixed · 21 Okt 2026', steps([2, 1, 3], balls: 2), pairSize: true);
      expect(l.balls, hasLength(6));
      expect([l.balls[0].rect.left, l.balls[1].rect.left], [253.5, 264.5]);
      expect(l.balls[0].rect.top, 121.5);
    });

    test('11j K79 empat anak tangga (kartu 5 pemain): lebar 21, angka 16 / 22 / 10 / 10, 4 bola', () {
      final l = miniOf(card, akhir, 'Padel · Mixed · 21 Okt 2026', steps([2, 1, 3, 3]));
      expect(rects(l), [
        [246, 55, 21, 24],
        [267, 45, 21, 34],
        [288, 63, 21, 16],
        [309, 63, 21, 16],
      ]);
      expect(faces(l), [16, 22, 10, 10]);
      expect(l.balls, hasLength(4));
      expect((l.balls[0].rect.left, l.balls[0].rect.top), (255, 45));
    });

    test('11m K85 Feed Kerumunan: satu blok 78 lebar level 1, angka 22, tanpa bola', () {
      final l = miniOf(feed, garuda, 'Klasemen sementara · 6 Nov 2026', kerumunan, wide: true);
      expect(rects(l), [
        [254, 41, 78, 34],
      ]);
      expect(faces(l), [22]);
      expect(l.balls, isEmpty);
    });

    test('11m K87 Story Kosong: tanpa blok dan bola, garis belakang 188 tetap', () {
      final l = miniOf(story, garuda, 'Klasemen sementara · 6 Nov 2026', const []);
      expect(l.blocks, isEmpty);
      expect(l.balls, isEmpty);
      expect(l.backLine, 188);
    });

    test('13s/13t K79 Sparing: dua blok skor klub, klub pertama kiri, tanpa bola', () {
      const sub = 'Padel · Fixed · 4 Nov 2026';
      final c = miniOf(card, akhir, sub, klub('7', '5'));
      expect(rects(c), [
        [262, 45, 34, 34],
        [296, 55, 34, 24],
      ]);
      expect(faces(c), [22, 16]);
      expect(c.balls, isEmpty);
      expect(rects(miniOf(feed, akhir, sub, klub('7', '5'))).first, [264, 45, 34, 34]);
      final s = miniOf(story, akhir, sub, klub('7', '5'));
      expect(rects(s), [
        [258, 118, 36, 52],
        [294, 133, 36, 37],
      ]);
      expect(faces(s), [34, 24]);
    });

    test('13u/13v/13w K79 angka dua karakter dikecilkan rumus Ringkas: kartu "10" 22, Story "10" 23 / "6" 24', () {
      const sub = 'Padel · Mixed · 4 Nov 2026';
      expect(faces(miniOf(card, akhir, sub, klub('10', '6'))), [22, 16]);
      final s = miniOf(story, akhir, sub, klub('10', '6'));
      expect(rects(s).first, [258, 118, 36, 52]);
      expect(faces(s), [23, 24]);
    });

    test('K79 rata kanan: kanan blok terakhir + dx = W − 22 untuk 1–4 slot dan Kerumunan', () {
      for (final t in [card, feed, story]) {
        for (final (blocks, wide) in [
          (steps([1]), false),
          (steps([2, 1]), false),
          (steps([2, 1, 3]), false),
          (steps([2, 1, 3, 3]), false),
          (kerumunan, true),
        ]) {
          final l = miniOf(t, akhir, 'x', blocks, wide: wide);
          expect(l.blocks.last.rect.right + l.depth.dx, t.designSize.width - 22, reason: '${t.name} ${blocks.length}');
        }
      }
    });

    test('K79 tinggi tetap: tidak ikut batas tinggi atau ukuran pasangan (beda dengan Ringkas)', () {
      List<double> heights(PodiumLayout l) => [for (final b in l.blocks) b.rect.height];
      expect(heights(miniOf(feed, liga, 'x', steps([2, 1, 3]), pairSize: true)), [24, 34, 16]);
      expect(heights(miniOf(story, liga, 'x', steps([2, 1, 3]), pairSize: true)), [37, 52, 25]);
    });
  });

  group('widget bersama (17.7 lencana, kaki)', () {
    final theme = PodiumTheme.court(SportType.padel);

    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: MabarTheme.light(),
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    );

    testWidgets('PodiumRank: ukuran dari pemanggil, #1 lencana emas, "#" bisa dihilangkan', (tester) async {
      await pump(tester, PodiumRank(rank: '1', gold: true, fontSize: 15 * 1.04, theme: theme));
      final rich = tester.widget<RichText>(
        find.descendant(of: find.byType(PodiumRank), matching: find.byType(RichText)),
      );
      expect(rich.text.toPlainText(), '#1');
      final sizes = <double?>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) sizes.add(span.style?.fontSize);
        return true;
      });
      expect(sizes, [closeTo(15.6, 1e-9), closeTo(15.6, 1e-9)]);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(PodiumRank), matching: find.byType(DecoratedBox)),
      );
      expect((box.decoration as BoxDecoration).color, PodiumTheme.goldFront);

      await pump(tester, PodiumRank(rank: '7', hash: false, gold: false, fontSize: 13, theme: theme));
      expect(find.text('7', findRichText: true), findsOneWidget);
      expect(find.descendant(of: find.byType(PodiumRank), matching: find.byType(DecoratedBox)), findsNothing);
    });

    testWidgets('PodiumSignature: tinggi dari pemanggil, fakta mengecil supaya tidak terpotong di lebar sempit', (
      tester,
    ) async {
      const facts = 'Padel · 20 pemain · 8 round · 32 match';
      await pump(tester, PodiumSignature(facts: facts, theme: theme, height: 34));
      expect(tester.getSize(find.byType(PodiumSignature)).height, 34);
      double factsSize() => tester.widget<Text>(find.text(facts)).style!.fontSize!;
      // Fakta 9,5 (keputusan 92: kaki satu tingkat lebih kecil).
      expect(factsSize(), 9.5);

      await tester.pumpWidget(
        MaterialApp(
          theme: MabarTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: PodiumSignature(facts: facts, theme: theme, height: 26),
              ),
            ),
          ),
        ),
      );
      expect(factsSize(), lessThan(9.5));
      expect(find.text('Match Addict'), findsOneWidget);
    });
  });
}
