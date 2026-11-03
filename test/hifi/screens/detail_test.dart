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
  Widget screen(ActiveTournament active, String playerId) => hifiScreen(
    DetailPlayerScreen(playerId: playerId),
    overrides: [tournamentProvider.overrideWith(() => LoadedTournament(active))],
  );

  testWidgets('10a pemain Mixed', (tester) async {
    await expectMatchesHifi(tester, screen(set1, 'p00'), '10a');
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
