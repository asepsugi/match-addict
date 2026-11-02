import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';

import '../hifi_golden.dart';

/// Layar penuh untuk golden: tema v2, safe area frame (47/34), provider yang di-override.
Widget hifiScreen(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
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
  overrides: overrides,
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
