import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart' show LoadedTournament;
import 'screen_harness.dart';
import 'sparing_mixed_fixture.dart';

/// Kelola pemain Mixed sparing (15l, 15m; SP-18d): klub wajib dipilih (AC-S12), daftar per klub, Keluarkan lewat
/// `canWithdraw`.
void main() {
  Widget screen(MixedSparingState s) => hifiScreen(
    ScheduleMixedScreen(config: s.active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(s.active)),
      clockProvider.overrideWithValue(() => s.now),
    ],
  );

  Future<ProviderContainer> pumpLive(WidgetTester tester, MixedSparingState s) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(s));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ScheduleMixedScreen)));
  }

  Future<void> openPlayers(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is MabarIconButton && w.semanticLabel == 'Pemain'));
    await tester.pumpAndSettle();
  }

  MabarButton addButton(WidgetTester tester) => tester.widget(find.widgetWithText(MabarButton, 'Tambah'));

  // Isian fokus: di Android test menggambar pegangan seleksi berbentuk tetesan; di iOS tidak.
  testWidgets('15l tambah Oki ke Matcha Club', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    await expectMatchesHifi(
      tester,
      screen(mixedSparing13m()),
      '15l',
      act: (tester) async {
        await openPlayers(tester);
        await tester.enterText(find.byType(TextField), 'Oki');
        await tester.tap(find.widgetWithText(MabarChip, 'Matcha Club'));
      },
    );
  });

  // Frame 15m menampilkan PB Garuda 4 baris saja ("daftar digulir", catatan frame), padahal 8 aktif: layar menggambar
  // 8 baris, jadi hanya wilayah di atas baris ke-5 (sampai y 576 pt) yang bisa dibandingkan piksel per piksel.
  testWidgets('15m Matcha tinggal 2 aktif: Keluarkan mati di sana, Garuda tetap bisa', (tester) async {
    final diff = await compareWithHifi(
      tester,
      screen(mixedSparing15m()),
      '15m',
      region: const Rect.fromLTWH(0, 0, 390, 576),
      act: openPlayers,
    );
    expect(diff.ratio, lessThanOrEqualTo(0.02), reason: '$diff');
    expect(find.text('Matcha Club · 2 aktif · 1 keluar'), findsOneWidget);
    expect(find.text('Butuh minimal 2 pemain per klub'), findsOneWidget);
    expect(find.text('Butuh minimal 4 pemain'), findsNothing);
  });

  testWidgets('AC-S12 Tambah mati tanpa nama/klub; Oki masuk Matcha Club dan simpanan terbaca', (tester) async {
    final container = await pumpLive(tester, mixedSparing13m());
    await openPlayers(tester);
    expect(find.text('PB Garuda · 8 aktif'), findsOneWidget);
    expect(find.text('Matcha Club · 6 aktif'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Oki');
    await tester.pump();
    expect(addButton(tester).onPressed, isNull, reason: 'klub belum dipilih');
    await tester.tap(find.widgetWithText(MabarChip, 'Matcha Club'));
    await tester.pump();
    expect(addButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(MabarButton, 'Tambah'));
    await tester.pumpAndSettle();
    final active = container.read(tournamentProvider)!;
    final oki = active.config.players.firstWhere((p) => p.name == 'Oki');
    expect(oki.clubId, matcha.id);
    expect(find.text('Matcha Club · 7 aktif'), findsOneWidget);
    expect(TournamentCodec.decode(TournamentCodec.encode(active)), isNotNull);
  });

  testWidgets('nama dicek terhadap kedua klub', (tester) async {
    await pumpLive(tester, mixedSparing13m());
    await openPlayers(tester);
    await tester.enterText(find.byType(TextField), 'Andi');
    await tester.tap(find.widgetWithText(MabarChip, 'Matcha Club'));
    await tester.pump();
    await tester.tap(find.widgetWithText(MabarButton, 'Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Andi sudah ada di PB Garuda'), findsOneWidget);
  });

  testWidgets('AC-S12 Keluarkan: mati di Matcha, Garuda bisa; Kembalikan Kiki ke Matcha', (tester) async {
    final container = await pumpLive(tester, mixedSparing15m());
    await openPlayers(tester);
    final actions = tester.widgetList<MabarRowAction>(find.widgetWithText(MabarRowAction, 'Keluarkan')).toList();
    // 8 Garuda + Indra + Joko; dua terakhir mati.
    expect(actions, hasLength(10));
    expect(actions.take(8).every((a) => a.onPressed != null), isTrue);
    expect(actions.skip(8).every((a) => a.onPressed == null), isTrue);

    await tester.ensureVisible(find.widgetWithText(MabarRowAction, 'Kembalikan'));
    await tester.tap(find.widgetWithText(MabarRowAction, 'Kembalikan'));
    await tester.pumpAndSettle();
    final active = container.read(tournamentProvider)!;
    expect(active.withdrawnPlayerIds, isEmpty);
    expect(active.activePlayersOfClub(matcha.id).map((p) => p.name), contains('Kiki'));
    expect(find.text('Matcha Club · 3 aktif'), findsOneWidget);
  });
}
