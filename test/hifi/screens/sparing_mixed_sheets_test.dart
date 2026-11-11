import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';
import 'package:match_addict/features/konfigurasi/konfigurasi_screen.dart';
import 'package:match_addict/features/schedule/mixed/resume_tournament_sheet.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart' show LoadedTournament;
import 'screen_harness.dart';
import 'sparing_mixed_fixture.dart';

/// Sheet Mixed sparing di atas Jadwal (SP-18e): Lanjutkan 15j, Cara kerja 15k, Kelola court 15o. Data dari
/// `sparing_mixed_fixture.dart`; jam `clockProvider` ikut keadaan.
void main() {
  List<Override> overrides(MixedSparingState s) => [
    tournamentProvider.overrideWith(() => LoadedTournament(s.active)),
    clockProvider.overrideWithValue(() => s.now),
  ];

  Widget screen(MixedSparingState s) =>
      hifiScreen(ScheduleMixedScreen(config: s.active.config), overrides: overrides(s));

  Future<void> pumpPhone(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  Future<void> openMenuItem(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('15j lanjutkan, Court 1 + 1 jam: 4 round, 1 court', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing15f()),
      '15j',
      act: (tester) async {
        await tester.tap(find.text('Tambah jam'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Tambah').first);
      },
    );
    expect(find.text('4 round (R9–R12) · 1 court'), findsOneWidget);
  });

  testWidgets('AC-S10 Lanjutkan 8 / 3: "maks 1 match per round (Matcha Club 3 pemain)"', (tester) async {
    final s = mixedSparing15e();
    await pumpPhone(
      tester,
      hifiScreen(
        Builder(
          builder: (context) =>
              TextButton(onPressed: () => showResumeTournamentSheet(context, s.active), child: const Text('Buka')),
        ),
        overrides: overrides(s),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.textContaining('maks 1 match per round (Matcha Club 3 pemain)'), findsOneWidget);
  });

  testWidgets('15k cara kerja Mixed sparing: Estimasi per klub, aturan ketiga per klub', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing15k()),
      '15k',
      act: (tester) => openMenuItem(tester, 'Cara kerja Mixed'),
    );
    for (final t in [
      'Selisih match antar pemain satu klub ≤ 1',
      'Match/Pemain · PB Garuda',
      'Match/Pemain · Matcha Club',
      '±4',
      '±5',
      '16',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Match/Pemain'), findsNothing);
  });

  testWidgets('13i → Mulai Round 1: sheet Cara kerja muncul sekali', (tester) async {
    final players = [
      for (final (i, n) in garudaNames.indexed) Player(id: 'g$i', name: n, clubId: garuda.id),
      for (final (i, n) in matchaNames.indexed) Player(id: 'm$i', name: n, clubId: matcha.id),
    ];
    final router = GoRouter(
      initialLocation: '/atur',
      routes: [
        GoRoute(
          path: '/atur',
          builder: (_, _) => KonfigurasiScreen(sport: SportType.padel, players: players, clubs: const [garuda, matcha]),
        ),
        GoRoute(
          path: '/schedule',
          builder: (_, state) => ScheduleMixedScreen(config: state.extra! as TournamentConfig),
        ),
      ],
    );
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      hifiRouterScreen(router, overrides: [clockProvider.overrideWithValue(() => mixedSparingStart)]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mixed'));
    await tester.pump();
    await tester.tap(find.widgetWithText(MabarButton, 'Mulai Round 1'));
    await tester.pumpAndSettle();

    expect(find.byType(MabarSheet), findsOneWidget);
    expect(find.text('Cara kerja Mixed'), findsOneWidget);
    expect(find.text('Selisih match antar pemain satu klub ≤ 1'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.byType(MabarSheet), findsNothing, reason: 'hanya sekali');
  });

  testWidgets('15o kelola court sparing: langsung main per klub; Tambah court → match Court 3', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing15b()),
      '15o',
      act: (tester) => openMenuItem(tester, 'Kelola court'),
    );
    expect(find.text('Langsung main di R4'), findsOneWidget);
    for (final t in ['Fajar', 'Gita', 'Joko', 'Maya']) {
      expect(find.text(t), findsWidgets, reason: t);
    }

    await tester.tap(find.text('Tambah court'));
    await tester.pumpAndSettle();
    final active = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleMixedScreen)),
    ).read(tournamentProvider)!;
    final court3 = active.matchesOfRound(4).last;
    expect(court3.courtId, isNot(anyOf('c1', 'c2')));
    final names = [for (final id in court3.pair1.playerIds + court3.pair2.playerIds) active.playerName(id)];
    expect(names, unorderedEquals(['Fajar', 'Gita', 'Joko', 'Maya']));
  });
}
