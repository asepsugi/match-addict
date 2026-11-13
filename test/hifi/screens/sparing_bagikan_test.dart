import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_result_screen.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/share/lengkap.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';
import 'sparing_mixed_fixture.dart';

/// Golden Bagikan sparing, frame 13q–13w (docs/tasks.md SP-15, PL-3). Fixed: data 13C Final ([sparingFull]), tanpa
/// nama. Mixed: 15f (13u, 13v) dan 16 + 14 sampai R8 (13w). Lembar gambar: Feed 360×360 di x 0, Story 360×640 di x 374,
/// kartu 358×372 di x 748 (13w), seperti 11d/11l.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final now = sparingAt(6);
  List<Override> overrides(ActiveTournament active, [DateTime? at]) => [
    tournamentProvider.overrideWith(() => LoadedTournament(active)),
    clockProvider.overrideWithValue(() => at ?? now),
  ];

  Widget screen(ActiveTournament active, [DateTime? at]) =>
      hifiScreen(const ShareResultScreen(), overrides: overrides(active, at));
  Future<void> lengkap(WidgetTester tester) => tester.tap(find.text('Lengkap'));

  /// Isi poster lewat provider yang sama dengan layar (nomor per klub = Klasemen).
  ProviderContainer containerOf(ActiveTournament active, [DateTime? at]) {
    final container = ProviderContainer(overrides: [...overrides(active, at), hifiTotalPoint]);
    addTearDown(container.dispose);
    return container;
  }

  SharePosterData posterOf(ActiveTournament active, [DateTime? at]) {
    final container = containerOf(active, at);
    return sharePosterData(
      active: active,
      entries: container.read(standingEntriesProvider),
      method: container.read(rankingMethodProvider),
      isFinal: active.isFinal(at ?? now),
      clubResult: container.read(clubScoreProvider),
      clubEntries: container.read(clubStandingEntriesProvider),
    );
  }

  /// Poster podium Ringkas lewat provider yang sama dengan layar.
  PodiumPosterData podiumOf(ActiveTournament active, [DateTime? at]) {
    final container = containerOf(active, at);
    return podiumPosterData(
      active: active,
      entries: container.read(standingEntriesProvider),
      method: container.read(rankingMethodProvider),
      isFinal: active.isFinal(at ?? now),
      clubResult: container.read(clubScoreProvider),
      clubEntries: container.read(clubStandingEntriesProvider),
    );
  }

  testWidgets('13q Ringkas: podium skor klub 7 – 5, tanpa daftar pemain per klub', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(sparingFull()), '13q');
    // Teks kecil lolos toleransi golden walau salah, jadi dicek juga lewat teks.
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('game · +13'), findsOneWidget);
    expect(find.text('49'), findsOneWidget);
    expect(find.text('game · −13'), findsOneWidget);
    expect(find.text('7 pasangan · 6 round · 12 match · 1 WO'), findsOneWidget);
    expect(find.text('Klasemen akhir'), findsOneWidget);
    expect(find.text('Padel · Fixed · 4 Nov 2026'), findsOneWidget);
    expect(find.text('Eko + Fajar'), findsNothing);
    expect(find.text('Podium · gambar Feed 1:1 & Story 9:16'), findsOneWidget);
  });

  testWidgets('13s Lengkap: semua 7 pasangan, label tanpa +n, kepala klub tanpa skor', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(sparingFull()), '13s', act: lengkap);
    // Podium mini digambar painter (angka blok dicek di "13s kartu"), jadi teksnya hanya kepala klub.
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('56 game · +13'), findsOneWidget);
    expect(find.text('49 game · −13'), findsOneWidget);
    expect(find.text('Citra + Dewi'), findsOneWidget);
    expect(find.text('Semua 7 pasangan · gambar Feed 1:1 & Story 9:16'), findsOneWidget);
  });

  testWidgets('AC-S17 nomor poster = Klasemen per klub (Garuda #1–#4, Matcha #1–#3)', (tester) async {
    final data = posterOf(sparingFull());
    expect(
      [
        for (final c in data.clubs!)
          [for (final r in c.rows) '${r.position} ${r.names.join(' + ')} ${r.value} ${r.diff}'],
      ],
      [
        ['1 Eko + Fajar 18 +11', '2 Andi + Budi 14 +1', '3 Gita + Hadi 14 −2', '4 Citra + Dewi 10 +3'],
        ['1 Maya + Nanda 23 +4', '2 Kiki + Lina 16 −3', '3 Indra + Joko 10 −14'],
      ],
    );
  });

  // Pemetaan isi Lengkap (logic.md §17.10).
  test('13s K83 isi: blok [L1 "7", L2 "5"], kepala klub tanpa skor, fakta = podium', () {
    final data = posterOf(sparingFull());
    expect([for (final b in data.blocks) (b.level, b.face, b.balls)], [(1, '7', 0), (2, '5', 0)]);
    expect((data.wide, data.pairBalls, data.endless), (false, false, false));
    expect(data.rows, isEmpty);
    expect(
      [for (final c in data.clubs!) (c.name, c.detail, c.rows.length)],
      [('PB Garuda', '56 game · +13', 4), ('Matcha Club', '49 game · −13', 3)],
    );
    expect(data.facts, '7 pasangan · 6 round · 12 match · 1 WO');
    expect((data.title, data.subtitle), ('Klasemen akhir', 'Padel · Fixed · 4 Nov 2026'));
  });

  test('K89 Sparing 0 – 0 tanpa kepala klub: blok kosong, tanpa baris, grid 0 satuan', () {
    final data = posterOf(sparingSchedule());
    expect(data.blocks, isEmpty);
    expect(data.rows, isEmpty);
    expect(data.clubs, isNull);
    for (final story in [false, true]) {
      final grid = lengkapGrid(story: story, endless: data.endless, rowCounts: data.rowCounts, pairs: false);
      expect(grid.units, 0);
      expect(grid.columns.expand((c) => c).whereType<LengkapClubCell>(), isEmpty);
    }
  });

  // Feed 360 × 360 di x 0 dan Story 360 × 640 di x 374, Ringkas (13r) dan Lengkap (13t, 13v, 13w); kartu 13w di x 748.
  const feedAt = Rect.fromLTWH(0, 0, 360, 360), storyAt = Rect.fromLTWH(374, 0, 360, 640);
  const cardAt = Rect.fromLTWH(748, 0, 358, 372);

  /// Poster Lengkap di wilayah lembar gambar [frame] (kartu: sudut 14, gambar: 4).
  Future<void> lengkapImage(
    WidgetTester tester, {
    required String frame,
    required SharePosterData data,
    required PodiumTheme theme,
    required PodiumPosterTarget target,
    required Rect at,
    double maxDiffRatio = 0.02,
  }) => expectRegionMatchesHifi(
    tester,
    hifiStage(
      theme: MabarTheme.light(),
      at: at,
      height: at.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(target == PodiumPosterTarget.card ? MabarRadius.poster : 4),
        child: SharePoster(data: data, theme: theme, target: target),
      ),
    ),
    frame,
    at,
    label: target.name,
    maxDiffRatio: maxDiffRatio,
  );

  /// Layout podium mini yang tergambar (blok, angka, bola).
  PodiumLayout sceneOf(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PodiumScenePainter),
                  )
                  .painter!
              as PodiumScenePainter)
          .layout;

  for (final (target, at) in [(PodiumPosterTarget.feed, feedAt), (PodiumPosterTarget.story, storyAt)]) {
    testWidgets('13r gambar Ringkas podium ${target.name}', (tester) async {
      await expectRegionMatchesHifi(
        tester,
        hifiStage(
          theme: MabarTheme.light(),
          at: at,
          height: at.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: PodiumPoster(
              data: podiumOf(sparingFull()),
              theme: PodiumTheme.court(SportType.padel),
              target: target,
            ),
          ),
        ),
        '13r',
        at,
        label: target.name,
      );
      expect(find.text('PB Garuda'), findsOneWidget);
      expect(find.text('game · +13'), findsOneWidget);
      expect(find.text('7 pasangan · 6 round · 12 match · 1 WO'), findsOneWidget);
    });
  }

  for (final (target, at) in [(PodiumPosterTarget.feed, feedAt), (PodiumPosterTarget.story, storyAt)]) {
    testWidgets('13t gambar Lengkap Fixed 4 + 3 ${target.name}', (tester) async {
      await lengkapImage(
        tester,
        frame: '13t',
        data: posterOf(sparingFull()),
        theme: PodiumTheme.court(SportType.padel),
        target: target,
        at: at,
      );
      expect(find.text('PB Garuda'), findsOneWidget);
      expect(find.text('56 game · +13'), findsOneWidget);
      expect(find.text('49 game · −13'), findsOneWidget);
      expect(find.text('7 pasangan · 6 round · 12 match · 1 WO'), findsOneWidget);
      expect(find.text('Klasemen akhir'), findsOneWidget);
      // K83: skor klub hanya di blok, bukan di kepala klub; podium mini tanpa bola.
      expect(find.text('7'), findsNothing);
      expect(sceneOf(tester).balls, isEmpty);
      if (target == PodiumPosterTarget.story) {
        // `.prow.duo`: dua nama pasangan ditumpuk.
        expect(find.text('Eko'), findsOneWidget);
        expect(find.text('Fajar'), findsOneWidget);
      } else {
        expect(find.text('Eko + Fajar'), findsOneWidget);
        expect(find.text('game · +11'), findsOneWidget);
      }
    });
  }

  testWidgets('13s kartu: blok klub (262,45,34,34) "7" 22 dan (296,55,34,24) "5" 16, dua lencana emas, tanpa bola', (
    tester,
  ) async {
    await tester.pumpWidget(
      hifiStage(
        theme: MabarTheme.light(),
        at: cardAt,
        child: SharePoster(
          data: posterOf(sparingFull()),
          theme: PodiumTheme.court(SportType.padel),
          target: PodiumPosterTarget.card,
        ),
      ),
    );
    final scene = sceneOf(tester);
    expect(
      [for (final b in scene.blocks) (b.rect, b.face, b.faceSize)],
      const [(Rect.fromLTWH(262, 45, 34, 34), '7', 22.0), (Rect.fromLTWH(296, 55, 34, 24), '5', 16.0)],
    );
    expect(scene.balls, isEmpty);
    expect(tester.widgetList<PodiumRank>(find.byType(PodiumRank)).where((r) => r.gold), hasLength(2));
  });

  testWidgets('Sparing belum ada match selesai: lapangan kosong, tombol Bagikan aktif (keputusan 72)', (tester) async {
    final data = podiumOf(sparingSchedule());
    expect(data.blocks, isEmpty);
    expect(data.rows, isEmpty);
    await tester.pumpWidget(screen(sparingSchedule()));
    expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Bagikan hasil')).onPressed, isNotNull);
  });

  testWidgets('13q caption = teks frame persis (nomor per klub dari provider)', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(sparingFull()));
    await tester.pumpAndSettle();

    // Share sheet tidak ada di test: share gagal dan caption disalin.
    await tester.tap(find.text('Bagikan hasil').last);
    await tester.pump();
    for (var i = 0; i < 30 && copied == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      copied,
      '🏆 PB Garuda 7–5 Matcha Club · Padel\n'
      '4 November 2026\n'
      '\n'
      'Klasemen Akhir · PB Garuda\n'
      '1. Eko + Fajar — 18 game · 100.0% (3-0, +11 game)\n'
      '2. Andi + Budi — 14 game · 66.7% (2-1, +1 game)\n'
      '3. Gita + Hadi — 14 game · 33.3% (1-2, -2 game)\n'
      '4. Citra + Dewi — 10 game · 33.3% (1-2, +3 game)\n'
      '\n'
      'Klasemen Akhir · Matcha Club\n'
      '1. Maya + Nanda — 23 game · 75.0% (3-1, +4 game)\n'
      '2. Kiki + Lina — 16 game · 50.0% (2-2, -3 game)\n'
      '3. Indra + Joko — 10 game · 0.0% (0-4, -14 game)\n'
      '\n'
      '6 round · 12 match · 1 WO · 4 Nov 2026',
    );
    await tester.pump(const Duration(seconds: 3)); // toast hilang sendiri
  });

  // ---------- Mixed sparing (13u–13w) ----------

  /// Frame Mixed ditulis 4 Nov 2026 (baris kecil "Padel · Mixed · 4 Nov 2026"); fixture bersama mulai 7 Nov, jadi
  /// hanya tanggal buatnya yang diganti di sini (jadwal dan jam tidak berubah).
  ActiveTournament on4Nov(ActiveTournament active) {
    final t = active.tournament;
    return active.copyWith(
      tournament: Tournament(
        id: t.id,
        createdAt: DateTime(2026, 11, 4, 19),
        config: t.config,
        matches: t.matches,
        isFinished: t.isFinished,
      ),
    );
  }

  final mixed8v6 = on4Nov(mixedSparing15f().active);
  final mixedEnd = mixedSparing15f().now;

  /// 13w: 16 + 14 (15d) dilanjutkan sampai R8 dengan `Random(1)` bersambung, skor contoh catatan 13w.
  const scores13w = <SparingScore>[
    (6, 3), (4, 6), (6, 4), (6, 2), (6, 5), (3, 6), (6, 2), (5, 6), //
    (6, 4), (6, 1), (2, 6), (6, 3), (6, 4), (4, 6), (6, 3), (5, 6),
  ];
  final mixed16v14 = on4Nov(
    sparingScored(
      mixedSparingRounds(
        mixedSparingEmpty(mixedSparingConfig(garudaPlayers: garuda16Names, matchaPlayers: matcha14Names)),
        8,
        Random(1),
      ),
      scores13w,
    ),
  );

  testWidgets('13u Lengkap Mixed 8 + 6: dua kolom per klub, tema peach', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(
      tester,
      screen(mixed8v6, mixedEnd),
      '13u',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Tema ${ShareTheme.peach.name}'));
        await tester.pump();
        await lengkap(tester);
      },
    );
    expect(find.text('83 game · +14'), findsOneWidget);
    expect(find.text('69 game · −14'), findsOneWidget);
    expect(find.text('14 pemain · 8 round · 16 match'), findsOneWidget);
    expect(find.text('Semua 14 pemain · gambar Feed 1:1 & Story 9:16'), findsOneWidget);
  });

  testWidgets('13u nomor per klub = Klasemen 15s (AC-S17)', (tester) async {
    final data = posterOf(mixed8v6, mixedEnd);
    expect(
      [
        for (final c in data.clubs!) [for (final r in c.rows) '${r.position} ${r.names.single} ${r.value} ${r.diff}'],
      ],
      [
        [
          '1 Dewi 24 +9',
          '2 Gita 23 +8',
          '3 Andi 22 +9',
          '4 Fajar 21 +7',
          '5 Budi 21 +2',
          '6 Eko 20 +3',
          '7 Hadi 19 −4',
          '8 Citra 16 −6',
        ],
        ['1 Lina 29 −1', '2 Joko 26 +5', '3 Nanda 26 −4', '4 Indra 23 −6', '5 Maya 20 −6', '6 Kiki 14 −16'],
      ],
    );
  });

  for (final (target, at) in [(PodiumPosterTarget.feed, feedAt), (PodiumPosterTarget.story, storyAt)]) {
    testWidgets('13v gambar Lengkap Mixed 8 + 6 ${target.name}', (tester) async {
      await lengkapImage(
        tester,
        frame: '13v',
        data: posterOf(mixed8v6, mixedEnd),
        theme: PodiumTheme.gradient(ShareTheme.peach),
        target: target,
        at: at,
      );
      expect(find.text('83 game · +14'), findsOneWidget);
      expect(find.text('69 game · −14'), findsOneWidget);
      expect(find.text('Matcha Club'), findsOneWidget);
      expect(find.text('14 pemain · 8 round · 16 match'), findsOneWidget);
    });
  }

  for (final (target, at) in [
    (PodiumPosterTarget.feed, feedAt),
    (PodiumPosterTarget.story, storyAt),
    (PodiumPosterTarget.card, cardAt),
  ]) {
    testWidgets('13w K86 gambar Lengkap Mixed 16 + 14 ${target.name}: dua kolom per klub', (tester) async {
      await lengkapImage(
        tester,
        frame: '13w',
        data: posterOf(mixed16v14, mixedEnd),
        theme: PodiumTheme.gradient(ShareTheme.biru),
        target: target,
        at: at,
        // §17.11: 30 baris rapat (huruf ±8 pt), sisa geseran huruf ≤ 1 pt.
        maxDiffRatio: 0.03,
      );
      expect(find.text('83 game · +16'), findsOneWidget);
      expect(find.text('67 game · −16'), findsOneWidget);
      expect(find.text('30 pemain · 8 round · 16 match'), findsOneWidget);
      if (target == PodiumPosterTarget.story) {
        // 13v/13w Story: "10" dibatasi lebar blok 36 → 23, "6" dibatasi tinggi 37 → 24.
        expect(
          [for (final b in sceneOf(tester).blocks) (b.rect, b.faceSize)],
          const [(Rect.fromLTWH(258, 118, 36, 52), 23.0), (Rect.fromLTWH(294, 133, 36, 37), 24.0)],
        );
      }
    });
  }

  test('13u/13w K83 isi: detail kepala klub per frame, blok 10 – 6', () {
    final u = posterOf(mixed8v6, mixedEnd), w = posterOf(mixed16v14, mixedEnd);
    expect([for (final c in u.clubs!) (c.detail, c.rows.length)], [('83 game · +14', 8), ('69 game · −14', 6)]);
    expect([for (final c in w.clubs!) (c.detail, c.rows.length)], [('83 game · +16', 16), ('67 game · −16', 14)]);
    for (final d in [u, w]) {
      expect([for (final b in d.blocks) (b.level, b.face)], [(1, '10'), (2, '6')]);
      expect(d.endless, isTrue);
    }
  });

  testWidgets('13w nomor sama untuk poin dan selisih sama (Rizky, Sari #2 · Citra, Gita #3 · Tari, Zaki #13)', (
    tester,
  ) async {
    final data = posterOf(mixed16v14, mixedEnd);
    int? position(String name) => [
      for (final c in data.clubs!)
        for (final r in c.rows)
          if (r.names.single == name) r.position,
    ].single;
    expect([position('Rizky'), position('Sari'), position('Citra'), position('Gita')], [2, 2, 3, 3]);
    expect([position('Tari'), position('Zaki')], [13, 13]);
  });
}
