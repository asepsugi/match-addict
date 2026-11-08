import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/club_score.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/match_score_row.dart';
import 'package:match_addict/features/live/live_screen.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';

import '../hifi_golden.dart';
import 'live_fixture.dart';
import 'schedule_fixture.dart' show LoadedTournament;
import 'screen_harness.dart';
import 'sparing_mixed_fixture.dart';

/// Golden Jadwal Mixed sparing, frame 13m, 15a–15i, 15n, 15p (SP-18c). Satu keadaan per frame dari
/// `sparing_mixed_fixture.dart`; jam `clockProvider` ikut keadaan itu.
void main() {
  Widget screen(MixedSparingState s) => hifiScreen(
    ScheduleMixedScreen(config: s.active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(s.active)),
      clockProvider.overrideWithValue(() => s.now),
    ],
  );

  /// Dua baris papan skor: (nama, detail, skor) per klub, dan jumlah bola.
  void expectBoard((String, String, String) first, (String, String, String) second, {required int balls}) {
    final board = find.byType(ClubScore);
    for (final (name, detail, score) in [first, second]) {
      expect(find.descendant(of: board, matching: find.text(name)), findsOneWidget);
      expect(find.descendant(of: board, matching: find.text(detail)), findsWidgets);
      expect(find.descendant(of: board, matching: find.text(score)), findsWidgets);
    }
    expect(find.byKey(ClubScore.ballKey), findsNWidgets(balls));
  }

  void expectTexts(Iterable<String> texts) {
    for (final t in texts) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  }

  List<String> topNames(WidgetTester tester) => [
    for (final r in tester.widgetList<MatchScoreRow>(find.byType(MatchScoreRow))) r.top.names.join(' · '),
  ];

  final playersButton = find.byWidgetPredicate((w) => w is MabarIconButton && w.semanticLabel == 'Pemain');

  const garuda = 'PB Garuda', matcha = 'Matcha Club';

  testWidgets('13m round berjalan: 4 – 1, Prioritas R4 per klub, hitung mundur 01:20', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing13m()), '13m');
    expectBoard((garuda, '27 game · +6', '4'), (matcha, '21 game · −6', '1'), balls: 1);
    expect(find.text('Istirahat · Prioritas main di R4'), findsOneWidget);
    expect(find.text('Istirahat lagi di R4'), findsNothing);
    expectTexts(['Andi', 'Budi', 'Dewi', 'Hadi', 'Kiki', 'Nanda']);
    expect(find.text('01:20'), findsWidgets);
    // AC-S7: klub pertama di baris atas.
    expect(topNames(tester), ['Fajar · Eko', 'Citra · Gita']);
  });

  testWidgets('15a round lengkap: 4 – 2; Buat R4 = daftar Prioritas yang tampil (AC-S11)', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15a()), '15a');
    expectBoard((garuda, '32 game · +5', '4'), (matcha, '27 game · −5', '2'), balls: 1);
    expect(find.text('Istirahat lagi di R4'), findsNothing);
    expectTexts(['Andi', 'Budi', 'Dewi', 'Hadi', 'Kiki', 'Nanda']);

    await tester.tap(find.text('Buat R4'));
    await tester.pumpAndSettle();
    final next = ProviderScope.containerOf(tester.element(find.byType(ScheduleMixedScreen))).read(tournamentProvider)!;
    expect(next.roundCount, 4);
    final playing = {
      for (final m in next.matchesOfRound(4)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
    };
    List<String> inClub(List<String> club) => [
      for (final id in playing)
        if (club.contains(next.playerName(id))) next.playerName(id),
    ]..sort();
    expect(inClub(garudaNames), ['Andi', 'Budi', 'Dewi', 'Hadi']);
    expect(inClub(matchaNames), containsAll(['Kiki', 'Nanda']));
    expect(playing.length, 8);
  });

  testWidgets('15b round baru: Batalkan R4, Prioritas R5, tanpa daftar kedua', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15b()), '15b');
    expect(find.text('Batalkan R4'), findsOneWidget);
    expect(find.text('Istirahat · Prioritas main di R5'), findsOneWidget);
    expect(find.text('Istirahat lagi di R5'), findsNothing);
    expect(find.text('01:13'), findsWidgets);
    expectTexts(['Citra', 'Eko', 'Fajar', 'Gita', 'Joko', 'Maya']);
  });

  testWidgets('15c dialog batalkan round', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing15b()),
      '15c',
      act: (tester) => tester.tap(find.text('Batalkan R4')),
    );
  });

  testWidgets('15d 30 pemain: Prioritas lalu Istirahat lagi per klub', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15d()), '15d');
    expectBoard((garuda, '28 game · +8', '4'), (matcha, '20 game · −8', '1'), balls: 1);
    expect(find.text('Istirahat · Prioritas main di R4'), findsOneWidget);
    expect(find.text('Istirahat lagi di R4'), findsOneWidget);
  });

  testWidgets('15e court lebih dari yang terpakai: hanya Court 1 (AC-S10)', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15e()), '15e');
    final rows = tester.widgetList<MatchScoreRow>(find.byType(MatchScoreRow)).toList();
    expect([for (final r in rows) r.badge], ['1']);
    expect(find.text('Court 2'), findsNothing);
    expect(find.text('Istirahat · Prioritas main di R3'), findsOneWidget);
    expect(find.text('Istirahat lagi di R3'), findsOneWidget);
    expect(find.text('01:45'), findsWidgets);
    // C' = 1 sama dengan match round terakhir: Buat R3 tanpa "· n court".
    expect(find.text('· 1 court'), findsNothing);
  });

  testWidgets('15f waktu habis, banyak round: 10 – 6, Tambah jam', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15f()), '15f');
    expectBoard((garuda, '83 game · +14', '10'), (matcha, '69 game · −14', '6'), balls: 1);
    expect(find.text('Waktu habis'), findsOneWidget);
    expect(find.text('Tambah jam'), findsOneWidget);
  });

  testWidgets('15g menu ⋯', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing15b()),
      '15g',
      act: (tester) => tester.tap(find.bySemanticsLabel('Menu')),
    );
    expectTexts(['Live score', 'Kelola court', 'Cara kerja Mixed', 'Akhiri turnamen']);
  });

  testWidgets('15h dialog akhiri turnamen', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing15b()),
      '15h',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Akhiri turnamen'));
      },
    );
  });

  testWidgets('15i diakhiri: Tidak dimainkan, 4 – 2, Lanjutkan turnamen, tanpa Pemain', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15i()), '15i');
    expect(find.text('Tidak dimainkan'), findsNWidgets(2));
    expect(find.text('Lanjutkan turnamen'), findsOneWidget);
    expect(playersButton, findsNothing);
    expect(find.text('01:13'), findsNothing);
    expectBoard((garuda, '32 game · +5', '4'), (matcha, '27 game · −5', '2'), balls: 1);
  });

  testWidgets('15n pemain telat: Oki main, tombol Pemain (15) tetap membuka Kelola pemain', (tester) async {
    await expectMatchesHifi(tester, screen(mixedSparing15n()), '15n');
    expect(find.text('Oki · Nanda'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    await tester.tap(playersButton);
    await tester.pumpAndSettle();
    expect(find.text('Kelola pemain'), findsWidgets);
  });

  testWidgets('15p court baru langsung main: Court 3 Gita · Fajar vs Maya · Joko, 02:00, kolom Matcha "–"', (
    tester,
  ) async {
    await expectMatchesHifi(tester, screen(mixedSparing15p()), '15p');
    final rows = tester.widgetList<MatchScoreRow>(find.byType(MatchScoreRow)).toList();
    expect(rows.length, 3);
    expect(rows.last.top.names.join(' · '), 'Gita · Fajar');
    expect(rows.last.bottom.names.join(' · '), 'Maya · Joko');
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('Penonton Live: skor klub dan Istirahat per klub tampil, tanpa ⋯ dan Batalkan', (tester) async {
    final s = mixedSparing15b();
    await tester.pumpWidget(
      hifiScreen(
        const LiveScreen(),
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          liveViewProvider.overrideWith(() => Watching(LiveView(LiveViewStatus.live, s.active))),
          tournamentProvider.overrideWith(LiveTournamentController.new),
          clockProvider.overrideWithValue(() => s.now),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expectBoard((garuda, '32 game · +5', '4'), (matcha, '27 game · −5', '2'), balls: 1);
    expect(find.text('Istirahat · Prioritas main di R5'), findsOneWidget);
    expect(find.bySemanticsLabel('Menu'), findsNothing);
    expect(find.text('Batalkan R4'), findsNothing);
    expect(find.text('Isi skor'), findsNothing);
  });
}
