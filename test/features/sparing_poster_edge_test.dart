import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';

import '../hifi/hifi_golden.dart';
import '../hifi/screens/schedule_fixture.dart';
import '../hifi/screens/sparing_fixture.dart';

/// Kasus tepi poster Lengkap sparing (saran review SP-15, QA 3.2.0; ditulis ulang untuk arah B, PL-3): nama klub
/// panjang di kepala `.lclub` terpotong elipsis, skor ½ dan Seri di blok podium mini, sparing tanpa hasil (0 – 0) panel
/// hanya kaki. Tanpa golden: yang dicek teks, blok, dan ukuran render dengan font asli.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final now = sparingAt(6);

  SharePosterData posterOf(ActiveTournament active) {
    final container = ProviderContainer(
      overrides: [
        tournamentProvider.overrideWith(() => LoadedTournament(active)),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return sharePosterData(
      active: active,
      entries: container.read(standingEntriesProvider),
      method: container.read(rankingMethodProvider),
      isFinal: active.isFinal(now),
      clubResult: container.read(clubScoreProvider),
      clubEntries: container.read(clubStandingEntriesProvider),
    );
  }

  /// Nama klub diganti di data poster (teks jadi dari provider, jadi cukup di lapisan ini).
  SharePosterData withClubNames(SharePosterData d, String a, String b) => SharePosterData(
    sport: d.sport,
    title: d.title,
    subtitle: d.subtitle,
    blocks: d.blocks,
    wide: d.wide,
    pairBalls: d.pairBalls,
    endless: d.endless,
    rows: d.rows,
    clubs: [
      for (final (i, c) in d.clubs!.indexed) SharePosterClub(name: i == 0 ? a : b, detail: c.detail, rows: c.rows),
    ],
    facts: d.facts,
  );

  Future<void> pump(WidgetTester tester, SharePosterData data, PodiumPosterTarget target) async {
    await loadHifiFonts();
    final size = target.designSize;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MabarTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SharePoster(data: data, theme: PodiumTheme.court(SportType.padel), target: target),
          ),
        ),
      ),
    );
  }

  RenderParagraph paragraph(WidgetTester tester, Finder f) => tester.renderObject<RenderParagraph>(f);

  /// Teks muat di kotaknya: lebar isi alami <= lebar kotak yang diberikan layout.
  void expectFits(WidgetTester tester, Finder f) {
    final p = paragraph(tester, f);
    expect(p.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(p.size.width + 0.5), reason: '$f terpotong');
  }

  PodiumLayout sceneOf(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PodiumScenePainter),
                  )
                  .painter!
              as PodiumScenePainter)
          .layout;

  const longA = 'Persatuan Bulutangkis dan Tenis Garuda Nusantara Jaya Raya';
  const longB = 'Perkumpulan Padel Matcha Club Kota Bandung Selatan Sentosa';

  for (final target in PodiumPosterTarget.values) {
    testWidgets('K83 nama klub panjang ${target.name}: kepala klub elipsis, detail dan nilai utuh, tanpa overflow', (
      tester,
    ) async {
      final data = withClubNames(posterOf(sparingFull()), longA, longB);
      await pump(tester, data, target);
      expect(tester.takeException(), isNull);

      for (final name in [longA, longB]) {
        expect(find.text(name), findsOneWidget);
        expect(paragraph(tester, find.text(name)).didExceedMaxLines, isTrue, reason: '$name tidak dipotong');
      }
      for (final t in ['56 game · +13', '49 game · −13', for (final c in data.clubs!) c.rows.first.value]) {
        expect(find.text(t), findsOneWidget);
        expectFits(tester, find.text(t));
      }
      // Skor klub hanya di blok podium mini, bukan teks di panel.
      expect(find.text('7'), findsNothing);
      expect([for (final b in sceneOf(tester).blocks) b.face], ['7', '5']);
    });
  }

  for (final target in PodiumPosterTarget.values) {
    testWidgets('K62 skor klub ½ (14u): "6½" dan "5½" di muka blok, muat di lebar blok ${target.name}', (tester) async {
      final data = posterOf(sparing14u());
      expect([for (final b in data.blocks) b.face], ['6½', '5½']);
      await pump(tester, data, target);
      expect(tester.takeException(), isNull);
      for (final b in sceneOf(tester).blocks) {
        final face = TextPainter(
          text: TextSpan(
            text: b.face,
            style: TextStyle(
              fontFamily: MabarType.family,
              fontSize: b.faceSize,
              fontWeight: FontWeight.w800,
              fontVariations: const [FontVariation('wdth', 72)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(face.width, lessThanOrEqualTo(b.rect.width), reason: '${b.face} ${b.faceSize}');
      }
      // Kartu/Feed: blok 34, "6½" tetap 22 (0,7 × 34 cukup); Story: blok 36 → dibatasi lebar jadi 23.
      expect(sceneOf(tester).blocks.first.faceSize, target == PodiumPosterTarget.story ? 23 : 22);
    });
  }

  testWidgets('K62 Seri penuh (6 – 6, Total Point sama, 14t): dua blok emas setinggi #1', (tester) async {
    final data = posterOf(sparing14t());
    expect([for (final b in data.blocks) (b.level, b.face)], [(1, '6'), (1, '6')]);
    await pump(tester, data, PodiumPosterTarget.card);
    expect(tester.takeException(), isNull);
    final blocks = sceneOf(tester).blocks;
    expect(blocks.every((b) => b.gold && b.rect.height == 34), isTrue);
  });

  for (final target in PodiumPosterTarget.values) {
    testWidgets('K89 sparing 0 – 0 ${target.name}: tanpa blok, tanpa kepala klub, panel hanya kaki', (tester) async {
      final data = posterOf(sparingSchedule());
      await pump(tester, data, target);
      expect(tester.takeException(), isNull);
      expect(sceneOf(tester).blocks, isEmpty);
      expect(find.text('PB Garuda'), findsNothing);
      expect(find.text('Matcha Club'), findsNothing);
      expect(find.byType(PodiumRank), findsNothing);
      expect(find.text(data.facts), findsOneWidget);
      final panel = tester.getRect(
        find.ancestor(of: find.byType(PodiumSignature), matching: find.byType(DecoratedBox)).first,
      );
      final foot = target == PodiumPosterTarget.story ? 34.0 : 26.0;
      expect(panel.height, 6 + foot);
    });
  }
}
