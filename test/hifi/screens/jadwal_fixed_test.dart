import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/match_score_row.dart';
import 'package:match_addict/features/live/live_host_controller.dart';
import 'package:match_addict/features/live/live_screen.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'live_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden layar penuh Jadwal Fixed, frame 06a–06e. Fixture ([fixedTournament]) di `schedule_fixture.dart`.
void main() {
  final running = fixedRunning, ended = fixedEnded;

  Widget screen(ActiveTournament active) {
    return hifiScreen(
      ScheduleFixedScreen(config: active.config),
      overrides: [
        tournamentProvider.overrideWith(() => LoadedTournament(active)),
        clockProvider.overrideWithValue(() => fixedStart.add(const Duration(minutes: 45))),
      ],
    );
  }

  testWidgets('06a round berjalan', (tester) async {
    await expectMatchesHifi(tester, screen(running), '06a');
  });

  testWidgets('06b round yang belum terbuka', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(running),
      '06b',
      act: (tester) => tester.tap(find.text('R3')),
    );
  });

  testWidgets('06c turnamen diakhiri', (tester) async {
    await expectMatchesHifi(tester, screen(ended), '06c');
  });

  testWidgets('06d menu ⋯', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(running),
      '06d',
      act: (tester) => tester.tap(find.bySemanticsLabel('Menu')),
    );
  });

  testWidgets('06e dialog akhiri', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(running),
      '06e',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Akhiri turnamen'));
      },
    );
  });

  testWidgets('12f menu ⋯ setelah diakhiri: tetap aktif, Live score menyala', (tester) async {
    await expectMatchesHifi(
      tester,
      hifiScreen(
        ScheduleFixedScreen(config: ended.config),
        overrides: [
          tournamentProvider.overrideWith(() => LoadedTournament(ended)),
          clockProvider.overrideWithValue(() => fixedStart.add(const Duration(minutes: 45))),
          liveHostProvider.overrideWith(() => ShownLive(LiveHost(code: 'K7Q2MX', sentAt: fixedStart))),
        ],
      ),
      '12f',
      act: (tester) => tester.tap(find.bySemanticsLabel('Menu')),
    );
  });

  testWidgets('12i penonton Jadwal Fixed tanpa nama', (tester) async {
    await expectMatchesHifi(
      tester,
      hifiScreen(
        const LiveScreen(),
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          liveViewProvider.overrideWith(() => Watching(LiveView(LiveViewStatus.live, running))),
          tournamentProvider.overrideWith(LiveTournamentController.new),
          clockProvider.overrideWithValue(() => fixedStart.add(const Duration(minutes: 45))),
        ],
      ),
      '12i',
    );
    expect(find.text('Isi skor'), findsNothing);
  });

  Future<void> pumpRouted(WidgetTester tester, ActiveTournament active, List<String> visited) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/schedule',
      routes: [
        GoRoute(path: '/schedule', builder: (_, _) => ScheduleFixedScreen(config: active.config)),
        GoRoute(
          path: '/score-input',
          builder: (_, state) {
            visited.add('score:${state.extra}');
            return const Text('Input skor');
          },
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) {
            visited.add('leaderboard');
            return const Text('Klasemen');
          },
        ),
      ],
    );
    await tester.pumpWidget(hifiRouterScreen(router, overrides: [tournamentProvider.overrideWith(() => LoadedTournament(active))]));
    await tester.pumpAndSettle();
  }

  testWidgets('Round terkunci tidak bisa diketuk; round sebelumnya tetap bisa diubah', (tester) async {
    final visited = <String>[];
    await pumpRouted(tester, running, visited);
    await tester.tap(find.text('R3'));
    await tester.pumpAndSettle();
    expect(find.text('Isi skor'), findsNothing);
    await tester.tap(find.text('Andi P · Budi S'));
    await tester.pumpAndSettle();
    expect(visited, isEmpty);

    await tester.tap(find.text('R1'));
    await tester.pumpAndSettle();
    expect(find.text('Round 1'), findsOneWidget);
    await tester.tap(find.text('Citra L · Dewant R'));
    await tester.pumpAndSettle();
    expect(visited, ['score:r1c1']);
  });

  testWidgets('Akhiri: match kosong tidak dimainkan, buka Klasemen, menu tinggal Live score', (tester) async {
    final visited = <String>[];
    await pumpRouted(tester, running, visited);
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri turnamen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri'));
    await tester.pumpAndSettle();
    expect(visited, ['leaderboard']);

    final element = tester.element(find.byType(ScheduleFixedScreen, skipOffstage: false));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(element.mounted, isTrue);
    expect(find.text('Tennis · Race to 6 · diakhiri'), findsOneWidget);
    // Tab default = round terakhir setelah diakhiri; R5 belum dimainkan sama sekali.
    expect(find.text('Round 5'), findsOneWidget);
    expect(find.text('Tidak dimainkan'), findsNWidgets(2));
    expect(find.text('Lihat klasemen'), findsOneWidget);
    expect(tester.widget<MatchScoreRow>(find.byType(MatchScoreRow).last).onTap, isNull);
    // ⋯ tetap aktif (12f): Akhiri turnamen hilang, Live score tetap ada.
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Live score'), findsOneWidget);
    expect(find.text('Akhiri turnamen'), findsNothing);
  });
}
