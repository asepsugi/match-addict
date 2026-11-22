import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/features/leaderboard/leaderboard_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'fixed_extra_fixture.dart';
import 'ranking_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden layar penuh Peringkat, frame 09a–09f. Data = `test/services/ranking_v2_test.dart` (logic.md §3–§4):
/// set 1 Americano 24 R1–R3 + Gilang belum main (09a/09b), set 2 R1–R4 dengan satu WO dan satu seri
/// (09d/09e, diakhiri di 09f), dan Fixed Tennis 5 pasangan final (09c).
void main() {
  /// [method] = metode yang tampil saat frame dibuka; harness memaksa Total Point, jadi default format yang
  /// bukan Total Point (Americano → Point %) wajib di-override di sini.
  Widget screen(ActiveTournament active, {RankingMethod? method}) => hifiScreen(
    const LeaderboardScreen(),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      if (method != null) rankingMethodProvider.overrideWith((ref) => method),
    ],
  );

  Future<void> winPercent(WidgetTester tester) => tester.tap(find.text('Win %').first);
  Future<void> pointPercent(WidgetTester tester) => tester.tap(find.text('Point %').first);

  testWidgets('09a Point %, dibuka pertama (Americano)', (tester) async {
    await expectMatchesHifi(tester, screen(set1, method: RankingMethod.pointPercent), '09a');
  });

  testWidgets('09i Total Point, nomor sama', (tester) async {
    await expectMatchesHifi(tester, screen(set1), '09i');
  });

  testWidgets('09j Point %, jumlah main beda (18A)', (tester) async {
    await expectMatchesHifi(tester, screen(data18a, method: RankingMethod.pointPercent), '09j');
  });

  testWidgets('09k Fixed Race to, tab Point %', (tester) async {
    await expectMatchesHifi(tester, screen(data18b()), '09k', act: pointPercent);
  });

  testWidgets('09l Point % dengan WO', (tester) async {
    await expectMatchesHifi(tester, screen(set2(), method: RankingMethod.pointPercent), '09l');
  });

  testWidgets('09b Win %', (tester) async {
    await expectMatchesHifi(tester, screen(set1), '09b', act: winPercent);
  });

  testWidgets('09c Fixed final', (tester) async {
    await expectMatchesHifi(tester, screen(fixedFinal()), '09c');
  });

  testWidgets('09d Total Point, satu WO', (tester) async {
    await expectMatchesHifi(tester, screen(set2()), '09d');
  });

  testWidgets('09e Win %, urutan berubah', (tester) async {
    await expectMatchesHifi(tester, screen(set2()), '09e', act: winPercent);
  });

  testWidgets('09f Mixed final setelah diakhiri', (tester) async {
    await expectMatchesHifi(tester, screen(set2(finished: true)), '09f');
  });

  testWidgets('09g Fixed, pasangan diatur ulang: baris campuran', (tester) async {
    await expectMatchesHifi(tester, screen(extraPlayed()), '09g');
  });

  testWidgets('Tiga tab berurutan Total Point · Point % · Win %; ganti tab mengubah urutan baris dan kolom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    // 18A (AC-RP3): Total Point Andi #1; Point % Budi #1, Andi #3; Win % Budi #1, Dewi #2.
    await tester.pumpWidget(screen(data18a, method: RankingMethod.pointPercent));
    await tester.pumpAndSettle();
    final tabs = [
      for (final t in ['Total Point', 'Point %', 'Win %']) tester.getTopLeft(find.text(t).first).dx,
    ];
    expect(tabs, orderedEquals([...tabs]..sort()));

    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    // Kolom Point %: judul "Point %" di tab dan di tabel, angka bulat tanpa tanda %.
    expect(find.text('Point %'), findsNWidgets(2));
    expect(find.text('57'), findsOneWidget); // Budi 36/63
    expect(find.text('49'), findsOneWidget); // Andi 41/84
    expect(y('Budi'), lessThan(y('Andi')));

    await tester.tap(find.text('Total Point').first);
    await tester.pumpAndSettle();
    expect(find.text('Point %'), findsOneWidget);
    expect(find.text('Poin'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(y('Andi'), lessThan(y('Budi')));

    await winPercent(tester);
    await tester.pumpAndSettle();
    expect(find.text('Win %'), findsNWidgets(2));
    expect(find.text('100'), findsOneWidget); // Budi 3–0
    expect(y('Budi'), lessThan(y('Dewi')));
  });

  testWidgets('Ketuk baris → Detail pemain itu; metode dipakai bersama', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    String? opened;
    final router = GoRouter(
      initialLocation: '/leaderboard',
      routes: [
        GoRoute(path: '/leaderboard', builder: (_, _) => const LeaderboardScreen()),
        GoRoute(
          path: '/detail-player',
          builder: (_, state) {
            opened = state.extra! as String;
            return const Text('Detail');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(router, overrides: [tournamentProvider.overrideWith(() => LoadedTournament(set2()))]),
    );
    await tester.pumpAndSettle();
    await winPercent(tester);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(LeaderboardScreen)));
    expect(container.read(rankingMethodProvider), RankingMethod.winPercent);
    await tester.tap(find.text('Indra W'));
    await tester.pumpAndSettle();
    expect(opened, 'p08');
  });
}
