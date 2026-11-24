import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
///
/// [textScale] = skala teks HP (frame `*ts`, `.ts13`); bawaan 1,0 tidak mengubah golden lama.
Widget hifiScreen(Widget home, {List<Override> overrides = const [], double textScale = 1.0}) => ProviderScope(
  overrides: [hifiTotalPoint, ...overrides],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MabarTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: hifiSafeArea,
        viewPadding: hifiSafeArea,
        textScaler: TextScaler.linear(textScale),
      ),
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

/// Layar di skala teks 1,3 tanpa pembanding gambar (frame `*ts` hanya ada untuk 06f dan 03a): lolos kalau tidak ada
/// exception tata letak (overflow) sampai [act] selesai. Dipakai untuk frame yang aturannya sama (20b, 07j).
Future<void> expectNoOverflowAtMaxTextScale(
  WidgetTester tester,
  Widget screen, {
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await loadHifiFonts();
  tester.view.physicalSize = hifiScreenSize * hifiPixelRatio;
  tester.view.devicePixelRatio = hifiPixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(screen);
  await tester.pumpAndSettle();
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
}
