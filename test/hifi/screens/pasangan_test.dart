import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/pair_setup/pair_setup_screen.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_generator.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// `Random` yang membuat `List.shuffle` (Fisher–Yates dari belakang) menghasilkan urutan [target], supaya
/// hasil acak sama dengan frame.
class _ScriptedRandom implements Random {
  final List<int> _picks = [];
  var _next = 0;

  _ScriptedRandom(List<String> original, List<String> target) {
    final list = [...original];
    for (var length = list.length; length > 1; length--) {
      final pos = list.indexOf(target[length - 1]);
      _picks.add(pos);
      final tmp = list[length - 1];
      list[length - 1] = list[pos];
      list[pos] = tmp;
    }
  }

  @override
  int nextInt(int max) => _picks[_next++ % _picks.length];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

/// Golden layar penuh Pasangan, frame 04a–04e. Pemain = urutan contoh layar Pemain.
void main() {
  const names = [
    'Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T', 'Indra W', 'Joko S', 'Kiki A', //
    'Lina M', 'Maya P', 'Nanda R', 'Oki S', 'Putri A', 'Rizky H', 'Sari D', 'Tono B', 'Umar F', 'Vina K', //
    'Wulan S', 'Yoga P', 'Zaki M', 'Bayu S', 'Dimas A', 'Galih P', 'Rina K', 'Tari W', 'Hendra G',
  ];
  List<Player> players(int n) => [for (var i = 0; i < n; i++) Player(id: 'p$i', name: names[i])];

  TournamentConfig config(SportType sport, int n) => TournamentConfig(
    sport: sport,
    mode: PartnerMode.fixed,
    matchDurationMinutes: sport.defaultMatchDurationMinutes,
    courts: const [],
    players: players(n),
  );

  /// Urutan acak 04a/04c: Gina–Citra, Andi–(Hana|Indra), Eko–Fajar, Dewant–Budi (+ Hana sisa di 04c).
  Random seeded(int n) {
    if (n != 8 && n != 9) return Random(1); // 04e langsung Manual; acaknya tidak tampil
    final order = n == 8
        ? ['Gina R', 'Citra L', 'Andi P', 'Hana T', 'Eko M', 'Fajar K', 'Dewant R', 'Budi S']
        : ['Gina R', 'Citra L', 'Andi P', 'Indra W', 'Eko M', 'Fajar K', 'Dewant R', 'Budi S', 'Hana T'];
    return _ScriptedRandom(names.take(n).toList(), order);
  }

  Widget screen(SportType sport, int n) =>
      hifiScreen(PairSetupScreen(config: config(sport, n), random: seeded(n)));

  Future<void> manual(WidgetTester tester, List<String> taps) async {
    await tester.tap(find.text('Manual'));
    await tester.pump();
    for (final name in taps) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
  }

  test('ScriptedRandom menghasilkan urutan frame', () {
    final draft = PairGenerator.random(players(9), random: seeded(9));
    String n(String id) => names[int.parse(id.substring(1))];
    expect([for (final p in draft.pairs) '${n(p.player1Id)}+${n(p.player2Id)}'],
        ['Gina R+Citra L', 'Andi P+Indra W', 'Eko M+Fajar K', 'Dewant R+Budi S']);
    expect(draft.unpaired.single.name, 'Hana T');
  });

  testWidgets('04a Acak', (tester) async {
    await expectMatchesHifi(tester, screen(SportType.tennis, 8), '04a');
  });

  testWidgets('04b Manual · sedang memilih', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis, 8),
      '04b',
      act: (tester) => manual(tester, ['Andi P', 'Budi S', 'Citra L']),
    );
  });

  testWidgets('04c jumlah pemain ganjil', (tester) async {
    await expectMatchesHifi(tester, screen(SportType.tennis, 9), '04c');
  });

  testWidgets('04d dialog buat jadwal', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis, 8),
      '04d',
      act: (tester) async {
        await tester.tap(find.text('Buat jadwal'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('04e Manual · 30 pemain', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel, 30),
      '04e',
      act: (tester) => manual(tester, names.take(14).toList()),
    );
  });

  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
  }

  MabarButton button(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));
  MabarTextButton undo(WidgetTester tester) => tester.widget<MabarTextButton>(find.widgetWithText(MabarTextButton, 'Urungkan'));

  testWidgets('Manual: ketuk lagi melepas pilihan; Urungkan melepas pasangan terakhir + pilihan', (tester) async {
    await pumpScreen(tester, screen(SportType.tennis, 8));
    await manual(tester, ['Andi P']);
    expect(undo(tester).onPressed, isNull);
    expect(find.text('Ketuk satu lagi untuk dipasangkan dengan Andi P'), findsOneWidget);
    await manual(tester, ['Andi P']);
    expect(find.text('Ketuk dua pemain untuk membuat pasangan'), findsOneWidget);
    await manual(tester, ['Andi P', 'Budi S', 'Citra L']);
    expect(find.text('1 dari 4 pasangan'), findsOneWidget);
    await tester.tap(find.text('Urungkan'));
    await tester.pump();
    expect(find.text('0 dari 4 pasangan'), findsOneWidget);
    expect(find.text('8 belum berpasangan'), findsOneWidget);
    expect(find.text('Ketuk dua pemain untuk membuat pasangan'), findsOneWidget);
  });

  testWidgets('Manual ganjil: chip terakhir pindah ke baris "–", tombol menunggu', (tester) async {
    await pumpScreen(tester, screen(SportType.tennis, 9));
    await manual(tester, names.take(8).toList());
    expect(find.text('tanpa pasangan'), findsOneWidget);
    expect(find.textContaining('belum berpasangan'), findsNothing);
    expect(button(tester).meta, '· 1 pemain tanpa pasangan');
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('Manual genap lengkap → tombol aktif; kembali ke Acak membuang hasil manual', (tester) async {
    await pumpScreen(tester, screen(SportType.tennis, 8));
    await manual(tester, names.take(8).toList());
    expect(button(tester).onPressed, isNotNull);
    await tester.tap(find.text('Acak'));
    await tester.pump();
    expect(find.text('4 pasangan'), findsOneWidget);
    await tester.tap(find.text('Manual'));
    await tester.pump();
    expect(find.text('0 dari 4 pasangan'), findsOneWidget);
  });

  testWidgets('Ubah pemain kembali ke layar Pemain; konfirmasi → Jadwal dengan pasangan', (tester) async {
    TournamentConfig? scheduled;
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (_, _) => const Text('Pemain')),
        GoRoute(path: '/b', builder: (_, _) => const Text('Konfigurasi')),
        GoRoute(path: '/c', builder: (_, state) => PairSetupScreen(config: state.extra as TournamentConfig)),
        GoRoute(
          path: '/schedule',
          builder: (_, state) {
            scheduled = state.extra as TournamentConfig;
            return const Text('Jadwal');
          },
        ),
      ],
    );
    await pumpScreen(tester, MaterialApp.router(routerConfig: router));
    router.push('/b');
    await tester.pumpAndSettle();
    router.push('/c', extra: config(SportType.tennis, 9));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah pemain'));
    await tester.pumpAndSettle();
    expect(find.text('Pemain'), findsOneWidget);

    router.push('/c', extra: config(SportType.tennis, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat jadwal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat jadwal').last);
    await tester.pumpAndSettle();
    expect(find.text('Jadwal'), findsOneWidget);
    expect(scheduled!.fixedPairs, hasLength(4));
  });
}
