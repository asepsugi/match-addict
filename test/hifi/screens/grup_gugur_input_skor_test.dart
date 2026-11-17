import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/score_input/knockout_text.dart';
import 'package:match_addict/features/score_input/score_input_screen.dart';
import 'package:match_addict/features/score_input/widgets/score_board.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden Input Skor / WO match gugur Grup + Gugur (GG-9): 21g, 21h, 21k–21n, plus AC-G9, AC-G10, AC-G11 lewat layar.
/// Fixture bersama `grup_gugur_fixture.dart` (16E); skor diketik lewat keypad seperti host.
void main() {
  /// 21l/21m: Final 7–9 sudah disimpan, Juara 3 belum.
  ActiveTournament finalPlayed() => gg21f().ko('F', 7, 9);

  Widget screen(ActiveTournament active, String code, DateTime now) => hifiScreen(
    ScoreInputScreen(matchId: active.byCode(code).id),
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

  Future<void> select(WidgetTester tester, int side) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^Skor tim $side')));
    await tester.pump();
  }

  /// SF1 tersimpan 6–4 diubah jadi 4–6 (pemenang berganti). 21k = data 21f (SF2 sudah 4–6, R8 masih Belum).
  Future<void> flipSf1(WidgetTester tester) async {
    await select(tester, 1);
    await type(tester, [4]);
    await select(tester, 2);
    await type(tester, [6]);
  }

  group('golden', () {
    testWidgets('21g Final Race to 9', (tester) async {
      await expectMatchesHifi(tester, screen(gg21f(), 'F', at21f), '21g', act: (t) => type(t, [7, 9]));
    });

    testWidgets('21h Juara 3 Race to 4', (tester) async {
      await expectMatchesHifi(tester, screen(gg21f(), 'J3', at21f), '21h', act: (t) => type(t, [4]));
    });

    testWidgets('21k ubah SF1, pemenang berganti → dialog', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg21f(), 'SF1', at21f),
        '21k',
        act: (t) async {
          await flipSf1(t);
          await t.tap(find.text('Perbarui skor'));
        },
      );
    });

    testWidgets('21l ubah SF1 ditolak, Final sudah ada skor', (tester) async {
      await expectMatchesHifi(tester, screen(finalPlayed(), 'SF1', at21f), '21l', act: flipSf1);
    });

    testWidgets('21m ubah SF1, pemenang sama', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(finalPlayed(), 'SF1', at21f),
        '21m',
        act: (t) async {
          await select(t, 2);
          await type(t, [5]);
        },
      );
    });

    testWidgets('21n sheet WO di Semifinal', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg21c(), 'SF2', at21b),
        '21n',
        act: (t) async {
          await t.tap(find.text('WO'));
          await t.pumpAndSettle();
          await t.tap(find.text('Indra · Joko'));
          await t.pump();
          await t.tap(find.text('Cedera'));
        },
      );
    });
  });

  group('perilaku', () {
    /// Layar di atas Jadwal palsu, supaya Simpan (pop) bisa dicek.
    Future<ProviderContainer> pumpRouted(WidgetTester tester, ActiveTournament active, String code) async {
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
            clockProvider.overrideWithValue(() => at21f),
          ],
        ),
      );
      router.push('/score-input', extra: active.byCode(code).id);
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(ScoreInputScreen)));
    }

    MabarButton save(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));

    testWidgets('AC-G10: Final Race to 9 menerima 9–7; turnamen belum Final selama Juara 3 Belum', (tester) async {
      final container = await pumpRouted(tester, gg21f(), 'F');
      await type(tester, [9, 7]);
      expect(find.text('Andi & Budi menang 9–7'), findsOneWidget);
      await tester.tap(find.text('Simpan skor'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final active = container.read(tournamentProvider)!;
      expect((active.byCode('F').sets.single.side1, active.byCode('F').sets.single.side2), (9, 7));
      expect(active.isFinal(at21f), isFalse);
    });

    testWidgets('AC-G10 21h: Juara 3 Race to 4, 6–2 tidak bisa diketik', (tester) async {
      await pumpRouted(tester, gg21f(), 'J3');
      await type(tester, [6, 2]);
      final board = find.byType(ScoreBoard);
      expect(find.descendant(of: board, matching: find.text('6')), findsNothing);
      expect(find.descendant(of: board, matching: find.text('2')), findsOneWidget);
      expect(save(tester).onPressed, isNull);
    });

    testWidgets('AC-G9 21k: Ganti → slot Final dan Juara 3 berganti', (tester) async {
      final container = await pumpRouted(tester, gg21f(), 'SF1');
      await flipSf1(tester);
      await tester.tap(find.text('Perbarui skor'));
      await tester.pumpAndSettle();
      expect(find.text('Ganti pemenang SF1?'), findsOneWidget);
      expect(find.text('Final: Maya · Nanda vs Citra · Dewi\nJuara 3: Andi · Budi vs Indra · Joko'), findsOneWidget);
      await tester.tap(find.text('Ganti'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final active = container.read(tournamentProvider)!;
      expect(active.byCode('F').pair1.id, 'Maya');
      expect(active.byCode('J3').pair1.id, 'Andi');
    });

    testWidgets('AC-G9 21k: Batal → kembali ke papan dengan angka yang diketik, tidak berubah', (tester) async {
      final container = await pumpRouted(tester, gg21f(), 'SF1');
      await flipSf1(tester);
      await tester.tap(find.text('Perbarui skor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(ScoreInputScreen), findsOneWidget);
      expect(find.text('Maya & Nanda menang 6–4'), findsOneWidget);
      expect(container.read(tournamentProvider)!.byCode('SF1').winnerPairId, 'Andi');
    });

    testWidgets('AC-G9 21l/21m: ditolak saat Final ada skor; pemenang sama boleh tanpa dialog', (tester) async {
      final container = await pumpRouted(tester, finalPlayed(), 'SF1');
      await flipSf1(tester);
      expect(find.text('Final sudah ada skor · pemenang SF1 tetap Andi & Budi'), findsOneWidget);
      expect(save(tester).onPressed, isNull);
      // Kembali ke pemenang yang sama: pesan hilang, tombol aktif, simpan tanpa dialog.
      await select(tester, 1);
      await type(tester, [6]);
      await select(tester, 2);
      await type(tester, [5]);
      expect(find.text('Andi & Budi menang 6–5'), findsOneWidget);
      await tester.tap(find.text('Perbarui skor'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final active = container.read(tournamentProvider)!;
      expect((active.byCode('SF1').sets.single.side1, active.byCode('SF1').sets.single.side2), (6, 5));
      expect((active.byCode('F').sets.single.side1, active.byCode('F').sets.single.side2), (7, 9));
    });

    testWidgets('AC-G11: SF2 WO lewat sheet → Citra · Dewi ke Final, Indra · Joko ke Juara 3', (tester) async {
      final start = gg21c();
      final container = await pumpRouted(tester, start, 'SF2');
      final before = start.matches.where((m) => m.phase is GroupPhase).toList();
      await tester.tap(find.text('WO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indra · Joko'));
      await tester.pump();
      expect(find.text('Citra & Dewi menang WO dan masuk Final.'), findsOneWidget);
      await tester.tap(find.text('Simpan WO'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final active = container.read(tournamentProvider)!;
      expect(active.byCode('F').pair2.id, 'Citra');
      expect(active.byCode('J3').pair2.id, 'Indra');
      // Klasemen grup tidak berubah: match grup identik (objek yang sama).
      final after = active.matches.where((m) => m.phase is GroupPhase).toList();
      expect([for (var i = 0; i < after.length; i++) identical(after[i], before[i])], everyElement(isTrue));
    });

    testWidgets('WO yang membalik pemenang ditolak di sheet kalau Final sudah ada skor', (tester) async {
      final container = await pumpRouted(tester, finalPlayed(), 'SF1');
      await tester.tap(find.text('WO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Andi · Budi'));
      await tester.pump();
      expect(find.text('Final sudah ada skor · pemenang SF1 tetap Andi & Budi'), findsOneWidget);
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Simpan WO')).onPressed, isNull);
      expect(container.read(tournamentProvider)!.byCode('SF1').status, MatchStatus.done);
    });
  });

  group('teks (knockout_text)', () {
    test('subjudul, WO per babak, pesan tolak dua babak', () {
      final a = gg21f();
      expect(knockoutScoreSubtitle(a, a.byCode('F')), 'R8 · Final · Race to 9');
      expect(knockoutScoreSubtitle(a, a.byCode('J3')), 'R8 · Juara 3 · Race to 4');
      expect(knockoutScoreSubtitle(a, a.matches.first), isNull);
      expect(knockoutWalkoverSubtitle(a, a.byCode('SF2')), 'R7 · SF2 · Court 2');
      const f = KnockoutPhase(KnockoutRound.finalRound, 1);
      const j3 = KnockoutPhase(KnockoutRound.thirdPlace, 1);
      const pf = KnockoutPhase(KnockoutRound.quarterfinal, 2);
      expect(knockoutWalkoverNote(f, 'Andi & Budi'), 'Andi & Budi menang WO dan juara.');
      expect(knockoutWalkoverNote(j3, 'Andi & Budi'), 'Andi & Budi menang WO dan juara 3.');
      expect(knockoutWalkoverNote(pf, 'Andi & Budi'), 'Andi & Budi menang WO dan masuk Semifinal.');
      final both = finalPlayed().ko('J3', 4, 2);
      final check = KnockoutBracket.flipCheck(both, both.byCode('SF1').id, 'Maya') as FlipBlocked;
      expect(
        knockoutBlockedMessage(check, const KnockoutPhase(KnockoutRound.semifinal, 1), 'Andi & Budi'),
        'Final dan Juara 3 sudah ada skor · pemenang SF1 tetap Andi & Budi',
      );
    });
  });
}
