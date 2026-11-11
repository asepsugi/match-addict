import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/features/konfigurasi/konfigurasi_screen.dart';
import 'package:match_addict/features/konfigurasi/widgets/config_pickers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/last_settings.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// Golden layar penuh Konfigurasi diringkas (KF-1 bagian 1), frame 03a–03q (Mexicano: 03c, 03e, 03q, bagian 2). Isian diubah lewat sheet seperti host; baris, estimasi, dan catatan kecil dicek juga lewat
/// `find.text` karena teks kecil lolos toleransi 2% walau salah.
void main() {
  List<Player> roster(int n) => [for (var i = 1; i <= n; i++) Player(id: 'p$i', name: 'Pemain $i')];

  Widget screen(SportType sport, {int players = 8, List<Override> overrides = const []}) => hifiScreen(
    KonfigurasiScreen(sport: sport, players: roster(players)),
    overrides: overrides,
  );

  Widget sparingScreen({List<Override> overrides = const []}) => hifiScreen(
    KonfigurasiScreen(
      sport: SportType.padel,
      players: roster(8),
      clubs: const [
        Club(id: 'a', name: 'PB Garuda'),
        Club(id: 'b', name: 'Matcha Club'),
      ],
    ),
    overrides: overrides,
  );

  /// Test perilaku: layar seukuran frame supaya ketukan mengenai yang terlihat di frame.
  Future<void> pumpScreen(
    WidgetTester tester,
    SportType sport, {
    int players = 8,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(sport, players: players, overrides: overrides));
  }

  Finder row(String text) => find.text(text, findRichText: true);

  Finder stepper(int index) => find.byType(MabarStepper).at(index);

  Future<void> tapStep(WidgetTester tester, int index, String label, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.descendant(of: stepper(index), matching: find.bySemanticsLabel(label)));
      await tester.pump();
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text, findRichText: true));
    await tester.pumpAndSettle();
  }

  /// Menutup sheet teratas dengan mengetuk scrim (di atas sheet).
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
  }

  Future<void> mixed(WidgetTester tester) async {
    await tester.tap(find.text('Mixed'));
    await tester.pump();
  }

  Future<void> bestOf5(WidgetTester tester) async {
    await tapText(tester, 'Race to 6 · 15 menit');
    await tester.tap(find.text('Best of'));
    await tester.pumpAndSettle();
  }

  /// Keadaan 03h–03k: Padel 24 pemain, Mixed, Americano 21, 6 court (Court 1–4 dua jam, 5–6 satu jam), nama diisi.
  Future<void> sixCourts(WidgetTester tester, {bool vip = false}) async {
    await mixed(tester);
    await tester.enterText(find.byType(TextField).first, 'Mabar Jumat PB Garuda');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapText(tester, 'Race to 6 · 15 menit');
    await tester.tap(find.text('Americano'));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    await tapText(tester, '2 court · 2 jam');
    await tapStep(tester, 0, 'Tambah', times: 4);
    await tapStep(tester, 5, 'Kurangi');
    await tapStep(tester, 6, 'Kurangi');
    if (vip) {
      await tester.enterText(find.byType(TextField).at(2), 'Court VIP');
      FocusManager.instance.primaryFocus?.unfocus();
    }
    await tester.pump();
  }

  /// Keadaan 03l–03n: Tennis, durasi 90, Court 2 satu jam.
  Future<void> tooLong(WidgetTester tester) async {
    await tapText(tester, 'Race to 6 · 20 menit');
    await tapStep(tester, 1, 'Tambah', times: 14);
    await closeSheet(tester);
    await tapText(tester, '2 court · 2 jam');
    await tapStep(tester, 2, 'Kurangi');
  }

  MabarButton button(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));

  testWidgets('03a Fixed · Race to 6 (turnamen pertama, Tennis)', (tester) async {
    await expectMatchesHifi(tester, screen(SportType.tennis), '03a');
    expect(row('Race to 6 · 20 menit'), findsOneWidget);
    expect(find.text('2 court · 2 jam'), findsOneWidget);
    expect((button(tester).label, button(tester).meta), ('Lanjut', '· ±6 round · 12 match'));
    for (final t in ['Fixed', 'Mixed']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('03b Mixed · Best of 5', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03b',
      act: (tester) async {
        await mixed(tester);
        await bestOf5(tester);
        await closeSheet(tester);
      },
    );
    expect(row('Best of 5 · 15 menit'), findsOneWidget);
    expect(find.text('2 court · 2 jam'), findsOneWidget);
    expect((button(tester).label, button(tester).meta), ('Mulai Round 1', '· ±8 round'));
  });

  Future<void> mexicano(WidgetTester tester) async {
    await tester.tap(find.text('Mexicano'));
    await tester.pump();
  }

  testWidgets('03c Mexicano dipilih · format jadi Americano', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03c',
      act: (tester) async {
        await mixed(tester);
        await bestOf5(tester);
        await closeSheet(tester);
        await mexicano(tester);
      },
    );
    expect(row('Americano 21 · 15 menit'), findsOneWidget);
    expect(find.text('2 court · 2 jam'), findsOneWidget);
    expect((button(tester).label, button(tester).meta), ('Mulai Round 1', '· ±8 round'));
    // Tanpa tulisan bahwa Race to / Best of tidak tersedia.
    expect(find.textContaining('Best of'), findsNothing);
    expect(find.text('Mexicano'), findsOneWidget);
  });

  testWidgets('03e sheet Skor · Mexicano', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03e',
      act: (tester) async {
        await mexicano(tester);
        await tapText(tester, 'Americano 21 · 15 menit');
      },
    );
    // Subjudul = format sebagai fakta; segmented tidak ada (jebakan 10).
    expect(find.text('Americano'), findsOneWidget);
    expect(find.byType(MabarSegmented<ScoringMethod>), findsNothing);
    expect(find.text('Race to'), findsNothing);
    expect(find.text('Best of'), findsNothing);
    expect(find.text('Poin per match'), findsOneWidget);
    expect(find.text('Durasi match'), findsOneWidget);
  });

  testWidgets('03d sheet Skor · Mixed · Best of 5', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03d',
      act: (tester) async {
        await mixed(tester);
        await bestOf5(tester);
      },
    );
    expect(find.text('Game per match'), findsOneWidget);
    expect(find.text('Durasi match'), findsOneWidget);
  });

  testWidgets('03f sheet Skor · Best of 6 · bisa seri', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '03f',
      act: (tester) async {
        await mixed(tester);
        await bestOf5(tester);
        await tapStep(tester, 0, 'Tambah');
      },
    );
    expect(row('Best of 6 · 15 menit'), findsOneWidget);
    // Catatan di bawah baris Skor dan di dalam sheet.
    expect(find.text('Bisa berakhir seri'), findsNWidgets(2));
  });

  testWidgets('03g sheet Court · 2 court', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '03g',
      act: (tester) async => tapText(tester, '2 court · 2 jam'),
    );
    expect(find.text('Jumlah court'), findsOneWidget);
    expect(find.text('Bisa berakhir seri'), findsNothing);
  });

  testWidgets('03h Mixed · 6 court · nama diisi', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel, players: 24),
      '03h',
      act: (tester) async {
        await sixCourts(tester);
        await closeSheet(tester);
      },
    );
    expect(row('Americano 21 · 15 menit'), findsOneWidget);
    expect(find.text('6 court · 1–2 jam'), findsOneWidget);
    expect((button(tester).label, button(tester).meta), ('Mulai Round 1', '· ±4 round'));
  });

  testWidgets('03i sheet Court · 6 court · booking berbeda', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel, players: 24),
      '03i',
      act: (tester) => sixCourts(tester, vip: true),
    );
    expect(find.text('6 court · 1–2 jam'), findsOneWidget);
    expect(find.text('· ±4 round'), findsOneWidget);
  });

  testWidgets('03j sheet Court · 10 court (maksimum)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel, players: 30),
      '03j',
      act: (tester) async {
        await mixed(tester);
        await tapText(tester, 'Race to 6 · 15 menit');
        await tester.tap(find.text('Americano'));
        await tester.pumpAndSettle();
        await closeSheet(tester);
        await tapText(tester, '2 court · 2 jam');
        await tapStep(tester, 0, 'Tambah', times: 8);
      },
    );
    expect(find.text('10 court · 2 jam'), findsOneWidget);
    expect(find.text('· ±8 round'), findsOneWidget);
    expect(tester.widget<MabarStepper>(stepper(0)).value, 10);
  });

  testWidgets('03k sheet warna court di atas sheet Court', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel, players: 24),
      '03k',
      act: (tester) async {
        await sixCourts(tester, vip: true);
        await tester.tap(find.byType(CourtSwatch).at(1));
        await tester.pumpAndSettle();
      },
    );
    expect(find.text('Warna Court VIP'), findsOneWidget);
  });

  testWidgets('03l durasi tidak muat · tombol mati', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '03l',
      act: (tester) async {
        await tooLong(tester);
        await closeSheet(tester);
      },
    );
    expect(row('Race to 6 · 90 menit'), findsOneWidget);
    expect(find.text('2 court · 1–2 jam'), findsOneWidget);
    expect(find.text('Lebih lama dari booking Court 2 (1 jam)'), findsOneWidget);
    expect((button(tester).label, button(tester).meta, button(tester).onPressed), ('Lanjut', null, null));
  });

  testWidgets('03m sheet Skor · durasi tidak muat', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '03m',
      act: (tester) async {
        await tooLong(tester);
        await closeSheet(tester);
        await tapText(tester, 'Race to 6 · 90 menit');
      },
    );
    expect(find.text('Lebih lama dari booking Court 2 (1 jam)'), findsNWidgets(2));
    // Turun ke 60 menit → catatan hilang di sheet dan di layar.
    await tapStep(tester, 1, 'Kurangi', times: 6);
    expect(find.textContaining('Lebih lama'), findsNothing);
    expect(button(tester).onPressed, isNotNull);
  });

  testWidgets('03n sheet Court · durasi tidak muat', (tester) async {
    await expectMatchesHifi(tester, screen(SportType.tennis), '03n', act: tooLong);
    expect(find.text('Lebih lama dari booking Court 2 (1 jam)'), findsNWidgets(2));
    // + di Court 2 → catatan hilang dan tombol aktif lagi.
    await tapStep(tester, 2, 'Tambah');
    expect(find.textContaining('Lebih lama'), findsNothing);
    expect(button(tester).onPressed, isNotNull);
  });

  /// Keyboard di frame hanya penanda (`.kbd`) dan tidak digambar `flutter test`: yang dibandingkan wilayah di atasnya.
  Future<void> expectAboveKeyboard(
    WidgetTester tester,
    Widget screen,
    String id,
    double keyboardHeight,
    Future<void> Function(WidgetTester) act,
  ) async {
    final diff = await compareWithHifi(
      tester,
      screen,
      id,
      region: Rect.fromLTWH(0, 0, 390, 844 - keyboardHeight),
      act: (tester) async {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight * hifiPixelRatio);
        await act(tester);
      },
    );
    expect(diff.ratio, lessThanOrEqualTo(0.02), reason: '$diff — lihat build/hifi_diff/$id.png');
  }

  // Dengan keyboard HP tidak memberi safe area bawah (frame: jarak bawah action bar 12).
  Widget keyboardScreen(SportType sport) => ProviderScope(
    overrides: [hifiTotalPoint],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MabarTheme.light(),
      builder: (context, child) {
        final inset = hifiSafeArea.copyWith(bottom: 0);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: inset, viewPadding: inset),
          child: child!,
        );
      },
      home: KonfigurasiScreen(sport: sport, players: roster(8)),
    ),
  );

  testWidgets('03o nama aktif · keyboard', (tester) async {
    await expectAboveKeyboard(tester, keyboardScreen(SportType.padel), '03o', 248, (tester) async {
      await mixed(tester);
      await bestOf5(tester);
      await closeSheet(tester);
      await tester.enterText(find.byType(TextField).first, 'Mabar Jumat PB Garuda x Matcha Club');
    });
    expect((button(tester).label, button(tester).meta), ('Mulai Round 1', '· ±8 round'));
  });

  testWidgets('03p durasi kosong · sedang diketik', (tester) async {
    await expectAboveKeyboard(tester, keyboardScreen(SportType.tennis), '03p', 242, (tester) async {
      await tapText(tester, 'Race to 6 · 20 menit');
      await tester.tap(stepper(1)); // tengah stepper = angkanya
      await tester.pump();
      await tester.enterText(find.descendant(of: stepper(1), matching: find.byType(TextField)), '');
      await tester.pump();
    });
    expect(row('Race to 6 · – menit'), findsOneWidget);
    expect(find.text('Isi durasi match'), findsNWidgets(2));
    expect((button(tester).label, button(tester).meta, button(tester).onPressed), ('Lanjut', null, null));
  });

  testWidgets('03p keyboard/sheet ditutup selagi kosong: tetap kosong sampai diisi', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    await tapText(tester, 'Race to 6 · 20 menit');
    await tester.tap(stepper(1));
    await tester.pump();
    await tester.enterText(find.descendant(of: stepper(1), matching: find.byType(TextField)), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await closeSheet(tester);
    expect(row('Race to 6 · – menit'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
    await tapText(tester, 'Race to 6 · – menit');
    await tapStep(tester, 1, 'Tambah');
    expect(tester.widget<MabarStepper>(stepper(1)).value, 5);
    expect(find.text('Isi durasi match'), findsNothing);
  });

  testWidgets('Ketuk warna: terpilih dan sheet warna tertutup, sheet Court tetap', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    await tapText(tester, '2 court · 2 jam');
    await tester.tap(find.byType(CourtSwatch).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Warna Court 2'), findsOneWidget);
    await tester.tap(find.byType(CourtSwatch).at(2 + 2)); // 2 swatch baris court + warna ke-3 (biru)
    await tester.pumpAndSettle();
    expect(find.text('Warna Court 2'), findsNothing);
    expect(find.text('Jumlah court'), findsOneWidget);
    expect(tester.widget<CourtSwatch>(find.byType(CourtSwatch).at(1)).color, MabarColors.courtPalette[2]);
  });

  testWidgets('Durasi diketik dibulatkan ke kelipatan 5; target diketik kembali ke batas', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    await tapText(tester, 'Race to 6 · 20 menit');
    Future<void> type(int index, String text) async {
      await tester.tap(stepper(index)); // tengah stepper = angkanya
      await tester.pump();
      await tester.enterText(find.descendant(of: stepper(index), matching: find.byType(TextField)), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    await type(1, '23');
    expect(tester.widget<MabarStepper>(stepper(1)).value, 25);
    expect(row('Race to 6 · 25 menit'), findsOneWidget);
    await type(0, '12');
    expect(tester.widget<MabarStepper>(stepper(0)).value, 9);
  });

  testWidgets('Best of genap: catatan seri; ganti format = default format itu', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    await tapText(tester, 'Race to 6 · 20 menit');
    await tester.tap(find.text('Best of'));
    await tester.pump();
    expect(tester.widget<MabarStepper>(stepper(0)).value, 5);
    expect(find.text('Bisa berakhir seri'), findsNothing);
    await tapStep(tester, 0, 'Tambah');
    expect(find.text('Bisa berakhir seri'), findsNWidgets(2));
  });

  testWidgets('Estimasi tombol: Fixed round + match, Mixed round saja; jumlah court 1–10', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    expect((button(tester).label, button(tester).meta), ('Lanjut', '· ±6 round · 12 match'));
    await tapText(tester, '2 court · 2 jam');
    await tapStep(tester, 0, 'Tambah', times: 20);
    expect(tester.widget<MabarStepper>(stepper(0)).value, 10);
    expect(button(tester).meta, '· ±6 round · 60 match');
    await closeSheet(tester);
    await mixed(tester);
    expect((button(tester).label, button(tester).meta), ('Mulai Round 1', '· ±6 round'));
  });

  testWidgets('AC-M1 (bagian Fixed/Mixed): berpindah Fixed ↔ Mixed tidak mengubah baris Skor dan Court', (
    tester,
  ) async {
    await pumpScreen(tester, SportType.padel);
    await tapText(tester, 'Race to 6 · 15 menit');
    await tester.tap(find.text('Americano'));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    await mixed(tester);
    await tester.tap(find.text('Fixed'));
    await tester.pump();
    await mixed(tester);
    expect(row('Americano 21 · 15 menit'), findsOneWidget);
    expect(find.text('2 court · 2 jam'), findsOneWidget);
  });

  testWidgets('AC-M1: Race to 6 → Mexicano → Americano 21; segmented tidak ada di sheet Skor', (tester) async {
    await pumpScreen(tester, SportType.padel);
    expect(row('Race to 6 · 15 menit'), findsOneWidget);
    await mexicano(tester);
    expect(row('Americano 21 · 15 menit'), findsOneWidget);
    await tapText(tester, 'Americano 21 · 15 menit');
    expect(find.byType(MabarSegmented<ScoringMethod>), findsNothing);
  });

  testWidgets('AC-M1: Americano 24 → Mexicano tetap 24; durasi dan court tidak berubah', (tester) async {
    await pumpScreen(tester, SportType.padel);
    await tapText(tester, 'Race to 6 · 15 menit');
    await tester.tap(find.text('Americano'));
    await tester.pumpAndSettle();
    await tapStep(tester, 0, 'Tambah', times: 3);
    await closeSheet(tester);
    await mexicano(tester);
    expect(row('Americano 24 · 15 menit'), findsOneWidget);
    expect(find.text('2 court · 2 jam'), findsOneWidget);
  });

  testWidgets('AC-M1 / jebakan 10: kembali ke Mixed atau Fixed tetap Americano, segmented muncul lagi', (tester) async {
    await pumpScreen(tester, SportType.padel);
    await tapText(tester, 'Race to 6 · 15 menit');
    await tester.tap(find.text('Best of'));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    await mexicano(tester);
    await mixed(tester);
    expect(row('Americano 21 · 15 menit'), findsOneWidget);
    await tapText(tester, 'Americano 21 · 15 menit');
    expect(find.byType(MabarSegmented<ScoringMethod>), findsOneWidget);
    expect(
      tester.widget<MabarSegmented<ScoringMethod>>(find.byType(MabarSegmented<ScoringMethod>)).selected,
      ScoringMethod.americano,
    );
    await closeSheet(tester);
    await tester.tap(find.text('Fixed'));
    await tester.pump();
    expect(row('Americano 21 · 15 menit'), findsOneWidget);
    expect((button(tester).label, button(tester).meta), ('Lanjut', '· ±8 round · 16 match'));
  });

  testWidgets('AC-M2: biasa tiga kartu Fixed · Mixed · Mexicano; Sparing hanya Fixed dan Mixed', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    expect(tester.widget<ModePicker>(find.byType(ModePicker)).slots, 3);
    expect(tester.widget<ModePicker>(find.byType(ModePicker)).modes, [
      PartnerMode.fixed,
      PartnerMode.mixed,
      PartnerMode.mexicano,
    ]);
    for (final t in ['Fixed', 'Mixed', 'Mexicano']) {
      expect(find.text(t), findsOneWidget);
    }

    await tester.pumpWidget(sparingScreen());
    await tester.pump();
    expect(tester.widget<ModePicker>(find.byType(ModePicker)).slots, 2);
    expect(tester.widget<ModePicker>(find.byType(ModePicker)).modes, [PartnerMode.fixed, PartnerMode.mixed]);
    expect(find.text('Mexicano'), findsNothing);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Mixed'), findsOneWidget);
  });

  testWidgets('AC-M3: estimasi Mexicano = Mixed untuk ukuran yang sama; Mulai Round 1 → Jadwal tanpa Pasangan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final opened = <(String, TournamentConfig)>[];
    final router = GoRouter(
      initialLocation: '/konfigurasi',
      routes: [
        GoRoute(
          path: '/konfigurasi',
          builder: (_, _) => KonfigurasiScreen(sport: SportType.padel, players: roster(12)),
        ),
        for (final path in ['/pair-setup', '/schedule'])
          GoRoute(
            path: path,
            builder: (_, state) {
              opened.add((path, state.extra! as TournamentConfig));
              return const Text('Tujuan');
            },
          ),
      ],
    );
    await tester.pumpWidget(hifiRouterScreen(router));
    await mixed(tester);
    final mixedButton = (button(tester).label, button(tester).meta);
    await mexicano(tester);
    expect((button(tester).label, button(tester).meta), mixedButton);
    expect(mixedButton, ('Mulai Round 1', '· ±8 round'));
    await tester.tap(find.text('Mulai Round 1'));
    await tester.pumpAndSettle();
    expect(opened.single.$1, '/schedule');
    expect(opened.single.$2.mode, PartnerMode.mexicano);
    expect(opened.single.$2.format, const ScoreFormat(ScoringMethod.americano, 21));
  });

  testWidgets('Kartu mode tanpa deskripsi, tinggi 86', (tester) async {
    await pumpScreen(tester, SportType.tennis);
    expect(find.text('Pasangan tetap'), findsNothing);
    expect(find.text('Pasangan berganti'), findsNothing);
    final fixedCard = find.ancestor(of: find.text('Fixed'), matching: find.byType(SizedBox)).first;
    expect(tester.getSize(fixedCard).height, 86);
  });

  group('pengaturan terakhir per olahraga (keputusan 36)', () {
    LastSettings padelLast() => const LastSettings(
      mode: PartnerMode.mixed,
      format: ScoreFormat(ScoringMethod.americano, 24),
      matchDurationMinutes: 15,
      courts: [
        LastCourt(colorIndex: 0, bookingMinutes: 120),
        LastCourt(name: 'Court Timur', colorIndex: 4, bookingMinutes: 120),
        LastCourt(colorIndex: 2, bookingMinutes: 60),
      ],
    );

    // 03q: turnamen terakhir Padel Mexicano, Americano 24, 15 menit, 3 court × 2 jam.
    LastSettings mexicanoLast() => const LastSettings(
      mode: PartnerMode.mexicano,
      format: ScoreFormat(ScoringMethod.americano, 24),
      matchDurationMinutes: 15,
      courts: [
        LastCourt(colorIndex: 0, bookingMinutes: 120),
        LastCourt(colorIndex: 1, bookingMinutes: 120),
        LastCourt(colorIndex: 2, bookingMinutes: 120),
      ],
    );

    List<Override> withStore(TournamentStore store) => [tournamentStoreProvider.overrideWithValue(store)];

    testWidgets('03q pengaturan terakhir di HP · Mexicano · 3 court', (tester) async {
      final store = TournamentStore.memory()..saveLastSettings(SportType.padel, mexicanoLast());
      await expectMatchesHifi(tester, screen(SportType.padel, players: 12, overrides: withStore(store)), '03q');
      expect(row('Americano 24 · 15 menit'), findsOneWidget);
      expect(find.text('3 court · 2 jam'), findsOneWidget);
      expect((button(tester).label, button(tester).meta), ('Mulai Round 1', '· ±8 round'));
      expect(tester.widget<ModePicker>(find.byType(ModePicker)).selected, PartnerMode.mexicano);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '');
    });

    testWidgets('03q keputusan 38: Sparing + simpanan Mexicano → Mixed, Americano 24, 3 court; tanpa kartu Mexicano', (
      tester,
    ) async {
      final store = TournamentStore.memory()..saveLastSettings(SportType.padel, mexicanoLast());
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sparingScreen(overrides: withStore(store)));
      expect(tester.widget<ModePicker>(find.byType(ModePicker)).selected, PartnerMode.mixed);
      expect(row('Americano 24 · 15 menit'), findsOneWidget);
      expect(find.text('3 court · 2 jam'), findsOneWidget);
      expect(find.text('Mexicano'), findsNothing);
    });

    testWidgets('Sparing + simpanan Mexicano: Mulai Round 1 membuat Mixed berklub yang bisa disimpan (canEncode)', (
      tester,
    ) async {
      final store = TournamentStore.memory()..saveLastSettings(SportType.padel, mexicanoLast());
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      final opened = <TournamentConfig>[];
      final router = GoRouter(
        initialLocation: '/konfigurasi',
        routes: [
          GoRoute(
            path: '/konfigurasi',
            builder: (_, _) => KonfigurasiScreen(
              sport: SportType.padel,
              players: [for (var i = 1; i <= 8; i++) Player(id: 'p$i', name: 'Pemain $i', clubId: i <= 4 ? 'a' : 'b')],
              clubs: const [
                Club(id: 'a', name: 'PB Garuda'),
                Club(id: 'b', name: 'Matcha Club'),
              ],
            ),
          ),
          GoRoute(
            path: '/schedule',
            builder: (_, state) {
              opened.add(state.extra! as TournamentConfig);
              return const Text('Jadwal');
            },
          ),
        ],
      );
      await tester.pumpWidget(hifiRouterScreen(router, overrides: withStore(store)));
      await tester.tap(find.text('Mulai Round 1'));
      await tester.pumpAndSettle();
      final config = opened.single;
      expect(config.mode, PartnerMode.mixed);
      expect(config.clubs, isNotNull);

      final container = ProviderContainer(
        overrides: [
          tournamentStoreProvider.overrideWithValue(TournamentStore.memory()),
          clockProvider.overrideWithValue(() => DateTime(2026)),
        ],
      );
      addTearDown(container.dispose);
      container.read(tournamentProvider.notifier).startIfNeeded(config);
      expect(TournamentCodec.canEncode(container.read(tournamentProvider)!), isTrue);
    });

    testWidgets('Padel dibuka dengan pengaturan tersimpan; nama turnamen kosong', (tester) async {
      final store = TournamentStore.memory()..saveLastSettings(SportType.padel, padelLast());
      await pumpScreen(tester, SportType.padel, overrides: withStore(store));
      expect(row('Americano 24 · 15 menit'), findsOneWidget);
      expect(find.text('3 court · 1–2 jam'), findsOneWidget);
      expect(find.text('Mulai Round 1'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '');
      await tapText(tester, '3 court · 1–2 jam');
      expect(tester.widget<MabarStepper>(stepper(3)).value, 1);
      expect(tester.widget<CourtSwatch>(find.byType(CourtSwatch).at(1)).color, MabarColors.courtPalette[4]);
    });

    testWidgets('Tennis terpisah dari Padel: tetap default 03a dengan 20 menit', (tester) async {
      final store = TournamentStore.memory()..saveLastSettings(SportType.padel, padelLast());
      await pumpScreen(tester, SportType.tennis, overrides: withStore(store));
      expect(row('Race to 6 · 20 menit'), findsOneWidget);
      expect(find.text('2 court · 2 jam'), findsOneWidget);
    });

    testWidgets('startIfNeeded menyimpan per olahraga; Konfigurasi berikutnya terisi, nama tidak ikut', (tester) async {
      final store = TournamentStore.memory();
      final container = ProviderContainer(
        overrides: [
          tournamentStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => DateTime(2026)),
        ],
      );
      addTearDown(container.dispose);
      final config = TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.mixed,
        matchDurationMinutes: 15,
        courts: const [
          Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
          Court(id: 'c2', name: 'Court Timur', colorIndex: 4, bookingDurationMinutes: 180),
        ],
        players: roster(8),
        format: const ScoreFormat(ScoringMethod.bestOf, 3),
        name: 'Mabar Jumat',
      );
      container.read(tournamentProvider.notifier).startIfNeeded(config);
      await tester.pump();
      expect(store.loadLastSettings(SportType.tennis), isNull);

      await pumpScreen(tester, SportType.padel, overrides: withStore(store));
      expect(row('Best of 3 · 15 menit'), findsOneWidget);
      expect(find.text('2 court · 2–3 jam'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '');
      await tapText(tester, '2 court · 2–3 jam');
      expect(find.text('Court Timur'), findsOneWidget);
    });

    testWidgets('Sparing memakai pengaturan tersimpan (forSparing)', (tester) async {
      final store = TournamentStore.memory()..saveLastSettings(SportType.padel, padelLast());
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        hifiScreen(
          KonfigurasiScreen(
            sport: SportType.padel,
            players: roster(8),
            clubs: const [
              Club(id: 'a', name: 'PB Garuda'),
              Club(id: 'b', name: 'Matcha Club'),
            ],
          ),
          overrides: withStore(store),
        ),
      );
      expect(row('Americano 24 · 15 menit'), findsOneWidget);
    });
  });

  testWidgets('Nama turnamen: dipangkas, maks 40 karakter, kosong = tanpa nama; ikut config ke Pasangan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final opened = <TournamentConfig>[];
    final router = GoRouter(
      initialLocation: '/konfigurasi',
      routes: [
        GoRoute(
          path: '/konfigurasi',
          builder: (_, _) => KonfigurasiScreen(sport: SportType.tennis, players: roster(8)),
        ),
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
