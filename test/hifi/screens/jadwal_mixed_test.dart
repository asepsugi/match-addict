import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden layar penuh Jadwal Mixed, frame 06f–06o dan 06u. Padel Americano 21, 2 court, durasi 15 menit; 10 pemain
/// (06o: 30). Fixture bersama di `schedule_fixture.dart`.
void main() {
  final start = fixtureStart;
  const tournament = mixedTournament;
  const r1 = mixedR1, r2 = mixedR2, r3Running = mixedR3Running;
  const r3Done = mixedR3Done, r4 = mixedR4;
  const wo = mixedWo;

  final f = tournament([r1, r2, r3Running]);
  final g = tournament([r1, r2, r3Done], adjust: wo);
  final h = tournament([r1, r2, r3Done, r4], adjust: wo);

  Widget screen(ActiveTournament active, Duration elapsed) => hifiScreen(
    ScheduleMixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => start.add(elapsed)),
    ],
  );

  testWidgets('06u nama lengkap panjang, nama depan sama', (tester) async {
    const roster = [
      'Muhammad Rizky Pratama', 'Lia Ibun', 'Muhammad Fajar Nugraha', 'Lia Ncii', 'Putri Ayu', 'Andi P', //
      'Putri Anggraini Kusuma', 'Muhammad Iqbal Ramadhan', 'Citra L', 'Dewant R',
    ];
    final u = tournament([
      [
        ('Muhammad Rizky Pratama', 'Lia Ibun', 'Muhammad Fajar Nugraha', 'Lia Ncii', null, null),
        ('Putri Ayu', 'Andi P', 'Putri Anggraini Kusuma', 'Muhammad Iqbal Ramadhan', 13, 8),
      ],
    ], roster: roster);
    await expectMatchesHifi(tester, screen(u, const Duration(minutes: 15)), '06u');
    // Nama pendek tetap utuh di samping partner bernama panjang; yang panjang dipotong sendiri.
    expect(find.text('Lia Ibun'), findsOneWidget);
    expect(find.text('Lia Ncii'), findsOneWidget);
    expect(find.text('Putri Ayu · Andi P'), findsOneWidget);
  });

  testWidgets('06f round berjalan', (tester) async {
    await expectMatchesHifi(tester, screen(f, const Duration(minutes: 40)), '06f');
  });

  testWidgets('06g round lengkap, WO beralasan', (tester) async {
    await expectMatchesHifi(tester, screen(g, const Duration(minutes: 52)), '06g');
  });

  testWidgets('06h round baru, masih bisa dibatalkan', (tester) async {
    await expectMatchesHifi(tester, screen(h, const Duration(minutes: 53)), '06h');
  });

  testWidgets('06i menu ⋯', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(h, const Duration(minutes: 53)),
      '06i',
      act: (tester) => tester.tap(find.bySemanticsLabel('Menu')),
    );
  });

  testWidgets('06j dialog batalkan round', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(h, const Duration(minutes: 53)),
      '06j',
      act: (tester) => tester.tap(find.text('Batalkan R4')),
    );
  });

  testWidgets('06k sheet cara kerja Mixed', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(tournament([r1.map((m) => (m.$1, m.$2, m.$3, m.$4, null, null)).toList()]), Duration.zero),
      '06k',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cara kerja Mixed'));
      },
    );
  });

  testWidgets('06l waktu booking habis', (tester) async {
    await expectMatchesHifi(tester, screen(tournament(mixedTimeUpRounds), const Duration(hours: 2, minutes: 4)), '06l');
  });

  testWidgets('06m diakhiri, bisa dilanjutkan', (tester) async {
    final rounds = [
      r1, r2, r3Running.map((m) => (m.$1, m.$2, m.$3, m.$4, 11, 10)).toList(), r1, //
      const <MatchSpec>[('Andi', 'Gina', 'Budi', 'Indra', 11, 10), ('Citra', 'Eko', 'Hana', 'Joko', null, null)],
    ];
    await expectMatchesHifi(tester, screen(tournament(rounds, finished: true), Duration.zero), '06m');
  });

  testWidgets('06n banyak round, melihat round awal', (tester) async {
    final rounds = [
      r1,
      const <MatchSpec>[('Andi', 'Citra', 'Budi', 'Dewant', 12, 9), ('Eko', 'Gina', 'Fajar', 'Hana', 10, 11)],
      for (var r = 2; r < 11; r++) r.isEven ? r1 : r2,
      const <MatchSpec>[('Andi', 'Budi', 'Citra', 'Dewant', 12, 9), ('Eko', 'Fajar', 'Indra', 'Joko', null, null)],
    ];
    await expectMatchesHifi(
      tester,
      screen(tournament(rounds, bookingHours: 4), const Duration(hours: 3, minutes: 10)),
      '06n',
      act: (tester) async {
        // Host menggeser baris tab ke awal, lalu mengetuk R2.
        await tester.drag(find.text('R10'), const Offset(800, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('R2'));
      },
    );
  });

  testWidgets('06o banyak yang istirahat, 30 pemain', (tester) async {
    // R1–R3 = hasil generator (8 pemain per round, urut prioritas undian id turnamen). Untuk R4: 6 yang belum
    // pernah main + 2 dari 8 pemain R1 (paling lama istirahat) yang menang undian round 4.
    const rounds = [
      <MatchSpec>[('Putri', 'Oki', 'Tari', 'Gina', 11, 10), ('Lina', 'Wulan', 'Kiki', 'Tono', 12, 9)],
      <MatchSpec>[('Fajar', 'Galih', 'Rizky', 'Joko', 11, 10), ('Nanda', 'Eko', 'Hendra', 'Bayu', 12, 9)],
      <MatchSpec>[('Citra', 'Vina', 'Maya', 'Dimas', 13, 8), ('Sari', 'Dewant', 'Umar', 'Andi', null, null)],
    ];
    await expectMatchesHifi(
      tester,
      screen(tournament(rounds, players: 30, id: 't-06o-30'), const Duration(minutes: 40)),
      '06o',
    );
  });

  Future<void> pumpRouted(
    WidgetTester tester,
    ActiveTournament active,
    List<String> visited, {
    Duration elapsed = Duration.zero,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/schedule',
      routes: [
        GoRoute(path: '/schedule', builder: (_, _) => ScheduleMixedScreen(config: active.config)),
        GoRoute(
          path: '/score-input',
          builder: (_, state) {
            visited.add('score:${state.extra}');
            return const Text('Input skor');
          },
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) {
            visited.add('leaderboard');
            return const Text('Klasemen');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(
        router,
        overrides: [
          tournamentProvider.overrideWith(() => LoadedTournament(active)),
          clockProvider.overrideWithValue(() => start.add(elapsed)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  MabarButton primary(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton).last);

  testWidgets('Buat R4 pindah ke round baru; Batalkan kembali ke R3', (tester) async {
    await pumpRouted(tester, g, []);
    await tester.tap(find.text('R1'));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan R3'), findsNothing);
    await tester.tap(find.text('Buat R4'));
    await tester.pumpAndSettle();
    expect(find.text('Round 4'), findsOneWidget);
    expect(find.text('Batalkan R4'), findsOneWidget);
    expect(primary(tester).meta, '· tunggu 2 match');

    await tester.tap(find.text('R2'));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan R4'), findsNothing, reason: 'hanya di tab round terakhir');
    await tester.tap(find.text('R4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan R4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan R4').last);
    await tester.pumpAndSettle();
    expect(find.text('Round 3'), findsOneWidget);
    expect(primary(tester).label, 'Buat R4');
  });

  testWidgets('Round lewat: Istirahat tanpa prioritas; Akhiri → menu hanya Cara kerja, Pemain hilang', (tester) async {
    final visited = <String>[];
    await pumpRouted(tester, g, visited);
    await tester.tap(find.text('R2'));
    await tester.pumpAndSettle();
    expect(find.text('Istirahat'), findsOneWidget);
    expect(find.textContaining('Prioritas'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri turnamen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri'));
    await tester.pumpAndSettle();
    expect(visited, ['leaderboard']);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pemain'), findsNothing);
    expect(primary(tester).label, 'Lanjutkan turnamen');
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Cara kerja Mixed'), findsOneWidget);
    expect(find.text('Akhiri turnamen'), findsNothing);
  });

  testWidgets('Court berkurang di round berikutnya: "Buat R… · 1 court"', (tester) async {
    final shortCourt = tournament([r1, r2, r3Done], adjust: wo);
    final config = shortCourt.config;
    final active = shortCourt.copyWith(
      tournament: shortCourt.tournament.copyWith(
        config: config.copyWith(courts: [config.courts[0], config.courts[1].copyWith(bookingDurationMinutes: 45)]),
      ),
    );
    // Menit ke-52 (06g): Court 2 (45 menit) tidak muat match 15 menit lagi.
    await pumpRouted(tester, active, [], elapsed: const Duration(minutes: 52));
    expect((primary(tester).label, primary(tester).meta), ('Buat R4', '· 1 court'));
  });

  testWidgets('Cara kerja Mixed muncul sendiri saat R1 dibuat', (tester) async {
    final config = f.config;
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(hifiScreen(ScheduleMixedScreen(config: config)));
    await tester.pumpAndSettle();
    expect(find.text('Cara kerja Mixed'), findsOneWidget);
    expect(find.text('Round 1'), findsOneWidget);
  });
}
