import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_group.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';
import 'package:match_addict/features/schedule/group_knockout/create_bracket_flow.dart';
import 'package:match_addict/features/schedule/group_knockout/gk_labels.dart';
import 'package:match_addict/features/schedule/group_knockout/playoff_format_sheet.dart';
import 'package:match_addict/features/schedule/group_knockout/seeding_sheet.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/schedule/widgets/round_tabs.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';

import '../hifi_golden.dart';
import 'group_playoff_fixture.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden Jadwal Grup + Gugur (GG-7): fase grup 20a–20q, round gugur 21b–21v. Tab Bagan 21a/21d/… = GG-9. Fixture
/// bersama `grup_gugur_fixture.dart`; jam frame lewat konstanta `at…` di sana.
void main() {
  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  ActiveTournament stateOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ScheduleFixedScreen))).read(tournamentProvider)!;

  Finder tab(String label) => find.descendant(of: find.byType(RoundTabs), matching: find.text(label));
  Finder option(String name) => find.descendant(of: find.byType(MabarOption), matching: find.text(name));

  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(BuildBracketDialog), matching: find.text('Buat bagan')));
    await tester.pumpAndSettle();
  }

  /// Menu ⋯ → Akhiri turnamen (20r, 21z).
  Future<void> openFinishDialog(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri turnamen'));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('fase grup', () {
    testWidgets('20a awal', (tester) async {
      await expectMatchesHifi(tester, screen(gg20a(), at20a), '20a');
    });

    testWidgets('20b sebagian terisi', (tester) async {
      await expectMatchesHifi(tester, screen(gg20b(), at20b), '20b');
    });

    testWidgets('20c round terkunci dibuka', (tester) async {
      await expectMatchesHifi(tester, screen(gg20b(), at20b), '20c', act: (t) => t.tap(tab('R4')));
    });

    testWidgets('20e semua terisi · Buat bagan', (tester) async {
      await expectMatchesHifi(tester, screen(gg20e(), at20e), '20e');
    });

    testWidgets('20g dialog tanpa pilihan', (tester) async {
      await expectMatchesHifi(tester, screen(gg20e(), at20e), '20g', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('20i sheet pilih A2', (tester) async {
      await expectMatchesHifi(tester, screen(gg20h(), at20e), '20i', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('20j sudah dipilih', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg20h(), at20e),
        '20j',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(option('Eko · Fajar'));
        },
      );
    });

    testWidgets('20k dialog setelah memilih', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg20h(), at20e),
        '20k',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(option('Eko · Fajar'));
          await t.pumpAndSettle();
          await t.tap(find.descendant(of: find.byType(MabarSheet), matching: find.text('Buat bagan')));
        },
      );
    });

    testWidgets('20l dua slot dari satu daftar', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gg20l(), at20e),
        '20l',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(option('Andi · Budi'));
        },
      );
    });

    testWidgets('20m 4 grup, 2 court', (tester) async {
      await expectMatchesHifi(tester, screen(gg20m(), at20m), '20m');
    });

    testWidgets('20o dialog 4 grup', (tester) async {
      await expectMatchesHifi(tester, screen(gg20o(), at20o), '20o', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('20p court lebih banyak dari grup', (tester) async {
      // Frame = R2 setelah R1 terisi dan Eko · Fajar 6–4 Kiki · Lina (1/3 match), 15 menit sejak mulai.
      final start = gg20p();
      final played = start.withMatches([
        for (final m in start.matches)
          if (m.roundNumber == 1 || (m.roundNumber == 2 && m.courtId == start.config.courts.first.id))
            m.withScore([const SetScore(side1: 6, side2: 4)])
          else
            m,
      ]);
      await expectMatchesHifi(tester, screen(played, ggAt(15)), '20p');
    });

    testWidgets('20q turnamen diakhiri', (tester) async {
      // Frame menggambar R4 (match yang dimainkan sebelum Akhiri), bukan round berjalan.
      await expectMatchesHifi(tester, screen(gg20q(), at20b), '20q', act: (t) => t.tap(tab('R4')));
    });

    testWidgets('20r dialog akhiri di fase grup', (tester) async {
      await expectMatchesHifi(tester, screen(gg20b(), at20b), '20r', act: openFinishDialog);
      expect(
        find.text('Match yang belum main tidak dihitung. Bagan tidak dibuat; peringkat dari posisi grup.'),
        findsOneWidget,
      );
    });
  });

  group('fase gugur', () {
    testWidgets('21b Semifinal belum ada skor', (tester) async {
      await expectMatchesHifi(tester, screen(gg21a(), at21b), '21b');
    });

    testWidgets('21c SF1 terisi', (tester) async {
      await expectMatchesHifi(tester, screen(gg21c(), at21b), '21c');
    });

    testWidgets('21e Final terkunci', (tester) async {
      await expectMatchesHifi(tester, screen(gg21c(), at21b), '21e', act: (t) => t.tap(tab('Final')));
    });

    testWidgets('21f Final berjalan', (tester) async {
      await expectMatchesHifi(tester, screen(gg21f(), at21f), '21f');
    });

    testWidgets('21i Final selesai', (tester) async {
      await expectMatchesHifi(tester, screen(gg21i(), at21f), '21i', act: (t) => t.tap(tab('Final')));
    });

    testWidgets('21o SF2 WO', (tester) async {
      final wo = gg21c().withMatches([
        for (final m in gg21c().matches)
          if (m.phase?.code == 'SF2') m.asWalkover(loserPairId: 'Indra', reason: WoReason.injury) else m,
      ]);
      await expectMatchesHifi(tester, screen(wo, at21b), '21o');
    });

    testWidgets('21z dialog akhiri sebelum Final', (tester) async {
      final wo = gg21c().withMatches([
        for (final m in gg21c().matches)
          if (m.phase?.code == 'SF2') m.asWalkover(loserPairId: 'Indra', reason: WoReason.injury) else m,
      ]);
      await expectMatchesHifi(tester, screen(wo, at21b), '21z', act: openFinishDialog);
      expect(
        find.text('Final dan Juara 3 tidak dimainkan. Andi · Budi dan Citra · Dewi sama-sama #1.'),
        findsOneWidget,
      );
    });

    testWidgets('21q tanpa Perebutan juara 3', (tester) async {
      final a = gg21a(thirdPlace: false).ko('SF1', 6, 4).ko('SF2', 4, 6);
      await expectMatchesHifi(tester, screen(a, at21f), '21q', act: (t) => t.tap(tab('Final')));
    });

    testWidgets('21s 1 court, Perebutan juara 3 sebelum Final', (tester) async {
      await expectMatchesHifi(tester, screen(gg21s(), at21s), '21s');
    });

    testWidgets('21v PF1–2, strip digeser', (tester) async {
      await expectMatchesHifi(tester, screen(gg21u(), at21v), '21v');
    });
  });

  group('perilaku', () {
    testWidgets('AC-G6 + AC-B1: match grup Belum = Buat bagan mati, tunggu N match (20b: 12 − 5 = 7)', (tester) async {
      await tester.pumpWidget(screen(gg20b(), at20b));
      await tester.pumpAndSettle();
      expect(find.text('· tunggu 7 match'), findsOneWidget);
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Buat bagan')).onPressed, isNull);
    });

    testWidgets('AC-G7: Batal di dialog tidak mengubah turnamen', (tester) async {
      await tester.pumpWidget((screen(gg20e(), at20e)));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      await tapText(tester, 'Batal');
      expect(stateOf(tester).hasBracket, isFalse);
      expect(find.text('Buat bagan'), findsOneWidget);
    });

    testWidgets('Buat bagan: bagan dibuat, Jadwal pindah ke tab Bagan', (tester) async {
      await tester.pumpWidget((screen(gg20e(), at20e)));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      await confirmDialog(tester);
      final active = stateOf(tester);
      expect(active.hasBracket, isTrue);
      expect(find.text('Padel · 4 pasangan lolos'), findsOneWidget);
      expect(find.text('0/4 match'), findsOneWidget);
    });

    testWidgets('Pilihan host sampai dialog dikonfirmasi: A2 = Eko · Fajar', (tester) async {
      await tester.pumpWidget((screen(gg20h(), at20e)));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      expect(find.text('Pilih A2'), findsOneWidget);
      await tester.tap(option('Eko · Fajar'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(MabarSheet), matching: find.text('Buat bagan')));
      await tester.pumpAndSettle();
      await confirmDialog(tester);
      final sf2 = stateOf(tester).byCode('SF2');
      expect(sf2.pair2.id, 'Eko');
      expect(GroupKnockoutRanking.qualifierPlan(gg20h()).picks.single.candidates, ['Citra', 'Eko', 'Gita']);
    });

    testWidgets('sisi tbd tidak bisa diketuk dan tanpa Isi skor', (tester) async {
      await tester.pumpWidget(screen(gg21c(), at21b));
      await tester.pumpAndSettle();
      await tester.tap(tab('Final'));
      await tester.pumpAndSettle();
      expect(find.text('Isi skor'), findsNothing);
      expect(find.text('Pemenang SF2'), findsOneWidget);
      expect(find.text('Kalah SF2'), findsOneWidget);
    });
  });

  // Group - Playoff 3.10.0 (GP-10): Buat bagan 3 grup 23b–23g, menu Format playoff 23m–23r. Jam 23b = 12 round × 15 mnt.
  group('Group - Playoff', () {
    final at23b = ggAt(180);
    final at23q = ggAt(240);

    // Sheet 3 grup lebih tinggi dari layar uji bawaan: ukuran layar frame.
    void phone(WidgetTester tester) {
      tester.view.physicalSize = hifiScreenSize * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
    }

    Finder rowOf(String text) => find.descendant(of: find.byType(MabarRow), matching: find.text(text));
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Menu'));
      await tester.pumpAndSettle();
    }

    Future<void> openPlayoffSheet(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Format playoff'));
    }

    /// Sheet babak dari label kolom Bagan (23o, 23p): latar Bagan milik GP-9, jadi hanya wilayah sheet dibandingkan.
    Future<void> openRoundSheet(WidgetTester tester, KnockoutRound round) async {
      showRoundFormatSheet(tester.element(find.byType(ScheduleFixedScreen)), round);
    }

    Future<void> expectSheetRegion(
      WidgetTester tester,
      Widget screen,
      String id,
      KnockoutRound round,
      double height,
    ) async {
      final diff = await compareWithHifi(
        tester,
        screen,
        id,
        region: Rect.fromLTWH(0, 844 - height, 390, height),
        act: (t) => openRoundSheet(t, round),
      );
      expect(diff.ratio, lessThanOrEqualTo(0.02), reason: '$diff');
    }

    testWidgets('23b Jadwal fase grup 3 grup · Buat bagan', (tester) async {
      await expectMatchesHifi(tester, screen(gp23b(), at23b), '23b');
    });

    testWidgets('23c sheet Buat bagan · juara + wildcard', (tester) async {
      await expectMatchesHifi(tester, screen(gp23b(), at23b), '23c', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('23d dialog 3 grup · wildcard', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gp23b(), at23b),
        '23d',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(find.descendant(of: find.byType(MabarSheet), matching: find.byType(MabarButton)).last);
        },
      );
    });

    testWidgets('23e sheet · seri di WC2 belum dipilih', (tester) async {
      await expectMatchesHifi(tester, screen(gp23e(), at23b), '23e', act: (t) => t.tap(find.text('Buat bagan')));
    });

    testWidgets('23f sheet · Umar · Vina dipilih', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gp23e(), at23b),
        '23f',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(find.descendant(of: find.byType(SeedingSheet), matching: find.text('Umar · Vina')));
        },
      );
    });

    testWidgets('23g dialog setelah memilih WC2', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gp23e(), at23b),
        '23g',
        act: (t) async {
          await tapText(t, 'Buat bagan');
          await t.tap(find.descendant(of: find.byType(SeedingSheet), matching: find.text('Umar · Vina')));
          await t.pumpAndSettle();
          await t.tap(find.descendant(of: find.byType(MabarSheet), matching: find.byType(MabarButton)).last);
        },
      );
    });

    testWidgets('23m menu ⋯ · Format playoff', (tester) async {
      await expectMatchesHifi(tester, screen(gp23b(), at23b), '23m', act: openMenu);
    });

    testWidgets('23n sheet Playoff dari Jadwal', (tester) async {
      await expectMatchesHifi(tester, screen(gp23b(), at23b), '23n', act: openPlayoffSheet);
    });

    testWidgets('23o sheet Perempat final (bisa diubah)', (tester) async {
      await expectSheetRegion(tester, screen(gp23h(), at23b), '23o', KnockoutRound.quarterfinal, 250);
    });

    testWidgets('23p sheet Perempat final terkunci · QF1 ada skor', (tester) async {
      await expectSheetRegion(tester, screen(gp23p(), at23b), '23p', KnockoutRound.quarterfinal, 250);
    });

    testWidgets('23q sheet Playoff · Final berskor', (tester) async {
      await expectMatchesHifi(tester, screen(gp23q(), at23q), '23q', act: openPlayoffSheet);
    });

    testWidgets('23r sheet Perebutan juara 3 · Ada terkunci', (tester) async {
      await expectMatchesHifi(
        tester,
        screen(gp23q(), at23q),
        '23r',
        act: (t) async {
          await openPlayoffSheet(t);
          await t.pumpAndSettle();
          await t.tap(rowOf('Perebutan juara 3'));
        },
      );
    });

    testWidgets('tab Bagan ada sejak jadwal dibuat, paling kanan; meta 0/4 (23s)', (tester) async {
      await tester.pumpWidget(screen(gg20a(), at20b));
      await tester.pumpAndSettle();
      expect(tab('Bagan'), findsOneWidget);
      await tester.tap(tab('Bagan'));
      await tester.pumpAndSettle();
      expect(find.text('Padel · Fase grup'), findsOneWidget);
      expect(find.text('0/4 match'), findsOneWidget);
    });

    testWidgets('Buat bagan 3 grup: sheet selalu muncul, bagan dibuat dengan wildcard terkunci', (tester) async {
      phone(tester);
      await tester.pumpWidget(screen(gp23b(), at23b));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      expect(find.byType(SeedingSheet), findsOneWidget);
      expect(find.text('Juara grup'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(MabarSheet), matching: find.byType(MabarButton)).last);
      await tester.pumpAndSettle();
      await confirmDialog(tester);
      final gk = stateOf(tester).config.groupKnockout!;
      expect(gk.wildcards, ['Eko', 'Kiki']);
      expect(stateOf(tester).hasBracket, isTrue);
      // Eko (A3) segrup dengan J1 Andi → tukar: QF1 = Andi vs Kiki, QF3 = Qori vs Eko (23d).
      expect(stateOf(tester).byCode('PF1').pair2.id, 'Kiki');
      expect(stateOf(tester).byCode('PF3').pair2.id, 'Eko');
    });

    testWidgets('seri di WC2: tombol mati "pilih WC2" sampai dipilih; Batal di dialog kembali ke sheet', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(screen(gp23e(), at23b));
      await tester.pumpAndSettle();
      await tapText(tester, 'Buat bagan');
      expect(find.text('Wildcard · pilih WC2'), findsOneWidget);
      final off = find.widgetWithText(MabarButton, 'Buat bagan · pilih WC2');
      expect(tester.widget<MabarButton>(off).onPressed, isNull);
      await tester.tap(find.descendant(of: find.byType(SeedingSheet), matching: find.text('Umar · Vina')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(MabarSheet), matching: find.byType(MabarButton)).last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Batal');
      expect(stateOf(tester).hasBracket, isFalse);
      expect(find.byType(SeedingSheet), findsOneWidget);
      final button = find.descendant(
        of: find.byType(SeedingSheet),
        matching: find.widgetWithText(MabarButton, 'Buat bagan'),
      );
      expect(tester.widget<MabarButton>(button).onPressed, isNotNull);
    });

    testWidgets('Format playoff: ubah format babak dan Juara 3 lewat mutator, sheet ikut', (tester) async {
      phone(tester);
      await tester.pumpWidget(screen(gp23b(), at23b));
      await tester.pumpAndSettle();
      await openPlayoffSheet(tester);
      await tester.pumpAndSettle();
      await tester.tap(rowOf('Perempat final'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Tambah target game'));
      await tester.pumpAndSettle();
      expect(stateOf(tester).config.groupKnockout!.formats[KnockoutRound.quarterfinal]!.target, 5);
      // Sheet babak Juara 3: Tidak ada mematikan, Ada lagi menyalakan; format tetap tersimpan (19g).
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      await tester.tap(rowOf('Perebutan juara 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tidak ada'));
      await tester.pumpAndSettle();
      expect(stateOf(tester).config.groupKnockout!.thirdPlace, isFalse);
      expect(find.text('Target game'), findsNothing);
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      expect(stateOf(tester).config.groupKnockout!.thirdPlace, isTrue);
    });

    testWidgets('Format playoff: babak berskor terkunci, kontrol tidak mengubah apa pun (23p, 23r)', (tester) async {
      phone(tester);
      await tester.pumpWidget(screen(gp23p(), at23b));
      await tester.pumpAndSettle();
      showRoundFormatSheet(tester.element(find.byType(ScheduleFixedScreen)), KnockoutRound.quarterfinal);
      await tester.pumpAndSettle();
      expect(find.text('Terkunci · QF1 ada skor'), findsOneWidget);
      await tester.tap(find.text('Best of'));
      await tester.pumpAndSettle();
      expect(stateOf(tester).config.groupKnockout!.formats[KnockoutRound.quarterfinal]!.method, ScoringMethod.raceTo);
    });

    testWidgets('menu ⋯: Format playoff hilang setelah diakhiri dan di turnamen biasa', (tester) async {
      await tester.pumpWidget(screen(gp23b().finish(), at23b));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('Format playoff'), findsNothing);
    });
  });

  group('teks (gk_labels)', () {
    final h = GroupKnockoutRanking.qualifierPlan(gg20h()).picks;
    final l = GroupKnockoutRanking.qualifierPlan(gg20l()).picks;

    test('judul, subjudul, dan sisa slot (20i, 20l)', () {
      expect(gkPickTitle(h), 'Pilih A2');
      expect(gkPickTitle(l), 'Pilih A1 dan A2');
      expect(gkPickSubtitle(h.single, gg20h().matches), 'Grup A · #2 seri · head-to-head 1–1');
      expect(gkPickSubtitle(l.single, gg20l().matches), 'Grup A · #1 seri · head-to-head 1–1');
      expect(gkMissingSlots(l, {}), 'pilih A1 dan A2');
      expect(
        gkMissingSlots(l, {
          0: ['Andi'],
        }),
        'pilih A2',
      );
      expect(
        gkMissingSlots(l, {
          0: ['Andi', 'Citra'],
        }),
        isNull,
      );
    });

    test('ketukan: lepas melepas yang sesudahnya, penuh memindahkan yang terakhir (20j, 20l)', () {
      expect(gkTap(h.single, [], 'Eko'), ['Eko']);
      expect(gkTap(h.single, ['Eko'], 'Gita'), ['Gita']);
      expect(gkTap(h.single, ['Eko'], 'Eko'), isEmpty);
      expect(gkTap(l.single, ['Andi'], 'Citra'), ['Andi', 'Citra']);
      expect(gkTap(l.single, ['Andi', 'Citra'], 'Andi'), isEmpty);
      expect(gkTap(l.single, ['Andi', 'Citra'], 'Eko'), ['Andi', 'Eko']);
    });

    test('subjudul dan meta Bagan (21a, 21t), subjudul round (20a, 21b, 20q)', () {
      expect(gkRoundSubtitle(gg21a(), 1), 'Padel · Fase grup · Race to 6');
      expect(gkRoundSubtitle(gg21a(), 7), 'Padel · R7');
      expect(gkRoundSubtitle(gg20q(), 4), 'Padel · Fase grup · Race to 6 · diakhiri');
      expect(gkBaganSubtitle(gg21t()), 'Padel · 4 pasangan lolos · diakhiri');
      expect(gkBaganMeta(gg21a()), '0/4 match');
      expect(gkBaganMeta(gg21t()), '2/4 match');
      expect(gkBaganMeta(gg21u()), '0/8 match');
    });

    test('subjudul Bagan sebelum bagan dibuat (23s) dan 3 grup sesudahnya (23p): 8 pasangan', () {
      expect(gkBaganSubtitle(gg20a()), 'Padel · Fase grup');
      expect(gkBaganSubtitle(gp23h()), 'Padel · 8 pasangan lolos');
      expect(gkBaganMeta(gg20a()), '0/4 match');
      expect(gkBaganMeta(gp23b()), '0/8 match');
    });

    test('pratinjau dialog 3 grup: tukar WC dan slot wildcard dengan asalnya (23d, 23g)', () {
      String name(Pair p) => p.id;
      final d = gkBracketPreview(gp23b(), GroupKnockoutRanking.bracketSeeding(gp23b(), {}, [])!, nameOf: name);
      expect(
        [for (final r in d) '${r.code} ${r.slot1} ${r.name1} ${r.slot2} ${r.name2}'],
        [
          'QF1 A1 Andi WC2 · B3 Kiki',
          'QF2 C2 Sari B2 Maya',
          'QF3 C1 Qori WC1 · A3 Eko',
          'QF4 B1 Indra A2 Citra',
        ].map((e) => e).toList(),
      );
    });

    test('2 grup tetap Semifinal (20g)', () {
      final a = gg20e();
      final rows = gkBracketPreview(a, GroupKnockoutRanking.bracketSeeding(a, {}, [])!, nameOf: (p) => p.id);
      expect([for (final r in rows) '${r.code} ${r.slot1} ${r.slot2}'], ['SF1 A1 B2', 'SF2 B1 A2']);
    });

    test('label wildcard: pilih WC2 / pilih WC1 dan WC2 (23e)', () {
      const one = WildcardPick(need: 1, candidates: ['Kiki', 'Umar']);
      const two = WildcardPick(need: 2, candidates: ['Eko', 'Kiki', 'Umar']);
      expect(gkWildcardLabel(null, 0, 0), 'Wildcard');
      expect(gkWildcardLabel(one, 1, 0), 'Wildcard · pilih WC2');
      expect(gkWildcardLabel(one, 1, 1), 'Wildcard');
      expect(gkWildcardMissing(two, 0, 0), 'pilih WC1 dan WC2');
      expect(gkWildcardMissing(two, 0, 1), 'pilih WC2');
    });
  });
}
