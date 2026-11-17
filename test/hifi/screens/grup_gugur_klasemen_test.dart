import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/detail_player/detail_player_screen.dart';
import 'package:match_addict/features/leaderboard/leaderboard_screen.dart';
import 'package:match_addict/features/leaderboard/widgets/standing_table.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden Klasemen Grup + Gugur (20d, 20f, 20h, 20n, 22a–22i) dan Detail (22j, 22k), docs/tasks.md GG-8.
void main() {
  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    const LeaderboardScreen(),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Widget detail(ActiveTournament active, String playerId) => hifiScreen(
    DetailPlayerScreen(playerId: playerId),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => at21f),
    ],
  );

  Future<void> fasePhase(WidgetTester tester) => tester.tap(find.text('Fase grup'));
  Future<void> scrollDown(WidgetTester tester) => tester.drag(find.byType(ListView), const Offset(0, -2000));

  /// Nomor dan nama baris tabel pertama: nomor dari `position`, bukan indeks.
  List<(int, String)> rows(WidgetTester tester) {
    final table = tester.widget<StandingTable>(find.byType(StandingTable).first);
    return [for (final r in table.rows) (r.position, r.names.join(' · '))];
  }

  testWidgets('20d tabel per grup tanpa tab metode, status Sementara', (tester) async {
    await expectMatchesHifi(tester, screen(gg20b(), at20b), '20d');
    expect(find.text('Padel · Fase grup · Sementara · R3 · 5 dari 12 match'), findsOneWidget);
    expect(find.text('Total Point'), findsNothing);
    expect(find.text('Peringkat'), findsNothing);
    expect(find.text('A1'), findsNothing);
  });

  testWidgets('20f nomor sama di #1 (1, 1, 2, 3), tetap Sementara walau semua terisi', (tester) async {
    await expectMatchesHifi(tester, screen(gg20e(), at20e), '20f');
    expect(find.textContaining('Sementara'), findsOneWidget);
    expect(rows(tester), [(1, 'Andi · Budi'), (1, 'Citra · Dewi'), (2, 'Eko · Fajar'), (3, 'Gita · Hadi')]);
  });

  testWidgets('20h seri tiga pasangan di #2 (1, 2, 2, 2)', (tester) async {
    await expectMatchesHifi(tester, screen(gg20h(), at20e), '20h');
    expect([for (final r in rows(tester)) r.$1], [1, 2, 2, 2]);
  });

  testWidgets('20n 4 grup, Tono belum main tanpa nomor', (tester) async {
    await expectMatchesHifi(tester, screen(gg20m(), at20m), '20n');
    expect(find.text('Belum main', skipOffstage: false), findsOneWidget);
  });

  testWidgets('22a peringkat akhir: nomor tingkat babak, kolom Babak', (tester) async {
    await expectMatchesHifi(tester, screen(gg21i(), at21f), '22a');
    expect(find.text('Padel · Grup + Gugur · Final · 8 round · 16 match'), findsOneWidget);
    expect(rows(tester), [
      (1, 'Citra · Dewi'),
      (2, 'Andi · Budi'),
      (3, 'Maya · Nanda'),
      (4, 'Indra · Joko'),
      (5, 'Eko · Fajar'),
      (5, 'Kiki · Lina'),
      (6, 'Gita · Hadi'),
      (6, 'Oki · Putri'),
    ]);
    expect(find.text('Main'), findsNothing);
  });

  testWidgets('22b Fase grup: slot A1/A2/B1/B2 dari seedOf, tabel grup', (tester) async {
    await expectMatchesHifi(tester, screen(gg21i(), at21f), '22b', act: fasePhase);
    for (final slot in ['A1', 'A2', 'B1', 'B2']) {
      expect(find.text(slot), findsOneWidget);
    }
  });

  testWidgets('22c tanpa Perebutan juara 3: dua Semifinal #3', (tester) async {
    await expectMatchesHifi(tester, screen(gg21q(), at21f), '22c');
    expect([for (final r in rows(tester)) r.$1], [1, 2, 3, 3, 4, 4, 5, 5]);
  });

  testWidgets('22d bagan baru dibuat: empat Semifinal #1', (tester) async {
    await expectMatchesHifi(tester, screen(gg21a(), at21b), '22d');
    expect(find.text('Padel · Gugur · Sementara · R7 · 12 dari 16 match'), findsOneWidget);
    expect([for (final r in rows(tester)) r.$1], [1, 1, 1, 1, 2, 2, 3, 3]);
  });

  testWidgets('22e SF1 terisi', (tester) async {
    await expectMatchesHifi(tester, screen(gg21c(), at21b), '22e');
    expect(find.text('Perebutan juara 3'), findsOneWidget);
  });

  testWidgets('22f diakhiri setelah Semifinal', (tester) async {
    await expectMatchesHifi(tester, screen(gg21t(), at21f), '22f');
    expect([for (final r in rows(tester)) r.$1], [1, 1, 2, 2, 3, 3, 4, 4]);
  });

  testWidgets('22g diakhiri di fase grup: Peringkat = posisi grup', (tester) async {
    await expectMatchesHifi(tester, screen(gg20q(), at20b), '22g');
    expect(find.text('Padel · Grup + Gugur · Final · 4 round · 7 match'), findsOneWidget);
    expect(find.text('5 match tidak dimainkan'), findsOneWidget);
    expect(find.text('Grup A · 1'), findsOneWidget);
  });

  testWidgets('22h 4 grup, Perempat final berbagi #5', (tester) async {
    await expectMatchesHifi(tester, screen(gg21y(), at21f), '22h');
  });

  testWidgets('22i 4 grup digulir: posisi grup 3 berbagi #6', (tester) async {
    await expectMatchesHifi(tester, screen(gg21y(), at21f), '22i', act: scrollDown);
  });

  testWidgets('22j Detail pasangan juara: angka fase grup, riwayat semua match berlabel babak', (tester) async {
    await expectMatchesHifi(tester, detail(gg21i(), 'Citra'), '22j');
    expect(find.text('Peringkat 1 · Juara · Padel · Grup + Gugur'), findsOneWidget);
    expect(find.text('Grup A · Race to 6'), findsOneWidget);
    expect(find.text('Final · Race to 9'), findsOneWidget);
    expect(find.text('Semifinal · Race to 6'), findsOneWidget);
    expect(find.text('Beda lawan'), findsNothing);
  });

  testWidgets('22k Detail pasangan tidak lolos: #5, hanya match grup', (tester) async {
    await expectMatchesHifi(tester, detail(gg21i(), 'Eko'), '22k');
    expect(find.text('Peringkat 5 · Grup A · 3 · Padel · Grup + Gugur'), findsOneWidget);
  });
}
