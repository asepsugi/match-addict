import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';
import 'package:match_addict/features/schedule/group_knockout/create_bracket_flow.dart';
import 'package:match_addict/features/schedule/group_knockout/gk_labels.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/schedule/widgets/round_tabs.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden Jadwal Grup + Gugur (GG-7): fase grup 20a–20q, round gugur 21b–21v. Tab Bagan 21a/21d/… = GG-9. Fixture
/// bersama `grup_gugur_fixture.dart`; jam frame lewat konstanta `at…` di sana.
void main() {
  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  ActiveTournament stateOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ScheduleFixedScreen))).read(tournamentProvider)!;

  Finder tab(String label) => find.descendant(of: find.byType(RoundTabs), matching: find.text(label));
  Finder option(String name) => find.descendant(of: find.byType(MabarOption), matching: find.text(name));

  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(BuildBracketDialog), matching: find.text('Buat bagan')));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('fase grup', () {
    testWidgets('20a awal', (tester) async {
      await expectMatchesHifi(tester, screen(gg20a(), at20a), '20a');
    });

    testWidgets('20b sebagian terisi', (tester) async {
      await expectMatchesHifi(tester, screen(gg20b(), at20b), '20b');
    });

    testWidgets('20c round terkunci dibuka', (tester) async {
      await expectMatchesHifi(tester, screen(gg20b(), at20b), '20c', act: (t) => t.tap(tab('R4')));
    });

    testWidgets('20e semua terisi · Buat bagan', (tester) async {
      await expectMatchesHifi(tester, screen(gg20e(), at20e), '20e');
    });

    testWidgets('20g dialog tanpa pilihan', (tester) async {
      await expectMatchesHifi(tester, screen(gg20e(), at20e), '20g', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('20i sheet pilih A2', (tester) async {
      await expectMatchesHifi(tester, screen(gg20h(), at20e), '20i', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('20j sudah dipilih', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg20h(), at20e),
        '20j',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(option('Eko · Fajar'));
        },
      );
    });

    testWidgets('20k dialog setelah memilih', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg20h(), at20e),
        '20k',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(option('Eko · Fajar'));
          await t.pumpAndSettle();
          await t.tap(find.descendant(of: find.byType(MabarSheet), matching: find.text('Buat bagan')));
        },
      );
    });

    testWidgets('20l dua slot dari satu daftar', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg20l(), at20e),
        '20l',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(option('Andi · Budi'));
        },
      );
    });

    testWidgets('20m 4 grup, 2 court', (tester) async {
      await expectMatchesHifi(tester, screen(gg20m(), at20m), '20m');
    });

    testWidgets('20o dialog 4 grup', (tester) async {
      await expectMatchesHifi(tester, screen(gg20o(), at20o), '20o', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('20p court lebih banyak dari grup', (tester) async {
      // Frame = R2 setelah R1 terisi dan Eko · Fajar 6–4 Kiki · Lina (1/3 match), 15 menit sejak mulai.
      final start = gg20p();
      final played = start.withMatches([
        for (final m in start.matches)
          if (m.roundNumber == 1 || (m.roundNumber == 2 && m.courtId == start.config.courts.first.id))
            m.withScore([const SetScore(side1: 6, side2: 4)])
          else
            m,
      ]);
      await expectMatchesHifi(tester, screen(played, ggAt(15)), '20p');
    });

    testWidgets('20q turnamen diakhiri', (tester) async {
      await expectMatchesHifi(tester, screen(gg20q(), at20b), '20q');
    });
  });

  group('fase gugur', () {
    testWidgets('21b Semifinal belum ada skor', (tester) async {
      await expectMatchesHifi(tester, screen(gg21a(), at21b), '21b');
    });

    testWidgets('21c SF1 terisi', (tester) async {
      await expectMatchesHifi(tester, screen(gg21c(), at21b), '21c');
    });

    testWidgets('21e Final terkunci', (tester) async {
      await expectMatchesHifi(tester, screen(gg21c(), at21b), '21e', act: (t) => t.tap(tab('Final')));
    });

    testWidgets('21f Final berjalan', (tester) async {
      await expectMatchesHifi(tester, screen(gg21f(), at21f), '21f');
    });

    testWidgets('21i Final selesai', (tester) async {
      await expectMatchesHifi(tester, screen(gg21i(), at21f), '21i', act: (t) => t.tap(tab('Final')));
    });

    testWidgets('21o SF2 WO', (tester) async {
      final wo = gg21c().withMatches([
        for (final m in gg21c().matches)
          if (m.phase?.code == 'SF2') m.asWalkover(loserPairId: 'Indra', reason: WoReason.injury) else m,
      ]);
      await expectMatchesHifi(tester, screen(wo, at21b), '21o');
    });

    testWidgets('21q tanpa Perebutan juara 3', (tester) async {
      final a = gg21a(thirdPlace: false).ko('SF1', 6, 4).ko('SF2', 4, 6);
      await expectMatchesHifi(tester, screen(a, at21f), '21q', act: (t) => t.tap(tab('Final')));
    });

    testWidgets('21s 1 court, Perebutan juara 3 sebelum Final', (tester) async {
      await expectMatchesHifi(tester, screen(gg21s(), at21s), '21s');
    });

    testWidgets('21v PF1–2, strip digeser', (tester) async {
      await expectMatchesHifi(tester, screen(gg21u(), at21v), '21v');
    });
  });

  group('perilaku', () {
    testWidgets('AC-G6: satu match grup Belum = tanpa Buat bagan', (tester) async {
      await tester.pumpWidget(screen(gg20b(), at20b));
      await tester.pumpAndSettle();
      expect(find.text('Buat bagan'), findsNothing);
      expect(find.text('Klasemen'), findsOneWidget);
    });

    testWidgets('AC-G7: Batal di dialog tidak mengubah turnamen', (tester) async {
      await tester.pumpWidget((screen(gg20e(), at20e)));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      await tapText(tester, 'Batal');
      expect(stateOf(tester).hasBracket, isFalse);
      expect(find.text('Buat bagan'), findsOneWidget);
    });

    testWidgets('Buat bagan: bagan dibuat, Jadwal pindah ke tab Bagan', (tester) async {
      await tester.pumpWidget((screen(gg20e(), at20e)));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      await confirmDialog(tester);
      final active = stateOf(tester);
      expect(active.hasBracket, isTrue);
      expect(find.text('Padel · 4 pasangan lolos'), findsOneWidget);
      expect(find.text('0/4 match'), findsOneWidget);
    });

    testWidgets('Pilihan host sampai dialog dikonfirmasi: A2 = Eko · Fajar', (tester) async {
      await tester.pumpWidget((screen(gg20h(), at20e)));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      expect(find.text('Pilih A2'), findsOneWidget);
      await tester.tap(option('Eko · Fajar'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(MabarSheet), matching: find.text('Buat bagan')));
      await tester.pumpAndSettle();
      await confirmDialog(tester);
      final sf2 = stateOf(tester).byCode('SF2');
      expect(sf2.pair2.id, 'Eko');
      expect(GroupKnockoutRanking.qualifierPlan(gg20h()).picks.single.candidates, ['Citra', 'Eko', 'Gita']);
    });

    testWidgets('sisi tbd tidak bisa diketuk dan tanpa Isi skor', (tester) async {
      await tester.pumpWidget(screen(gg21c(), at21b));
      await tester.pumpAndSettle();
      await tester.tap(tab('Final'));
      await tester.pumpAndSettle();
      expect(find.text('Isi skor'), findsNothing);
      expect(find.text('Pemenang SF2'), findsOneWidget);
      expect(find.text('Kalah SF2'), findsOneWidget);
    });
  });

  group('teks (gk_labels)', () {
    final h = GroupKnockoutRanking.qualifierPlan(gg20h()).picks;
    final l = GroupKnockoutRanking.qualifierPlan(gg20l()).picks;

    test('judul, subjudul, dan sisa slot (20i, 20l)', () {
      expect(gkPickTitle(h), 'Pilih A2');
      expect(gkPickTitle(l), 'Pilih A1 dan A2');
      expect(gkPickSubtitle(h.single, gg20h().matches), 'Grup A · #2 seri · head-to-head 1–1');
      expect(gkPickSubtitle(l.single, gg20l().matches), 'Grup A · #1 seri · head-to-head 1–1');
      expect(gkMissingSlots(l, {}), 'pilih A1 dan A2');
      expect(
        gkMissingSlots(l, {
          0: ['Andi'],
        }),
        'pilih A2',
      );
      expect(
        gkMissingSlots(l, {
          0: ['Andi', 'Citra'],
        }),
        isNull,
      );
    });

    test('ketukan: lepas melepas yang sesudahnya, penuh memindahkan yang terakhir (20j, 20l)', () {
      expect(gkTap(h.single, [], 'Eko'), ['Eko']);
      expect(gkTap(h.single, ['Eko'], 'Gita'), ['Gita']);
      expect(gkTap(h.single, ['Eko'], 'Eko'), isEmpty);
      expect(gkTap(l.single, ['Andi'], 'Citra'), ['Andi', 'Citra']);
      expect(gkTap(l.single, ['Andi', 'Citra'], 'Andi'), isEmpty);
      expect(gkTap(l.single, ['Andi', 'Citra'], 'Eko'), ['Andi', 'Eko']);
    });

    test('subjudul dan meta Bagan (21a, 21t), subjudul round (20a, 21b, 20q)', () {
      expect(gkRoundSubtitle(gg21a(), 1), 'Padel · Fase grup · Race to 6');
      expect(gkRoundSubtitle(gg21a(), 7), 'R7 · Padel');
      expect(gkRoundSubtitle(gg20q(), 4), 'Padel · Fase grup · Race to 6 · diakhiri');
      expect(gkBaganSubtitle(gg21t()), 'Padel · 4 pasangan lolos · diakhiri');
      expect(gkBaganMeta(gg21a()), '0/4 match');
      expect(gkBaganMeta(gg21t()), '2/4 match');
      expect(gkBaganMeta(gg21u()), '0/8 match');
    });
  });
}
