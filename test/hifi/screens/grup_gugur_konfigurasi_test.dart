import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/features/konfigurasi/konfigurasi_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/last_settings.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// Golden Konfigurasi Grup + Gugur (GG-5), frame 19a–19l. Teks kecil lolos toleransi 2% walau salah, jadi baris dan
/// tombol dicek juga lewat `find.text` / `MabarButton`.
void main() {
  List<Player> roster(int n) => [for (var i = 1; i <= n; i++) Player(id: 'p$i', name: 'Pemain $i')];

  Widget screen(SportType sport, int players, {List<Override> overrides = const []}) => hifiScreen(
    KonfigurasiScreen(sport: sport, players: roster(players)),
    overrides: overrides,
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    SportType sport,
    int players, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(sport, players, overrides: overrides));
  }

  Finder row(String text) => find.text(text, findRichText: true);
  Finder stepper(int index) => find.byType(MabarStepper).at(index);
  MabarButton button(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text, findRichText: true));
    await tester.pumpAndSettle();
  }

  Future<void> tapStep(WidgetTester tester, int index, String label, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.descendant(of: stepper(index), matching: find.bySemanticsLabel(label)));
      await tester.pump();
    }
  }

  /// Menutup sheet teratas dengan mengetuk scrim di atasnya.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
  }

  Future<void> groupKnockout(WidgetTester tester) => tapText(tester, 'Grup + Gugur');

  /// Sheet Gugur → sheet babak [round]; format diubah lewat [act].
  Future<void> inRound(WidgetTester tester, String round, Future<void> Function() act) async {
    await tapText(tester, round);
    await act();
    await closeSheet(tester);
  }

  /// Keadaan 19e: contoh 16A, Semifinal Race to 6, juara 3 Race to 4, Final Race to 9; sheet Gugur terbuka.
  Future<void> exampleA(WidgetTester tester) async {
    await groupKnockout(tester);
    await tapText(tester, 'Race to 6');
    await inRound(tester, 'Perebutan juara 3', () => tapStep(tester, 0, 'Kurangi', times: 2));
    await inRound(tester, 'Final', () => tapStep(tester, 0, 'Tambah', times: 3));
  }

  group('golden', () {
    testWidgets('19a Fixed · Round-robin · 16 pemain', (tester) async {
      await expectMatchesHifi(tester, screen(SportType.padel, 16), '19a');
      expect(find.text('Round-robin'), findsOneWidget);
      expect(find.text('Grup + Gugur'), findsOneWidget);
      expect(find.text('Skor'), findsOneWidget);
      expect(row('Race to 6 · 15 menit'), findsOneWidget);
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· ±8 round · 16 match'));
    });

    testWidgets('19b Grup + Gugur · 2 grup · default', (tester) async {
      await expectMatchesHifi(tester, screen(SportType.padel, 16), '19b', act: groupKnockout);
      expect(row('2 grup · Race to 6 · 15 menit'), findsOneWidget);
      expect(row('Race to 6'), findsOneWidget);
      expect(find.text('Skor'), findsNothing);
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· 8 round · 16 match'));
    });

    testWidgets('19c sheet Fase grup · 8 pasangan · hanya 2 grup', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19c',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 15 menit');
        },
      );
      expect(find.text('2 grup'), findsOneWidget); // subjudul sheet
      expect(find.text('4 grup'), findsNothing);
    });

    testWidgets('19d sheet Fase grup · 12 pasangan · 4 grup', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.tennis, 24),
        '19d',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 20 menit');
          await tapText(tester, '4 grup');
        },
      );
      expect(row('4 grup · Race to 6 · 20 menit'), findsOneWidget);
    });

    testWidgets('19e sheet Gugur · 2 grup · format per babak', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19e',
        act: (tester) async {
          await exampleA(tester);
        },
      );
      expect(find.text('Perempat final'), findsNothing);
      expect(find.text('Race to 4'), findsOneWidget);
      expect(find.text('Race to 9'), findsOneWidget);
    });

    testWidgets('19f sheet Final di atas sheet Gugur', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19f',
        act: (tester) async {
          await exampleA(tester);
          await tapText(tester, 'Final');
        },
      );
      expect(tester.widget<MabarStepper>(stepper(0)).value, 9);
      // Race to 9 = batas atas: + mati.
      await tapStep(tester, 0, 'Tambah');
      expect(tester.widget<MabarStepper>(stepper(0)).value, 9);
    });

    testWidgets('19g sheet Perebutan juara 3 · Tidak ada', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19g',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, 'Race to 6');
          await inRound(tester, 'Final', () => tapStep(tester, 0, 'Tambah', times: 3));
          await tapText(tester, 'Perebutan juara 3');
          await tapText(tester, 'Tidak ada');
        },
      );
      expect(row('Race to 6–9 · tanpa Juara 3'), findsOneWidget);
      // 16 → 15 match, tetap 8 round (19g).
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· 8 round · 15 match'));
    });

    testWidgets('19h Fase grup Best of 6 · babak gugur Best of 7, stepper 7 → 5 / 9', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19h',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 15 menit');
          await tester.tap(find.text('Best of'));
          await tester.pumpAndSettle();
          await tapStep(tester, 0, 'Tambah');
          await closeSheet(tester);
          await tapText(tester, 'Best of 7');
          await tapText(tester, 'Semifinal');
        },
      );
      expect(row('2 grup · Best of 6 · 15 menit'), findsOneWidget);
      expect(find.text('Bisa berakhir seri'), findsOneWidget);
      expect(tester.widget<MabarStepper>(stepper(0)).value, 7);
      await tapStep(tester, 0, 'Kurangi');
      expect(tester.widget<MabarStepper>(stepper(0)).value, 5);
      await tapStep(tester, 0, 'Tambah', times: 2);
      expect(tester.widget<MabarStepper>(stepper(0)).value, 9);
    });

    testWidgets('19i 4 grup · 24 pemain · lewat booking', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.tennis, 24),
        '19i',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 20 menit');
          await tapText(tester, '4 grup');
          await closeSheet(tester);
          await tapText(tester, '2 court · 2 jam');
          await tapStep(tester, 1, 'Tambah');
          await tapStep(tester, 2, 'Tambah');
          await closeSheet(tester);
        },
      );
      expect(row('2 court · 3 jam'), findsOneWidget);
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· 10 round · lewat booking 00:20'));
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('19j sheet Gugur · 4 grup', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.tennis, 24),
        '19j',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 20 menit');
          await tapText(tester, '4 grup');
          await closeSheet(tester);
          await tapText(tester, 'Race to 6');
        },
      );
      expect(find.text('Perempat final'), findsOneWidget);
      // Kembali ke 2 grup: baris Perempat final hilang, format babak lain tetap.
      await closeSheet(tester);
      await tapText(tester, '4 grup · Race to 6 · 20 menit');
      await tapText(tester, '2 grup');
      await closeSheet(tester);
      await tapText(tester, 'Race to 6');
      expect(find.text('Perempat final'), findsNothing);
    });

    testWidgets('19k 1 court · lewat booking 02:00', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19k',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 court · 2 jam');
          await tapStep(tester, 0, 'Kurangi');
          await closeSheet(tester);
        },
      );
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· 16 round · lewat booking 02:00'));
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('19l durasi tidak muat · tombol mati', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19l',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 15 menit');
          await tapStep(tester, 1, 'Tambah', times: 15);
          await closeSheet(tester);
          await tapText(tester, '2 court · 2 jam');
          await tapStep(tester, 2, 'Kurangi');
          await closeSheet(tester);
        },
      );
      expect(row('2 grup · Race to 6 · 90 menit'), findsOneWidget);
      expect(find.text('Lebih lama dari booking Court 2 (1 jam)'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      expect(button(tester).meta, isNull);
    });
  });

  group('perilaku', () {
    testWidgets('AC-G1: segmented hanya Fixed biasa dengan 6+ pasangan', (tester) async {
      for (final (players, offered) in [(10, false), (12, true), (22, true), (24, true)]) {
        await pumpScreen(tester, SportType.padel, players);
        expect(find.text('Grup + Gugur'), offered ? findsOneWidget : findsNothing, reason: '$players pemain');
      }
      await pumpScreen(tester, SportType.padel, 24);
      await tester.tap(find.text('Mixed'));
      await tester.pump();
      expect(find.text('Grup + Gugur'), findsNothing);
      await tester.tap(find.text('Mexicano'));
      await tester.pump();
      expect(find.text('Grup + Gugur'), findsNothing);
      // Sparing: tidak pernah (GU14).
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      await tester.pumpWidget(
        hifiScreen(
          KonfigurasiScreen(
            sport: SportType.padel,
            players: roster(24),
            clubs: const [
              Club(id: 'a', name: 'PB Garuda'),
              Club(id: 'b', name: 'Matcha Club'),
            ],
          ),
        ),
      );
      expect(find.text('Grup + Gugur'), findsNothing);
    });

    testWidgets('Pindah ke Mixed lalu kembali ke Fixed memulihkan pilihan Grup + Gugur', (tester) async {
      await pumpScreen(tester, SportType.padel, 16);
      await groupKnockout(tester);
      await tester.tap(find.text('Mixed'));
      await tester.pump();
      expect(find.text('Fase grup'), findsNothing);
      expect(find.text('Skor'), findsOneWidget);
      await tester.tap(find.text('Fixed'));
      await tester.pump();
      expect(find.text('Fase grup'), findsOneWidget);
    });

    testWidgets('Config keluar membawa GroupKnockout tanpa grup', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      final opened = <TournamentConfig>[];
      final router = GoRouter(
        initialLocation: '/konfigurasi',
        routes: [
          GoRoute(
            path: '/konfigurasi',
            builder: (_, _) => KonfigurasiScreen(sport: SportType.padel, players: roster(16)),
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
      await exampleA(tester);
      await closeSheet(tester);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      final gk = opened.single.groupKnockout!;
      expect(gk.groupCount, 2);
      expect(gk.groups, isEmpty);
      expect(gk.thirdPlace, isTrue);
      expect(gk.formats, {
        KnockoutRound.semifinal: const ScoreFormat(ScoringMethod.raceTo, 6),
        KnockoutRound.thirdPlace: const ScoreFormat(ScoringMethod.raceTo, 4),
        KnockoutRound.finalRound: const ScoreFormat(ScoringMethod.raceTo, 9),
      });
    });

    testWidgets('Round-robin: config tanpa groupKnockout', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      TournamentConfig? opened;
      final router = GoRouter(
        initialLocation: '/konfigurasi',
        routes: [
          GoRoute(
            path: '/konfigurasi',
            builder: (_, _) => KonfigurasiScreen(sport: SportType.padel, players: roster(16)),
          ),
          GoRoute(
            path: '/pair-setup',
            builder: (_, state) {
              opened = state.extra! as TournamentConfig;
              return const Text('Pasangan');
            },
          ),
        ],
      );
      await tester.pumpWidget(hifiRouterScreen(router));
      await groupKnockout(tester);
      await tapText(tester, 'Round-robin');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(opened!.groupKnockout, isNull);
    });

    group('pengaturan terakhir (GG-0)', () {
      LastSettings last(
        int groups, {
        bool third = true,
        ScoreFormat format = const ScoreFormat(ScoringMethod.raceTo, 6),
      }) => LastSettings(
        mode: PartnerMode.fixed,
        format: format,
        matchDurationMinutes: 15,
        courts: const [LastCourt(colorIndex: 0, bookingMinutes: 120), LastCourt(colorIndex: 1, bookingMinutes: 120)],
        groupKnockout: GroupKnockout(
          groupCount: groups,
          thirdPlace: third,
          formats: {
            if (groups == 4) KnockoutRound.quarterfinal: const ScoreFormat(ScoringMethod.raceTo, 5),
            KnockoutRound.semifinal: format.forKnockout,
            KnockoutRound.thirdPlace: const ScoreFormat(ScoringMethod.raceTo, 4),
            KnockoutRound.finalRound: const ScoreFormat(ScoringMethod.raceTo, 9),
          },
        ),
      );

      List<Override> withStore(LastSettings s) => [
        tournamentStoreProvider.overrideWithValue(TournamentStore.memory()..saveLastSettings(SportType.padel, s)),
      ];

      testWidgets('4 grup terakhir dipulihkan di 24 pemain', (tester) async {
        await pumpScreen(tester, SportType.padel, 24, overrides: withStore(last(4, third: false)));
        expect(row('4 grup · Race to 6 · 15 menit'), findsOneWidget);
        expect(row('Race to 5–9 · tanpa Juara 3'), findsOneWidget);
      });

      testWidgets('4 grup terakhir lalu 22 pemain (< 12 pasangan) → 2 grup, Perempat final dibuang (19i)', (
        tester,
      ) async {
        await pumpScreen(tester, SportType.padel, 22, overrides: withStore(last(4)));
        expect(row('2 grup · Race to 6 · 15 menit'), findsOneWidget);
        expect(row('Race to 4–9'), findsOneWidget);
      });

      testWidgets('turunan tidak mengubah simpanan; Sparing membuang Grup + Gugur', (tester) async {
        final store = TournamentStore.memory()..saveLastSettings(SportType.padel, last(4));
        await pumpScreen(tester, SportType.padel, 22, overrides: [tournamentStoreProvider.overrideWithValue(store)]);
        expect(store.loadLastSettings(SportType.padel)!.groupKnockout!.groupCount, 4);
        expect(last(4).forSparing().groupKnockout, isNull);
      });

      testWidgets('simpanan Grup + Gugur di bawah 12 pemain (tanpa segmented) → round-robin biasa', (tester) async {
        await pumpScreen(tester, SportType.padel, 8, overrides: withStore(last(2)));
        expect(find.text('Grup + Gugur'), findsNothing);
        expect(find.text('Skor'), findsOneWidget);
      });
    });
  });
}
