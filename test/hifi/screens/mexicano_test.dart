import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/detail_player/detail_player_screen.dart';
import 'package:match_addict/features/home/app_install.dart';
import 'package:match_addict/features/home/home_screen.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/share/result_text_builder.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'mexicano_fixture.dart';
import 'schedule_fixture.dart' show LoadedTournament, fixtureStart;
import 'screen_harness.dart';

/// Golden Jadwal Mexicano 16a–16g (PRD §14, keputusan 39–40) + turunan layar lain (AC-M16, AC-M19). Data = contoh
/// PRD 14B, dibangun `generateMexicanoRound` di `mexicano_fixture.dart`.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final r1Done = mexicanoTournament(1, lastScored: true);
  final r1 = mexicanoTournament(1);
  final r2 = mexicanoTournament(2);
  final r2GitaOut = mexicanoTournament(2, gitaOut: true);
  final r3 = mexicanoTournament(3, gitaOut: true);

  Widget screen(ActiveTournament active, int minutes) => hifiScreen(
    ScheduleMixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => fixtureStart.add(Duration(minutes: minutes))),
    ],
  );

  Future<void> openPlayers(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is MabarIconButton && w.semanticLabel == 'Pemain'));
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpLive(WidgetTester tester, ActiveTournament active, int minutes) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(active, minutes));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ScheduleMixedScreen)));
  }

  testWidgets('16a R1 lengkap, siap buat R2', (tester) async {
    await expectMatchesHifi(tester, screen(r1Done, 16), '16a');
    // Istirahat R1 = Indra, Joko (0 main); subjudul tanpa nama mode, tombol Buat R2 aktif.
    expect(find.text('Padel · Americano 21'), findsOneWidget);
    expect(find.text('Buat R2'), findsOneWidget);
  });

  testWidgets('16b R2 baru, pasangan dari Klasemen, Citra · Hadi istirahat', (tester) async {
    await expectMatchesHifi(tester, screen(r2, 18), '16b');
    expect(find.text('Andi · Gita'), findsOneWidget);
    expect(find.text('Fajar · Eko'), findsOneWidget);
    expect(find.text('Budi · Indra'), findsOneWidget);
    expect(find.text('Dewi · Joko'), findsOneWidget);
    expect(find.text('Batalkan R2'), findsOneWidget);
  });

  testWidgets('16c sheet cara kerja Mexicano', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(r1, 0),
      '16c',
      act: (tester) async {
        await tester.tap(find.bySemanticsLabel('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cara kerja Mexicano'));
      },
    );
    expect(find.text('R1 diundi. Isi semua skor, lalu tekan Buat R2.'), findsOneWidget);
    expect(find.text('Urut Total Point, 4 pemain per court'), findsOneWidget);
    expect(find.text('#1 + #3 lawan #2 + #4'), findsOneWidget);
    expect(find.text('Partner berulang dihindari'), findsOneWidget);
    expect(find.text('Pasangan baru diprioritaskan'), findsNothing);
    // Estimasi = rumus Mixed: 120 ÷ 15 = 8 round, 16 match, ⌊16 × 4 ÷ 10⌋ = 6, 2 court.
    expect(find.text('±6'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('keputusan 43: Cara kerja dibuka di R2 → subjudul tanpa "R1 diundi."', (tester) async {
    await pumpLive(tester, r2, 18);
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cara kerja Mexicano'));
    await tester.pumpAndSettle();
    expect(find.text('Isi semua skor, lalu tekan Buat R3.'), findsOneWidget);
    expect(find.textContaining('R1 diundi'), findsNothing);
  });

  testWidgets('16d menu ⋯ Mexicano', (tester) async {
    await expectMatchesHifi(tester, screen(r2, 18), '16d', act: (tester) => tester.tap(find.bySemanticsLabel('Menu')));
    expect(find.text('Cara kerja Mexicano'), findsOneWidget);
    expect(find.text('Cara kerja Mixed'), findsNothing);
  });

  testWidgets('16e dialog batalkan R2 Mexicano (teks keputusan 40)', (tester) async {
    await expectMatchesHifi(tester, screen(r2, 18), '16e', act: (tester) => tester.tap(find.text('Batalkan R2')));
    expect(
      find.text('Jadwal R2 dihapus. Keluarkan pemain atau ubah skor R1, lalu tekan "Buat R2" lagi.'),
      findsOneWidget,
    );
  });

  // Isian fokus tidak ada di Mexicano, jadi tidak perlu varian iOS saja seperti 08a.
  testWidgets('16f kelola pemain, Gita baru dikeluarkan: Kembalikan ada, tanpa kotak nama dan Tambah', (tester) async {
    await expectMatchesHifi(tester, screen(r2GitaOut, 18), '16f', act: openPlayers);
    expect(find.text('Kembalikan'), findsOneWidget);
    expect(find.text('9 pemain aktif · 1 keluar'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Tambah'), findsNothing);
    expect(find.textContaining('Pemain baru langsung ikut main'), findsNothing);
  });

  testWidgets('16g Gita sudah melewatkan R3: tanpa Kembalikan', (tester) async {
    await expectMatchesHifi(tester, screen(r3, 36), '16g', act: openPlayers);
    expect(find.text('Kembalikan'), findsNothing);
    expect(find.text('Gita'), findsOneWidget);
    expect(find.text('Keluar · skornya tetap dihitung'), findsOneWidget);
    expect(find.text('Tambah'), findsNothing);
  });

  testWidgets('AC-M16 / keputusan 39: Batalkan R3 → Kembalikan muncul lagi, ketukannya mengembalikan Gita', (
    tester,
  ) async {
    final container = await pumpLive(tester, r3, 36);
    await tester.tap(find.text('Batalkan R3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan R3').last);
    await tester.pumpAndSettle();
    expect(container.read(tournamentProvider)!.roundCount, 2);

    await openPlayers(tester);
    expect(find.text('Kembalikan'), findsOneWidget);
    await tester.tap(find.text('Kembalikan'));
    await tester.pumpAndSettle();
    expect(container.read(tournamentProvider)!.withdrawnPlayerIds, isEmpty);
    expect(find.text('10 pemain aktif'), findsOneWidget);
    expect(find.text('Kembalikan'), findsNothing);
  });

  testWidgets('AC-M16 Kelola pemain Mexicano tanpa Tambah di batas 4: hanya catatan minimum', (tester) async {
    final base = mexicanoTournament(2);
    // Sisa 4 pemain aktif; keluar semua kecuali Andi, Budi, Citra, Dewi.
    final four = ActiveTournament(
      tournament: base.tournament,
      restingPlayerIdsByRound: base.restingPlayerIdsByRound,
      withdrawnPlayerIds: {'Eko', 'Fajar', 'Gita', 'Hadi', 'Indra', 'Joko'},
    );
    await pumpLive(tester, four, 18);
    await openPlayers(tester);
    expect(find.text('Butuh minimal 4 pemain'), findsOneWidget);
    expect(find.text('Tambah'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  group('AC-M19', () {
    /// 8 pemain seperti frame Beranda; hanya daftar pemain yang dipangkas, matchnya tidak dipakai di sini.
    ActiveTournament eight({bool finished = false}) {
      final base = mexicanoTournament(2);
      return ActiveTournament(
        tournament: base.tournament.copyWith(
          isFinished: finished,
          config: base.config.copyWith(players: base.config.players.take(8).toList()),
        ),
      );
    }

    Widget home(ActiveTournament last) => hifiScreen(
      const HomeScreen(),
      overrides: [
        tournamentStoreProvider.overrideWithValue(TournamentStore.memory()),
        lastFinishedProvider.overrideWith((ref) => last),
        appInstallModeProvider.overrideWithValue(ValueNotifier(AppInstallMode.none) as ValueListenable<AppInstallMode>),
      ],
    );

    testWidgets('Beranda: turnamen terakhir Mexicano tampil dan bisa dilanjutkan', (tester) async {
      await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
      await tester.pumpWidget(home(eight(finished: true)));
      await tester.pumpAndSettle();
      expect(find.text('Padel · Mexicano · 8 pemain'), findsOneWidget);
      await tester.tap(find.text('Padel · Mexicano · 8 pemain'));
      await tester.pumpAndSettle();
      expect(find.text('Lanjutkan turnamen'), findsWidgets);
    });

    testWidgets('Detail "Padel · Mexicano · Americano 21"', (tester) async {
      await tester.pumpWidget(
        hifiScreen(
          const DetailPlayerScreen(playerId: 'Andi'),
          overrides: [tournamentProvider.overrideWith(() => LoadedTournament(mexicanoTournament(2)))],
        ),
      );
      expect(find.textContaining('Padel · Mexicano · Americano 21'), findsOneWidget);
    });

    test('Klasemen default Total Point; poster "Padel · Mexicano · tanggal", baris "pemain"', () {
      final container = ProviderContainer(
        overrides: [tournamentProvider.overrideWith(() => LoadedTournament(mexicanoTournament(2)))],
      );
      addTearDown(container.dispose);
      expect(container.read(rankingMethodProvider), RankingMethod.totalGames);

      final active = container.read(tournamentProvider)!;
      final entries = container.read(standingEntriesProvider);
      expect(shareRowNoun(active, entries), 'pemain');
      final poster = sharePosterData(
        active: active,
        entries: entries,
        method: container.read(rankingMethodProvider),
        format: ShareFormat.ringkas,
        isFinal: false,
      );
      expect(poster.eyebrow, 'Padel · Mexicano · 11 Nov 2026');
      expect(poster.more, '+5 pemain lainnya');
    });
  });
}
