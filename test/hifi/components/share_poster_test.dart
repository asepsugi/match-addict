import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/share/podium.dart';

import '../hifi_golden.dart';
import 'share_poster_data.dart';

/// Golden SharePoster arah B "Podium mini" (logic.md §17.11): kartu pratinjau 358 × 372 di layar Bagikan (11b, 11e,
/// 11h, 11i; hanya wilayah posternya), lembar gambar Feed 360 × 360 di x 0 dan Story 360 × 640 di x 374 (11f, 11g, 11k,
/// 11l, 11m), plus kartu di x 748 (11k, 11l), dan delapan kartu skala 1:2 (11j). Baris = `share_poster_data.dart`
/// (teks frame); kepala, tema, dan fakta = teks frame di sini; blok podium mini dari [Podium.of] + [podiumBlocks]
/// atas baris itu (jalur yang sama dengan `sharePosterData`).
void main() {
  final theme = MabarTheme.light();
  const feedAt = Rect.fromLTWH(0, 0, 360, 360), storyAt = Rect.fromLTWH(374, 0, 360, 640);
  const cardAt = Rect.fromLTWH(748, 0, 358, 372);
  final padel = PodiumTheme.court(SportType.padel), tennis = PodiumTheme.court(SportType.tennis);
  final peach = PodiumTheme.gradient(ShareTheme.peach), biru = PodiumTheme.gradient(ShareTheme.biru);

  setUpAll(loadHifiFonts);

  SharePosterData dataOf(
    List<SharePosterRow> rows, {
    required String title,
    required String subtitle,
    required String facts,
    required bool endless,
    SportType sport = SportType.padel,
  }) {
    final entries = [
      for (final r in rows)
        StandingEntry(
          players: [for (final n in r.names) Player(id: n, name: n)],
          standing: PlayerStanding(
            player: Player(id: r.names.first, name: r.names.first),
          ),
          position: r.position,
        ),
    ];
    final mini = podiumBlocks(Podium.of(entries: entries));
    return SharePosterData(
      sport: sport,
      title: title,
      subtitle: subtitle,
      blocks: mini.blocks,
      wide: mini.wide,
      pairBalls: mini.pairSize,
      endless: endless,
      rows: rows,
      facts: facts,
    );
  }

  Widget poster(SharePosterData data, PodiumTheme t, PodiumPosterTarget target) => ClipRRect(
    borderRadius: BorderRadius.circular(target == PodiumPosterTarget.card ? MabarRadius.poster : 4),
    child: SharePoster(data: data, theme: t, target: target),
  );

  Future<void> check(
    WidgetTester tester, {
    required String frame,
    required Rect at,
    required SharePosterData data,
    required PodiumTheme t,
    required PodiumPosterTarget target,
    required String label,
    double maxDiffRatio = 0.02,
  }) async {
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, at: at, height: at.height, child: poster(data, t, target)),
      frame,
      at,
      label: label,
      maxDiffRatio: maxDiffRatio,
    );
    _expectText(data);
  }

  // ---------- Data per frame (teks frame) ----------
  SharePosterData fixed10() => dataOf(
    posterRows[('11b', 0)]!,
    title: 'Klasemen akhir',
    subtitle: 'Tennis · Fixed · 21 Okt 2026',
    facts: '10 pasangan · 9 round · 45 match',
    endless: false,
    sport: SportType.tennis,
  );
  SharePosterData mixed20(int index) => dataOf(
    posterRows[(index < 0 ? '11e' : '11f', index < 0 ? 0 : index)]!,
    title: 'Mabar Jumat PB Garuda',
    subtitle: 'Klasemen akhir · 6 Nov 2026',
    facts: 'Padel · 20 pemain · 8 round · 32 match',
    endless: true,
  );
  SharePosterData mixedPlain(String frame, int index, String facts) => dataOf(
    posterRows[(frame, index)]!,
    title: 'Klasemen akhir',
    subtitle: 'Padel · Mixed · 21 Okt 2026',
    facts: facts,
    endless: true,
  );
  SharePosterData fixed15(int index) => dataOf(
    posterRows[('11k', index)]!,
    title: 'Klasemen akhir',
    subtitle: 'Tennis · Fixed · 8 Nov 2026',
    facts: '15 pasangan · 10 round · 40 match',
    endless: false,
    sport: SportType.tennis,
  );
  SharePosterData mixed30(int index) => dataOf(
    posterRows[('11l', index)]!,
    title: 'Liga Akhir Tahun Padel Kemang',
    subtitle: 'Klasemen akhir · 27 Des 2026',
    facts: 'Padel · 30 pemain · 8 round · 32 match',
    endless: true,
  );
  SharePosterData crowd(bool empty) => dataOf(
    empty ? const [] : posterRows[('11m', 0)]!,
    title: 'Mabar Jumat PB Garuda',
    subtitle: 'Klasemen sementara · 6 Nov 2026',
    facts: 'Padel · 12 pemain · R1 · ${empty ? 0 : 3} dari 3 match',
    endless: true,
  );

  // ---------- Kartu pratinjau di layar Bagikan ----------
  for (final (frame, name, data, t) in [
    ('11b', 'K79 Fixed 10 pasangan, peach', fixed10, peach),
    ('11e', 'K82 Mixed 20 bernama, lapangan', () => mixed20(-1), padel),
    ('11h', 'K80 Mixed 12 dua kolom 6–6, biru', () => mixedPlain('11h', 0, '12 pemain · 6 round · 18 match'), biru),
    ('11i', 'K81 Mixed 13 dua kolom 7–6', () => mixedPlain('11i', 0, '13 pemain · 6 round · 18 match'), padel),
  ]) {
    testWidgets('$frame $name kartu', (tester) async {
      await check(
        tester,
        frame: frame,
        at: hifiRect(frame, 'poster'),
        data: data(),
        t: t,
        target: PodiumPosterTarget.card,
        label: 'kartu',
      );
    });
  }

  // ---------- Lembar gambar Feed + Story (+ kartu) ----------
  for (final (target, at, index) in [(PodiumPosterTarget.feed, feedAt, 0), (PodiumPosterTarget.story, storyAt, 1)]) {
    testWidgets('11f K81 Mixed 20 bernama ${target.name}', (tester) async {
      await check(tester, frame: '11f', at: at, data: mixed20(index), t: padel, target: target, label: target.name);
    });
    testWidgets('11g K79 Fixed 10 pasangan ${target.name}', (tester) async {
      await check(tester, frame: '11g', at: at, data: fixed10(), t: peach, target: target, label: target.name);
    });
    testWidgets('11m K85 ${index == 0 ? 'lebih dari empat di #1' : 'K87 belum ada match'} ${target.name}', (
      tester,
    ) async {
      await check(tester, frame: '11m', at: at, data: crowd(index == 1), t: padel, target: target, label: target.name);
    });
  }
  for (final (target, at, index) in [
    (PodiumPosterTarget.feed, feedAt, 0),
    (PodiumPosterTarget.story, storyAt, 1),
    (PodiumPosterTarget.card, cardAt, 2),
  ]) {
    testWidgets('11k K88 Fixed 15 pasangan ${target.name}', (tester) async {
      await check(tester, frame: '11k', at: at, data: fixed15(index), t: tennis, target: target, label: target.name);
    });
    testWidgets('11l K81 Mixed 30 judul dua baris ${target.name}', (tester) async {
      await check(
        tester,
        frame: '11l',
        at: at,
        data: mixed30(index),
        t: biru,
        target: target,
        label: target.name,
        // §17.11: 30 baris rapat (huruf ±9 pt, line-height 1–1,2), sisa geseran huruf ≤ 1 pt seperti Lengkap lama.
        maxDiffRatio: target == PodiumPosterTarget.card ? 0.02 : 0.03,
      );
    });
  }

  // ---------- 11j: delapan kartu skala 1:2 (179 × 186), tujuh per baris, kisi 193 × 228 pt ----------
  const facts11j = [
    '5 pemain · 5 round · 5 match',
    '7 pemain · 7 round · 7 match',
    '9 pemain · 6 round · 12 match',
    '11 pemain · 6 round · 12 match',
    '13 pemain · 6 round · 18 match',
    '15 pemain · 7 round · 21 match',
    '17 pemain · 6 round · 24 match',
    '19 pemain · 7 round · 28 match',
  ];
  for (var i = 0; i < facts11j.length; i++) {
    testWidgets('11j K81 Mixed ${5 + 2 * i} pemain kartu 1:2', (tester) async {
      final at = Rect.fromLTWH(193.0 * (i % 7), 228.0 * (i ~/ 7), 179, 186);
      final data = mixedPlain('11j', i, facts11j[i]);
      await expectRegionMatchesHifi(
        tester,
        hifiStage(
          theme: theme,
          at: at,
          height: at.height,
          child: FittedBox(child: poster(data, padel, PodiumPosterTarget.card)),
        ),
        '11j',
        at,
        label: 'kartu$i',
      );
      _expectText(data);
    });
  }

  // ---------- Benda kecil yang lolos golden 2% (§17.11, jebakan #12) ----------
  Future<PodiumLayout> layoutOf(WidgetTester tester, SharePosterData data, PodiumPosterTarget target) async {
    await tester.pumpWidget(hifiStage(theme: theme, at: feedAt, child: poster(data, padel, target)));
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PodiumScenePainter),
    );
    return (paint.painter! as PodiumScenePainter).layout;
  }

  int goldBadges(WidgetTester tester) =>
      tester.widgetList<PodiumRank>(find.byType(PodiumRank)).where((r) => r.gold).length;

  for (final (name, data, target, balls) in [
    ('11b K61 pasangan 2 bola per blok', fixed10, PodiumPosterTarget.card, 6),
    ('11f Mixed 1 bola per blok', () => mixed20(0), PodiumPosterTarget.feed, 3),
    ('11j-5 empat anak tangga', () => mixedPlain('11j', 0, facts11j[0]), PodiumPosterTarget.card, 4),
    ('11m K68 Kerumunan tanpa bola', () => crowd(false), PodiumPosterTarget.feed, 0),
    ('11m K69 Kosong tanpa bola', () => crowd(true), PodiumPosterTarget.story, 0),
  ]) {
    testWidgets('$name: bola = $balls', (tester) async {
      expect((await layoutOf(tester, data(), target)).balls, hasLength(balls));
    });
  }

  testWidgets('11m K85 Feed: satu blok lebar (254,41,78,34) angka 22, enam lencana emas', (tester) async {
    final layout = await layoutOf(tester, crowd(false), PodiumPosterTarget.feed);
    expect(layout.blocks.single.rect, const Rect.fromLTWH(254, 41, 78, 34));
    expect(layout.blocks.single.faceSize, 22);
    expect(goldBadges(tester), 6);
  });

  testWidgets('11m K87 Story: tanpa blok, tanpa baris, panel hanya kaki', (tester) async {
    final layout = await layoutOf(tester, crowd(true), PodiumPosterTarget.story);
    expect(layout.blocks, isEmpty);
    expect(find.byType(PodiumRank), findsNothing);
    expect(find.text('Padel · 12 pemain · R1 · 0 dari 3 match'), findsOneWidget);
  });

  testWidgets('11b kartu: blok (252,55,26,24) (278,45,26,34) (304,63,26,16), angka 16 / 22 / 10', (tester) async {
    final layout = await layoutOf(tester, fixed10(), PodiumPosterTarget.card);
    expect(
      [for (final b in layout.blocks) b.rect],
      const [Rect.fromLTWH(252, 55, 26, 24), Rect.fromLTWH(278, 45, 26, 34), Rect.fromLTWH(304, 63, 26, 16)],
    );
    expect([for (final b in layout.blocks) b.faceSize], [16, 22, 10]);
    expect(goldBadges(tester), 1);
  });

  // ---------- Ukuran baris: s dan kn (§17.4, 17.7) ----------
  double nameSize(WidgetTester tester, String name) => tester.widget<Text>(find.text(name)).style!.fontSize!;

  for (final (frame, data, target, name, size) in [
    // feed1 s 1,04 (batas), kn 1: 13,5 × 1,04.
    ('11b', fixed10, PodiumPosterTarget.card, 'Gina Rosalia + Hana Taslim', 13.5 * 1.04),
    // feed2 s 1, kn 0,94 (§17.7).
    ('11e', () => mixed20(-1), PodiumPosterTarget.card, 'Citra Lestari', 12 * 0.94),
    ('11f', () => mixed20(0), PodiumPosterTarget.feed, 'Citra Lestari', 12 * 0.94),
    (
      '11h',
      () => mixedPlain('11h', 0, ''),
      PodiumPosterTarget.card,
      posterRows[('11h', 0)]![1].names.single,
      12 * 0.94,
    ),
    // story2 s 1, kn 0,86.
    ('11l', () => mixed30(1), PodiumPosterTarget.story, posterRows[('11l', 1)]![1].names.single, 12 * 0.86),
  ]) {
    testWidgets('$frame ${target.name} K80 ukuran nama = ${size.toStringAsFixed(2)}', (tester) async {
      await tester.pumpWidget(hifiStage(theme: theme, at: feedAt, child: poster(data(), padel, target)));
      expect(nameSize(tester, name), closeTo(size, 0.01));
    });
  }

  testWidgets('11j kn: 15 dan 17 pemain 0,94, 19 pemain 0,86, lainnya 1', (tester) async {
    for (var i = 0; i < facts11j.length; i++) {
      final rows = posterRows[('11j', i)]!;
      await tester.pumpWidget(
        hifiStage(
          theme: theme,
          at: feedAt,
          child: poster(mixedPlain('11j', i, facts11j[i]), padel, PodiumPosterTarget.card),
        ),
      );
      final base = rows.length <= 10 ? 13.5 * 1.04 : 12.0;
      final kn = switch (rows.length) {
        15 || 17 => 0.94,
        19 => 0.86,
        _ => 1.0,
      };
      expect(nameSize(tester, rows[1].names.single), closeTo(base * kn, 0.01), reason: '${rows.length} pemain');
    }
  });
}

/// Judul, baris kecil, fakta, dan nomor tiap baris tertulis (teks kecil lolos golden walau salah).
void _expectText(SharePosterData data) {
  expect(find.text(data.title), findsOneWidget);
  expect(find.text(data.subtitle), findsOneWidget);
  expect(find.text(data.facts), findsOneWidget);
  for (final r in data.allRows) {
    final n = data.allRows.where((o) => o.position == r.position).length;
    expect(find.text('#${r.position}', findRichText: true), findsNWidgets(n), reason: 'nomor #${r.position}');
  }
}
