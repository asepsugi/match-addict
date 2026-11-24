import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_result_screen.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/share/result_text_builder.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden Bagikan Grup + Gugur (22l–22r) dan caption, docs/tasks.md GG-10. Kolom kanan poster = babak (GU16),
/// bukan nilai · selisih. Data 16E/16F (gg21i), tanpa Perebutan juara 3 (gg21q), SF1 terisi (gg21c), 16B (gg21y).
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  /// Turnamen yang sama dengan nama ("Garuda Open 2026"): 22l–22o bernama, 22p–22r tidak.
  ActiveTournament named(ActiveTournament a) {
    final t = a.tournament, c = t.config;
    return a.copyWith(
      tournament: Tournament(
        id: t.id,
        createdAt: t.createdAt,
        config: TournamentConfig(
          sport: c.sport,
          mode: c.mode,
          matchDurationMinutes: c.matchDurationMinutes,
          courts: c.courts,
          players: c.players,
          fixedPairs: c.fixedPairs,
          format: c.format,
          name: 'Garuda Open 2026',
          groupKnockout: c.groupKnockout,
        ),
        matches: t.matches,
        isFinished: t.isFinished,
      ),
    );
  }

  List<Override> overrides(ActiveTournament active, DateTime now) => [
    tournamentProvider.overrideWith(() => LoadedTournament(active)),
    clockProvider.overrideWithValue(() => now),
  ];

  Widget screen(ActiveTournament active, DateTime now) =>
      hifiScreen(const ShareResultScreen(), overrides: overrides(active, now));

  ProviderContainer containerOf(ActiveTournament active, DateTime now) {
    final container = ProviderContainer(overrides: overrides(active, now));
    addTearDown(container.dispose);
    return container;
  }

  PodiumPosterData podiumOf(ActiveTournament active, DateTime now) {
    final c = containerOf(active, now);
    return podiumPosterData(
      active: active,
      entries: c.read(standingEntriesProvider),
      method: c.read(rankingMethodProvider),
      isFinal: active.isFinal(now),
    );
  }

  SharePosterData posterOf(ActiveTournament active, DateTime now) {
    final c = containerOf(active, now);
    return sharePosterData(
      active: active,
      entries: c.read(standingEntriesProvider),
      method: c.read(rankingMethodProvider),
      isFinal: active.isFinal(now),
    );
  }

  String captionOf(ActiveTournament active, ShareFormat format) => ResultTextBuilder.build(
    active: active,
    standings: containerOf(active, at21f).read(standingEntriesProvider),
    format: format,
    now: at21f,
    method: RankingMethod.winPercent,
  );

  Future<void> peachLengkap(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Tema ${ShareTheme.peach.name}'));
    await tester.pump();
    await tester.tap(find.text('Lengkap'));
  }

  // Lembar gambar: Feed 360 × 360 di x 0, Story 360 × 640 di x 374, kartu 358 × 372 di x 748 (22r).
  const feedAt = Rect.fromLTWH(0, 0, 360, 360), storyAt = Rect.fromLTWH(374, 0, 360, 640);
  const cardAt = Rect.fromLTWH(748, 0, 358, 372);

  Future<void> image(WidgetTester tester, String frame, Widget poster, Rect at, String label, {bool card = false}) =>
      expectRegionMatchesHifi(
        tester,
        hifiStage(
          theme: MabarTheme.light(),
          at: at,
          height: at.height,
          child: ClipRRect(borderRadius: BorderRadius.circular(card ? MabarRadius.poster : 4), child: poster),
        ),
        frame,
        at,
        label: label,
      );

  final peach = PodiumTheme.gradient(ShareTheme.peach);
  final padel = PodiumTheme.court(SportType.padel), tennis = PodiumTheme.court(SportType.tennis);

  /// Isi baris panel poster Ringkas: (nomor, nama, babak).
  List<(String, String, String)> podiumRows(PodiumPosterData d) => [
    for (final r in d.rows) (r.badge, r.names.join(' + '), r.value),
  ];

  testWidgets('22l Ringkas: podium Final, kolom kanan = babak, tanpa nilai · selisih', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(named(gg21i()), at21f), '22l');
    expect(find.text('Padel · Group - Playoff · Final'), findsOneWidget);
    expect(find.text('Garuda Open 2026'), findsOneWidget);
    expect(find.text('Klasemen akhir · 17 Nov 2026'), findsOneWidget);
    expect(find.text('Juara 1'), findsOneWidget);
    expect(find.text('Juara 2'), findsOneWidget);
    expect(find.text('Juara 3'), findsOneWidget);
    expect(find.text('Padel · 8 pasangan · 8 round · 16 match'), findsOneWidget);
    expect(find.textContaining('game'), findsNothing);
  });

  test('22l caption Ringkas = teks frame persis', () {
    expect(
      captionOf(named(gg21i()), ShareFormat.ringkas),
      '🏆 Garuda Open 2026 · Padel\n'
      '17 November 2026\n'
      '\n'
      'Klasemen Akhir\n'
      '1. Citra + Dewi — Juara 1\n'
      '2. Andi + Budi — Juara 2\n'
      '3. Maya + Nanda — Juara 3\n'
      '4. Indra + Joko — Semifinal\n'
      '5. Eko + Fajar — Grup A · 3\n'
      '5. Kiki + Lina — Grup B · 3\n'
      '6. Gita + Hadi — Grup A · 4\n'
      '6. Oki + Putri — Grup B · 4\n'
      '\n'
      '8 round · 16 match · 17 Nov 2026',
    );
  });

  for (final (target, at) in [(PodiumPosterTarget.feed, feedAt), (PodiumPosterTarget.story, storyAt)]) {
    testWidgets('22m gambar Ringkas ${target.name}', (tester) async {
      await precacheHifiAssets(tester, [SportType.padel.assetPath]);
      final data = podiumOf(named(gg21i()), at21f);
      await image(tester, '22m', PodiumPoster(data: data, theme: padel, target: target), at, target.name);
    });

    // 22n: Perebutan juara 3 dimatikan, #1 #2 #3 #3: empat anak tangga, kedua #3 "Semifinal".
    testWidgets('22n gambar Ringkas tanpa Juara 3 ${target.name}', (tester) async {
      await precacheHifiAssets(tester, [SportType.padel.assetPath]);
      final data = podiumOf(named(gg21q()), at21f);
      await image(tester, '22n', PodiumPoster(data: data, theme: padel, target: target), at, target.name);
    });

    // 22o: Sementara, SF1 terisi.
    testWidgets('22o gambar Ringkas Sementara ${target.name}', (tester) async {
      await precacheHifiAssets(tester, [SportType.padel.assetPath]);
      final data = podiumOf(named(gg21c()), at21f);
      await image(tester, '22o', PodiumPoster(data: data, theme: padel, target: target), at, target.name);
    });

    testWidgets('22q gambar Lengkap 2 grup peach ${target.name}', (tester) async {
      await precacheHifiAssets(tester, [SportType.padel.assetPath]);
      final data = posterOf(gg21i(), at21f);
      await image(tester, '22q', SharePoster(data: data, theme: peach, target: target), at, target.name);
    });

    testWidgets('22r gambar Lengkap 4 grup ${target.name}', (tester) async {
      await precacheHifiAssets(tester, [SportType.tennis.assetPath]);
      final data = posterOf(gg21y(), at21v);
      await image(tester, '22r', SharePoster(data: data, theme: tennis, target: target), at, target.name);
    });
  }

  testWidgets('22r pratinjau kartu 4 grup, 12 pasangan', (tester) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath]);
    final data = posterOf(gg21y(), at21v);
    await image(
      tester,
      '22r',
      SharePoster(data: data, theme: tennis, target: PodiumPosterTarget.card),
      cardAt,
      'card',
      card: true,
    );
  });

  testWidgets('22p Lengkap 2 grup, tema peach, tanpa nama', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(gg21i(), at21f), '22p', act: peachLengkap);
    expect(find.text('Klasemen akhir'), findsOneWidget);
    expect(find.text('Padel · Group - Playoff · 17 Nov 2026'), findsOneWidget);
    expect(find.text('8 pasangan · 8 round · 16 match'), findsOneWidget);
    expect(find.text('Grup A · 3'), findsOneWidget);
    expect(find.text('Grup B · 4'), findsOneWidget);
    expect(find.text('Semua 8 pasangan · gambar Feed 1:1 & Story 9:16'), findsOneWidget);
  });

  test('22p caption Lengkap = caption 22l + Hasil per Round berlabel babak', () {
    final lines = captionOf(gg21i(), ShareFormat.lengkap).split('\n');
    expect(lines.take(5), [
      '🏆 Match Addict · Padel',
      '17 November 2026',
      '',
      'Klasemen Akhir',
      '1. Citra + Dewi — Juara 1',
    ]);
    // Label babak per baris Hasil per Round dan K106: test/services/result_text_builder_test.dart.
    expect(lines, contains('Hasil per Round'));
  });

  // AC-G18: podium = peringkat akhir apa adanya.
  test('AC-G18 podium 16F Citra · Andi · Maya; tanpa Juara 3 empat anak tangga #3 kembar', () {
    final full = podiumOf(gg21i(), at21f);
    expect(podiumRows(full), [
      ('1', 'Citra + Dewi', 'Juara 1'),
      ('2', 'Andi + Budi', 'Juara 2'),
      ('3', 'Maya + Nanda', 'Juara 3'),
    ]);
    expect(full.blocks.map((b) => b.level), [2, 1, 3]);

    final noThird = podiumOf(gg21q(), at21f);
    expect(podiumRows(noThird), [
      ('1', 'Citra + Dewi', 'Juara 1'),
      ('2', 'Andi + Budi', 'Juara 2'),
      ('3', 'Indra + Joko', 'Semifinal'),
      ('3', 'Maya + Nanda', 'Semifinal'),
    ]);
    expect(noThird.blocks.map((b) => b.level), [2, 1, 3, 3]);
  });

  test('22o fakta Sementara dan baris kecil', () {
    final data = podiumOf(named(gg21c()), at21f);
    expect(data.facts, 'Padel · 8 pasangan · R7 · 13 dari 16 match');
    expect((data.title, data.subtitle), ('Garuda Open 2026', 'Klasemen sementara · 17 Nov 2026'));
  });
}
