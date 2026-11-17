import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/features/schedule/group_knockout/bagan_view.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/schedule/widgets/round_tabs.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden tab Bagan Jadwal Grup + Gugur (GG-9): 2 grup 21a–21t, 4 grup 21u–21y. Fixture bersama
/// `grup_gugur_fixture.dart`; Bagan tidak menampilkan jam, jadi jam frame terdekat saja.
void main() {
  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Finder tab(String label) => find.descendant(of: find.byType(RoundTabs), matching: find.text(label));

  /// Tab Bagan di ujung kanan strip; strip digeser dulu kalau tab di luar layar.
  Future<void> openBagan(WidgetTester t) async {
    await t.ensureVisible(tab('Bagan'));
    await t.pumpAndSettle();
    await t.tap(tab('Bagan'));
  }

  /// 21p: SF1 6–4, SF2 WO Indra · Joko (Cedera) → Final Andi–Citra, Juara 3 Maya–Indra.
  ActiveTournament wo21p() => gg21c().koWo('SF2', 'Indra');

  for (final (frame, active, now) in [
    ('21a', gg21a(), at21b),
    ('21d', gg21c(), at21b),
    ('21j', gg21i(), at21f),
    ('21r', gg21q(), at21f),
    ('21t', gg21t(), at21f),
    ('21u', gg21u(), at21v),
    ('21w', gg21w(), at21v),
    ('21x', gg21x(), at21v),
    ('21y', gg21y(), at21v),
  ]) {
    testWidgets('$frame Bagan', (tester) async {
      await expectMatchesHifi(tester, screen(active, now), frame, act: openBagan);
    });
  }

  testWidgets('21p Bagan · SF2 WO', (tester) async {
    await expectMatchesHifi(tester, screen(wo21p(), at21b), '21p', act: openBagan);
  });

  group('perilaku', () {
    /// Jadwal di atas router palsu: ketuk kartu → rute Input Skor dengan id match.
    Future<List<String>> pumpRouted(WidgetTester tester, ActiveTournament active) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      final opened = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ScheduleFixedScreen(config: active.config),
          ),
          GoRoute(
            path: '/score-input',
            builder: (_, state) {
              opened.add(state.extra! as String);
              return const SizedBox();
            },
          ),
        ],
      );
      await tester.pumpWidget(
        hifiRouterScreen(
          router,
          overrides: [
            tournamentProvider.overrideWith(() => LoadedTournament(active)),
            clockProvider.overrideWithValue(() => at21b),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await openBagan(tester);
      await tester.pumpAndSettle();
      return opened;
    }

    Finder card(String text) => find.descendant(of: find.byType(BaganView), matching: find.text(text));

    testWidgets('21a: ketuk SF1 → Input Skor; kartu Final bersisi tbd tidak bisa diketuk', (tester) async {
      final opened = await pumpRouted(tester, gg21a());
      await tester.tap(card('Pemenang SF1'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      await tester.tap(card('Maya'));
      await tester.pumpAndSettle();
      expect(opened, [gg21a().byCode('SF1').id]);
    });

    testWidgets('21f: Final di round berjalan bisa diketuk', (tester) async {
      final opened = await pumpRouted(tester, gg21f());
      await tester.tap(card('Citra').last);
      await tester.pumpAndSettle();
      expect(opened, [gg21f().byCode('F').id]);
    });

    testWidgets('21t: kartu "Tidak dimainkan" tidak bisa diketuk', (tester) async {
      final opened = await pumpRouted(tester, gg21t());
      expect(card('Tidak dimainkan'), findsNWidgets(2));
      await tester.tap(card('Tidak dimainkan').first);
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
    });
  });
}
