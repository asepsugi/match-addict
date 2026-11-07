import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/pair_setup/pair_setup_screen.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// `Random` yang membuat dua `shuffle` berurutan (klub pertama lalu kedua, seperti `randomByClub`) menghasilkan urutan
/// target masing-masing, supaya hasil acak = G1–G4 / M1–M3 di frame.
class _ScriptedRandom implements Random {
  final List<int> _picks = [];
  var _next = 0;

  _ScriptedRandom(List<List<String>> originals, List<List<String>> targets) {
    for (final (k, original) in originals.indexed) {
      final list = [...original];
      for (var length = list.length; length > 1; length--) {
        final pos = list.indexOf(targets[k][length - 1]);
        _picks.add(pos);
        final tmp = list[length - 1];
        list[length - 1] = list[pos];
        list[pos] = tmp;
      }
    }
  }

  @override
  int nextInt(int max) => _picks[_next++ % _picks.length];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

/// Golden layar Pasangan sparing, frame 14a–14e, plus AC-S3/AC-S4/K12 (docs/tasks.md SP-10).
void main() {
  final garuda9 = [...garudaNames, 'Gilang'];
  final matcha7 = [...matchaNames, 'Oki'];
  const garuda16 = [
    ...['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'],
    ...['Gilang', 'Hendra', 'Iwan', 'Jaka', 'Rizky', 'Sari', 'Tono', 'Umar'],
  ];
  const matcha14 = [...matchaNames, 'Oki', 'Putri', 'Rina', 'Tari', 'Vina', 'Wulan', 'Yoga', 'Zaki'];

  /// Urutan acak = urutan daftar, jadi G1 Andi · Budi, G2 Citra · Dewi, … dan M1 Indra · Joko, …
  Random scripted(List<String> g, List<String> m) => _ScriptedRandom([g, m], [g, m]);

  Widget screen(List<String> g, List<String> m) => hifiScreen(
    PairSetupScreen(
      config: sparingConfig(garudaPlayers: g, matchaPlayers: m, paired: false),
      random: scripted(g, m),
    ),
  );

  Future<void> manual(WidgetTester tester, List<String> taps) async {
    await tester.tap(find.text('Manual'));
    await tester.pump();
    await tap(tester, taps);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
  }

  MabarButton button(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));

  testWidgets('14a Acak · AC-S3', (tester) async {
    await expectMatchesHifi(tester, screen(garudaNames, matchaNames), '14a');
    expect(find.text('Padel · PB Garuda 8 · Matcha Club 6'), findsOneWidget);
    expect(find.text('PB Garuda · 4 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 3 pasangan'), findsOneWidget);
    expect(find.text('Acak ulang'), findsOneWidget);
    expect(button(tester).onPressed, isNotNull);
  });

  testWidgets('14b Manual · sedang memilih', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(garudaNames, matchaNames),
      '14b',
      act: (tester) => manual(tester, ['Andi', 'Budi', 'Citra']),
    );
    expect(find.text('PB Garuda · 1 dari 4 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 0 dari 3 pasangan'), findsOneWidget);
    expect(find.text('Ketuk satu lagi untuk dipasangkan dengan Citra'), findsOneWidget);
    expect(button(tester).meta, '· 6 pasangan lagi');
  });

  testWidgets('14c pemain ganjil di dua klub · K12', (tester) async {
    await expectMatchesHifi(tester, screen(garuda9, matcha7), '14c');
    expect(find.text('Padel · PB Garuda 9 · Matcha Club 7'), findsOneWidget);
    expect(find.text('Fixed butuh pemain genap per klub'), findsOneWidget);
    expect(find.text('Ubah pemain'), findsOneWidget);
    expect(find.text('tanpa pasangan'), findsNWidgets(2));
    expect(button(tester).meta, '· 2 pemain tanpa pasangan');
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('14d dialog buat jadwal', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(garudaNames, matchaNames),
      '14d',
      act: (tester) async {
        await tester.tap(find.text('Buat jadwal'));
        await tester.pumpAndSettle();
      },
    );
    expect(find.text('Buat jadwal?'), findsOneWidget);
    expect(find.text('Pasangan tidak bisa diubah setelah jadwal dibuat.'), findsOneWidget);
  });

  testWidgets('14e Manual · 30 pemain', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(garuda16, matcha14),
      '14e',
      act: (tester) => manual(tester, [...garuda16.take(8), ...matchaNames]),
    );
    expect(find.text('PB Garuda · 4 dari 8 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 3 dari 7 pasangan'), findsOneWidget);
    expect(button(tester).meta, '· 8 pasangan lagi');
  });

  testWidgets('AC-S4: Citra lalu Indra tidak membentuk pasangan, pilihan pindah ke Indra', (tester) async {
    await pumpScreen(tester, screen(garudaNames, matchaNames));
    await manual(tester, ['Andi', 'Budi', 'Citra', 'Indra']);
    expect(find.text('PB Garuda · 1 dari 4 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 0 dari 3 pasangan'), findsOneWidget);
    expect(find.text('Ketuk satu lagi untuk dipasangkan dengan Indra'), findsOneWidget);
    expect(find.text('Ketuk satu lagi untuk dipasangkan dengan Citra'), findsNothing);
    // Indra lalu Joko (sesama klub) membentuk pasangan Matcha.
    await tap(tester, ['Joko']);
    expect(find.text('Matcha Club · 1 dari 3 pasangan'), findsOneWidget);
    expect(find.text('Ketuk dua pemain satu klub untuk membuat pasangan'), findsOneWidget);
  });

  testWidgets('Manual: Urungkan melepas pasangan terakhir dari klub mana pun; Acak ulang hanya satu', (tester) async {
    await pumpScreen(tester, screen(garudaNames, matchaNames));
    await manual(tester, ['Andi', 'Budi', 'Indra', 'Joko', 'Citra']);
    await tester.tap(find.text('Urungkan'));
    await tester.pump();
    expect(find.text('PB Garuda · 1 dari 4 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 0 dari 3 pasangan'), findsOneWidget);
    expect(find.text('Ketuk dua pemain satu klub untuk membuat pasangan'), findsOneWidget);
    await tester.tap(find.text('Acak'));
    await tester.pump();
    expect(find.text('Acak ulang'), findsOneWidget);
  });

  testWidgets('K12: satu klub ganjil menahan tombol dengan satu sisa', (tester) async {
    await pumpScreen(tester, screen(garudaNames, [...matchaNames.take(5)]));
    expect(find.text('tanpa pasangan'), findsOneWidget);
    expect(button(tester).meta, '· 1 pemain tanpa pasangan');
    expect(button(tester).onPressed, isNull);
    expect(find.text('Fixed butuh pemain genap per klub'), findsOneWidget);
  });

  testWidgets('K12: hanya Garuda ganjil, catatan di bawah baris sisa Garuda (di atas header Matcha)', (tester) async {
    await pumpScreen(tester, screen(garuda9, matchaNames));
    final note = tester.getTopLeft(find.text('Fixed butuh pemain genap per klub')).dy;
    expect(note, lessThan(tester.getTopLeft(find.text('Matcha Club · 3 pasangan')).dy));
    expect(button(tester).meta, '· 1 pemain tanpa pasangan');
  });

  testWidgets('Manual ganjil: chip terakhir klub pindah ke baris "–"', (tester) async {
    await pumpScreen(tester, screen(garuda9, matchaNames));
    await manual(tester, [...garudaNames, ...matchaNames]);
    expect(find.text('tanpa pasangan'), findsOneWidget);
    expect(button(tester).meta, '· 1 pemain tanpa pasangan');
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('Buat jadwal → Jadwal dengan pasangan per klub, klub terbawa', (tester) async {
    TournamentConfig? scheduled;
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (_, _) => const Text('Beranda')),
        GoRoute(
          path: '/c',
          builder: (_, state) =>
              PairSetupScreen(config: state.extra as TournamentConfig, random: scripted(garudaNames, matchaNames)),
        ),
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
    router.push('/c', extra: sparingConfig(paired: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat jadwal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat jadwal').last);
    await tester.pumpAndSettle();
    expect(find.text('Jadwal'), findsOneWidget);
    expect(scheduled!.isSparing, isTrue);
    expect(scheduled!.fixedPairs, hasLength(7));
    expect(scheduled!.pairsOfClub(garuda.id), hasLength(4));
    expect(scheduled!.pairsOfClub(matcha.id), hasLength(3));
    // Urutan = indeks generator: klub pertama dulu, sesuai fixture 13A.
    expect(
      [for (final p in scheduled!.fixedPairs!.take(2)) '${p.player1Id}+${p.player2Id}'],
      ['p-andi+p-budi', 'p-citra+p-dewi'],
    );
  });
}

/// Ketuk berurutan, satu `pump` per ketukan.
Future<void> tap(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    await tester.tap(find.text(name));
    await tester.pump();
  }
}
