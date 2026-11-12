import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_ball.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'podium_poster_data.dart';

/// Golden PodiumPoster (PP-2): gambar Feed 360 × 360 di x 0 dan Story 360 × 640 di x 374 (11d, 13r, 18c–18p, 18s,
/// 18t), 18q (lima Feed) dan 18r (dua belas Feed) yang membungkus baris (kisi 374 pt), serta kartu pratinjau 358 × 372
/// di layar 11a, 11c, 13q, 18a, 18b (hanya wilayah posternya). Data = `podium_poster_data.dart` (teks frame).
void main() {
  final theme = MabarTheme.light();
  const feedAt = Rect.fromLTWH(0, 0, 360, 360), storyAt = Rect.fromLTWH(374, 0, 360, 640);

  PodiumTheme themeOf(String key) => switch (key) {
    'padel' => PodiumTheme.court(SportType.padel),
    'tennis' => PodiumTheme.court(SportType.tennis),
    _ => PodiumTheme.gradient(ShareTheme.values.byName(key)),
  };

  /// Poster di [at] dalam layar frame [frame]; mengembalikan datanya untuk assert benda kecil.
  Future<void> check(
    WidgetTester tester, {
    required String frame,
    required Rect at,
    required PodiumFrameCase c,
    required PodiumPosterTarget target,
    required String label,
    double maxDiffRatio = 0.02,
  }) async {
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        height: at.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(target == PodiumPosterTarget.card ? MabarRadius.poster : 4),
          child: PodiumPoster(data: c.data, theme: themeOf(c.theme), target: target),
        ),
      ),
      frame,
      at,
      label: label,
      maxDiffRatio: maxDiffRatio,
    );
    _expectDetails(c.data);
  }

  // 18c K61 … 18t K69: Feed + Story satu data.
  const pairs = <(String, String)>[
    ('11d', 'K63 nama turnamen dua baris, fakta 9,3, 1 WO'),
    ('13r', 'K62 Sparing 7 – 5'),
    ('18c', 'K61 Mixed 2·1·3'),
    ('18d', 'K63 tanpa nama'),
    ('18e', 'K61 Fixed pasangan Win %'),
    ('18f', 'K64 kembar #1 #2 #2'),
    ('18g', 'K64 kembar #1 #1 #2'),
    ('18h', 'K65 empat anak tangga'),
    ('18i', 'K65 dipangkas dua anak tangga'),
    ('18j', 'K65 dua pasangan'),
    ('18k', 'K63 Sementara R3'),
    ('18l', 'K71 pasangan dan pemain bercampur'),
    ('18m', 'K61 nama sangat panjang'),
    ('18n', 'K62 klub kedua unggul'),
    ('18o', 'K62 Seri'),
    ('18p', 'K62 6½ – 5½'),
    ('18s', 'K68 lebih dari empat di #1'),
    ('18t', 'K69 belum ada match selesai'),
  ];
  for (final (frame, name) in pairs) {
    for (final (target, at) in [(PodiumPosterTarget.feed, feedAt), (PodiumPosterTarget.story, storyAt)]) {
      testWidgets('$frame $name ${target.name}', (tester) async {
        await check(
          tester,
          frame: frame,
          at: at,
          c: podiumFrames[frame]!.first,
          target: target,
          label: target.name,
          maxDiffRatio: _tolerance['$frame ${target.name}'] ?? 0.02,
        );
      });
    }
  }

  // Kisi 374 pt: kolom 0–2, baris 0–3 (urut dokumen).
  Rect cell(int i) => Rect.fromLTWH(374.0 * (i % 3), 374.0 * (i ~/ 3), 360, 360);

  for (final frame in ['18q', '18r']) {
    final cases = podiumFrames[frame]!;
    for (var i = 0; i < cases.length; i++) {
      final label = frame == '18q' ? 'K64/K65 kembar lain' : 'K66 tema ${cases[i].theme}';
      testWidgets('$frame $label feed $i', (tester) async {
        await check(
          tester,
          frame: frame,
          at: cell(i),
          c: cases[i],
          target: PodiumPosterTarget.feed,
          label: 'feed$i',
          maxDiffRatio: _tolerance['$frame feed$i'] ?? 0.02,
        );
      });
    }
  }

  // Kartu pratinjau 358 × 372 di layar Bagikan (hanya wilayah poster; layar penuh = PP-3).
  for (final (frame, name) in [
    ('11a', 'K65 Sementara #1 #1 #2'),
    ('11c', 'K65 tanpa nama'),
    ('13q', 'K62 Sparing'),
    ('18a', 'K61 Fixed tennis'),
    ('18b', 'K66 gradien nude'),
  ]) {
    testWidgets('$frame $name kartu', (tester) async {
      await check(
        tester,
        frame: frame,
        at: hifiRect(frame, 'podium'),
        c: podiumFrames[frame]!.first,
        target: PodiumPosterTarget.card,
        label: 'kartu',
        maxDiffRatio: _tolerance['$frame kartu'] ?? 0.02,
      );
    });
  }

  // Jumlah bola dan lencana (§16.7 #12): golden 2% bisa lolos tanpa benda kecil.
  const balls = {'18c': 3, '18e': 6, '18l': 5, '18n': 0, '18s': 0, '18t': 0};
  for (final MapEntry(key: frame, value: n) in balls.entries) {
    for (final target in [PodiumPosterTarget.feed, PodiumPosterTarget.story]) {
      testWidgets('$frame K61 bola di atas blok = $n (${target.name})', (tester) async {
        final c = podiumFrames[frame]!.first;
        await tester.pumpWidget(
          hifiStage(
            theme: theme,
            at: feedAt,
            child: PodiumPoster(data: c.data, theme: themeOf(c.theme), target: target),
          ),
        );
        final painter = tester
            .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PodiumScenePainter))
            .painter!;
        expect((painter as PodiumScenePainter).layout.balls, hasLength(n));
        // Wordmark kaki = satu MabarBall (bola blok digambar painter, bukan widget).
        expect(find.byType(MabarBall), findsOneWidget);
      });
    }
  }

  group('podiumLayout (logic.md §16.6)', () {
    List<PodiumBlockData> steps(List<int> levels) => [
      for (final l in levels) PodiumBlockData(level: l, face: '$l', balls: 1),
    ];
    List<double> heights(PodiumLayout l) => [for (final b in l.blocks) b.rect.height];

    test('K61 x awal blok dipusatkan: Feed 3 blok 55, 2 blok 71, 1 blok 121; kartu 3 blok 54', () {
      double x0(PodiumPosterTarget t, int n) => podiumLayout(
        target: t,
        blocks: steps([for (var i = 0; i < n; i++) i + 1]),
        panelRows: n,
      ).blocks.first.rect.left;
      expect(x0(PodiumPosterTarget.feed, 3), 55);
      expect(x0(PodiumPosterTarget.feed, 2), 71);
      expect(x0(PodiumPosterTarget.feed, 1), 121);
      expect(x0(PodiumPosterTarget.card, 3), 54);
    });

    test('K65 Story 18h empat anak tangga: 139 / 100 / 67 (batas tinggi)', () {
      final l = podiumLayout(target: PodiumPosterTarget.story, blocks: steps([2, 1, 3, 3]), panelRows: 4);
      expect(heights(l), [100, 139, 67, 67]);
      expect(l.base, 338);
    });

    test('K63 Story 11d judul dua baris: 160 / 115 / 77', () {
      final l = podiumLayout(target: PodiumPosterTarget.story, blocks: steps([2, 1, 3]), panelRows: 3, titleLines: 2);
      expect(heights(l), [115, 160, 77]);
      expect(l.base, 380);
      expect(l.backLine, 297);
    });

    test('K61 Story 18m pasangan, judul dua baris: 128 / 92 / 62', () {
      final l = podiumLayout(
        target: PodiumPosterTarget.story,
        blocks: steps([2, 1, 3]),
        panelRows: 3,
        pairSize: true,
        titleLines: 2,
      );
      expect(heights(l), [92, 128, 62]);
      expect(l.base, 344);
    });

    test('K61 Feed tidak tertekan batas tinggi: 96 / 68 / 46 walau judul dua baris', () {
      final l = podiumLayout(target: PodiumPosterTarget.feed, blocks: steps([2, 1, 3]), panelRows: 3, titleLines: 2);
      expect(heights(l), [68, 96, 46]);
    });

    test('K61 garis belakang: Feed 3 baris 174, Story 3 baris 288, 2 anak tangga 200, 4 baris 148, Kerumunan 226', () {
      double back(PodiumPosterTarget t, List<int> levels, {bool wide = false, int? rows}) =>
          podiumLayout(target: t, blocks: steps(levels), wide: wide, panelRows: rows ?? levels.length).backLine;
      expect(back(PodiumPosterTarget.feed, [2, 1, 3]), 174);
      expect(back(PodiumPosterTarget.story, [2, 1, 3]), 288);
      expect(back(PodiumPosterTarget.feed, [1, 2]), 200);
      expect(back(PodiumPosterTarget.feed, [2, 1, 3, 3]), 148);
      expect(back(PodiumPosterTarget.feed, [1], wide: true, rows: 1), 226);
    });

    test('K69 Kosong: tanpa blok, garis belakang sama dengan poster tiga baris (18c)', () {
      final feed = podiumLayout(target: PodiumPosterTarget.feed, blocks: const [], panelRows: 0);
      final story = podiumLayout(target: PodiumPosterTarget.story, blocks: const [], panelRows: 0);
      expect(feed.blocks, isEmpty);
      expect(feed.backLine, 174);
      expect(story.backLine, 288);
    });

    test('K68 Kerumunan: satu blok selebar tiga anak tangga, tanpa bola', () {
      final l = podiumLayout(
        target: PodiumPosterTarget.feed,
        blocks: const [PodiumBlockData(level: 1, face: '1')],
        wide: true,
        panelRows: 1,
      );
      expect(l.blocks.single.rect.left, 55);
      expect(l.blocks.single.rect.width, 234);
      expect(l.balls, isEmpty);
    });

    test('K62 angka muka: 0,656 × tinggi; "6½" dikecilkan sampai ±70% lebar blok (Feed 63, Story 80, 18p)', () {
      List<double> faces(PodiumPosterTarget t) => podiumLayout(
        target: t,
        blocks: const [
          PodiumBlockData(level: 1, face: '6½'),
          PodiumBlockData(level: 2, face: '5½'),
        ],
        panelRows: 2,
      ).blocks.map((b) => b.faceSize).toList();
      expect(faces(PodiumPosterTarget.feed), [63, 45]);
      expect(faces(PodiumPosterTarget.story), [80, 80]);
      final single = podiumLayout(target: PodiumPosterTarget.story, blocks: steps([2, 1, 3]), panelRows: 3);
      expect(single.blocks.map((b) => b.faceSize), [84, 117, 56]);
    });

    test('K61 bola: Feed 22 satu bola, pasangan 19 dua bola jarak 2 (18j)', () {
      final l = podiumLayout(
        target: PodiumPosterTarget.feed,
        blocks: const [
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 2, face: '2', balls: 2),
        ],
        pairSize: true,
        panelRows: 2,
      );
      expect(l.balls.map((b) => b.rect.width).toSet(), {19});
      expect(l.balls.first.rect.left, 109.5);
      expect(l.balls[1].rect.left, 130.5);
    });
  });
}

/// Toleransi di atas 2% per frame; kosong = bawaan. Alasannya ditulis di tempat yang butuh (laporan PP-2).
const _tolerance = <String, double>{};

/// Lencana (nomor/skor) tiap baris tertulis di poster dan jumlah blok/bola cocok dengan data.
void _expectDetails(PodiumPosterData data) {
  for (final r in data.rows) {
    final badge = '${r.hash ? '#' : ''}${r.badge}';
    final n = data.rows.where((o) => '${o.hash ? '#' : ''}${o.badge}' == badge).length;
    expect(find.text(badge, findRichText: true), findsNWidgets(n), reason: 'lencana $badge');
  }
}
