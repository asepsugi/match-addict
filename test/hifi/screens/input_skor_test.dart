import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/score_input/score_input_screen.dart';
import 'package:match_addict/features/score_input/widgets/score_board.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden layar penuh Input Skor, frame 07a–07o. Match sama dengan Jadwal: Round 2 Tennis (06a: court 1
/// Andi·Budi 6–4 Citra·Dewant, court 2 Eko·Fajar vs Gina·Hana) dan Round 3 Mixed (06f: court 1
/// Andi·Dewant vs Citra·Fajar, court 2 Eko·Budi vs Hana·Gina). Skor diketik lewat keypad seperti host.
void main() {
  const race6 = ScoreFormat.standard;
  const r2 = <MatchSpec>[('Andi', 'Budi', 'Citra', 'Dewant', 6, 4), ('Eko', 'Fajar', 'Gina', 'Hana', null, null)];
  const r3 = <MatchSpec>[('Andi', 'Dewant', 'Citra', 'Fajar', null, null), ('Eko', 'Budi', 'Hana', 'Gina', null, null)];

  ActiveTournament round2() => mixedTournament([mixedR1, r2], sport: SportType.tennis, format: race6);
  ActiveTournament round3(ScoreFormat format) => mixedTournament([mixedR1, mixedR2, r3], format: format);

  // Jam frame: Round 2 = 06a (45 menit berjalan, sisa 01:15), Round 3 = 06f (40 menit, sisa 01:20).
  Override clock(ActiveTournament active) =>
      clockProvider.overrideWithValue(() => fixtureStart.add(Duration(minutes: active.roundCount == 2 ? 45 : 40)));

  Widget screen(ActiveTournament active, String matchId) => hifiScreen(
    ScoreInputScreen(matchId: matchId),
    overrides: [tournamentProvider.overrideWith(() => LoadedTournament(active)), clock(active)],
  );

  Future<void> type(WidgetTester tester, List<int> digits) async {
    for (final d in digits) {
      await tester.tap(find.descendant(of: find.byType(ScoreKeypad), matching: find.text('$d')));
      await tester.pump();
    }
  }

  for (final (frame, digits) in [
    ('07a', <int>[]),
    ('07b', [6, 4]),
    ('07c', [6, 5]),
    ('07d', [6, 6]),
    // "4" sudah penuh (8 dan 9 mati), kursor pindah sendiri ke kotak Gina·Hana.
    ('07k', [4]),
  ]) {
    testWidgets('$frame Race to 6', (tester) async {
      await expectMatchesHifi(tester, screen(round2(), 'r2c2'), frame, act: (tester) => type(tester, digits));
    });
  }

  for (final (frame, format, digits) in [
    ('07e', const ScoreFormat(ScoringMethod.bestOf, 5), [3]),
    ('07f', const ScoreFormat(ScoringMethod.bestOf, 6), [3]),
    ('07g', const ScoreFormat(ScoringMethod.americano, 21), [1, 3]),
    ('07h', const ScoreFormat(ScoringMethod.americano, 21), [2]),
  ]) {
    testWidgets('$frame ${format.label}', (tester) async {
      await expectMatchesHifi(tester, screen(round3(format), 'r3c1'), frame, act: (tester) => type(tester, digits));
    });
  }

  // Sisi kedua diketik sendiri: nilai otomatis ditimpa, sisi pertama tidak dihitung ulang.
  for (final (frame, format, first, second) in [
    ('07m', const ScoreFormat(ScoringMethod.americano, 21), [1, 1], [5]),
    ('07n', const ScoreFormat(ScoringMethod.americano, 21), [1, 3], [9]),
    ('07o', const ScoreFormat(ScoringMethod.bestOf, 5), [2], [1]),
  ]) {
    testWidgets('$frame ${format.label} dua sisi diketik', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(round3(format), 'r3c1'),
        frame,
        act: (tester) async {
          await type(tester, first);
          await tester.tap(find.bySemanticsLabel('Tim berikutnya'));
          await tester.pump();
          await type(tester, second);
        },
      );
    });
  }

  testWidgets('07i mengubah skor tersimpan', (tester) async {
    await expectMatchesHifi(tester, screen(round2(), 'r2c1'), '07i');
  });

  testWidgets('07j sheet walkover', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(round3(const ScoreFormat(ScoringMethod.americano, 21)), 'r3c2'),
      '07j',
      act: (tester) async {
        await tester.tap(find.text('WO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eko M · Budi S'));
        await tester.pump();
        await tester.tap(find.text('Absen'));
      },
    );
  });

  /// Layar di atas Jadwal palsu, supaya Simpan (pop) bisa dicek.
  Future<ProviderContainer> pumpRouted(WidgetTester tester, ActiveTournament active, String matchId) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/schedule',
      routes: [
        GoRoute(path: '/schedule', builder: (_, _) => const Text('Jadwal')),
        GoRoute(path: '/score-input', builder: (_, state) => ScoreInputScreen(matchId: state.extra! as String)),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(router, overrides: [tournamentProvider.overrideWith(() => LoadedTournament(active)), clock(active)]),
    );
    router.push('/score-input', extra: matchId);
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ScoreInputScreen)));
  }

  MabarButton save(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));

  testWidgets('Simpan → kembali ke Jadwal; satu sisi kosong = Simpan mati tanpa pesan', (tester) async {
    final container = await pumpRouted(tester, round2(), 'r2c2');
    await type(tester, [6]);
    expect(save(tester).onPressed, isNull);
    expect(find.textContaining('menang'), findsNothing);
    await type(tester, [3]);
    await tester.tap(find.text('Simpan skor'));
    await tester.pumpAndSettle();
    expect(find.text('Jadwal'), findsOneWidget);
    final match = container.read(tournamentProvider)!.matchById('r2c2')!;
    expect((match.status, match.sets.single.side1, match.sets.single.side2), (MatchStatus.done, 6, 3));
  });

  testWidgets('Ubah skor: angka mati sampai kotak diketuk; ketikan pertama mengganti isi', (tester) async {
    await pumpRouted(tester, round2(), 'r2c1');
    expect(find.text('Perbarui skor'), findsOneWidget);
    await type(tester, [5]);
    expect(find.text('Andi P & Budi S menang 6–4'), findsOneWidget, reason: 'belum ada kotak aktif');
    await tester.tap(find.descendant(of: find.byType(ScoreBoard), matching: find.text('4')));
    await tester.pump();
    await type(tester, [6]);
    expect(find.text('Hanya satu tim yang bisa mencapai 6'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(ScoreBoard), matching: find.text('6')).first);
    await tester.pump();
    await type(tester, [3]);
    expect(find.text('Citra L & Dewant R menang 6–3'), findsOneWidget);
  });

  testWidgets('Americano berhenti lebih awal: 11–5 tersimpan apa adanya', (tester) async {
    final container = await pumpRouted(tester, round3(const ScoreFormat(ScoringMethod.americano, 21)), 'r3c1');
    await type(tester, [1, 1]);
    await tester.tap(find.bySemanticsLabel('Tim berikutnya'));
    await tester.pump();
    await type(tester, [5]);
    await tester.tap(find.text('Simpan skor'));
    await tester.pumpAndSettle();
    expect(find.text('Jadwal'), findsOneWidget);
    final match = container.read(tournamentProvider)!.matchById('r3c1')!;
    expect((match.status, match.sets.single.side1, match.sets.single.side2), (MatchStatus.done, 11, 5));
  });

  testWidgets('WO: Simpan WO mati sampai dipilih; menyimpan → Jadwal; membuka lagi terisi', (tester) async {
    final container = await pumpRouted(tester, round3(const ScoreFormat(ScoringMethod.americano, 21)), 'r3c2');
    await tester.tap(find.text('WO'));
    await tester.pumpAndSettle();
    MabarButton woButton() => tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Simpan WO'));
    expect(woButton().onPressed, isNull);
    await tester.tap(find.text('Hana T · Gina R'));
    await tester.pump();
    expect(find.text('Eko M & Budi S menang WO dan dapat poin rata-rata mereka, minimal 11.'), findsOneWidget);
    await tester.tap(find.text('Cedera'));
    await tester.pump();
    await tester.tap(find.text('Cedera'));
    await tester.pump();
    await tester.tap(find.text('Simpan WO'));
    await tester.pumpAndSettle();
    expect(find.text('Jadwal'), findsOneWidget);
    final match = container.read(tournamentProvider)!.matchById('r3c2')!;
    expect((match.status, match.woLoserPairId, match.woReason), (MatchStatus.wo, match.pair2.id, null));
  });
}
