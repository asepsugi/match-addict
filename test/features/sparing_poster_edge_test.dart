import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/share/result_text_builder.dart';

import '../hifi/hifi_golden.dart';
import '../hifi/screens/schedule_fixture.dart';
import '../hifi/screens/sparing_fixture.dart';

/// Kasus tepi poster sparing (saran review SP-15, QA 3.2.0): nama klub panjang terpotong elipsis tanpa mendorong
/// skor, sparing tanpa hasil "0 – 0", dan skor klub ½. Tanpa golden: yang dicek teks dan ukuran render dengan font asli.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final now = sparingAt(6);

  SharePosterData posterOf(ActiveTournament active, ShareFormat format) {
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
      format: format,
      isFinal: active.isFinal(now),
      clubResult: container.read(clubScoreProvider),
      clubEntries: container.read(clubStandingEntriesProvider),
    );
  }

  /// Nama klub diganti di data poster (teks jadi dari provider, jadi cukup di lapisan ini).
  SharePosterData withClubNames(SharePosterData d, String a, String b) => SharePosterData(
    sport: d.sport,
    eyebrow: d.eyebrow,
    isFinal: d.isFinal,
    rows: d.rows,
    summary: d.summary,
    more: d.more,
    complete: d.complete,
    clubScore: [
      for (final (i, s) in d.clubScore!.indexed)
        SharePosterClubScore(name: i == 0 ? a : b, detail: s.detail, score: s.score),
    ],
    clubs: [for (final (i, c) in d.clubs!.indexed) SharePosterClub(name: i == 0 ? a : b, rows: c.rows, more: c.more)],
  );

  Future<void> pump(WidgetTester tester, SharePosterData data, SharePosterTarget target) async {
    await loadHifiFonts();
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    final size = switch (target) {
      SharePosterTarget.story => const Size(203, 360),
      SharePosterTarget.feed => const Size(360, 360),
      SharePosterTarget.preview => const Size(358, 372),
    };
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MabarTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: SharePoster(data: data, theme: ShareTheme.biru, target: target),
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

  const longA = 'Persatuan Bulutangkis dan Tenis Garuda Nusantara Jaya Raya';
  const longB = 'Perkumpulan Padel Matcha Club Kota Bandung Selatan Sentosa';

  for (final target in SharePosterTarget.values) {
    testWidgets('nama klub panjang ${target.name}: elipsis, skor dan detail tetap utuh, tanpa overflow', (
      tester,
    ) async {
      final data = withClubNames(posterOf(sparingFull(), ShareFormat.ringkas), longA, longB);
      await pump(tester, data, target);
      expect(tester.takeException(), isNull);

      // Nama klub di .pscore terpotong elipsis (satu baris), angka di kanan tetap terbaca penuh.
      final nameA = find.text(longA);
      expect(nameA, findsOneWidget);
      expect(paragraph(tester, nameA).didExceedMaxLines, isTrue);
      expect(find.text(longB), findsOneWidget);
      for (final t in ['56 game · +13', '49 game · −13', '7', '5']) {
        expect(find.text(t), findsOneWidget);
        expectFits(tester, find.text(t));
      }
      // Label .pclub kapital; ada dan satu baris.
      final labelA = find.text(longA.toUpperCase());
      expect(labelA, findsOneWidget);
      expect(paragraph(tester, labelA).maxLines, 1);
      // "+1 pasangan lainnya" di ujung kanan label klub 1 tidak ikut terpotong.
      expect(find.text('+1 pasangan lainnya'), findsOneWidget);
      expectFits(tester, find.text('+1 pasangan lainnya'));
    });
  }

  testWidgets('sparing tanpa hasil: skor klub "0 – 0" (selisih 0 tanpa tanda), tanpa bola', (tester) async {
    final data = posterOf(sparingSchedule(), ShareFormat.ringkas);
    expect([for (final s in data.clubScore!) s.score], ['0', '0']);
    expect([for (final s in data.clubScore!) s.detail], ['0 game · 0', '0 game · 0']);
    await pump(tester, data, SharePosterTarget.feed);
    expect(tester.takeException(), isNull);
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  for (final target in SharePosterTarget.values) {
    testWidgets('skor klub ½ (Seri Americano 20): "6½" dan "5½" muat di kolom skor ${target.name}', (tester) async {
      final data = posterOf(sparing14u(), ShareFormat.ringkas);
      expect([for (final s in data.clubScore!) s.score], ['6½', '5½']);
      await pump(tester, data, target);
      expect(tester.takeException(), isNull);
      for (final t in ['6½', '5½']) {
        expect(find.text(t), findsOneWidget);
        expectFits(tester, find.text(t));
      }
    });
  }

  testWidgets('klub imbang penuh (6 – 6 dan Total Point sama) menulis "6" dan "6" untuk Seri', (tester) async {
    final data = posterOf(sparing14t(), ShareFormat.ringkas);
    await pump(tester, data, SharePosterTarget.preview);
    expect(tester.takeException(), isNull);
    expect(find.text('6'), findsWidgets);
  });
}
