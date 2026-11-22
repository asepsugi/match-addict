import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/score_input/reset_text.dart';
import 'package:match_addict/features/score_input/score_input_screen.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/scoring/score_reset.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Kosongkan skor / Hapus WO (3.9.0, KS-7b): golden 07p–07x, 06aa–06ac dan perilaku layar. Aturan ketersediaan diuji
/// di `test/services/score_reset_test.dart`; di sini hanya yang terlihat dan pop hanya kalau controller `true`.
void main() {
  const race6 = ScoreFormat.standard;
  const americano = ScoreFormat(ScoringMethod.americano, 21);
  const r2 = <MatchSpec>[('Andi', 'Budi', 'Citra', 'Dewant', 6, 4), ('Eko', 'Fajar', 'Gina', 'Hana', null, null)];

  // Mixed 07p/07q: R2 Court 1 (06a/07i) di round terakhir.
  ActiveTournament mixedRound2() => mixedTournament([mixedR1, r2], sport: SportType.tennis, format: race6);
  // Mixed 07t/07u: R3 Court 2 WO (06g), R3 round terakhir.
  ActiveTournament mixedWoRound3() => mixedTournament(
    [mixedR1, mixedR2, mixedR3Running],
    format: americano,
    // Eko M · Budi S (sisi atas) yang tidak main, bukan sisi bawah seperti mixedWo.
    adjust: (m) => m.id == 'r3c2' ? m.asWalkover(loserPairId: m.pair1.id, reason: WoReason.absent) : m,
  );
  // Mixed 07s: R3 Court 1 sudah bukan round terakhir karena R4 dibuat.
  ActiveTournament mixedOldRound() => mixedTournament([
    mixedR1,
    mixedR2,
    const <MatchSpec>[('Andi', 'Dewant', 'Citra', 'Fajar', 13, 8), ('Eko', 'Budi', 'Hana', 'Gina', 11, 10)],
    mixedR4,
  ], format: americano);

  // Fixed 06aa/06ab: R1–R4 lengkap (06a lebih lanjut), R5 belum; R3 Court 2 dikosongkan lewat ScoreReset.
  const fixedScores = {
    'r1c1': (6, 3), 'r1c2': (4, 6), 'r2c1': (6, 4), 'r2c2': (3, 6), 'r3c1': (4, 6), 'r3c2': (6, 2), //
    'r4c1': (6, 2), 'r4c2': (3, 6),
  };
  ActiveTournament fixedR3Cleared() => ScoreReset.apply(fixedTournament(fixedScores), 'r3c2', ResetAction.clearScore)!;
  // Fixed 07v: R2 Court 2 6–4 dijadikan WO (Gina R · Hana T, Cedera), skor lama tersimpan.
  ActiveTournament fixedWoWithScore() {
    final a = fixedTournament({'r1c1': (6, 3), 'r1c2': (4, 6), 'r2c1': (6, 4), 'r2c2': (6, 4)});
    return a.copyWith(
      tournament: a.tournament.copyWith(
        matches: [
          for (final m in a.matches)
            m.id == 'r2c2' ? m.asWalkover(loserPairId: m.pair2.id, reason: WoReason.injury) : m,
        ],
      ),
    );
  }

  Widget inputScreen(ActiveTournament active, String matchId, DateTime now) => hifiScreen(
    ScoreInputScreen(matchId: matchId),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Widget jadwal(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> select(WidgetTester tester, int side) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^Skor ')).at(side - 1));
    await tester.pump();
  }

  Future<void> backspace(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Hapus'));
    await tester.pump();
  }

  /// Kedua kotak dikosongkan seperti host: pilih kotak atas, ⌫, pilih kotak bawah, ⌫ (07p).
  Future<void> emptyBoth(WidgetTester tester) async {
    await select(tester, 1);
    await backspace(tester);
    await select(tester, 2);
    await backspace(tester);
  }

  Future<void> openWoSheet(WidgetTester tester) async {
    await tester.tap(find.text('WO'));
    await tester.pumpAndSettle();
  }

  final at45 = fixtureStart.add(const Duration(minutes: 45));
  final at52 = fixtureStart.add(const Duration(minutes: 52));
  final fixedAt45 = fixedStart.add(const Duration(minutes: 45));
  final fixedAt85 = fixedStart.add(const Duration(minutes: 85));

  group('golden Input Skor', () {
    testWidgets('07p kedua kotak dikosongkan', (tester) async {
      await expectMatchesHifi(tester, inputScreen(mixedRound2(), 'r2c1', at45), '07p', act: emptyBoth);
    });

    testWidgets('07q dialog kosongkan skor', (tester) async {
      await expectMatchesHifi(
        tester,
        inputScreen(mixedRound2(), 'r2c1', at45),
        '07q',
        act: (t) async {
          await emptyBoth(t);
          await t.tap(find.text('Kosongkan skor'));
        },
      );
    });

    testWidgets('07r dialog kosongkan skor setelah diakhiri', (tester) async {
      await expectMatchesHifi(
        tester,
        inputScreen(fixedEnded, 'r5c1', fixedAt45),
        '07r',
        act: (t) async {
          await emptyBoth(t);
          await t.tap(find.text('Kosongkan skor'));
        },
      );
    });

    testWidgets('07s Mixed round lama: Perbarui skor mati', (tester) async {
      await expectMatchesHifi(tester, inputScreen(mixedOldRound(), 'r3c1', at52), '07s', act: emptyBoth);
    });

    testWidgets('07t sheet WO dari match WO: Hapus WO', (tester) async {
      await expectMatchesHifi(tester, inputScreen(mixedWoRound3(), 'r3c2', at52), '07t', act: openWoSheet);
    });

    testWidgets('07u dialog hapus WO tanpa skor lama', (tester) async {
      await expectMatchesHifi(
        tester,
        inputScreen(mixedWoRound3(), 'r3c2', at52),
        '07u',
        act: (t) async {
          await openWoSheet(t);
          await t.tap(find.text('Hapus WO'));
        },
      );
    });

    testWidgets('07v dialog hapus WO dengan skor lama 6–4', (tester) async {
      await expectMatchesHifi(
        tester,
        inputScreen(fixedWoWithScore(), 'r2c2', fixedAt45),
        '07v',
        act: (t) async {
          await openWoSheet(t);
          await t.tap(find.text('Hapus WO'));
        },
      );
    });

    testWidgets('07w gugur: dialog kosongkan SF1', (tester) async {
      final a = gg21f();
      await expectMatchesHifi(
        tester,
        inputScreen(a, a.byCode('SF1').id, at21f),
        '07w',
        act: (t) async {
          await emptyBoth(t);
          await t.tap(find.text('Kosongkan skor'));
        },
      );
    });

    testWidgets('07x gugur: kosongkan SF1 ditolak', (tester) async {
      final a = gg21i();
      await expectMatchesHifi(tester, inputScreen(a, a.byCode('SF1').id, at21f), '07x', act: emptyBoth);
    });
  });

  group('golden Jadwal', () {
    testWidgets('06aa match round lama dikosongkan, round berjalan lagi', (tester) async {
      await expectMatchesHifi(tester, jadwal(fixedR3Cleared(), fixedAt85), '06aa');
    });

    testWidgets('06ab round terkunci lagi, skor tetap terlihat', (tester) async {
      await expectMatchesHifi(tester, jadwal(fixedR3Cleared(), fixedAt85), '06ab', act: (t) => t.tap(find.text('R4')));
    });

    testWidgets('06ac diakhiri, match dikosongkan jadi tidak dimainkan', (tester) async {
      final a = ScoreReset.apply(fixedEnded, 'r5c1', ResetAction.clearScore)!;
      await expectMatchesHifi(tester, jadwal(a, fixedAt45), '06ac');
    });
  });

  group('teks dialog (reset_text)', () {
    ResetAllowed allowed(ActiveTournament a, String id, ResetAction action) {
      final c = ScoreReset.check(a, id, action);
      expect(c, isA<ResetAllowed>());
      return c as ResetAllowed;
    }

    test('judul: nama court, atau kode match untuk gugur', () {
      final mixed = mixedWoRound3();
      expect(resetDialogTitle(mixed, mixed.matchById('r3c1')!, ResetAction.clearScore), 'Kosongkan skor Court 1?');
      expect(resetDialogTitle(mixed, mixed.matchById('r3c2')!, ResetAction.removeWalkover), 'Hapus WO Court 2?');
      final gk = gg21f();
      expect(resetDialogTitle(gk, gk.byCode('SF1'), ResetAction.clearScore), 'Kosongkan skor SF1?');
      expect(resetDialogTitle(gk, gk.byCode('SF2'), ResetAction.removeWalkover), 'Hapus WO SF2?');
      expect(resetConfirmLabel(ResetAction.clearScore), 'Kosongkan');
      expect(resetConfirmLabel(ResetAction.removeWalkover), 'Hapus');
    });

    test('isi: belum dimainkan · tidak dimainkan · skor lama (urut pair1–pair2)', () {
      final mixed = mixedRound2();
      expect(
        resetDialogMessage(mixed, allowed(mixed, 'r2c1', ResetAction.clearScore)),
        'Match kembali belum dimainkan.',
      );
      expect(
        resetDialogMessage(fixedEnded, allowed(fixedEnded, 'r5c1', ResetAction.clearScore)),
        'Match jadi tidak dimainkan.',
      );
      final wo = fixedWoWithScore();
      expect(resetDialogMessage(wo, allowed(wo, 'r2c2', ResetAction.removeWalkover)), 'Match kembali ke skor 6–4.');
    });

    test('preview gugur: susunan baru, sisi tbd dari asalnya (07w)', () {
      final a = gg21f();
      expect(
        resetDialogMessage(a, allowed(a, a.byCode('SF1').id, ResetAction.clearScore)),
        startsWith('Match kembali belum dimainkan.\nFinal: Pemenang SF1 vs '),
      );
      // Final tidak mengisi match lain: tanpa baris susunan.
      final fin = gg21i();
      expect(
        resetDialogMessage(fin, allowed(fin, fin.byCode('F').id, ResetAction.clearScore)),
        'Match kembali belum dimainkan.',
      );
    });
  });

  group('perilaku', () {
    Future<ProviderContainer> pumpRouted(
      WidgetTester tester,
      ActiveTournament active,
      String matchId,
      DateTime now,
    ) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/schedule',
        routes: [
          GoRoute(path: '/schedule', builder: (_, _) => const Text('Jadwal')),
          GoRoute(
            path: '/score-input',
            builder: (_, state) => ScoreInputScreen(matchId: state.extra! as String),
          ),
        ],
      );
      await tester.pumpWidget(
        hifiRouterScreen(
          router,
          overrides: [
            tournamentProvider.overrideWith(() => LoadedTournament(active)),
            clockProvider.overrideWithValue(() => now),
          ],
        ),
      );
      router.push('/score-input', extra: matchId);
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(ScoreInputScreen)));
    }

    // Tombol aksi di dalam dialog (bukan MabarButton), bukan teks judul/tombol lain yang sama.
    Finder dialogButton(String label) =>
        find.descendant(of: find.byType(MabarConfirmDialog), matching: find.text(label));

    MatchGame matchOf(ProviderContainer c, String id) => c.read(tournamentProvider)!.matchById(id)!;

    testWidgets('AC-K1: Batal tetap di papan; Kosongkan → Jadwal, match Belum', (tester) async {
      final c = await pumpRouted(tester, mixedRound2(), 'r2c1', at45);
      expect(find.text('Perbarui skor'), findsOneWidget);
      await emptyBoth(tester);
      expect(find.text('Perbarui skor'), findsNothing);
      await tester.tap(find.text('Kosongkan skor'));
      await tester.pumpAndSettle();
      expect(find.text('Kosongkan skor Court 1?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsNothing);
      expect(matchOf(c, 'r2c1').status, MatchStatus.done);

      await tester.tap(find.text('Kosongkan skor'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Kosongkan'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final m = matchOf(c, 'r2c1');
      expect(m.status, MatchStatus.pending);
      expect(m.sets, isEmpty);
    });

    testWidgets('satu kotak kosong saja: Perbarui skor mati, tanpa Kosongkan skor', (tester) async {
      await pumpRouted(tester, mixedRound2(), 'r2c1', at45);
      await select(tester, 1);
      await backspace(tester);
      expect(find.text('Kosongkan skor'), findsNothing);
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Perbarui skor')).onPressed, isNull);
    });

    testWidgets('07s: round lama Mixed tanpa Kosongkan skor', (tester) async {
      await pumpRouted(tester, mixedOldRound(), 'r3c1', at52);
      await emptyBoth(tester);
      expect(find.text('Kosongkan skor'), findsNothing);
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Perbarui skor')).onPressed, isNull);
    });

    testWidgets('AC-K3: match WO tanpa Kosongkan skor; sheet match selesai tanpa Hapus WO', (tester) async {
      await pumpRouted(tester, mixedWoRound3(), 'r3c2', at52);
      await select(tester, 1);
      await backspace(tester);
      expect(find.text('Kosongkan skor'), findsNothing);
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Perbarui skor')).onPressed, isNull);

      final done = await pumpRouted(tester, mixedWoRound3(), 'r3c1', at52);
      expect(done, isNotNull);
      await openWoSheet(tester);
      expect(find.text('Hapus WO'), findsNothing);
    });

    testWidgets('AC-K2: Hapus WO → dialog → Jadwal, match Belum; Batal tetap di sheet', (tester) async {
      final c = await pumpRouted(tester, mixedWoRound3(), 'r3c2', at52);
      await openWoSheet(tester);
      await tester.tap(find.text('Hapus WO'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus WO Court 2?'), findsOneWidget);
      expect(find.text('Match kembali belum dimainkan.'), findsOneWidget);
      await tester.tap(find.text('Batal').last);
      await tester.pumpAndSettle();
      expect(find.text('Walkover'), findsOneWidget);
      expect(matchOf(c, 'r3c2').status, MatchStatus.wo);

      await tester.tap(find.text('Hapus WO'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final m = matchOf(c, 'r3c2');
      expect(m.status, MatchStatus.pending);
      expect(m.woLoserPairId, isNull);
      expect(m.woReason, isNull);
    });

    testWidgets('07x: gugur ditolak, tombol mati dengan pesan 21l, tidak pernah pop', (tester) async {
      final a = gg21i();
      final c = await pumpRouted(tester, a, a.byCode('SF1').id, at21f);
      await emptyBoth(tester);
      expect(find.text('Final dan Juara 3 sudah ada skor · pemenang SF1 tetap Andi & Budi'), findsOneWidget);
      final button = tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Kosongkan skor'));
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Kosongkan skor'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsNothing);
      expect(c.read(tournamentProvider)!.matchById(a.byCode('SF1').id)!.status, MatchStatus.done);
    });

    testWidgets('07w: kosongkan SF1 → match Belum, sisi Final kembali ke asalnya', (tester) async {
      final a = gg21f();
      final c = await pumpRouted(tester, a, a.byCode('SF1').id, at21f);
      await emptyBoth(tester);
      await tester.tap(find.text('Kosongkan skor'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Kosongkan'));
      await tester.pumpAndSettle();
      expect(find.text('Jadwal'), findsOneWidget);
      final now = c.read(tournamentProvider)!;
      expect(now.byCode('SF1').status, MatchStatus.pending);
      expect(KnockoutBracket.sourcesOf(now.config, now.byCode('F')), isNotNull);
      expect(now.byCode('F').pair1.isTbd || now.byCode('F').pair2.isTbd, isTrue);
    });
  });

  group('Jadwal Fixed', () {
    testWidgets('17A-ii: catatan kunci menyebut R3 untuk R4 dan R5 (06ab)', (tester) async {
      await tester.pumpWidget(jadwal(fixedR3Cleared(), fixedAt85));
      await tester.pumpAndSettle();
      await tester.tap(find.text('R4'));
      await tester.pumpAndSettle();
      expect(find.text('Terbuka setelah semua skor R3 terisi'), findsOneWidget);
      await tester.tap(find.text('R5'));
      await tester.pumpAndSettle();
      expect(find.text('Terbuka setelah semua skor R3 terisi'), findsOneWidget);
    });

    testWidgets('AC-B1: Buat bagan · tunggu N match mati, N turun saat diisi (20b: 7 → 6)', (tester) async {
      final a = gg20b();
      expect(a.pendingGroupMatches, 7);
      await tester.pumpWidget(jadwal(a, at20b));
      await tester.pumpAndSettle();
      expect(find.text('· tunggu 7 match'), findsOneWidget);
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Buat bagan')).onPressed, isNull);
      expect(find.text('Tambah round'), findsNothing);
    });
  });
}
