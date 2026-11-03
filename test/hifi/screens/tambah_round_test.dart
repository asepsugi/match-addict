import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/pair_edit/pair_edit_screen.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_draft.dart';

import '../hifi_golden.dart';
import 'fixed_extra_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Round tambahan Fixed: Jadwal 06v, sheet Tambah round 06w–06z, Atur pasangan 04f–04h. Fixture TBNE36 di
/// `fixed_extra_fixture.dart`; 06y memakai turnamen 06a–06e.
void main() {
  final roundRobin = extraRoundRobin();

  Widget screen(ActiveTournament active, DateTime now, {List<Override> extra = const []}) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
      ...extra,
    ],
  );
  final afterR14 = extraStart.add(const Duration(minutes: 210));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Tambah round'));
    await tester.pumpAndSettle();
  }

  /// 04f: Budi pulang (Ubah di pasangan nomor 1), Rizky H masuk, Andi P dipilih.
  Future<void> splitAndAdd(WidgetTester tester) async {
    await tester.tap(find.text('Ubah').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Rizky H');
    await tester.tap(find.text('Tambah'));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Andi P'));
  }

  /// Test perilaku: ukuran layar sama dengan frame, supaya sheet dan tombolnya ada di tempat yang sama.
  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('06v semua match terisi', (tester) async {
    await expectMatchesHifi(tester, screen(roundRobin, afterR14), '06v');
    expect(find.text('00:30'), findsNWidgets(2));
  });

  testWidgets('06w sheet tambah round, sisa pas', (tester) async {
    await expectMatchesHifi(tester, screen(roundRobin, afterR14), '06w', act: openSheet);
    expect(find.text('2 round (R15–R16) · 2 court'), findsOneWidget);
  });

  testWidgets('06x jam ditambah di satu court', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(roundRobin, afterR14),
      '06x',
      act: (tester) async {
        await openSheet(tester);
        await tester.tap(find.bySemanticsLabel('Tambah').first);
      },
    );
    expect(find.text('6 round (R15–R20) · 2 court, berkurang mulai R17'), findsOneWidget);
  });

  testWidgets('06y pasangan ganjil, lewat booking', (tester) async {
    final complete = fixedTournament({
      for (var r = 1; r <= 4; r++) ...{'r${r}c1': (6, 2), 'r${r}c2': (3, 6)},
      'r5c1': (6, 5),
      'r5c2': (4, 6),
    });
    await expectMatchesHifi(
      tester,
      screen(complete, fixedStart.add(const Duration(minutes: 100))),
      '06y',
      act: openSheet,
    );
    expect(find.text('3 round (R6–R8) · 2 court · lewat booking 00:40'), findsOneWidget);
  });

  testWidgets('06z waktu habis', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(roundRobin, extraStart.add(const Duration(minutes: 244))),
      '06z',
      act: openSheet,
    );
    final button = find.ancestor(of: find.text('Buat round'), matching: find.byType(GestureDetector)).first;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Buat round'), findsOneWidget, reason: 'tombol mati, sheet tetap terbuka');
  });

  Widget editor() => hifiScreen(
    PairEditScreen(initial: PairDraft.of(roundRobin.config), sport: SportType.padel, firstRound: 15),
  );

  testWidgets('04f atur pasangan: pisah, pemain baru, satu terpilih', (tester) async {
    await expectMatchesHifi(tester, editor(), '04f', act: splitAndAdd);
  });

  testWidgets('04g atur pasangan siap disimpan', (tester) async {
    await expectMatchesHifi(
      tester,
      editor(),
      '04g',
      act: (tester) async {
        await splitAndAdd(tester);
        await tester.pump();
        await tester.tap(find.text('Rizky H'));
      },
    );
  });

  testWidgets('04h sheet setelah pasangan diatur', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(roundRobin, afterR14),
      '04h',
      act: (tester) async {
        await openSheet(tester);
        await tester.tap(find.text('Pasangan'));
        await tester.pumpAndSettle();
        await splitAndAdd(tester);
        await tester.pump();
        await tester.tap(find.text('Rizky H'));
        await tester.pump();
        await tester.tap(find.text('Simpan pasangan'));
      },
    );
  });

  testWidgets('Buat R15–R16: jadwal pindah ke R15 dengan pasangan baru; tombol hilang sampai terisi lagi', (tester) async {
    await pump(tester, screen(roundRobin, afterR14));
    await openSheet(tester);
    await tester.tap(find.text('Pasangan'));
    await tester.pumpAndSettle();
    await splitAndAdd(tester);
    await tester.pump();
    await tester.tap(find.text('Rizky H'));
    await tester.pump();
    await tester.tap(find.text('Simpan pasangan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat R15–R16'));
    await tester.pumpAndSettle();

    expect(find.text('Round 15'), findsOneWidget);
    expect(find.text('Andi P · Rizky H'), findsOneWidget);
    expect(find.text('Tambah round'), findsNothing);
    expect(find.text('Isi skor'), findsNWidgets(2));
  });

  testWidgets('Atur pasangan: Urungkan, minimal 2 pasangan, nama kembar ditolak', (tester) async {
    await pump(tester, editor());
    await tester.enterText(find.byType(TextField), 'budi s');
    await tester.tap(find.text('Tambah'));
    await tester.pump();
    expect(find.text('Budi S sudah ada di daftar'), findsOneWidget);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Ubah').first);
      await tester.pump();
    }
    expect(find.text('· minimal 2 pasangan'), findsOneWidget);
    await tester.tap(find.text('Urungkan'));
    await tester.pump();
    expect(find.text('2 pasangan'), findsOneWidget);
    expect(find.text('· 12 tidak main'), findsOneWidget);
  });

  testWidgets('Di router app: Atur pasangan di atas sheet, kembali (←) ke sheet tanpa perubahan', (tester) async {
    final router = GoRouter(
      initialLocation: '/schedule',
      routes: [GoRoute(path: '/schedule', builder: (_, _) => ScheduleFixedScreen(config: roundRobin.config))],
    );
    await pump(
      tester,
      hifiRouterScreen(
        router,
        overrides: [
          tournamentProvider.overrideWith(() => LoadedTournament(roundRobin)),
          clockProvider.overrideWithValue(() => afterR14),
        ],
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text('Pasangan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah').first);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('8 pasangan · sama dengan sebelumnya'), findsOneWidget);
    await tester.tap(find.text('Buat R15–R16'));
    await tester.pumpAndSettle();
    expect(find.text('Round 15'), findsOneWidget);
  });

  testWidgets('Penonton live tidak melihat Tambah round', (tester) async {
    await pump(tester, screen(roundRobin, afterR14, extra: [liveCodeProvider.overrideWithValue('K7Q2MX')]));
    expect(find.text('Tambah round'), findsNothing);
  });
}
