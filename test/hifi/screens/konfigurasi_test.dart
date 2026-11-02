import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/features/konfigurasi/konfigurasi_screen.dart';
import 'package:match_addict/features/konfigurasi/widgets/config_pickers.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// Golden layar penuh Konfigurasi, frame 03a–03e. Semua frame 8 pemain; isian diubah lewat stepper,
/// segmented, dan kartu mode seperti host.
void main() {
  final players = [for (var i = 1; i <= 8; i++) Player(id: 'p$i', name: 'Pemain $i')];

  Widget screen(SportType sport) => hifiScreen(KonfigurasiScreen(sport: sport, players: players));

  /// Test perilaku: layar seukuran frame supaya ketukan mengenai yang terlihat di frame.
  Future<void> pumpScreen(WidgetTester tester, SportType sport) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(sport));
  }

  /// Stepper ke-[index] dari atas (0 = format, 1 = durasi, 2 = jumlah court, 3.. = booking court).
  Finder stepper(int index) => find.byType(MabarStepper).at(index);

  Future<void> tapStep(WidgetTester tester, int index, String label, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.descendant(of: stepper(index), matching: find.bySemanticsLabel(label)));
      await tester.pump();
    }
  }

  Future<void> mixed(WidgetTester tester) async {
    await tester.tap(find.text('Mixed'));
    await tester.pump();
  }

  testWidgets('03a Fixed · Race to 6 (default Tennis)', (tester) async {
    await expectMatchesHifi(tester, screen(SportType.tennis), '03a');
  });

  testWidgets('03b Mixed · Americano · 3 court', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03b',
      act: (tester) async {
        await mixed(tester);
        await tester.tap(find.text('Americano'));
        await tapStep(tester, 2, 'Tambah');
        // 0 = nama turnamen, 1.. = nama court (isian stepper hanya ada selama angkanya diketik).
        await tester.enterText(find.byType(TextField).at(2), 'Court VIP');
        FocusManager.instance.primaryFocus?.unfocus();
        await tapStep(tester, 5, 'Kurangi');
        await tester.pump();
      },
    );
  });

  testWidgets('03c Mixed · Best of 5 · nama diisi (kotak aktif)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03c',
      act: (tester) async {
        await mixed(tester);
        await tester.tap(find.text('Best of'));
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, 'Mabar Jumat PB Garuda x Matcha Club');
      },
    );
  });

  testWidgets('03d durasi tidak muat', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '03d',
      act: (tester) async {
        await tapStep(tester, 1, 'Tambah', times: 14);
        await tapStep(tester, 4, 'Kurangi');
      },
    );
  });

  testWidgets('03e sheet warna court', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '03e',
      act: (tester) async {
        await tester.tap(find.byType(CourtSwatch).at(1));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('Ketuk warna: terpilih dan sheet tertutup', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    await tester.tap(find.byType(CourtSwatch).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Warna Court 2'), findsOneWidget);
    await tester.tap(find.byType(CourtSwatch).at(2 + 2)); // 2 swatch baris court + warna ke-3 (biru)
    await tester.pumpAndSettle();
    expect(find.text('Warna Court 2'), findsNothing);
    expect(tester.widget<CourtSwatch>(find.byType(CourtSwatch).at(1)).color, MabarColors.courtPalette[2]);
  });

  testWidgets('Durasi diketik dibulatkan ke kelipatan 5; target diketik kembali ke batas', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    Future<void> type(int index, String text) async {
      await tester.tap(stepper(index)); // tengah stepper = angkanya
      await tester.pump();
      await tester.enterText(find.descendant(of: stepper(index), matching: find.byType(TextField)), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    await type(1, '23');
    expect(tester.widget<MabarStepper>(stepper(1)).value, 25);
    await type(0, '12');
    expect(tester.widget<MabarStepper>(stepper(0)).value, 9);
  });

  testWidgets('Best of genap: catatan seri; ganti format = default format itu', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    await tester.tap(find.text('Best of'));
    await tester.pump();
    expect(tester.widget<MabarStepper>(stepper(0)).value, 5);
    expect(find.text('Bisa berakhir seri'), findsNothing);
    await tapStep(tester, 0, 'Tambah');
    expect(find.text('Bisa berakhir seri'), findsOneWidget);
  });

  testWidgets('Estimasi tombol: Fixed round + match, Mixed round saja; jumlah court 1–10', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    MabarButton button() => tester.widget<MabarButton>(find.byType(MabarButton));
    expect((button().label, button().meta), ('Lanjut', '· ±6 round · 12 match'));
    await tapStep(tester, 2, 'Tambah', times: 20);
    expect(tester.widget<MabarStepper>(stepper(2)).value, 10);
    expect(button().meta, '· ±6 round · 60 match');
    await mixed(tester);
    expect((button().label, button().meta), ('Mulai Round 1', '· ±6 round'));
  });

  testWidgets('Nama turnamen: dipangkas, maks 40 karakter, kosong = tanpa nama; ikut config ke Pasangan', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final opened = <TournamentConfig>[];
    final router = GoRouter(
      initialLocation: '/konfigurasi',
      routes: [
        GoRoute(path: '/konfigurasi', builder: (_, _) => KonfigurasiScreen(sport: SportType.tennis, players: players)),
        GoRoute(
          path: '/pair-setup',
          builder: (_, state) {
            opened.add(state.extra! as TournamentConfig);
            return const Text('Pasangan');
          },
        ),
      ],
    );
    await tester.pumpWidget(hifiRouterScreen(router));
    final name = find.byType(TextField).first;
    Future<TournamentConfig> next() async {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      final config = opened.last;
      router.pop();
      await tester.pumpAndSettle();
      return config;
    }

    expect((await next()).name, isNull);
    await tester.enterText(name, '   ');
    expect((await next()).name, isNull);
    await tester.enterText(name, '  PB Garuda x Matcha Club ');
    expect((await next()).name, 'PB Garuda x Matcha Club');
    await tester.enterText(name, 'Mabar Jumat PB Garuda x Matcha Club 2026 Ceria');
    expect((await next()).name, 'Mabar Jumat PB Garuda x Matcha Club 2026');
  });
}
