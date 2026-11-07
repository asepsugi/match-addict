import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/konfigurasi/konfigurasi_screen.dart';
import '../../features/pair_setup/pair_setup_screen.dart';
import '../../features/detail_player/detail_player_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/live/live_screen.dart';
import '../../features/schedule/schedule_fixed_screen.dart';
import '../../features/schedule/schedule_mixed_screen.dart';
import '../../features/share/share_result_screen.dart';
import '../../features/score_input/score_input_screen.dart';
import '../../features/setup_peserta/setup_peserta_screen.dart';
import '../../models/models.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/setup-peserta',
      builder: (_, state) {
        final sport = state.extra as SportType;
        return SetupPesertaScreen(sport: sport);
      },
    ),
    GoRoute(
      path: '/konfigurasi',
      builder: (_, state) {
        final (sport, players, clubs) = state.extra as (SportType, List<Player>, List<Club>?);
        return KonfigurasiScreen(sport: sport, players: players, clubs: clubs);
      },
    ),
    GoRoute(
      path: '/pair-setup',
      builder: (_, state) => PairSetupScreen(config: state.extra as TournamentConfig),
    ),
    GoRoute(
      path: '/schedule',
      builder: (_, state) {
        final config = state.extra as TournamentConfig;
        return config.mode == PartnerMode.fixed
            ? ScheduleFixedScreen(config: config)
            : ScheduleMixedScreen(config: config);
      },
    ),
    GoRoute(
      path: '/score-input',
      builder: (_, state) => ScoreInputScreen(matchId: state.extra as String),
    ),
    GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
    GoRoute(
      path: '/detail-player',
      builder: (_, state) => DetailPlayerScreen(playerId: state.extra as String),
    ),
    GoRoute(path: '/share', builder: (_, __) => const ShareResultScreen()),
    // Halaman penonton; kodenya dibaca `main()` dari URL (liveCodeProvider), bukan dari parameter ini.
    GoRoute(path: '/live/:code', builder: (_, __) => const LiveScreen()),
  ],
  errorBuilder: (_, state) => Scaffold(body: Center(child: Text('Halaman tidak ditemukan'))),
);

/// [appRouter] tanpa menulis riwayat browser. Back Android di PWA (= back browser) ditangani sendiri lewat
/// `browser_back.dart`: menutup layar teratas yang masih ada di memori, seperti app native. Riwayat bawaan go_router
/// membangun ulang tumpukan layar dari riwayat saat back, dan `extra` yang bukan JSON (config turnamen) hilang jadi
/// null — layar Jadwal gagal dibangun dan app tinggal abu-abu.
final appRouterConfig = RouterConfig<RouteMatchList>(
  routeInformationProvider: _NoBrowserHistory(appRouter.routeInformationProvider),
  routeInformationParser: appRouter.routeInformationParser,
  routerDelegate: appRouter.routerDelegate,
  backButtonDispatcher: appRouter.backButtonDispatcher,
);

/// Navigasi go_router apa adanya, tapi rute tidak pernah dilaporkan ke platform: di web laporan itu menambah entri
/// riwayat browser, di native tidak dipakai.
class _NoBrowserHistory extends RouteInformationProvider {
  final GoRouteInformationProvider _inner;

  _NoBrowserHistory(this._inner);

  @override
  RouteInformation get value => _inner.value;

  @override
  void addListener(VoidCallback listener) => _inner.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _inner.removeListener(listener);

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {}
}
