import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/core/widgets/match_score_row.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_mixed_fixture.dart';
import 'swap_fixture.dart';

/// Toko yang menghitung tulisan, untuk membuktikan Batal tidak menyimpan apa pun (AC-T4).
class _CountingStore extends TournamentStore {
  int saves = 0;
  _CountingStore() : super.memory();

  @override
  Future<void> saveActive(ActiveTournament active) {
    saves++;
    return super.saveActive(active);
  }
}

/// Golden Tukar pemain Mixed, frame 17a–17r (ikon tukar di baris match + sheet), dan perilakunya. Frame sesudah tukar
/// (17e, 17h, 17m, 17q) dibuat dengan mengetuk ikon → chip → Tukar, bukan fixture literal. Jumlah ikon per frame
/// dicek `expectMatchesHifi` lewat `hifiSwapIcons`.
void main() {
  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleMixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> tapIcon(WidgetTester tester, String team) async {
    await tester.tap(find.bySemanticsLabel('Tukar pemain $team'));
    await tester.pumpAndSettle();
  }

  // Chip di sheet; nama yang sama juga tampil di daftar Istirahat Jadwal di belakangnya.
  Finder chip(String name) => find.descendant(of: find.byType(MabarChip), matching: find.text(name));

  Future<void> pick(WidgetTester tester, List<String> names) async {
    for (final n in names) {
      await tester.tap(chip(n));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tukar(WidgetTester tester) async {
    await tester.tap(find.text('Tukar'));
    await tester.pumpAndSettle();
  }

  final a = swap15A(), b = swap15B();
  final p = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Court1], courts: 1);
  final sparing = mixedSparing15b();

  group('golden', () {
    for (final (id, active, now, act) in <(String, ActiveTournament, DateTime, Future<void> Function(WidgetTester)?)>[
      ('17a', a, swapNow, null),
      ('17b', a, swapNow, (t) => tapIcon(t, 'Dewi · Eko')),
      (
        '17c',
        a,
        swapNow,
        (t) async {
          await tapIcon(t, 'Dewi · Eko');
          await pick(t, ['Dewi']);
        },
      ),
      (
        '17d',
        a,
        swapNow,
        (t) async {
          await tapIcon(t, 'Dewi · Eko');
          await pick(t, ['Dewi', 'Budi']);
        },
      ),
      (
        '17e',
        a,
        swapNow,
        (t) async {
          await tapIcon(t, 'Dewi · Eko');
          await pick(t, ['Dewi', 'Budi']);
          await tukar(t);
        },
      ),
      ('17f', b, swapNow, null),
      (
        '17g',
        b,
        swapNow,
        (t) async {
          await tapIcon(t, 'Citra · Indra');
          await pick(t, ['Citra', 'Budi']);
        },
      ),
      (
        '17h',
        b,
        swapNow,
        (t) async {
          await tapIcon(t, 'Citra · Indra');
          await pick(t, ['Citra', 'Budi']);
          await tukar(t);
        },
      ),
      (
        '17i',
        b,
        swapNow,
        (t) async {
          await tapIcon(t, 'Citra · Indra');
          await pick(t, ['Citra', 'Budi']);
          await tukar(t);
          await t.tap(find.text('Batalkan R3'));
        },
      ),
      (
        '17j',
        p,
        fixtureStart.add(const Duration(minutes: 62)),
        (t) async {
          await tapIcon(t, 'Hana T · Joko S');
          await pick(t, ['Hana T', 'Budi S']);
        },
      ),
      ('17k', sparing.active, sparing.now, null),
      (
        '17l',
        sparing.active,
        sparing.now,
        (t) async {
          await tapIcon(t, 'Indra · Kiki');
          await pick(t, ['Kiki', 'Maya']);
        },
      ),
      (
        '17m',
        sparing.active,
        sparing.now,
        (t) async {
          await tapIcon(t, 'Indra · Kiki');
          await pick(t, ['Kiki', 'Maya']);
          await tukar(t);
        },
      ),
      ('17n', swap15C(), mixedSparingAt(5), null),
      ('17o', swap17o(), swapAt(5), null),
      (
        '17p',
        swap17o(),
        swapAt(5),
        (t) async {
          await tapIcon(t, 'Fajar · Hadi');
          await pick(t, ['Hadi', 'Joko']);
        },
      ),
      (
        '17q',
        swap17o(),
        swapAt(5),
        (t) async {
          await tapIcon(t, 'Fajar · Hadi');
          await pick(t, ['Hadi', 'Joko']);
          await tukar(t);
        },
      ),
      ('17r', swap17r(), swapAt(17), null),
    ]) {
      testWidgets(id, (tester) async {
        await expectMatchesHifi(tester, screen(active, now), id, act: act);
      });
    }
  });

  /// Layar dengan toko yang dihitung dan controller sungguhan (auto-save aktif), supaya tukar dan Batal terbukti
  /// lewat jalur yang sama dengan app.
  Future<({_CountingStore store, ProviderContainer container})> pumpLive(
    WidgetTester tester,
    ActiveTournament active, {
    List<String>? visited,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    final store = _CountingStore();
    await store.saveActive(active);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          // Config dari state controller, supaya `startIfNeeded` melihatnya identik dan tidak membuat jadwal baru.
          builder: (_, _) =>
              Consumer(builder: (context, ref, _) => ScheduleMixedScreen(config: ref.read(tournamentProvider)!.config)),
        ),
        GoRoute(
          path: '/score-input',
          builder: (_, state) {
            visited?.add('score:${state.extra}');
            return const Text('Input skor');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      hifiRouterScreen(
        router,
        overrides: [tournamentStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => swapNow)],
      ),
    );
    await tester.pumpAndSettle();
    // Membangun controller menulis keadaan awal sekali (listenSelf); yang dihitung hanya tulisan sesudahnya.
    store.saves = 0;
    return (store: store, container: ProviderScope.containerOf(tester.element(find.byType(ScheduleMixedScreen))));
  }

  MabarButton tukarButton(WidgetTester tester) => tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Tukar'));

  bool selected(WidgetTester tester, String name) =>
      tester.widget<MabarChip>(find.widgetWithText(MabarChip, name)).selected;

  group('perilaku', () {
    testWidgets('Tukar mati sampai dua pilihan; ketuk ulang = lepas', (tester) async {
      await pumpLive(tester, a);
      await tapIcon(tester, 'Dewi · Eko');
      expect(tukarButton(tester).onPressed, isNull);
      await pick(tester, ['Dewi']);
      expect(tukarButton(tester).onPressed, isNull, reason: 'baru satu pilihan');
      await pick(tester, ['Budi']);
      expect(tukarButton(tester).onPressed, isNotNull);
      await pick(tester, ['Dewi']);
      expect(selected(tester, 'Dewi'), isFalse);
      expect(tukarButton(tester).onPressed, isNull);
      // Pilihan lain di grup yang sama menggantikan, bukan menambah.
      await pick(tester, ['Dewi', 'Eko']);
      expect((selected(tester, 'Dewi'), selected(tester, 'Eko')), (false, true));
      await pick(tester, ['Andi']);
      expect((selected(tester, 'Andi'), selected(tester, 'Budi')), (true, false));
      expect(tukarButton(tester).onPressed, isNotNull);
    });

    testWidgets('satu pilihan lintas grup kandidat (17j)', (tester) async {
      tester.view.physicalSize = const Size(390, 1200) * hifiPixelRatio;
      await pumpLive(tester, p);
      await tapIcon(tester, 'Hana T · Joko S');
      expect(find.text('Istirahat · Prioritas main di R6'), findsWidgets);
      // Sekali di sheet, sekali di Jadwal di belakangnya.
      expect(find.text('Istirahat lagi di R6'), findsNWidgets(2));
      await pick(tester, ['Andi P']);
      await pick(tester, ['Budi S']);
      expect((selected(tester, 'Andi P'), selected(tester, 'Budi S')), (false, true));
      await pick(tester, ['Gina R']);
      expect((selected(tester, 'Gina R'), selected(tester, 'Budi S')), (true, false));
    });

    testWidgets('Tukar: sheet tertutup tanpa dialog/toast, satu perubahan tersimpan, tanpa tanda "ditukar"', (
      tester,
    ) async {
      final live = await pumpLive(tester, a);
      await tapIcon(tester, 'Dewi · Eko');
      await pick(tester, ['Dewi', 'Budi']);
      await tukar(tester);

      expect(find.text('Tukar pemain'), findsNothing, reason: 'sheet tertutup');
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('tukar', findRichText: true), findsNothing);
      expect(live.store.saves, 1);
      final m = live.container.read(tournamentProvider)!.matchById('m-r3-2')!;
      expect([...m.pair1.playerIds, ...m.pair2.playerIds], ['Budi', 'Eko', 'Fajar', 'Gita']);
      expect(find.text('Budi · Eko'), findsOneWidget);
      // Court 2 masih Belum dan Andi, Dewi kandidat: ikon tetap ada (17e).
      expect(find.byIcon(MabarIcons.arrowsLeftRight), findsNWidgets(2));
    });

    testWidgets('AC-T4: Batal, scrim, dan back menutup tanpa perubahan atau tulisan', (tester) async {
      final live = await pumpLive(tester, a);
      final before = live.container.read(tournamentProvider);

      Future<void> open() async {
        await tapIcon(tester, 'Dewi · Eko');
        await pick(tester, ['Dewi', 'Budi']);
        expect(find.text('Tukar pemain'), findsOneWidget);
      }

      await open();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Tukar pemain'), findsNothing);

      await open();
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text('Tukar pemain'), findsNothing, reason: 'scrim');

      await open();
      await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Tukar pemain'), findsNothing, reason: 'back');

      expect(identical(live.container.read(tournamentProvider), before), isTrue);
      expect(live.store.saves, 0);
    });

    testWidgets('sheet: judul, subjudul, pratinjau tanpa hitung mundur/ikon/Isi skor', (tester) async {
      await pumpLive(tester, a);
      await tapIcon(tester, 'Dewi · Eko');
      expect(find.text('Tukar pemain'), findsOneWidget);
      expect(find.text('Round 3 · Court 2'), findsOneWidget);
      expect(find.text('Diganti'), findsOneWidget);
      // Pratinjau berubah setelah dua pilihan: Budi di tempat Dewi.
      await pick(tester, ['Dewi', 'Budi']);
      expect(find.text('Budi · Eko'), findsOneWidget);
      final sheetRows = find.descendant(of: find.byType(BottomSheet), matching: find.byType(MatchScoreRow));
      expect(sheetRows, findsOneWidget);
      final row = tester.widget<MatchScoreRow>(sheetRows);
      expect((row.countdown, row.trailing, row.top.onSwap, row.bottom.onSwap), (null, null, null, null));
    });

    testWidgets('sparing: subjudul memuat nama klub, kandidat hanya sesama klub (17l)', (tester) async {
      await pumpLive(tester, sparing.active);
      await tapIcon(tester, 'Indra · Kiki');
      expect(find.text('Round 4 · Court 2 · Matcha Club'), findsOneWidget);
      expect(chip('Joko'), findsOneWidget);
      expect(chip('Maya'), findsOneWidget);
      expect(chip('Citra'), findsNothing);
    });

    testWidgets('ketuk ikon membuka sheet, ketuk bagian lain baris tetap Input Skor', (tester) async {
      final visited = <String>[];
      await pumpLive(tester, a, visited: visited);
      await tapIcon(tester, 'Dewi · Eko');
      expect(visited, isEmpty);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fajar · Gita'));
      await tester.pumpAndSettle();
      expect(visited, ['score:m-r3-2']);
    });

    testWidgets('tanpa ikon: Fixed-nya Jadwal lain, diakhiri, round lewat, tim tanpa kandidat', (tester) async {
      // 17n: tim Garuda tidak punya yang istirahat, hanya tim Matcha berikon.
      await pumpLive(tester, swap15C());
      expect(find.byIcon(MabarIcons.arrowsLeftRight), findsNWidgets(2));
      expect(find.bySemanticsLabel('Tukar pemain Andi · Citra'), findsNothing);
      expect(find.bySemanticsLabel('Tukar pemain Indra · Kiki'), findsOneWidget);
    });
  });
}
