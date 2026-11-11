import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/features/schedule/schedule_widgets.dart';

/// Back HP/browser di Jadwal ke Beranda, tidak ke Atur turnamen yang bisa membuat jadwal baru (keputusan host
/// 2026-11-11). Tombol ‹ memanggil `context.go('/')` yang sama.
void main() {
  Future<GoRouter> open(WidgetTester tester, {required bool enabled}) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Beranda')),
        GoRoute(path: '/konfigurasi', builder: (_, _) => const Text('Atur turnamen')),
        GoRoute(
          path: '/schedule',
          builder: (_, _) => ScheduleBackToHome(enabled: enabled, child: const Text('Jadwal')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/konfigurasi');
    await tester.pumpAndSettle();
    router.push('/schedule');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('back sistem dari Jadwal langsung ke Beranda', (tester) async {
    final router = await open(tester, enabled: true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget);
    expect(router.canPop(), isFalse, reason: 'Atur turnamen tidak tersisa di tumpukan');
  });

  testWidgets('penonton live: back biasa', (tester) async {
    await open(tester, enabled: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Atur turnamen'), findsOneWidget);
  });
}
