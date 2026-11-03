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
  Widget screen(ActiveTournament active) =>
      hifiScreen(const LeaderboardScreen(), overrides: [tournamentProvider.overrideWith(() => LoadedTournament(active))]);

  Future<void> winPercent(WidgetTester tester) => tester.tap(find.text('Win %').first);

  testWidgets('09a Total Point, statistik identik', (tester) async {
    await expectMatchesHifi(tester, screen(set1), '09a');
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
