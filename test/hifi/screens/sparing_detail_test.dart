import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/detail_player/detail_player_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';
import 'sparing_mixed_fixture.dart';

/// Golden Detail pasangan sparing, frame 14v (Eko · Fajar, PB Garuda) dan 14w (Maya · Nanda, Matcha Club), data
/// `sparingFull()`.
void main() {
  Widget screen(ActiveTournament active, String playerId) => hifiScreen(
    DetailPlayerScreen(playerId: playerId),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => sparingAt(6)),
    ],
  );

  testWidgets('14v Detail pasangan klub pertama', (tester) async {
    await expectMatchesHifi(tester, screen(sparingFull(), 'p-eko'), '14v');
    expect(find.widgetWithText(MabarAppBar, 'Eko · Fajar'), findsOneWidget);
    expect(find.text('Peringkat 1 · PB Garuda · Padel · Fixed · Race to 6'), findsOneWidget);
    expect(find.text('6 / 6'), findsOneWidget);
    expect(find.text('Beda partner'), findsNothing);
  });

  testWidgets('14w Detail pasangan klub kedua: Peringkat 1, Beda lawan 8 / 8', (tester) async {
    await expectMatchesHifi(tester, screen(sparingFull(), 'p-maya'), '14w');
    expect(find.text('Peringkat 1 · Matcha Club · Padel · Fixed · Race to 6'), findsOneWidget);
    expect(find.text('8 / 8'), findsOneWidget);
    // AC-S7: tim sendiri di atas, R2 "Maya · Nanda" sebelum "Eko · Fajar".
    final maya = tester.getTopLeft(find.text('Maya · Nanda').last).dy;
    expect(maya, lessThan(tester.getTopLeft(find.text('vs Eko · Fajar')).dy));
  });

  Widget mixedScreen(MixedSparingState s, String playerId) => hifiScreen(
    DetailPlayerScreen(playerId: playerId),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(s.active)),
      clockProvider.overrideWithValue(() => s.now),
    ],
  );

  testWidgets('15u Detail Mixed sparing klub pertama: Andi, Beda partner 3 / 7, Beda lawan 6 / 6', (tester) async {
    await expectMatchesHifi(tester, mixedScreen(mixedSparing15f(), 'g01'), '15u');
    expect(find.widgetWithText(MabarAppBar, 'Andi'), findsOneWidget);
    expect(find.textContaining('PB Garuda · Padel · Mixed · Race to 6'), findsOneWidget);
    expect(find.text('3 / 7'), findsOneWidget); // 8 pemain Garuda - 1
    expect(find.text('6 / 6'), findsOneWidget); // 6 pemain Matcha
  });

  testWidgets('15v Detail Mixed sparing klub kedua: Lina, Beda partner 5 / 5, Beda lawan 7 / 8', (tester) async {
    await expectMatchesHifi(tester, mixedScreen(mixedSparing15f(), 'm04'), '15v');
    expect(find.widgetWithText(MabarAppBar, 'Lina'), findsOneWidget);
    expect(find.textContaining('Matcha Club · Padel · Mixed · Race to 6'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget); // 6 pemain Matcha - 1
    expect(find.text('7 / 8'), findsOneWidget); // 8 pemain Garuda
  });

  testWidgets('Pemain sparing yang belum main: subjudul "Belum main · klub · …" (Oki, 15l)', (tester) async {
    await tester.pumpWidget(mixedScreen(mixedSparing15lOki(), 'm07'));
    await tester.pumpAndSettle();
    expect(find.text('Belum main · Matcha Club · Padel · Mixed · Race to 6'), findsOneWidget);
  });

  test('coverageTotals: sparing 8 vs 6, turnamen biasa tidak berubah', () {
    final config = sparingFull().config;
    expect(coverageTotals(config, 'p-eko', partnerCount: 1), (partners: 7, opponents: 6));
    expect(coverageTotals(config, 'p-maya', partnerCount: 1), (partners: 5, opponents: 8));
    final plain = TournamentConfig(
      sport: SportType.padel,
      mode: PartnerMode.fixed,
      matchDurationMinutes: 15,
      courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 60)],
      players: [for (var i = 0; i < 6; i++) Player(id: 'q$i', name: 'Q$i')],
    );
    expect(coverageTotals(plain, 'q0', partnerCount: 1), (partners: 5, opponents: 4));
  });
}
