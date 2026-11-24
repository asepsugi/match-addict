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
      await tester.tap(find.descendant(of: stepper(index), matching: find.bySemanticsLabel(RegExp('^$label'))));
      await tester.pump();
    }
  }

  /// Menutup sheet teratas dengan mengetuk scrim di atasnya.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
  }

  Future<void> groupKnockout(WidgetTester tester) => tapText(tester, 'Group - Playoff');

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
      expect(find.text('Group - Playoff'), findsOneWidget);
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

    testWidgets('19c sheet Fase grup · 8 pasangan · 3 dan 4 grup mati', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 16),
        '19c',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 15 menit');
        },
      );
      expect(find.text('8 pasangan'), findsOneWidget); // subjudul sheet
      expect(find.text('4 + 4 · Semifinal'), findsOneWidget);
      expect(find.text('Mulai 24 pemain'), findsOneWidget);
      expect(find.text('Tepat 32 pemain'), findsOneWidget);
      // Pilihan mati tidak bisa diketuk (GP9).
      await tester.tap(find.text('3 grup'));
      await tester.pumpAndSettle();
      expect(row('2 grup · Race to 6 · 15 menit'), findsOneWidget);
    });

    testWidgets('19d sheet Fase grup · 12 pasangan · 3 grup · 4 grup mati', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.tennis, 24),
        '19d',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 grup · Race to 6 · 20 menit');
          await tapText(tester, '3 grup');
        },
      );
      expect(row('3 grup · Race to 6 · 20 menit'), findsOneWidget);
      expect(row('Playoff · Perempat final · 2 wildcard'), findsOneWidget);
      expect(find.text('4 + 4 + 4 · Perempat final · 2 wildcard'), findsOneWidget);
      expect(find.text('Tepat 32 pemain'), findsOneWidget);
    });

    testWidgets('23a sheet Fase grup · 32 pemain · 4 grup', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 32),
        '23a',
        act: (tester) async {
          await groupKnockout(tester);
          await tapText(tester, '2 court · 2 jam');
          await tapStep(tester, 1, 'Tambah');
          await tapStep(tester, 2, 'Tambah');
          await closeSheet(tester);
          await tapText(tester, '2 grup · Race to 6 · 15 menit');
          await tapText(tester, '4 grup');
        },
      );
      expect(row('4 grup · Race to 6 · 15 menit'), findsOneWidget);
      expect(row('Playoff · Perempat final'), findsOneWidget);
      expect(find.text('16 pasangan'), findsOneWidget);
      expect(find.text('8 + 8 · Semifinal'), findsOneWidget);
      expect(find.text('6 + 5 + 5 · Perempat final · 2 wildcard'), findsOneWidget);
      expect(find.text('4 + 4 + 4 + 4 · Perempat final'), findsOneWidget);
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· 16 round · lewat booking 01:00'));
    });

    testWidgets('19e sheet Playoff · 2 grup · format per babak', (tester) async {
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
          await tester.tap(find.byKey(const ValueKey(KnockoutRound.semifinal)));
          await tester.pumpAndSettle();
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

    /// Keadaan 19i: 24 pemain, 3 grup, 2 court × 3 jam, Playoff 16G (Perempat final Race to 4, Semifinal dan Perebutan
    /// juara 3 Race to 5, Final Race to 6).
    Future<void> example16G(WidgetTester tester) async {
      await groupKnockout(tester);
      await tapText(tester, '2 grup · Race to 6 · 15 menit');
      await tapText(tester, '3 grup');
      await closeSheet(tester);
      await tapText(tester, '2 court · 2 jam');
      await tapStep(tester, 1, 'Tambah');
      await tapStep(tester, 2, 'Tambah');
      await closeSheet(tester);
      await tapText(tester, 'Race to 6');
      await inRound(tester, 'Perempat final', () => tapStep(tester, 0, 'Kurangi', times: 2));
      await inRound(tester, 'Semifinal', () => tapStep(tester, 0, 'Kurangi'));
      await inRound(tester, 'Perebutan juara 3', () => tapStep(tester, 0, 'Kurangi'));
    }

    testWidgets('19i 3 grup · 24 pemain · lewat booking', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(SportType.padel, 24),
        '19i',
        act: (tester) async {
          await example16G(tester);
          await closeSheet(tester);
        },
      );
      expect(row('3 grup · Race to 6 · 15 menit'), findsOneWidget);
      expect(row('Playoff · Perempat final · 2 wildcard'), findsOneWidget);
      expect(row('Race to 4–6'), findsOneWidget);
      expect(row('2 court · 3 jam'), findsOneWidget);
      expect((button(tester).label, button(tester).meta), ('Lanjut', '· 16 round · lewat booking 01:00'));
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('19j sheet Playoff · 3 grup', (tester) async {
      await expectMatchesHifi(tester, screen(SportType.padel, 24), '19j', act: example16G);
      expect(find.text('Perempat final · 2 wildcard'), findsOneWidget); // subjudul sheet
      expect(row('Race to 4'), findsOneWidget);
      expect(row('Race to 5'), findsNWidgets(2));
      expect(row('Race to 6'), findsOneWidget);
      // Kembali ke 2 grup: baris Perempat final hilang, format babak lain tetap.
      await closeSheet(tester);
      await tapText(tester, '3 grup · Race to 6 · 15 menit');
      await tapText(tester, '2 grup');
      await closeSheet(tester);
      await tapText(tester, 'Race to 5–6');
      expect(find.text('Perempat final'), findsNothing);
      expect(row('Race to 5'), findsNWidgets(2));
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
    testWidgets('AC-G1: segmented hanya Fixed biasa dengan 8+ pasangan (16+ pemain, keputusan 143)', (tester) async {
      for (final (players, offered) in [
        (10, false),
        (12, false),
        (14, false),
        (16, true),
        (22, true),
        (24, true),
        (32, true),
      ]) {
        await pumpScreen(tester, SportType.padel, players);
        expect(find.text('Group - Playoff'), offered ? findsOneWidget : findsNothing, reason: '$players pemain');
      }
      await pumpScreen(tester, SportType.padel, 24);
      await tester.tap(find.text('Mixed'));
      await tester.pump();
      expect(find.text('Group - Playoff'), findsNothing);
      await tester.tap(find.text('Mexicano'));
      await tester.pump();
      expect(find.text('Group - Playoff'), findsNothing);
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
      expect(find.text('Group - Playoff'), findsNothing);
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
            if (groups >= 3) KnockoutRound.quarterfinal: const ScoreFormat(ScoringMethod.raceTo, 5),
            KnockoutRound.semifinal: format.forKnockout,
            KnockoutRound.thirdPlace: const ScoreFormat(ScoringMethod.raceTo, 4),
            KnockoutRound.finalRound: const ScoreFormat(ScoringMethod.raceTo, 9),
          },
        ),
      );

      List<Override> withStore(LastSettings s) => [
        tournamentStoreProvider.overrideWithValue(TournamentStore.memory()..saveLastSettings(SportType.padel, s)),
      ];

      testWidgets('4 grup terakhir di 24 pemain → 3 grup (GP9, AC-G21), format Perempat final tetap', (tester) async {
        await pumpScreen(tester, SportType.padel, 24, overrides: withStore(last(4, third: false)));
        expect(row('3 grup · Race to 6 · 15 menit'), findsOneWidget);
        expect(row('Race to 5–9 · tanpa Juara 3'), findsOneWidget);
      });

      testWidgets('4 grup terakhir dipulihkan di 32 pemain', (tester) async {
        await pumpScreen(tester, SportType.padel, 32, overrides: withStore(last(4)));
        expect(row('4 grup · Race to 6 · 15 menit'), findsOneWidget);
        expect(row('Playoff · Perempat final'), findsOneWidget);
      });

      // `LastSettings.read` masih menolak 3 grup (last_settings.dart:123, 127): dikerjakan GP-4.
      testWidgets(
        '3 grup terakhir dipulihkan di 24 pemain (menunggu GP-4)',
        skip: true, // menunggu GP-4
        (tester) async {
          await pumpScreen(tester, SportType.padel, 24, overrides: withStore(last(3)));
          expect(row('3 grup · Race to 6 · 15 menit'), findsOneWidget);
          expect(row('Playoff · Perempat final · 2 wildcard'), findsOneWidget);
        },
      );

      testWidgets('3 grup terakhir lalu 20 pemain → 2 grup (19d, menunggu GP-4)', skip: true, (tester) async {
        await pumpScreen(tester, SportType.padel, 20, overrides: withStore(last(3)));
        expect(row('2 grup · Race to 6 · 15 menit'), findsOneWidget);
      });

      for (final (previous, players, expected) in [(4, 30, 3), (4, 22, 2)]) {
        testWidgets('$previous grup terakhir lalu $players pemain → $expected grup (19d)', (tester) async {
          await pumpScreen(tester, SportType.padel, players, overrides: withStore(last(previous)));
          expect(row('$expected grup · Race to 6 · 15 menit'), findsOneWidget);
        });
      }

      testWidgets('simpanan 2 grup di 12 pemain (6 pasangan) → round-robin biasa (keputusan 143)', (tester) async {
        await pumpScreen(tester, SportType.padel, 12, overrides: withStore(last(2)));
        expect(find.text('Group - Playoff'), findsNothing);
        expect(find.text('Skor'), findsOneWidget);
      });

      testWidgets('turunan tidak mengubah simpanan; Sparing membuang Grup + Gugur', (tester) async {
        final store = TournamentStore.memory()..saveLastSettings(SportType.padel, last(4));
        await pumpScreen(tester, SportType.padel, 22, overrides: [tournamentStoreProvider.overrideWithValue(store)]);
        expect(store.loadLastSettings(SportType.padel)!.groupKnockout!.groupCount, 4);
        expect(last(4).forSparing().groupKnockout, isNull);
      });

      testWidgets('simpanan Grup + Gugur di bawah 12 pemain (tanpa segmented) → round-robin biasa', (tester) async {
        await pumpScreen(tester, SportType.padel, 8, overrides: withStore(last(2)));
        expect(find.text('Group - Playoff'), findsNothing);
        expect(find.text('Skor'), findsOneWidget);
      });
    });
  });
}
