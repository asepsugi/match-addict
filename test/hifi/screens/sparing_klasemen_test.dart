import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/club_score.dart';
import 'package:match_addict/features/leaderboard/leaderboard_screen.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// Golden Klasemen sparing, frame 13n–13p, 14p, 14s–14u (docs/tasks.md SP-13). Data dari `sparing_fixture.dart`.
void main() {
  Widget screen(ActiveTournament active, {int rounds = 6, List<Override> extra = const []}) => hifiScreen(
    const LeaderboardScreen(),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => sparingAt(rounds)),
      ...extra,
    ],
  );

  Future<void> winPercent(WidgetTester tester) => tester.tap(find.text('Win %').first);
  Future<void> scrollDown(WidgetTester tester) => tester.drag(find.byType(ListView), const Offset(0, -2000));

  // Teks kecil (angka skor klub, bola) lolos toleransi 2% walau salah, jadi dicek juga lewat teks.
  void expectBoard({required String first, required String second, required int balls}) {
    final board = find.byType(ClubScore);
    expect(find.descendant(of: board, matching: find.text(first)), findsWidgets);
    expect(find.descendant(of: board, matching: find.text(second)), findsWidgets);
    expect(find.byKey(ClubScore.ballKey), findsNWidgets(balls));
  }

  testWidgets('13n Sementara: 6 – 4, 45 – 43 (AC-S14)', (tester) async {
    await expectMatchesHifi(tester, screen(sparingAfterR5(), rounds: 5), '13n');
    expectBoard(first: '6', second: '4', balls: 1);
    expect(find.text('45 game · +8'), findsOneWidget);
    expect(find.text('43 game · −8'), findsOneWidget);
    expect(find.text('Padel · Fixed · Sementara · R6 · 10 dari 12 match'), findsOneWidget);
  });

  testWidgets('13o Final digulir: papan dan tab tetap, 7 – 5, 56 – 49, "1 match WO" di bawah (AC-S14)', (tester) async {
    await expectMatchesHifi(tester, screen(sparingFull()), '13o', act: scrollDown);
    expectBoard(first: '7', second: '5', balls: 1);
    expect(find.text('56 game · +13'), findsOneWidget);
    expect(find.text('49 game · −13'), findsOneWidget);
    expect(find.text('1 match WO'), findsOneWidget);
    expect(find.text('Padel · Fixed · Final · 6 round · 12 match'), findsOneWidget);
  });

  testWidgets('13o papan dan tab metode tidak bergeser saat digulir', (tester) async {
    await tester.pumpWidget(screen(sparingFull()));
    await tester.pumpAndSettle();
    final board = tester.getTopLeft(find.byType(ClubScore));
    final tab = tester.getTopLeft(find.text('Total Point').first);
    await scrollDown(tester);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ClubScore)), board);
    expect(tester.getTopLeft(find.text('Total Point').first), tab);
  });

  testWidgets('13o nomor tiap klub mulai #1: Garuda #1–#4, Matcha #1–#3 (AC-S17)', (tester) async {
    await tester.pumpWidget(screen(sparingFull()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(LeaderboardScreen)));
    final groups = container.read(clubStandingEntriesProvider);
    expect(
      [
        for (final g in groups) [for (final e in g.entries) e.position],
      ],
      [
        [1, 2, 3, 4],
        [1, 2, 3],
      ],
    );
    // Baris pertama tiap klub = pasangan yang dimaksud frame 13o.
    expect(
      [for (final g in groups) g.entries.first.players.map((p) => p.name).join(' · ')],
      ['Eko · Fajar', 'Maya · Nanda'],
    );
    expect(find.text('PB Garuda'), findsWidgets);
  });

  testWidgets('13p Win %: urutan dan kolom berubah, papan tetap (AC-S17)', (tester) async {
    await expectMatchesHifi(tester, screen(sparingFull()), '13p', act: winPercent);
    expectBoard(first: '7', second: '5', balls: 1);
    expect(find.text('56 game · +13'), findsOneWidget);
    expect(find.text('Win %'), findsNWidgets(3)); // tab + kolom di dua tabel
  });

  testWidgets('14p pasangan diatur ulang: baris campuran, Belum main per klub, papan tetap 7 – 5', (tester) async {
    await expectMatchesHifi(tester, screen(sparingReplaced()), '14p', act: scrollDown);
    expectBoard(first: '7', second: '5', balls: 1);
    expect(find.text('Belum main'), findsNWidgets(2));
    expect(find.text('Gilang'), findsOneWidget);
    expect(find.text('Oki'), findsOneWidget);
    expect(find.text('Padel · Fixed · Sementara · R7 · 12 dari 24 match'), findsOneWidget);
  });

  testWidgets('14s klub kedua unggul: bola pindah ke baris bawah, 5 – 7, 56 – 60', (tester) async {
    await expectMatchesHifi(tester, screen(sparing14s()), '14s');
    expectBoard(first: '5', second: '7', balls: 1);
    expect(find.text('56 game · −4'), findsOneWidget);
    expect(find.text('60 game · +4'), findsOneWidget);
  });

  testWidgets('14t Seri: 6 – 6, bola di kedua baris', (tester) async {
    await expectMatchesHifi(tester, screen(sparing14t()), '14t');
    expectBoard(first: '6', second: '6', balls: 2);
    expect(find.text('58 game · 0'), findsNWidgets(2));
  });

  testWidgets('14u match seri: 6½ – 5½ (AC-S16)', (tester) async {
    await expectMatchesHifi(tester, screen(sparing14u()), '14u');
    expectBoard(first: '6½', second: '5½', balls: 1);
  });

  testWidgets('Penonton Live membaca angka yang sama, tanpa Bagikan (AC-S17)', (tester) async {
    await tester.pumpWidget(screen(sparingFull(), extra: [liveCodeProvider.overrideWithValue('K7Q2MX')]));
    await tester.pumpAndSettle();
    expectBoard(first: '7', second: '5', balls: 1);
    expect(find.text('56 game · +13'), findsOneWidget);
    expect(find.text('Bagikan'), findsNothing);
  });
}
