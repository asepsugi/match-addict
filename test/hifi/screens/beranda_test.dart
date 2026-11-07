import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/app_version.dart';
import 'package:match_addict/features/home/app_install.dart';
import 'package:match_addict/features/home/home_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// Golden layar penuh Beranda, frame 01a–01f, 01h, 01i. Data sama dengan frame: turnamen terakhir Padel
/// Mixed 8 pemain selesai di R6 (01a bernama "PB Garuda x Matcha Club", 01c tanpa nama); turnamen berjalan
/// Padel Mixed 8 pemain R4 (6 dari 8 match, bernama) dan Tennis Fixed 10 pemain R2 (3 dari 10 match).
void main() {
  Court court(int i) => Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: 120);

  MatchGame match(int round, int no, Pair a, Pair b, {bool done = true}) => MatchGame(
    id: 'r$round-$no',
    roundNumber: round,
    matchNumberInRound: no,
    courtId: 'c$no',
    pair1: a,
    pair2: b,
    sets: done ? const [SetScore(side1: 6, side2: 4)] : const [],
    status: done ? MatchStatus.done : MatchStatus.pending,
  );

  /// Mixed 8 pemain, 2 court; [played] match pertama sudah selesai.
  ActiveTournament mixed(
    SportType sport, {
    required int rounds,
    required int played,
    bool finished = false,
    String? name,
  }) {
    final players = [for (var i = 1; i <= 8; i++) Player(id: 'p$i', name: 'Pemain $i')];
    Pair pair(int a, int b) => Pair(id: 'p$a+p$b', player1Id: 'p$a', player2Id: 'p$b');
    var n = 0;
    final matches = [
      for (var r = 1; r <= rounds; r++) ...[
        match(r, 1, pair(1, 2), pair(3, 4), done: n++ < played),
        match(r, 2, pair(5, 6), pair(7, 8), done: n++ < played),
      ],
    ];
    return ActiveTournament(
      tournament: Tournament(
        id: 't-mixed',
        createdAt: DateTime(2026, 10, 21, 19),
        isFinished: finished,
        config: TournamentConfig(
          sport: sport,
          mode: PartnerMode.mixed,
          matchDurationMinutes: 15,
          courts: [court(1), court(2)],
          players: players,
          format: const ScoreFormat(ScoringMethod.americano, 21),
          name: name,
        ),
        matches: matches,
      ),
    );
  }

  /// Fixed 10 pemain (5 pasangan), round-robin 10 match dalam 5 round; R1 lengkap, R2 satu match.
  ActiveTournament fixedTennis() {
    final players = [for (var i = 1; i <= 10; i++) Player(id: 'p$i', name: 'Pemain $i')];
    final pairs = [for (var i = 0; i < 5; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i + 1}', player2Id: 'p${2 * i + 2}')];
    var n = 0;
    final matches = [
      for (var r = 1; r <= 5; r++) ...[
        match(r, 1, pairs[(r) % 5], pairs[(r + 1) % 5], done: n++ < 3),
        match(r, 2, pairs[(r + 2) % 5], pairs[(r + 3) % 5], done: n++ < 3),
      ],
    ];
    return ActiveTournament(
      tournament: Tournament(
        id: 't-fixed',
        createdAt: DateTime(2026, 10, 21, 19),
        config: TournamentConfig(
          sport: SportType.tennis,
          mode: PartnerMode.fixed,
          matchDurationMinutes: 20,
          courts: [court(1), court(2)],
          players: players,
          fixedPairs: pairs,
        ),
        matches: matches,
      ),
    );
  }

  Widget screen({ActiveTournament? active, ActiveTournament? last, AppInstallMode install = AppInstallMode.none}) {
    final store = TournamentStore.memory();
    if (active != null) store.saveActive(active);
    return hifiScreen(
      const HomeScreen(),
      overrides: [
        tournamentStoreProvider.overrideWithValue(store),
        lastFinishedProvider.overrideWith((ref) => last),
        appInstallModeProvider.overrideWithValue(ValueNotifier(install) as ValueListenable<AppInstallMode>),
      ],
    );
  }

  final lastPadel = mixed(SportType.padel, rounds: 6, played: 12, finished: true);
  const longName = 'Mabar Jumat PB Garuda x Matcha Club';
  ActiveTournament runningPadel() => mixed(SportType.padel, rounds: 4, played: 6, name: longName);

  Future<void> golden(WidgetTester tester, String frame, Widget screen, {Future<void> Function(WidgetTester)? act}) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen, frame, act: act);
    // Golden bertoleransi 2%: "v3.2.0" di frame vs versi kode (sementara 3.1.0) tidak terbaca di piksel,
    // jadi teksnya dicek terpisah. Ada di semua kondisi Beranda, termasuk di bawah dialog/sheet (01h, 01i).
    expect(find.text('v$appVersion'), findsOneWidget, reason: 'versi app di banner $frame');
  }

  testWidgets('01a belum terpasang + ada riwayat', (tester) async {
    final named = mixed(SportType.padel, rounds: 6, played: 12, finished: true, name: 'PB Garuda x Matcha Club');
    await golden(tester, '01a', screen(last: named, install: AppInstallMode.prompt));
  });

  testWidgets('01b belum terpasang saja', (tester) async {
    await golden(tester, '01b', screen(install: AppInstallMode.prompt));
  });

  testWidgets('01c ada riwayat saja', (tester) async {
    await golden(tester, '01c', screen(last: lastPadel));
  });

  testWidgets('01d terpasang, belum ada riwayat', (tester) async {
    await golden(tester, '01d', screen());
  });

  testWidgets('01e turnamen berjalan Padel', (tester) async {
    await golden(tester, '01e', screen(active: runningPadel()));
  });

  testWidgets('01f turnamen berjalan Tennis', (tester) async {
    await golden(tester, '01f', screen(active: fixedTennis()));
  });

  testWidgets('01h dialog mulai turnamen baru', (tester) async {
    await golden(
      tester,
      '01h',
      screen(active: runningPadel()),
      act: (tester) => tester.tap(find.text('Mulai turnamen Padel')),
    );
  });

  testWidgets('01i sheet pasang di iPhone', (tester) async {
    await golden(
      tester,
      '01i',
      screen(install: AppInstallMode.manual),
      act: (tester) => tester.tap(find.text('Pasang Match Addict di HP')),
    );
  });

  // "Akhiri" tanpa "Selesai" di Bagikan: turnamennya masih di slot aktif, tapi bukan turnamen berjalan lagi.
  testWidgets('01c dari slot aktif: turnamen yang sudah diakhiri tampil sebagai turnamen terakhir', (tester) async {
    await golden(tester, '01c', screen(active: lastPadel));
  });

  testWidgets('mulai baru setelah Akhiri: tanpa dialog 01h, turnamennya pindah ke turnamen terakhir', (tester) async {
    final store = TournamentStore.memory();
    await store.saveActive(lastPadel);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/setup-peserta', builder: (_, _) => const Text('Pemain')),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(
        router,
        overrides: [
          tournamentStoreProvider.overrideWithValue(store),
          appInstallModeProvider.overrideWithValue(ValueNotifier(AppInstallMode.none) as ValueListenable<AppInstallMode>),
        ],
      ),
    );
    await tester.tap(find.text('Mulai turnamen Padel'));
    await tester.pumpAndSettle();

    expect(find.text('Mulai turnamen baru?'), findsNothing);
    expect(find.text('Pemain'), findsOneWidget);
    expect(store.loadActive(), isNull);
    expect(store.loadLastFinished()?.tournament.id, lastPadel.tournament.id);
  });

  testWidgets('turnamen terakhir Fixed tidak tampil (tidak bisa dilanjutkan)', (tester) async {
    final lastFixed = ActiveTournament(tournament: fixedTennis().tournament.copyWith(isFinished: true));
    await tester.pumpWidget(screen(last: lastFixed));
    expect(find.textContaining('Selesai di R'), findsNothing);
  });

  testWidgets('turnamen berjalan menyembunyikan baris riwayat', (tester) async {
    await tester.pumpWidget(screen(active: fixedTennis(), last: lastPadel));
    expect(find.textContaining('Selesai di R'), findsNothing);
    expect(find.text('Round 2'), findsOneWidget);
  });

  testWidgets('pilihan olahraga: dari turnamen terakhir, banner ikut tile kecuali ada turnamen berjalan', (tester) async {
    await tester.pumpWidget(screen(last: lastPadel));
    expect(find.text('Mulai turnamen Padel'), findsOneWidget);
    await tester.tap(find.text('Tennis'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai turnamen Tennis'), findsOneWidget);
  });
}
