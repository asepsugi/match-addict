import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/score_input/score_input_screen.dart';
import 'package:match_addict/features/score_input/widgets/score_board.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart' show LoadedTournament;
import 'screen_harness.dart';
import 'sparing_fixture.dart';
import 'sparing_mixed_fixture.dart' show MixedSparingState, mixedSparing13m, mixedSparing15r;

/// Golden Input Skor + sheet WO turnamen sparing (14q, 14r; Mixed 15q, 15r) dan perilakunya (AC-S7, AC-S15, K11). Papan membaca
/// `pair1` = klub pertama (S4), jadi layarnya sama dengan Input Skor biasa.
void main() {
  Widget screen(ActiveTournament active, String matchId, DateTime now) => hifiScreen(
    ScoreInputScreen(matchId: matchId),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> type(WidgetTester tester, List<int> digits) async {
    for (final d in digits) {
      await tester.tap(find.descendant(of: find.byType(ScoreKeypad), matching: find.text('$d')));
      await tester.pump();
    }
  }

  // 14q: R6 berjalan, sisa 00:45 = 75 menit sejak mulai.
  final r6Now = sparingAt(5);
  // 14r: R3 berjalan, sisa 01:20 = 40 menit sejak mulai.
  final r3Now = sparingStart.add(const Duration(minutes: 40));

  testWidgets('14q Input Skor Court 1 R6 (klub pertama di atas)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(sparingAfterR5(), 'm-r6-1', r6Now),
      '14q',
      act: (tester) => type(tester, [6, 0]),
    );
    expect(find.text('Eko & Fajar menang 6–0'), findsOneWidget);
    expect(find.textContaining('sisa 00:45'), findsOneWidget);
  });

  testWidgets('14r sheet walkover: urutan pilihan = urutan papan', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(sparingR3(), 'm-r3-2', r3Now),
      '14r',
      act: (tester) async {
        await tester.tap(find.text('WO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Citra · Dewi'));
        await tester.pump();
        await tester.tap(find.text('Absen'));
      },
    );
    expect(tester.getTopLeft(find.text('Citra · Dewi')).dy, lessThan(tester.getTopLeft(find.text('Maya · Nanda')).dy));
    expect(find.text('Maya & Nanda menang WO dan dapat 6 game.'), findsOneWidget);
  });

  Future<ProviderContainer> pump(WidgetTester tester, ActiveTournament active, String matchId, DateTime now) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/schedule',
      routes: [
        GoRoute(path: '/schedule', builder: (_, _) => const Text('Jadwal')),
        GoRoute(
          path: '/score-input',
          builder: (_, state) => ScoreInputScreen(matchId: state.extra! as String),
        ),
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
    router.push('/score-input', extra: matchId);
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ScoreInputScreen)));
  }

  String line(ClubResult r) =>
      '${r.first.winsLabel} – ${r.second.winsLabel} · ${r.first.totalPoint} – ${r.second.totalPoint}';

  testWidgets('AC-S7 simpan skor R6 menghitung ulang skor klub: 13k → 13l', (tester) async {
    final container = await pump(tester, sparingAfterR5(), 'm-r6-1', r6Now);
    expect(line(container.read(clubScoreProvider)!), '6 – 4 · 45 – 43');
    await type(tester, [6, 0]);
    await tester.tap(find.text('Simpan skor'));
    await tester.pumpAndSettle();
    expect(container.read(clubScoreProvider)!.first.totalPoint, 51);

    // Court 2 lewat controller (layar yang sama): pair1 = klub pertama, jadi 5–6 = Matcha menang.
    final active = container.read(tournamentProvider)!;
    final match = active.matchById('m-r6-2')!;
    expect(active.config.clubOfPlayer(match.pair1.player1Id), garuda);
    container.read(tournamentProvider.notifier).submitScore('m-r6-2', [const SetScore(side1: 5, side2: 6)]);
    expect(line(container.read(clubScoreProvider)!), '7 – 5 · 56 – 49');
  });

  testWidgets('AC-S15 simpan WO R3 Court 2: Matcha +1 menang, Total Point +6, selisih tetap', (tester) async {
    final container = await pump(tester, sparingR3(), 'm-r3-2', r3Now);
    final before = container.read(clubScoreProvider)!;
    expect(line(before), '4 – 1 · 28 – 22');
    await tester.tap(find.text('WO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Citra · Dewi'));
    await tester.pump();
    await tester.tap(find.text('Simpan WO'));
    await tester.pumpAndSettle();
    final after = container.read(clubScoreProvider)!;
    expect(after.second.halfWins - before.second.halfWins, 2);
    expect(after.second.totalPoint - before.second.totalPoint, 6);
    expect(after.first.totalPoint, before.first.totalPoint);
    expect((after.first.diff, after.second.diff), (before.first.diff, before.second.diff));
  });

  // SP-18f: Mixed sparing memakai layar dan sheet yang sama dengan Fixed (S4: pair1 = klub pertama).
  Widget mixedScreen(MixedSparingState s, String matchId) => screen(s.active, matchId, s.now);

  testWidgets('15q Input Skor Mixed sparing Court 2 R3 (klub pertama di atas, tanpa label klub)', (tester) async {
    final s = mixedSparing13m();
    await expectMatchesHifi(tester, mixedScreen(s, 'm-r3-2'), '15q', act: (tester) => type(tester, [5, 6]));
    expect(find.text('Lina & Maya menang 6–5'), findsOneWidget);
    // AC-S7: dua pemain klub pertama di baris atas papan, tanpa nama klub.
    expect(tester.getTopLeft(find.text('Citra')).dy, lessThan(tester.getTopLeft(find.text('Lina')).dy));
    expect(find.text('PB Garuda'), findsNothing);
    expect(find.text('Matcha Club'), findsNothing);
  });

  testWidgets('15r sheet walkover Mixed sparing Americano: urutan pilihan = urutan papan', (tester) async {
    final s = mixedSparing15r();
    await expectMatchesHifi(
      tester,
      mixedScreen(s, 'm-r3-2'),
      '15r',
      act: (tester) async {
        await tester.tap(find.text('WO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Citra · Gita'));
        await tester.pump();
        await tester.tap(find.text('Absen'));
      },
    );
    expect(tester.getTopLeft(find.text('Citra · Gita')).dy, lessThan(tester.getTopLeft(find.text('Lina · Maya')).dy));
    expect(find.text('Lina & Maya menang WO dan dapat poin rata-rata mereka, minimal 11.'), findsOneWidget);
  });

  testWidgets('K11 simpan WO 15r: Matcha +1 menang, +12 Total Point klub, selisih tetap; Lina 18, Maya 24', (
    tester,
  ) async {
    final s = mixedSparing15r();
    final container = await pump(tester, s.active, 'm-r3-2', s.now);
    final before = container.read(clubScoreProvider)!;
    await tester.tap(find.text('WO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Citra · Gita'));
    await tester.pump();
    await tester.tap(find.text('Simpan WO'));
    await tester.pumpAndSettle();
    final after = container.read(clubScoreProvider)!;
    expect(after.second.halfWins - before.second.halfWins, 2);
    expect(after.second.totalPoint - before.second.totalPoint, 12);
    expect(after.first.totalPoint, before.first.totalPoint);
    expect((after.first.diff, after.second.diff), (before.first.diff, before.second.diff));
    expect(line(after), '4 – 2 · 59 – 58');

    // Nilai WO pemain (4.4): rata-rata poin mereka sendiri, minimal 11 — Lina 7 + 11, Maya 12 + 12.
    final points = {
      for (final g in container.read(clubStandingEntriesProvider))
        for (final e in g.entries) e.players.single.name: e.standing.totalPoint,
    };
    expect([points['Lina'], points['Maya']], [18, 24]);
  });
}
