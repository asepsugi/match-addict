import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_exports.dart';
import 'package:match_addict/features/share/share_result_screen.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';

import '../components/share_poster_data.dart';
import '../hifi_golden.dart';
import 'fixed_extra_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden layar penuh Bagikan, frame 11a, 11b, 11e, 11h, 11i (11d/11f/11g/11j = lembar gambar, sudah
/// di golden komponen SharePoster). Semua dibuat 21 Okt 2026.
void main() {
  // Caption memakai tanggal berbahasa Indonesia, seperti di main().
  setUpAll(() => initializeDateFormatting('id'));

  const fullNames = [
    'Andi Pratama', 'Budi Santoso', 'Citra Lestari', 'Dewant Rahman', 'Eko Mulyadi', 'Fajar Kurnia', //
    'Gina Rosalia', 'Hana Taslim', 'Indra Wijaya', 'Joko Susilo', 'Kiki Amalia', 'Lina Marlina', 'Maya Putri',
    'Nanda Rizki', 'Oki Setiawan', 'Putri Anggraini', 'Rizky Hidayat', 'Sari Dewi', 'Tono Basuki', 'Umar Faruq',
  ];
  final date = DateTime(2026, 10, 21, 19);
  // Jam saat membagikan: R3 baru selesai, booking 2 jam masih tersisa (Mixed "sementara").
  final now = date.add(const Duration(minutes: 45));

  /// 11a: data set 1 Peringkat (Americano 24, R1–R3) dengan nama lengkap; Gilang belum main ikut "+6".
  /// Turnamennya bernama "Mabar Jumat PB Garuda".
  final set1 = mixedTournament(
    const [
      [('Andi', 'Hana', 'Budi', 'Eko', 14, 10), ('Dewant', 'Citra', 'Fajar', 'Joko', 15, 9)],
      [('Andi', 'Gina', 'Fajar', 'Indra', 15, 9), ('Dewant', 'Joko', 'Budi', 'Hana', 14, 10)],
      [('Andi', 'Dewant', 'Citra', 'Indra', 13, 11), ('Eko', 'Gina', 'Fajar', 'Hana', 12, 12)],
    ],
    roster: [...fullNames.take(10), 'Gilang Saputra'],
    format: const ScoreFormat(ScoringMethod.americano, 24),
    createdAt: date,
    name: 'Mabar Jumat PB Garuda',
  );

  /// 11b: Fixed Tennis 10 pasangan, round-robin 45 match (5 court, 9 round), semua selesai. Urutan kuat:
  /// Indra·Joko, Kiki·Lina, Oki·Putri, Andi·Budi, Eko·Fajar, Citra·Dewant, Maya·Nanda, Rizky·Sari,
  /// Tono·Umar, Gina·Hana; yang lebih kuat menang kecuali tiga kejutan. Skor kalah dipilih supaya total
  /// game = frame (52, 49, 46, 45, 43, 41, 34, 34, 33, 24).
  ActiveTournament fixed20() {
    final players = [for (var i = 0; i < 20; i++) Player(id: 'p$i', name: fullNames[i])];
    final pairs = [for (var i = 0; i < 10; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];
    const order = [4, 5, 7, 0, 2, 1, 6, 8, 9, 3]; // indeks pasangan, terkuat dulu
    const upsets = {(1, 4), (8, 5), (9, 7)}; // (pemenang, yang kalah): CD > IJ, RS > KL, TU > OP
    // Game yang didapat yang kalah, urut lawan yang mengalahkannya (urutan [order]).
    const lost = {
      4: [4], 5: [4, 3], 7: [4, 3, 3], 0: [3, 3, 3], 2: [4, 3, 3, 3], 1: [3, 3, 3, 2], //
      6: [3, 3, 3, 3, 2, 2], 8: [4, 3, 3, 2, 2, 2], 9: [3, 3, 3, 3, 3, 3, 3], 3: [3, 3, 3, 3, 3, 3, 2, 2, 2],
    };
    int winner(int a, int b) =>
        upsets.contains((a, b)) ? a : (upsets.contains((b, a)) ? b : (order.indexOf(a) < order.indexOf(b) ? a : b));
    List<int> beatenBy(int loser) => [
      for (final w in order)
        if (w != loser && winner(w, loser) == w) w,
    ];
    final courts = [
      for (var i = 0; i < 5; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: 0, bookingDurationMinutes: 240),
    ];
    final schedule = RoundRobinGenerator.generate(pairs: pairs, courts: courts);
    final matches = [
      for (final m in schedule.matches)
        () {
          final a = pairs.indexOf(m.pair1), b = pairs.indexOf(m.pair2);
          final w = winner(a, b), l = w == a ? b : a;
          final score = lost[l]![beatenBy(l).indexOf(w)];
          return m.withScore([SetScore(side1: w == a ? 6 : score, side2: w == a ? score : 6)]);
        }(),
    ];
    return ActiveTournament(
      tournament: Tournament(
        id: 't-fixed20',
        createdAt: date,
        config: TournamentConfig(
          sport: SportType.tennis,
          mode: PartnerMode.fixed,
          matchDurationMinutes: 20,
          courts: courts,
          players: players,
          fixedPairs: pairs,
        ),
        matches: matches,
      ),
      byePairIdByRound: schedule.byePairIdByRound,
    );
  }

  /// Mixed yang sudah diakhiri dengan [rounds] × [courts] match (hanya untuk "x round · y match"); barisnya
  /// langsung dari data poster frame (nomor, poin, selisih), karena nomor seri di sana (3, 3 · 10, 10 · 12, 12)
  /// butuh poin dan selisih yang sama persis.
  (ActiveTournament, List<StandingEntry>) mixedFromPoster(
    String frame, {
    required int rounds,
    required int courts,
    String? name,
  }) {
    final rows = posterRows[(frame, 0)]!;
    final roster = [for (final r in rows) r.names.single];
    final first = [for (final n in roster) n.split(' ').first];
    final active = mixedTournament(
      [
        for (var r = 0; r < rounds; r++)
          [
            for (var c = 0; c < courts; c++)
              () {
                String at(int k) => first[(r * 4 * courts + c * 4 + k) % first.length];
                return (at(0), at(1), at(2), at(3), 11, 10);
              }(),
          ],
      ],
      roster: roster,
      format: const ScoreFormat(ScoringMethod.americano, 21),
      courtCount: courts,
      createdAt: date,
      finished: true,
      name: name,
    );
    final entries = [
      for (final (i, r) in rows.indexed)
        StandingEntry(
          players: [active.config.players[i]],
          standing: PlayerStanding(
            player: active.config.players[i],
            wins: 1,
            gamesWon: int.parse(r.value),
            // Selisih poster ("−12") = gamesWon − gamesLost.
            gamesLost: int.parse(r.value) - int.parse(r.diff.replaceFirst('−', '-')),
          ),
          position: r.position,
        ),
    ];
    return (active, entries);
  }

  Widget screen(ActiveTournament active, {List<StandingEntry>? entries, RankingMethod? method}) => hifiScreen(
    const ShareResultScreen(),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
      if (method != null) rankingMethodProvider.overrideWith((ref) => method),
      if (entries != null) standingEntriesProvider.overrideWithValue(entries),
    ],
  );

  Future<void> lengkap(WidgetTester tester) => tester.tap(find.text('Lengkap'));

  testWidgets('11a Ringkas, tema biru, sementara', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(set1), '11a');
  });

  testWidgets('11b Lengkap Fixed 10 pasangan, tema peach', (tester) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath]);
    await expectMatchesHifi(
      tester,
      screen(fixed20()),
      '11b',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Tema ${ShareTheme.peach.name}'));
        await tester.pump();
        await lengkap(tester);
      },
    );
  });

  // Tema per frame: 11e/11i lapangan (bawaan), 11h biru; 11e bernama.
  for (final (frame, rounds, courts, name, theme) in [
    ('11e', 8, 4, 'Mabar Jumat PB Garuda', null),
    ('11h', 6, 3, null, ShareTheme.biru),
    ('11i', 6, 3, null, null),
  ]) {
    testWidgets('$frame Lengkap Mixed dua kolom', (tester) async {
      await precacheHifiAssets(tester, [SportType.padel.assetPath]);
      final (active, entries) = mixedFromPoster(frame, rounds: rounds, courts: courts, name: name);
      await expectMatchesHifi(
        tester,
        screen(active, entries: entries),
        frame,
        act: (tester) async {
          if (theme != null) {
            await tester.tap(find.bySemanticsLabel('Tema ${theme.name}'));
            await tester.pump();
          }
          await lengkap(tester);
        },
      );
    });
  }

  /// Satu baris Klasemen literal (nomor, nilai, selisih) untuk frame yang datanya cuma teks poster.
  StandingEntry entry(List<Player> players, int position, {required int won, required int diff, int wins = 1}) =>
      StandingEntry(
        players: players,
        standing: PlayerStanding(player: players.first, wins: wins, gamesWon: won, gamesLost: won - diff),
        position: position,
      );

  /// Mixed 12 pemain yang sudah selesai (6 round × 3 court = 18 match), Klasemen dari baris literal: 18b.
  (ActiveTournament, List<StandingEntry>) mixed12(List<(String, int, int)> top) {
    final roster = fullNames.take(12).toList();
    final first = [for (final n in roster) n.split(' ').first];
    final active = mixedTournament(
      [
        for (var r = 0; r < 6; r++)
          [
            for (var c = 0; c < 3; c++)
              (
                first[(r * 12 + c * 4) % 12],
                first[(r * 12 + c * 4 + 1) % 12],
                first[(r * 12 + c * 4 + 2) % 12],
                first[(r * 12 + c * 4 + 3) % 12],
                11,
                10,
              ),
          ],
      ],
      roster: roster,
      courtCount: 3,
      createdAt: DateTime(2026, 11, 6, 19),
      finished: true,
      name: 'Mabar Jumat PB Garuda',
    );
    final byName = {for (final p in active.config.players) p.name: p};
    final named = {for (final (n, _, _) in top) n};
    final rest = [
      for (final p in active.config.players)
        if (!named.contains(p.name)) p,
    ];
    final entries = [
      for (final (i, (n, won, diff)) in top.indexed) entry([byName[n]!], i + 1, won: won, diff: diff),
      for (final (i, p) in rest.indexed) entry([p], top.length + 1 + i, won: 60 - i, diff: -i),
    ];
    return (active, entries);
  }

  /// 18a: Tennis Fixed, 6 pasangan, round-robin 15 match (3 court × 5 round) semua selesai, Klasemen literal.
  (ActiveTournament, List<StandingEntry>) fixed6() {
    final players = [for (var i = 0; i < 12; i++) Player(id: 'p$i', name: fullNames[i])];
    final pairs = [for (var i = 0; i < 6; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];
    final courts = [
      for (var i = 0; i < 3; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: 0, bookingDurationMinutes: 240),
    ];
    final schedule = RoundRobinGenerator.generate(pairs: pairs, courts: courts);
    final active = ActiveTournament(
      tournament: Tournament(
        id: 't-fixed6',
        createdAt: DateTime(2026, 10, 30, 19),
        config: TournamentConfig(
          sport: SportType.tennis,
          mode: PartnerMode.fixed,
          matchDurationMinutes: 20,
          courts: courts,
          players: players,
          fixedPairs: pairs,
        ),
        matches: [
          for (final m in schedule.matches) m.withScore(const [SetScore(side1: 6, side2: 3)]),
        ],
      ),
      byePairIdByRound: schedule.byePairIdByRound,
    );
    // Indra·Joko #1 (5–0, +19), Eko·Fajar #2 (4–1, +10), Citra·Dewant #3 (3–2, +3), lalu tiga pasangan lain.
    const rows = [(4, 5, 19), (2, 4, 10), (1, 3, 3), (0, 2, 0), (3, 1, -12), (5, 0, -20)];
    final entries = [
      for (final (i, (pair, wins, diff)) in rows.indexed)
        StandingEntry(
          players: [players[2 * pair], players[2 * pair + 1]],
          standing: PlayerStanding(
            player: players[2 * pair],
            wins: wins,
            losses: 5 - wins,
            gamesWon: 30 + diff,
            gamesLost: 30,
          ),
          position: i + 1,
        ),
    ];
    return (active, entries);
  }

  Widget screenOf((ActiveTournament, List<StandingEntry>) c, {RankingMethod? method}) =>
      screen(c.$1, entries: c.$2, method: method);

  /// Layar 390 × 844 seperti frame; tanpa ini ListView tidak membangun deret tema (di luar cache) di jendela test.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
  }

  /// Bola di ilustrasi podium (digambar painter, bukan widget `MabarBall`): jumlah dari tata letaknya.
  int podiumBalls(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PodiumScenePainter),
    );
    return (paint.painter! as PodiumScenePainter).layout.balls.length;
  }

  testWidgets('18a Ringkas Fixed tennis: pasangan, dua bola per blok, tema lapangan biru', (tester) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath]);
    await expectMatchesHifi(tester, screenOf(fixed6(), method: RankingMethod.winPercent), '18a');
    expect(find.text('Indra Wijaya'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('· +19'), findsOneWidget);
    expect(find.text('6 pasangan · 5 round · 15 match'), findsOneWidget);
    expect(podiumBalls(tester), 6);
  });

  testWidgets('18b Ringkas gradien nude dipilih; pindah ke Lengkap nude tetap terpilih (11b)', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    final c = mixed12([('Hana Taslim', 80, 34), ('Gina Rosalia', 76, 26), ('Fajar Kurnia', 69, 12)]);
    await expectMatchesHifi(
      tester,
      screenOf(c),
      '18b',
      act: (tester) async {
        await tester.tap(_swatch('Tema nude'));
        await tester.pump();
      },
    );
    expect(find.text('Padel · 12 pemain · 6 round · 18 match'), findsOneWidget);
    expect(podiumBalls(tester), 3);
    // Lingkaran lapangan tetap di depan deret, tanpa cincin.
    expect(_selected(tester, 'Tema lapangan'), isFalse);
    expect(_selected(tester, 'Tema nude'), isTrue);
    await lengkap(tester);
    await tester.pump();
    expect(_selected(tester, 'Tema nude'), isTrue);
    expect(_selected(tester, 'Tema biru'), isFalse);
  });

  testWidgets('Deret tema: 11 lingkaran 27 pt dengan lapangan terpilih, sama di Ringkas dan Lengkap (K76)', (
    tester,
  ) async {
    phone(tester);
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await tester.pumpWidget(screen(set1));
    for (final tab in [null, 'Lengkap', 'Ringkas']) {
      if (tab != null) {
        await tester.tap(find.text(tab));
        await tester.pump();
      }
      expect(_swatch(), findsNWidgets(11));
      expect(tester.getSize(_swatch('Tema lapangan')), const Size.square(27));
      expect(tester.getSize(_swatch('Tema biru')), const Size.square(27));
      expect(_selected(tester, 'Tema lapangan'), isTrue);
    }
  });

  testWidgets('11e K76 lapangan tetap lapangan di Lengkap: biru tidak ikut ditandai', (tester) async {
    phone(tester);
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await tester.pumpWidget(screen(set1));
    await lengkap(tester);
    await tester.pump();
    expect(_selected(tester, 'Tema lapangan'), isTrue);
    expect(_selected(tester, 'Tema biru'), isFalse);
    expect([
      for (final t in ShareTheme.values)
        if (_selected(tester, 'Tema ${t.name}')) t,
    ], isEmpty);
  });

  testWidgets('Gradien dari Lengkap berlaku di Ringkas; kembali ke lapangan lewat deret Ringkas', (tester) async {
    phone(tester);
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await tester.pumpWidget(screen(set1));
    await lengkap(tester);
    await tester.pump();
    await tester.tap(_swatch('Tema peach'));
    await tester.pump();
    await tester.tap(find.text('Ringkas'));
    await tester.pump();
    expect(_selected(tester, 'Tema peach'), isTrue);
    expect(_selected(tester, 'Tema lapangan'), isFalse);
    await tester.tap(_swatch('Tema lapangan'));
    await tester.pump();
    expect(_selected(tester, 'Tema lapangan'), isTrue);
  });

  testWidgets('18t belum ada match selesai: lapangan kosong, "Bagikan hasil" tetap aktif', (tester) async {
    phone(tester);
    final pending = mixedTournament(
      const [
        [('Andi', 'Hana', 'Budi', 'Eko', null, null), ('Dewant', 'Citra', 'Fajar', 'Joko', null, null)],
      ],
      format: const ScoreFormat(ScoringMethod.americano, 24),
      createdAt: date,
    );
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await tester.pumpWidget(screen(pending));
    expect(podiumBalls(tester), 0);
    expect(find.text('Match Addict'), findsOneWidget);
    expect(find.text('Padel · Mixed · 21 Okt 2026'), findsOneWidget);
    expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Bagikan hasil')).onPressed, isNotNull);
  });

  group('ekspor Ringkas (keputusan 60, 70)', () {
    final data = PodiumPosterData(
      sport: SportType.padel,
      title: 'Klasemen akhir',
      subtitle: 'Padel · Mixed · 21 Okt 2026',
      facts: '10 pemain',
    );

    test('Feed 360 × 360 dan Story 360 × 640, keduanya ×3 → 1080 × 1080 dan 1080 × 1920', () {
      final images = podiumImages(data, PodiumTheme.court(SportType.padel));
      expect([for (final i in images) i.size], const [Size(360, 360), Size(360, 640)]);
      expect([for (final i in images) i.pixelRatio], const [3.0, 3.0]);
      expect([for (final i in images) i.size * i.pixelRatio], const [Size(1080, 1080), Size(1080, 1920)]);
      expect(
        [for (final i in images) i.fileName],
        ['match-addict-feed-1080x1080.png', 'match-addict-story-1080x1920.png'],
      );
      expect(
        [for (final i in images) (i.poster as PodiumPoster).target],
        [PodiumPosterTarget.feed, PodiumPosterTarget.story],
      );
    });
  });

  group('podiumPosterData: pemetaan Podium → teks', () {
    ProviderContainer containerOf(ActiveTournament active) {
      final c = ProviderContainer(
        overrides: [
          tournamentProvider.overrideWith(() => LoadedTournament(active)),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('18l / 09g Fixed pasangan diatur ulang: fakta "16 round · 32 match" tanpa hitungan pasangan', () {
      final active = extraPlayed();
      final c = containerOf(active);
      final entries = c.read(standingEntriesProvider);
      // Klasemen 09g campuran: ada baris satu nama (pasangan lama Andi bubar).
      expect({for (final e in entries) e.players.length}, {1, 2});
      final data = podiumPosterData(
        active: active,
        entries: entries,
        method: c.read(rankingMethodProvider),
        isFinal: true,
      );
      expect(data.facts, '16 round · 32 match');
      expect(data.pairSize, isTrue);
    });

    test('Kerumunan: kata dari SEMUA baris Klasemen, bukan dari baris #1 (keputusan 68, 74)', () {
      final active = extraPlayed();
      final ps = active.config.players;
      final pair = [ps[0], ps[1]];
      StandingEntry row(List<Player> p, int pos) => entry(p, pos, won: 20, diff: 5);
      PodiumPosterData of(List<StandingEntry> entries) =>
          podiumPosterData(active: active, entries: entries, method: RankingMethod.totalGames, isFinal: true);

      final semuaPasangan = of([for (var i = 0; i < 6; i++) row(pair, 1), row(pair, 2)]);
      expect(semuaPasangan.wide, isTrue);
      expect(semuaPasangan.rows.single.names, ['6 pasangan']);
      expect(semuaPasangan.facts, startsWith('7 pasangan'));

      // Semua #1 pasangan, tapi ada satu baris tunggal di bawahnya: tidak ada kata yang benar → "{n}" saja.
      final campuran = of([
        for (var i = 0; i < 6; i++) row(pair, 1),
        row([ps[2]], 2),
      ]);
      expect(campuran.rows.single.names, ['6']);
      expect(campuran.facts, isNot(contains('pasangan')));
    });
  });

  /// Clipboard palsu: test tidak punya plugin platform.
  void mockClipboard(WidgetTester tester, [void Function(String text)? onCopy]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') onCopy?.call((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  /// Render poster + share sheet berjalan di luar fake async; tanpa plugin share di test, share gagal dan
  /// caption disalin.
  Future<void> untilCopied(WidgetTester tester) async {
    for (var i = 0; i < 30 && find.text('Hasil disalin').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('11c share gagal: tombol aktif lagi, toast 19 pt di atas action bar', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    mockClipboard(tester);
    await expectMatchesHifi(
      tester,
      screen(set1),
      '11c',
      act: (tester) async {
        await tester.tap(find.text('Bagikan hasil').last);
        await tester.pump();
        await untilCopied(tester);
      },
    );
    await tester.pump(const Duration(seconds: 3)); // toast hilang sendiri
  });

  Future<ProviderContainer> pumpRouted(WidgetTester tester, ActiveTournament active) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Beranda')),
        GoRoute(path: '/share', builder: (_, _) => const ShareResultScreen()),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(
        router,
        overrides: [
          tournamentProvider.overrideWith(() => LoadedTournament(active)),
          clockProvider.overrideWithValue(() => now),
        ],
      ),
    );
    router.push('/share');
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ShareResultScreen)));
  }

  testWidgets('Selesai: turnamen pindah ke slot terakhir, kembali ke Beranda tanpa konfirmasi', (tester) async {
    final container = await pumpRouted(tester, set1);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget);
    expect(container.read(tournamentProvider), isNull);
    expect(container.read(lastFinishedProvider)?.tournament.id, set1.tournament.id);
  });

  testWidgets('Bagikan: tombol mati saat menyiapkan gambar; share gagal → caption disalin + toast', (tester) async {
    String? copied;
    mockClipboard(tester, (text) => copied = text);
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await pumpRouted(tester, set1);

    await tester.tap(find.text('Bagikan hasil').last);
    await tester.pump();
    expect(find.text('Menyiapkan gambar…'), findsOneWidget);
    expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Menyiapkan gambar…')).onPressed, isNull);

    await untilCopied(tester);
    expect(find.text('Hasil disalin'), findsOneWidget);
    expect(copied, contains('Klasemen Sementara'));
    expect(find.text('Bagikan hasil'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });
}

/// Lingkaran tema menurut labelnya ("Tema biru"); tanpa [label] = semuanya.
Finder _swatch([String? label]) => find.byWidgetPredicate(
  (w) =>
      w is Semantics && (label == null ? (w.properties.label ?? '').startsWith('Tema ') : w.properties.label == label),
);

/// Cincin tinta lingkaran tema = `Semantics.selected`.
bool _selected(WidgetTester tester, String label) =>
    tester.widget<Semantics>(_swatch(label)).properties.selected ?? false;
