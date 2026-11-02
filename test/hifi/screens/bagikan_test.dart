import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/share_result_screen.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';

import '../components/share_poster_data.dart';
import '../hifi_golden.dart';
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
  (ActiveTournament, List<StandingEntry>) mixedFromPoster(String frame, {required int rounds, required int courts}) {
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

  Widget screen(ActiveTournament active, {List<StandingEntry>? entries}) => hifiScreen(
    const ShareResultScreen(),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
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

  for (final (frame, rounds, courts) in [('11e', 8, 4), ('11h', 6, 3), ('11i', 6, 3)]) {
    testWidgets('$frame Lengkap Mixed dua kolom', (tester) async {
      await precacheHifiAssets(tester, [SportType.padel.assetPath]);
      final (active, entries) = mixedFromPoster(frame, rounds: rounds, courts: courts);
      await expectMatchesHifi(tester, screen(active, entries: entries), frame, act: lengkap);
    });
  }

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
