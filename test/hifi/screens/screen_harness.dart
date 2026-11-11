import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';

/// Frame hi-fi menggambar tab Total Point kecuali yang berjudul Win %, juga untuk Race to/Best of yang sekarang
/// terbuka di Win % (PRD 4.2, keputusan 21). Tanpa ini golden tetap lolos di tab yang salah: urutan baris sering sama
/// dan tab yang berpindah masih di bawah toleransi 2%. Test Win % tetap mengetuk tabnya.
final hifiTotalPoint = rankingMethodProvider.overrideWith((ref) => RankingMethod.totalGames);

/// Layar penuh untuk golden: tema v2, safe area frame (47/34), provider yang di-override.
Widget hifiScreen(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: [hifiTotalPoint, ...overrides],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MabarTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: hifiSafeArea, viewPadding: hifiSafeArea),
      child: child!,
    ),
    home: home,
  ),
);

/// [hifiScreen] dengan router, untuk test perilaku yang berpindah layar.
Widget hifiRouterScreen(RouterConfig<Object> router, {List<Override> overrides = const []}) => ProviderScope(
  overrides: [hifiTotalPoint, ...overrides],
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: MabarTheme.light(),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: hifiSafeArea, viewPadding: hifiSafeArea),
      child: child!,
    ),
  ),
);
