import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden sheet Kelola pemain (08a, 08b) dan Lanjutkan turnamen (08c, 08d) di atas Jadwal Mixed.
void main() {
  // 08a: keadaan 06f, daftar pemain awal dengan Kiki A di urutan ke-5 (sudah keluar).
  final kelola = mixedTournament(
    [mixedR1, mixedR2, mixedR3Running],
    roster: const ['Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Kiki A', 'Eko M', 'Fajar K', 'Gina R', 'Hana T', 'Indra W', 'Joko S'],
    withdrawn: {'Kiki'},
  );
  // 08b: Tennis Race to 6, 1 jam × 20 menit; Eko keluar setelah R1, tinggal 4 pemain aktif.
  final minimum = mixedTournament(
    [
      const [('Andi', 'Budi', 'Citra', 'Eko', 6, 4)],
      const [('Andi', 'Citra', 'Budi', 'Dewant', null, null)],
    ],
    players: 5,
    sport: SportType.tennis,
    format: ScoreFormat.standard,
    durationMinutes: 20,
    bookingHours: 1,
    courtCount: 1,
    withdrawn: {'Eko'},
  );
  // 08c/08d: keadaan 06l (R8, waktu habis), court kedua bernama "Court VIP".
  final timeUp = mixedTournament(mixedTimeUpRounds, courtNames: const ['Court 1', 'Court VIP']);

  Widget screen(ActiveTournament active, Duration elapsed) => hifiScreen(
    ScheduleMixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => fixtureStart.add(elapsed)),
    ],
  );

  Future<void> openPlayers(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is MabarIconButton && w.semanticLabel == 'Pemain'));
    await tester.pumpAndSettle();
  }

  // Isian fokus: di Android test menggambar pegangan seleksi berbentuk tetesan; di iOS tidak.
  testWidgets('08a kelola pemain', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    await expectMatchesHifi(
      tester,
      screen(kelola, const Duration(minutes: 40)),
      '08a',
      act: (tester) async {
        await openPlayers(tester);
        await tester.enterText(find.byType(TextField), 'Gilang S');
      },
    );
  });

  testWidgets('08b nama sudah ada, batas minimum', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    await expectMatchesHifi(
      tester,
      screen(minimum, const Duration(minutes: 25)),
      '08b',
      act: (tester) async {
        await openPlayers(tester);
        await tester.enterText(find.byType(TextField), 'andi p');
        await tester.tap(find.text('Tambah'));
      },
    );
  });

  testWidgets('08c lanjutkan, Court 1 + 1 jam', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(timeUp, const Duration(hours: 2, minutes: 4)),
      '08c',
      act: (tester) async {
        await tester.tap(find.text('Tambah jam'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Tambah').first);
      },
    );
  });

  testWidgets('08d lanjutkan, belum ada tambahan', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(timeUp, const Duration(hours: 2, minutes: 4)),
      '08d',
      act: (tester) => tester.tap(find.text('Tambah jam')),
    );
  });

  Future<ProviderContainerHolder> pumpLive(
    WidgetTester tester,
    ActiveTournament active, {
    Duration elapsed = Duration.zero,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(active, elapsed));
    await tester.pumpAndSettle();
    return ProviderContainerHolder(tester);
  }

  testWidgets('Kelola: tambah lewat Enter, keluarkan langsung, kembalikan; pesan error', (tester) async {
    final holder = await pumpLive(tester, kelola);
    await openPlayers(tester);
    await tester.enterText(find.byType(TextField), '3. gilang s');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(MabarSheet), matching: find.text('gilang s')), findsOneWidget,
        reason: 'nomor dibuang seperti di layar Pemain');
    expect(find.text('gilang s'), findsNWidgets(2), reason: 'langsung masuk Istirahat round terakhir di belakang sheet');
    expect(find.text('11 pemain aktif · 1 keluar'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'KIKI a');
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Kiki A sudah ada — pakai "Kembalikan" di bawah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Nama tidak boleh kosong'), findsOneWidget);

    await tester.tap(find.widgetWithText(MabarRowAction, 'Keluarkan').first);
    await tester.pumpAndSettle();
    expect(find.text('10 pemain aktif · 2 keluar'), findsOneWidget);
    expect(holder.active.withdrawnPlayerIds, hasLength(2));
    await tester.tap(find.widgetWithText(MabarRowAction, 'Kembalikan').first);
    await tester.pumpAndSettle();
    expect(find.text('11 pemain aktif · 1 keluar'), findsOneWidget);
  });

  testWidgets('Kelola: aktif 4 → semua Keluarkan mati', (tester) async {
    await pumpLive(tester, minimum);
    await openPlayers(tester);
    final actions = tester.widgetList<MabarRowAction>(find.widgetWithText(MabarRowAction, 'Keluarkan'));
    expect(actions, hasLength(4));
    expect(actions.every((a) => a.onPressed == null), isTrue);
  });

  testWidgets('Lanjutkan: diakhiri lebih awal → estimasi langsung > 0; Lanjutkan mengaktifkan lagi', (tester) async {
    final ended = mixedTournament(
      [mixedR1, mixedR2, const [('Andi', 'Dewant', 'Citra', 'Fajar', 13, 8), ('Eko', 'Budi', 'Hana', 'Gina', null, null)]],
      finished: true,
    );
    // Diakhiri di menit ke-45 dari booking 2 jam.
    final holder = await pumpLive(tester, ended, elapsed: const Duration(minutes: 45));
    await tester.tap(find.text('Lanjutkan turnamen'));
    await tester.pumpAndSettle();
    expect(find.text('Sisa 01:15'), findsNWidgets(2));
    expect(find.text('10 match lagi'), findsNothing);
    expect(find.text('match lagi'), findsOneWidget);
    expect(find.text('5 round (R4–R8) · 2 court'), findsOneWidget);
    expect(find.text('1 match yang belum dimainkan bisa diisi lagi'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(holder.active.tournament.isFinished, isFalse);
    expect(holder.active.matches.where((m) => m.status == MatchStatus.cancelled), isEmpty);
  });
}

/// Membaca turnamen terkini dari ProviderScope layar.
class ProviderContainerHolder {
  final WidgetTester tester;
  ProviderContainerHolder(this.tester);

  ActiveTournament get active {
    final element = tester.element(find.byType(ScheduleMixedScreen));
    return ProviderScope.containerOf(element).read(tournamentProvider)!;
  }
}
