import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';
import 'package:match_addict/features/detail_player/detail_player_screen.dart';
import 'package:match_addict/features/leaderboard/leaderboard_screen.dart';
import 'package:match_addict/features/live/live_host_controller.dart';
import 'package:match_addict/features/live/live_screen.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/widgets/resting_list.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/services/live/live_relay.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'live_fixture.dart';
import 'ranking_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden Live score, frame 12a–12o (Fixed 12f dan 12i di `jadwal_fixed_test.dart`). HP host: latar 06h (Padel
/// Americano 21, R4 baru dibuat, 19.53). Penonton: data 06f (bernama), 09a, 10a, 06m.
void main() {
  final start = fixtureStart;
  final host = mixedTournament([mixedR1, mixedR2, mixedR3Done, mixedR4], adjust: mixedWo);
  final hostNow = start.add(const Duration(minutes: 53));

  Widget hostScreen({LiveHost? live, http.Client? relay}) => hifiScreen(
    ScheduleMixedScreen(config: host.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(host)),
      clockProvider.overrideWithValue(() => hostNow),
      if (live != null) liveHostProvider.overrideWith(() => ShownLive(live)),
      if (relay != null) liveRelayProvider.overrideWithValue(LiveRelay(client: relay)),
    ],
  );
  final sent = LiveHost(code: 'K7Q2MX', sentAt: hostNow);
  final waiting = LiveHost(code: 'K7Q2MX', sentAt: start.add(const Duration(minutes: 48)), waiting: true);

  Future<void> openLive(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live score'));
  }

  testWidgets('12a menu ⋯ Mixed, live belum aktif', (tester) async {
    await expectMatchesHifi(tester, hostScreen(), '12a', act: (tester) => tester.tap(find.bySemanticsLabel('Menu')));
  });

  testWidgets('12b dialog mulai live', (tester) async {
    await expectMatchesHifi(tester, hostScreen(), '12b', act: openLive);
  });

  testWidgets('12c sheet live aktif, terkirim', (tester) async {
    await expectMatchesHifi(tester, hostScreen(live: sent), '12c', act: openLive);
  });

  testWidgets('12d sheet menunggu internet', (tester) async {
    await expectMatchesHifi(tester, hostScreen(live: waiting), '12d', act: openLive);
    expect(find.text('Menunggu internet · terakhir terkirim 19.48'), findsOneWidget);
  });

  testWidgets('12e dialog hentikan live', (tester) async {
    await expectMatchesHifi(
      tester,
      hostScreen(live: sent),
      '12e',
      act: (tester) async {
        await openLive(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hentikan'));
      },
    );
  });

  testWidgets('12g gagal mulai tanpa internet: toast', (tester) async {
    await expectMatchesHifi(
      tester,
      hostScreen(relay: MockClient((_) async => throw http.ClientException('tidak ada internet'))),
      '12g',
      act: (tester) async {
        await openLive(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mulai'));
        await tester.pumpAndSettle();
      },
    );
    expect(find.text('Live score'), findsNothing); // sheet tidak terbuka
    await tester.pump(const Duration(seconds: 3)); // toast hilang sendiri
  });

  // 12q (B-9): sheet tetap terbuka di bawah toast, live tetap menyala. Sesi live sungguhan (bukan ShownLive), supaya
  // "Hentikan" benar-benar memanggil relay yang gagal.
  testWidgets('12q gagal hentikan tanpa internet: toast di atas sheet', (tester) async {
    final store = TournamentStore.memory();
    await store.saveLive(
      LiveSession(
        tournamentId: host.tournament.id,
        code: 'K7Q2MX',
        token: 'token',
        sentAt: start.add(const Duration(minutes: 48)),
      ),
    );
    final offline = MockClient((_) async => throw http.ClientException('tidak ada internet'));
    await expectMatchesHifi(
      tester,
      hifiScreen(
        ScheduleMixedScreen(config: host.config),
        overrides: [
          tournamentStoreProvider.overrideWithValue(store),
          tournamentProvider.overrideWith(() => LoadedTournament(host)),
          clockProvider.overrideWithValue(() => hostNow),
          liveRelayProvider.overrideWithValue(LiveRelay(client: offline)),
        ],
      ),
      '12q',
      act: (tester) async {
        await openLive(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hentikan'));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(MabarConfirmDialog), matching: find.text('Hentikan')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
    expect(find.text('Live score'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // toast hilang sendiri
  });

  // --- Penonton ---------------------------------------------------------------------------------------------

  Widget watch(LiveView view, {Duration elapsed = Duration.zero, bool still = false}) => hifiScreen(
    // Bola memuat berputar terus; diam saat animasi dimatikan, seperti frame.
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: const LiveScreen(),
      ),
    ),
    overrides: [
      liveCodeProvider.overrideWithValue('K7Q2MX'),
      liveViewProvider.overrideWith(() => Watching(view)),
      tournamentProvider.overrideWith(LiveTournamentController.new),
      clockProvider.overrideWithValue(() => start.add(elapsed)),
    ],
  );
  final named = mixedTournament([mixedR1, mixedR2, mixedR3Running], name: 'Rabu Padel Matcha Club');
  const forty = Duration(minutes: 40);

  testWidgets('12h Jadwal Mixed bernama: baca saja, tag Live', (tester) async {
    await expectMatchesHifi(tester, watch(LiveView(LiveViewStatus.live, named), elapsed: forty), '12h');
    expect(find.text('Isi skor'), findsNothing);
    expect(find.bySemanticsLabel('Menu'), findsNothing);
    expect(find.bySemanticsLabel('Kembali'), findsNothing);
  });

  testWidgets('12j Klasemen tanpa Bagikan', (tester) async {
    await expectMatchesHifi(
      tester,
      hifiScreen(
        const LeaderboardScreen(),
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          tournamentProvider.overrideWith(() => LoadedTournament(set1)),
        ],
      ),
      '12j',
    );
    expect(find.text('Bagikan'), findsNothing);
  });

  testWidgets('12k Detail pemain', (tester) async {
    await expectMatchesHifi(
      tester,
      hifiScreen(
        const DetailPlayerScreen(playerId: 'p00'),
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          tournamentProvider.overrideWith(() => LoadedTournament(set1)),
        ],
      ),
      '12k',
    );
  });

  testWidgets('12l diakhiri: tanpa tag, Klasemen', (tester) async {
    final ended = mixedTournament([
      mixedR1, mixedR2, mixedR3Running.map((m) => (m.$1, m.$2, m.$3, m.$4, 11, 10)).toList(), mixedR1, //
      const <MatchSpec>[('Andi', 'Gina', 'Budi', 'Indra', 11, 10), ('Citra', 'Eko', 'Hana', 'Joko', null, null)],
    ], finished: true);
    await expectMatchesHifi(tester, watch(LiveView(LiveViewStatus.live, ended)), '12l');
    expect(find.text('Live'), findsNothing);
  });

  testWidgets('12l diakhiri: satu daftar Istirahat berisi semua yang istirahat, tanpa prioritas (B-20)', (tester) async {
    // 30 pemain (data 06o): setelah R3 ada yang diprioritaskan dan ada yang "istirahat lagi"; penonton melihat
    // keduanya dalam satu daftar, bukan hanya yang diprioritaskan.
    const rounds = [
      <MatchSpec>[('Putri', 'Oki', 'Tari', 'Gina', 11, 10), ('Lina', 'Wulan', 'Kiki', 'Tono', 12, 9)],
      <MatchSpec>[('Fajar', 'Galih', 'Rizky', 'Joko', 11, 10), ('Nanda', 'Eko', 'Hendra', 'Bayu', 12, 9)],
      <MatchSpec>[('Citra', 'Vina', 'Maya', 'Dimas', 13, 8), ('Sari', 'Dewant', 'Umar', 'Andi', 11, 9)],
    ];
    final ended = mixedTournament(rounds, players: 30, id: 't-12l-30', finished: true);
    final split = EndlessRoundGenerator.restingAfterLastRound(ended, start);
    // Tanpa `later` test ini tidak menguji apa-apa.
    expect(split.later, isNotEmpty);
    await tester.pumpWidget(watch(LiveView(LiveViewStatus.live, ended)));
    await tester.pumpAndSettle();
    final list = tester.widget<RestingList>(find.byType(RestingList));
    expect(list.priorityRound, isNull);
    expect(list.names, [
      for (final p in [...split.priority, ...split.later]) p.name,
    ]);
  });

  testWidgets('12m HP penonton offline', (tester) async {
    await expectMatchesHifi(tester, watch(LiveView(LiveViewStatus.offline, named), elapsed: forty), '12m');
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('12n live tidak ditemukan', (tester) async {
    await expectMatchesHifi(tester, watch(const LiveView(LiveViewStatus.gone)), '12n');
  });

  testWidgets('Data dari versi app lain: Live tidak bisa dibuka', (tester) async {
    await tester.pumpWidget(watch(const LiveView(LiveViewStatus.unreadable)));
    expect(find.text('Live tidak bisa dibuka'), findsOneWidget);
    expect(find.text('Buka Match Addict'), findsOneWidget);
  });

  testWidgets('Live dihentikan saat penonton di Klasemen: kembali ke halaman live, tidak ditemukan', (tester) async {
    final router = GoRouter(
      initialLocation: '/live/K7Q2MX',
      routes: [
        GoRoute(path: '/live/:code', builder: (_, _) => const LiveScreen()),
        GoRoute(path: '/leaderboard', builder: (_, _) => const LeaderboardScreen()),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(
        router,
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          liveViewProvider.overrideWith(() => Watching(LiveView(LiveViewStatus.live, named))),
          tournamentProvider.overrideWith(LiveTournamentController.new),
          clockProvider.overrideWithValue(() => start.add(forty)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klasemen'));
    await tester.pumpAndSettle();
    expect(find.text('Andi P'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(LeaderboardScreen)));
    (container.read(liveViewProvider.notifier) as Watching).show(const LiveView(LiveViewStatus.gone));
    await tester.pumpAndSettle();
    expect(find.byType(LeaderboardScreen), findsNothing);
    expect(find.text('Live tidak ditemukan'), findsOneWidget);
  });

  // AC-G17: penonton Grup + Gugur melihat Jadwal round dan Klasemen, tanpa tab Bagan dan tanpa aksi.
  testWidgets('AC-G17 penonton Grup + Gugur: tanpa tab Bagan, tanpa aksi', (tester) async {
    final active = gg21c();
    expect(active.hasBracket, isTrue);
    await tester.pumpWidget(watch(LiveView(LiveViewStatus.live, active), elapsed: const Duration(minutes: 96)));
    await tester.pumpAndSettle();
    expect(find.text('Bagan'), findsNothing);
    expect(find.text('Buat bagan'), findsNothing);
    expect(find.text('Isi skor'), findsNothing);
    expect(find.bySemanticsLabel('Menu'), findsNothing);
  });

  testWidgets('12o memuat', (tester) async {
    await expectMatchesHifi(tester, watch(const LiveView(LiveViewStatus.loading), still: true), '12o');
  });
}
