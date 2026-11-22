import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/detail_player/detail_player_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'fixed_extra_fixture.dart';
import 'ranking_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden layar penuh Detail, frame 10a–10c: Andi (data set 1), pasangan Gina · Hana (Fixed 09c), dan
/// Gilang yang belum main.
void main() {
  /// [method] = tab Klasemen asal; harness memaksa Total Point, jadi tab lain di-override.
  Widget screen(ActiveTournament active, String playerId, {RankingMethod? method}) => hifiScreen(
    DetailPlayerScreen(playerId: playerId),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      if (method != null) rankingMethodProvider.overrideWith((ref) => method),
    ],
  );

  testWidgets('10a pemain Mixed, dibuka dari tab Point %', (tester) async {
    await expectMatchesHifi(tester, screen(set1, 'p00', method: RankingMethod.pointPercent), '10a');
  });

  testWidgets('10e Win % tidak bulat, dibuka dari tab Win %', (tester) async {
    await expectMatchesHifi(tester, screen(set1, 'p05', method: RankingMethod.winPercent), '10e');
  });

  testWidgets('Statline lima angka; Point % tampil di semua tab dan "–" kalau belum main', (tester) async {
    for (final m in RankingMethod.values) {
      await tester.pumpWidget(screen(set1, 'p00', method: m));
      expect(find.text('Point %'), findsOneWidget, reason: '$m');
      expect(find.text('58%', findRichText: true), findsOneWidget, reason: 'Andi 42 ÷ 72, $m');
    }
    await tester.pumpWidget(screen(set1, 'p05', method: RankingMethod.totalGames));
    expect(find.text('42%', findRichText: true), findsOneWidget);
    await tester.pumpWidget(screen(set1, 'p10', method: RankingMethod.totalGames));
    expect(find.text('–'), findsNWidgets(5));
  });

  testWidgets('10b pasangan Fixed, menang WO "+6"', (tester) async {
    await expectMatchesHifi(tester, screen(fixedFinal(), 'p6'), '10b');
  });

  testWidgets('10c belum ada match', (tester) async {
    await expectMatchesHifi(tester, screen(set1, 'p10'), '10c');
  });

  testWidgets('10d Fixed, pasangan berubah: Beda partner, nama sendiri dulu', (tester) async {
    await expectMatchesHifi(tester, screen(extraPlayed(), 'p0'), '10d');
  });

  testWidgets('Anggota kedua pasangan membuka Detail yang sama; pemain tak dikenal → teks tengah', (tester) async {
    await tester.pumpWidget(screen(fixedFinal(), 'p7'));
    expect(find.widgetWithText(MabarAppBar, 'Gina R · Hana T'), findsOneWidget);
    await tester.pumpWidget(screen(fixedFinal(), 'nobody'));
    expect(find.text('Belum ada turnamen berjalan'), findsOneWidget);
  });

  testWidgets('Kalah WO: tim sendiri ditandai WO, lawan menang tanpa skor', (tester) async {
    await tester.pumpWidget(screen(fixedFinal(), 'p2'));
    expect(find.widgetWithText(MabarAppBar, 'Citra L · Dewant R'), findsOneWidget);
    expect(find.text('WO'), findsOneWidget);
    expect(find.text('vs Gina R · Hana T'), findsOneWidget);
  });
}
