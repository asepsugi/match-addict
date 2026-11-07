import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/club_score.dart';
import 'package:match_addict/core/widgets/match_score_row.dart';
import 'package:match_addict/features/live/live_screen.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'live_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// Golden Jadwal Fixed sparing, frame 13k, 13l, 14h–14m. Fixture bersama `sparing_fixture.dart`.
void main() {
  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  /// Dua baris papan skor: (nama, detail, skor) per klub, dan jumlah bola.
  void expectBoard((String, String, String) first, (String, String, String) second, {required int balls}) {
    final board = find.byType(ClubScore);
    for (final (name, detail, score) in [first, second]) {
      expect(find.descendant(of: board, matching: find.text(name)), findsOneWidget);
      // 0 – 0 (14m): kedua baris memuat teks yang sama.
      expect(find.descendant(of: board, matching: find.text(detail)), findsWidgets);
      expect(find.descendant(of: board, matching: find.text(score)), findsWidgets);
    }
    expect(find.byKey(ClubScore.ballKey), findsNWidgets(balls));
  }

  const garudaR6 = ('PB Garuda', '45 game · +8', '6');
  const matchaR6 = ('Matcha Club', '43 game · −8', '4');

  testWidgets('13k round berjalan: 6 – 4, istirahat dua kolom, hitung mundur 00:45', (tester) async {
    await expectMatchesHifi(tester, screen(sparingAfterR5(), sparingAt(5)), '13k');
    expectBoard(garudaR6, matchaR6, balls: 1);
    expect(find.text('00:45'), findsNWidgets(2));
    expect(find.text('Istirahat'), findsOneWidget);
    for (final n in ['Andi · Budi', 'Citra · Dewi', 'Indra · Joko']) {
      expect(find.text(n), findsOneWidget);
    }
    // AC-S7: baris atas match R6 = klub pertama (Eko · Fajar, Gita · Hadi).
    final rows = tester.widgetList<MatchScoreRow>(find.byType(MatchScoreRow)).toList();
    expect([for (final r in rows) r.top.names.join(' · ')], ['Eko · Fajar', 'Gita · Hadi']);
  });

  testWidgets('13l semua terisi: 7 – 5, 56 game · +13 / 49 game · −13 (AC-S14)', (tester) async {
    await expectMatchesHifi(tester, screen(sparingFull(), sparingAt(6)), '13l');
    expectBoard(('PB Garuda', '56 game · +13', '7'), ('Matcha Club', '49 game · −13', '5'), balls: 1);
    expect(find.text('Tambah round'), findsOneWidget);
  });

  testWidgets('14h membuka R4: skor klub 4 – 1 tetap, round terkunci', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(sparingR3(), sparingAt(2)),
      '14h',
      act: (tester) => tester.tap(find.text('R4')),
    );
    expectBoard(('PB Garuda', '28 game · +6', '4'), ('Matcha Club', '22 game · −6', '1'), balls: 1);
    expect(find.text('Terbuka setelah semua skor R3 terisi'), findsOneWidget);
    expect(find.text('Isi skor'), findsNothing);
  });

  testWidgets('14i round lewat dengan WO: Citra · Dewi di atas, tag WO', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(sparingAfterR5(), sparingAt(5)),
      '14i',
      act: (tester) => tester.tap(find.text('R3')),
    );
    expect(find.text('WO · Absen'), findsOneWidget);
    final woRow = tester.widgetList<MatchScoreRow>(find.byType(MatchScoreRow)).firstWhere((r) => r.top.tag != null);
    expect(woRow.top.names, ['Citra', 'Dewi']);
    expect(woRow.countdown, isNull);
    expectBoard(garudaR6, matchaR6, balls: 1);
  });

  testWidgets('14j menu ⋯', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(sparingAfterR5(), sparingAt(5)),
      '14j',
      act: (tester) => tester.tap(find.bySemanticsLabel('Menu')),
    );
    expect(find.text('Live score'), findsOneWidget);
    expect(find.text('Akhiri turnamen'), findsOneWidget);
  });

  testWidgets('14k dialog akhiri', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(sparingAfterR5(), sparingAt(5)),
      '14k',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Akhiri turnamen'));
      },
    );
  });

  testWidgets('14l diakhiri: Tidak dimainkan, skor 6 – 4 tetap, Lihat klasemen', (tester) async {
    await expectMatchesHifi(tester, screen(sparingEnded(), sparingAt(5)), '14l');
    expect(find.text('Tidak dimainkan'), findsNWidgets(2));
    expect(find.text('Lihat klasemen'), findsOneWidget);
    expect(find.text('00:45'), findsNothing);
    expectBoard(garudaR6, matchaR6, balls: 1);
  });

  testWidgets('14m / AC-S6 Court 3 tanpa match: tidak tampil, 0 – 0 tanpa bola, Matcha "–"', (tester) async {
    await expectMatchesHifi(tester, screen(sparingSmall(), sparingAt(0)), '14m');
    expectBoard(('PB Garuda', '0 game · 0', '0'), ('Matcha Club', '0 game · 0', '0'), balls: 0);
    final rows = tester.widgetList<MatchScoreRow>(find.byType(MatchScoreRow)).toList();
    expect([for (final r in rows) r.badge], ['1', '2']);
    expect(find.text('02:00'), findsNWidgets(2));
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('Seri 6 – 6: bola di kedua baris', (tester) async {
    await tester.pumpWidget(screen(sparing14t(), sparingAt(6)));
    await tester.pumpAndSettle();
    expect(find.byKey(ClubScore.ballKey), findsNWidgets(2));
  });

  testWidgets('Penonton Live: skor klub tampil, tanpa ⋯ dan tanpa Isi skor', (tester) async {
    await tester.pumpWidget(
      hifiScreen(
        const LiveScreen(),
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          liveViewProvider.overrideWith(() => Watching(LiveView(LiveViewStatus.live, sparingAfterR5()))),
          tournamentProvider.overrideWith(LiveTournamentController.new),
          clockProvider.overrideWithValue(() => sparingAt(5)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expectBoard(garudaR6, matchaR6, balls: 1);
    expect(find.bySemanticsLabel('Menu'), findsNothing);
    expect(find.text('Isi skor'), findsNothing);
    expect(find.text('Matcha Club'), findsWidgets);
  });
}
