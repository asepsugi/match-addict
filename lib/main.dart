import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/router/browser_back.dart';
import 'core/theme/mabar_theme.dart';
import 'features/live/live_host_controller.dart';
import 'features/live/live_view_controller.dart';
import 'features/schedule/tournament_controller.dart';
import 'services/live/live_relay.dart';
import 'services/storage/tournament_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tanggal di kartu hasil ditulis dalam bahasa Indonesia.
  initializeDateFormatting('id');

  // Seluruh layout mockup disusun untuk portrait; landscape tidak pernah didesain.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  SystemChrome.setSystemUIOverlayStyle(MabarTheme.statusBarDark);

  // Dibuka dari link live (`#/live/KODE`): seluruh app jadi halaman penonton. Turnamen datang dari relay dan
  // simpanan Hive penonton sendiri tidak dibuka, jadi turnamennya di HP ini tidak pernah tertimpa.
  final liveCode = LiveRelay.codeIn(Uri.base);
  handleBrowserBack(appRouter);
  runApp(
    ProviderScope(
      overrides: liveCode == null
          ? [tournamentStoreProvider.overrideWithValue(await _openStore())]
          : [
              liveCodeProvider.overrideWithValue(liveCode),
              tournamentProvider.overrideWith(LiveTournamentController.new),
            ],
      child: const MabarApp(),
    ),
  );
}

/// Box Hive untuk turnamen. Kalau gagal dibuka (disk penuh, browser mode
/// private), app tetap jalan dengan penyimpanan memori — lebih baik kehilangan
/// resume daripada gagal start.
Future<TournamentStore> _openStore() async {
  try {
    await Hive.initFlutter();
    return TournamentStore(await Hive.openBox<String>(TournamentStore.boxName));
  } catch (_) {
    return TournamentStore.memory();
  }
}

class MabarApp extends ConsumerWidget {
  const MabarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live score host hidup sepanjang app: skor dari layar mana pun, dan resume dari Beranda, ikut terkirim.
    ref.listen(liveHostProvider, (_, __) {});
    return MaterialApp.router(
      title: 'Match Addict',
      debugShowCheckedModeBanner: false,
      theme: MabarTheme.light(),
      routerConfig: appRouterConfig,
      // Default untuk semua layar. Beranda memasang region putih sendiri; tanpa
      // default ini gaya putihnya terbawa ke layar berikutnya (Flutter hanya
      // mengganti gaya status bar kalau menemukan region lain).
      builder: (context, child) =>
          AnnotatedRegion<SystemUiOverlayStyle>(value: MabarTheme.statusBarDark, child: child!),
    );
  }
}
