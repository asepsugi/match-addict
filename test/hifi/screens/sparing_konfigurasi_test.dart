import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/features/konfigurasi/konfigurasi_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// Golden Atur turnamen pilihan Sparing Fixed, frame 13h, 14f, 14g (AC-S7a). Teks tombol dan subjudul dicek juga lewat
/// `find.text` karena teks kecil lolos toleransi 2% walau salah.
void main() {
  List<Player> roster(int n1, int n2) => [
    for (var i = 1; i <= n1; i++) sparingPlayer('Garuda $i', garuda),
    for (var i = 1; i <= n2; i++) sparingPlayer('Matcha $i', matcha),
  ];

  Widget screen(int n1, int n2) =>
      hifiScreen(KonfigurasiScreen(sport: SportType.padel, players: roster(n1, n2), clubs: const [garuda, matcha]));

  Future<void> tapStep(WidgetTester tester, int index, String label, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(
        find.descendant(of: find.byType(MabarStepper).at(index), matching: find.bySemanticsLabel(label)),
      );
      await tester.pump();
    }
  }

  Future<void> toBottom(WidgetTester tester) async {
    final page = tester.state<ScrollableState>(
      find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first,
    );
    page.position.jumpTo(page.position.maxScrollExtent);
    await tester.pump();
  }

  testWidgets('13h Fixed sparing 8 / 6 · 2 court', (tester) async {
    await expectMatchesHifi(tester, screen(8, 6), '13h');
    expect(find.text('Padel · PB Garuda 8 · Matcha Club 6'), findsOneWidget);
    expect(find.text('· 6 round · 12 match'), findsOneWidget);
  });

  testWidgets('14f Fixed sparing 16 / 14 · 4 court · lewat booking', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(16, 14),
      '14f',
      act: (tester) async {
        await tapStep(tester, 2, 'Tambah', times: 2);
        await toBottom(tester);
      },
    );
    expect(find.text('Padel · PB Garuda 16 · Matcha Club 14'), findsOneWidget);
    expect(find.text('· 14 round · lewat booking 01:30'), findsOneWidget);
    expect(tester.widget<MabarButton>(find.byType(MabarButton)).onPressed, isNotNull);
  });

  testWidgets('14g Fixed sparing 8 / 4 · 3 court · 2 court aktif', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(8, 4),
      '14g',
      act: (tester) async {
        await tapStep(tester, 2, 'Tambah');
        await toBottom(tester);
      },
    );
    expect(find.text('Padel · PB Garuda 8 · Matcha Club 4'), findsOneWidget);
    expect(find.text('· 4 round · 8 match · 2 court'), findsOneWidget);
  });

  testWidgets('AC-S7a K10 28 / 2 di 2 court → lewat booking 01:30', (tester) async {
    await tester.pumpWidget(screen(28, 2));
    expect(find.text('· 14 round · lewat booking 01:30'), findsOneWidget);
  });

  testWidgets('AC-S7a K10 lewat booking dan court aktif < dipesan: tanpa "· n court"', (tester) async {
    await tester.pumpWidget(screen(20, 2));
    await tapStep(tester, 2, 'Tambah', times: 2);
    expect(find.textContaining('lewat booking'), findsOneWidget);
    expect(find.textContaining('court aktif'), findsNothing);
    expect(find.textContaining(RegExp(r'· \d+ court')), findsNothing);
  });

  Future<void> pickMixed(WidgetTester tester) async {
    await tester.tap(find.text('Mixed'));
    await tester.pump();
  }

  testWidgets('13i Mixed sparing 8 / 6 · ±8 round', (tester) async {
    await expectMatchesHifi(tester, screen(8, 6), '13i', act: pickMixed);
    expect(find.text('Padel · PB Garuda 8 · Matcha Club 6'), findsOneWidget);
    expect(find.text('Mulai Round 1'), findsOneWidget);
    expect(find.text('· ±8 round'), findsOneWidget);
    expect(tester.widget<MabarButton>(find.byType(MabarButton)).onPressed, isNotNull);
  });

  testWidgets('13j / AC-S10 Mixed sparing 8 / 3 · 2 court · 1 court aktif', (tester) async {
    await expectMatchesHifi(tester, screen(8, 3), '13j', act: pickMixed);
    expect(find.text('Padel · PB Garuda 8 · Matcha Club 3'), findsOneWidget);
    expect(find.text('· ±8 round · 1 court'), findsOneWidget);
    expect(tester.widget<MabarButton>(find.byType(MabarButton)).onPressed, isNotNull);
  });

  testWidgets('Mixed sparing: Mulai Round 1 → R1 sesama klub dan simpanan sah', (tester) async {
    Object? extra;
    final players = roster(8, 6);
    final router = GoRouter(
      initialLocation: '/atur',
      routes: [
        GoRoute(
          path: '/atur',
          builder: (_, _) => KonfigurasiScreen(sport: SportType.padel, players: players, clubs: const [garuda, matcha]),
        ),
        GoRoute(
          path: '/schedule',
          builder: (_, state) {
            extra = state.extra;
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pickMixed(tester);
    await tester.tap(find.byType(MabarButton));
    await tester.pumpAndSettle();
    final config = extra as TournamentConfig;
    expect(config.mode, PartnerMode.mixed);
    expect(config.isSparing, isTrue);

    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => sparingStart)]);
    addTearDown(container.dispose);
    container.read(tournamentProvider.notifier).startIfNeeded(config);
    final active = container.read(tournamentProvider)!;
    expect(active.roundCount, 1);
    final r1 = active.matchesOfRound(1);
    expect(r1, hasLength(2));
    String? clubOf(String id) => config.playerById(id)?.clubId;
    for (final m in r1) {
      for (final pair in [m.pair1, m.pair2]) {
        expect(clubOf(pair.player1Id), clubOf(pair.player2Id), reason: m.id);
      }
      expect(clubOf(m.pair1.player1Id), garuda.id);
      expect(clubOf(m.pair2.player1Id), matcha.id);
    }
    expect(TournamentCodec.decode(TournamentCodec.encode(active)), isNotNull);
  });

  testWidgets('AC-S7a Lanjut membawa klub + pemain berklub ke Pasangan', (tester) async {
    Object? extra;
    final players = roster(8, 6);
    final router = GoRouter(
      initialLocation: '/atur',
      routes: [
        GoRoute(
          path: '/atur',
          builder: (_, _) => KonfigurasiScreen(sport: SportType.padel, players: players, clubs: const [garuda, matcha]),
        ),
        GoRoute(
          path: '/pair-setup',
          builder: (_, state) {
            extra = state.extra;
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byType(MabarButton));
    await tester.pumpAndSettle();
    final config = extra as TournamentConfig;
    expect(config.isSparing, isTrue);
    expect([for (final c in config.clubs!) c.name], ['PB Garuda', 'Matcha Club']);
    expect(config.players.where((p) => p.clubId == garuda.id), hasLength(8));
    expect(config.playersOfClub(matcha.id), hasLength(6));
  });
}
