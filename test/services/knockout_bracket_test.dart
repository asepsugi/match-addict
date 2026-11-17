import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/scoring/score_entry.dart';

import 'group_knockout_fixture.dart';

/// Bagan Grup + Gugur (logic.md §18.8, 18.10): topologi, susunan round/court, pemenang maju, ubah skor gugur, label
/// round. Data = PRD 16A, 16B, 16E dan frame 21a–21y.

String _sourcesOf(KnockoutPhase p, int groupCount) {
  final (a, b) = KnockoutBracket.sources(p, groupCount: groupCount);
  return '${KnockoutBracket.sourceLabel(a)} vs ${KnockoutBracket.sourceLabel(b)}';
}

/// "R7 SF1 C1" per match susunan.
List<String> _layout(int groupCount, bool thirdPlace, int courts, int firstRound) => [
  for (final s in KnockoutBracket.layout(
    groupCount: groupCount,
    thirdPlace: thirdPlace,
    courts: courts,
    firstRound: firstRound,
  ))
    'R${s.round} ${s.phase.code} C${s.court + 1}#${s.matchNumber}',
];

void main() {
  group('AC-G8 topologi', () {
    test('2 grup: SF1 = A1 vs B2, SF2 = B1 vs A2; Final/Juara 3 dari SF', () {
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 1), 2), 'A1 vs B2');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 2), 2), 'B1 vs A2');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.finalRound, 1), 2), 'Pemenang SF1 vs Pemenang SF2');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.thirdPlace, 1), 2), 'Kalah SF1 vs Kalah SF2');
    });

    test('4 grup: PF1 A1–B2, PF2 C1–D2, PF3 B1–A2, PF4 D1–C2; SF dari PF', () {
      expect(
        [for (var s = 1; s <= 4; s++) _sourcesOf(KnockoutPhase(KnockoutRound.quarterfinal, s), 4)],
        ['A1 vs B2', 'C1 vs D2', 'B1 vs A2', 'D1 vs C2'],
      );
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 1), 4), 'Pemenang PF1 vs Pemenang PF2');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 2), 4), 'Pemenang PF3 vs Pemenang PF4');
    });

    test('AC-G8 paruh: slot 1 dan 2 tiap grup di paruh berbeda', () {
      for (final g in [2, 4]) {
        final first = g == 4 ? KnockoutRound.quarterfinal : KnockoutRound.semifinal;
        final half = <String, int>{};
        for (var s = 1; s <= (g == 4 ? 4 : 2); s++) {
          final (a, b) = KnockoutBracket.sources(KnockoutPhase(first, s), groupCount: g);
          final h = g == 4 ? (s <= 2 ? 0 : 1) : s - 1;
          for (final src in [a, b]) {
            half[(src as SeedSource).code] = h;
          }
        }
        expect(half, hasLength(g * 2));
        for (var grp = 0; grp < g; grp++) {
          final l = GroupKnockout.letter(grp);
          expect(half['${l}1'], isNot(half['${l}2']), reason: '$g grup, $l');
        }
      }
    });

    test('dependents: PF → SF-nya; SF → Final dan Juara 3; Final/Juara 3 → tidak ada', () {
      final gk = gkTournament().config.groupKnockout!;
      expect(KnockoutBracket.dependents(gk, const KnockoutPhase(KnockoutRound.quarterfinal, 2)), [
        const KnockoutPhase(KnockoutRound.semifinal, 1),
      ]);
      expect(KnockoutBracket.dependents(gk, const KnockoutPhase(KnockoutRound.quarterfinal, 3)), [
        const KnockoutPhase(KnockoutRound.semifinal, 2),
      ]);
      expect(KnockoutBracket.dependents(gk, const KnockoutPhase(KnockoutRound.semifinal, 1)), [
        const KnockoutPhase(KnockoutRound.finalRound, 1),
        const KnockoutPhase(KnockoutRound.thirdPlace, 1),
      ]);
      expect(
        KnockoutBracket.dependents(gk.copyWith(thirdPlace: false), const KnockoutPhase(KnockoutRound.semifinal, 2)),
        [const KnockoutPhase(KnockoutRound.finalRound, 1)],
      );
      expect(KnockoutBracket.dependents(gk, const KnockoutPhase(KnockoutRound.finalRound, 1)), isEmpty);
    });

    test('code: SF1, PF4, Juara 3, Final', () {
      expect(
        [for (final p in KnockoutBracket.phases(groupCount: 4, thirdPlace: true)) KnockoutBracket.code(p)],
        ['PF1', 'PF2', 'PF3', 'PF4', 'SF1', 'SF2', 'Juara 3', 'Final'],
      );
    });
  });

  group('GU10 layout', () {
    test('16E 2 court: R7 SF1 C1 + SF2 C2 · R8 Final C1 + Juara 3 C2', () {
      expect(_layout(2, true, 2, 7), ['R7 SF1 C1#1', 'R7 SF2 C2#2', 'R8 F C1#1', 'R8 J3 C2#2']);
    });
    test('16A 1 court (21s): R13 SF1 · R14 SF2 · R15 Juara 3 · R16 Final', () {
      expect(_layout(2, true, 1, 13), ['R13 SF1 C1#1', 'R14 SF2 C1#1', 'R15 J3 C1#1', 'R16 F C1#1']);
    });
    test('16B 2 court (21u): R7 PF1+PF2 · R8 PF3+PF4 · R9 SF · R10 Final + Juara 3', () {
      expect(_layout(4, true, 2, 7), [
        'R7 PF1 C1#1',
        'R7 PF2 C2#2',
        'R8 PF3 C1#1',
        'R8 PF4 C2#2',
        'R9 SF1 C1#1',
        'R9 SF2 C2#2',
        'R10 F C1#1',
        'R10 J3 C2#2',
      ]);
    });
    test('4 grup 3 court: PF1–PF3 satu round, PF4 round berikut', () {
      expect(_layout(4, true, 3, 7), [
        'R7 PF1 C1#1',
        'R7 PF2 C2#2',
        'R7 PF3 C3#3',
        'R8 PF4 C1#1',
        'R9 SF1 C1#1',
        'R9 SF2 C2#2',
        'R10 F C1#1',
        'R10 J3 C2#2',
      ]);
    });
    test('21q tanpa juara 3: R8 hanya Final di C1', () {
      expect(_layout(2, false, 2, 7), ['R7 SF1 C1#1', 'R7 SF2 C2#2', 'R8 F C1#1']);
      expect(_layout(2, false, 1, 13), ['R13 SF1 C1#1', 'R14 SF2 C1#1', 'R15 F C1#1']);
    });
  });

  group('AC-G9 16E pemenang maju', () {
    final built = groups16E().bracket(q16E);

    test('build: SF1 Andi (A1) vs Maya (B2), SF2 Indra (B1) vs Citra (A2); Final/Juara 3 tbd; id dan court', () {
      final ko = built.matches.where((m) => m.phase is KnockoutPhase).toList();
      expect(
        [for (final m in ko) '${m.id} ${m.courtId} ${m.phase!.code}'],
        ['m-r7-1 c1 SF1', 'm-r7-2 c2 SF2', 'm-r8-1 c1 F', 'm-r8-2 c2 J3'],
      );
      expect(built.sides('SF1'), 'Andi–Maya');
      expect(built.sides('SF2'), 'Indra–Citra');
      expect(built.sides('F'), '?–?');
      expect(built.sides('J3'), '?–?');
      expect(KnockoutBracket.seedOf(built, 'Andi'), 'A1');
      expect(KnockoutBracket.seedOf(built, 'Maya'), 'B2');
      expect(KnockoutBracket.seedOf(built, 'Citra'), 'A2');
      expect(KnockoutBracket.seedOf(built, 'Eko'), isNull);
      expect(KnockoutBracket.seedOf(built, ''), isNull);
      expect(KnockoutBracket.isResolved(built.config, built.matches), isTrue);
    });

    test('SF1 6–4 → Final pair1 Andi, Juara 3 pair1 Maya; pair2 tbd (Final belum bisa dibuka)', () {
      final a = built.ko('SF1', 6, 4);
      expect(a.sides('F'), 'Andi–?');
      expect(a.sides('J3'), 'Maya–?');
      expect(a.byCode('F').pair2.isTbd, isTrue);
    });

    test('SF2 4–6 → Final Andi vs Citra, Juara 3 Maya vs Indra (21f); WO Indra sama (21o, AC-G11)', () {
      final a = built.ko('SF1', 6, 4).ko('SF2', 4, 6);
      expect(a.sides('F'), 'Andi–Citra');
      expect(a.sides('J3'), 'Maya–Indra');
      final wo = built.ko('SF1', 6, 4).koWo('SF2', 'Indra');
      expect(wo.sides('F'), 'Andi–Citra');
      expect(wo.sides('J3'), 'Maya–Indra');
      // Tabel grup tidak berubah oleh WO gugur: match grup identik.
      expect(
        [for (final m in wo.matches.where((m) => m.phase is GroupPhase)) m.sets.single.side1],
        [for (final m in built.matches.where((m) => m.phase is GroupPhase)) m.sets.single.side1],
      );
    });

    test('ubah SF1 jadi 4–6 sebelum R8 ada skor → allowed + pratinjau; Final Maya vs Citra, Juara 3 Andi vs Indra', () {
      final a = built.ko('SF1', 6, 4).ko('SF2', 4, 6);
      final sf1 = a.byCode('SF1');
      final check = KnockoutBracket.flipCheck(a, sf1.id, 'Maya');
      expect(check, isA<FlipAllowed>());
      final preview = (check as FlipAllowed).preview;
      expect(
        [for (final m in preview) '${m.phase!.code} ${m.pair1.id}–${m.pair2.id}'],
        ['F Maya–Citra', 'J3 Andi–Indra'],
      );
      final b = a.ko('SF1', 4, 6);
      expect(b.sides('F'), 'Maya–Citra');
      expect(b.sides('J3'), 'Andi–Indra');
    });

    test('Final 7–9 tersimpan → SF1 4–6 blocked [Final]; + Juara 3 4–2 → blocked [Final, Juara 3]; 6–5 boleh', () {
      final a = built.ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9);
      final sf1 = a.byCode('SF1').id;
      expect((KnockoutBracket.flipCheck(a, sf1, 'Maya') as FlipBlocked).rounds, [KnockoutRound.finalRound]);
      final b = a.ko('J3', 4, 2);
      expect((KnockoutBracket.flipCheck(b, sf1, 'Maya') as FlipBlocked).rounds, [
        KnockoutRound.finalRound,
        KnockoutRound.thirdPlace,
      ]);
      // 6–5: pemenang sama → boleh tanpa pratinjau.
      expect((KnockoutBracket.flipCheck(b, sf1, 'Andi') as FlipAllowed).preview, isEmpty);
      // Final 7–9 → 9–7: tanpa dependent → boleh tanpa dialog.
      expect((KnockoutBracket.flipCheck(b, b.byCode('F').id, 'Andi') as FlipAllowed).preview, isEmpty);
      final c = b.ko('F', 9, 7);
      expect(c.byCode('F').winnerPairId, 'Andi');
    });

    test('skor pertama (belum ada pemenang) → boleh tanpa pratinjau; dependent cancelled = tanpa hasil', () {
      expect((KnockoutBracket.flipCheck(built, built.byCode('SF1').id, 'Maya') as FlipAllowed).preview, isEmpty);
      final ended = built.ko('SF1', 6, 4).ko('SF2', 4, 6).finish();
      expect(KnockoutBracket.flipCheck(ended, ended.byCode('SF1').id, 'Maya'), isA<FlipAllowed>());
    });

    test('AC-G10 format per babak: Final Race to 9 menerima 9–7, Juara 3 Race to 4 menolak 6–2', () {
      final a = built.ko('SF1', 6, 4).ko('SF2', 4, 6);
      expect(ScoreRules.judge(a.config.formatFor(a.byCode('F')), 9, 7), isA<ScoreWin>());
      expect(ScoreRules.judge(a.config.formatFor(a.byCode('J3')), 6, 2), isNot(isA<ScoreWin>()));
      expect(ScoreRules.judge(a.config.formatFor(a.byCode('J3')), 4, 2), isA<ScoreWin>());
    });

    test('isResolved menolak sisi yang tidak sama dengan resolve (GR15)', () {
      final a = built.ko('SF1', 6, 4);
      final wrong = [
        for (final m in a.matches)
          m.phase?.code == 'F'
              ? MatchGame(
                  id: m.id,
                  roundNumber: m.roundNumber,
                  matchNumberInRound: m.matchNumberInRound,
                  courtId: m.courtId,
                  pair1: pairOf('Maya'),
                  pair2: Pair.tbd,
                  phase: m.phase,
                )
              : m,
      ];
      expect(KnockoutBracket.isResolved(a.config, wrong), isFalse);
      expect(KnockoutBracket.isResolved(a.config, KnockoutBracket.resolve(a.config, wrong)), isTrue);
    });
  });

  test('16B 4 grup (21w–21y): PF → SF Andi vs Vina, Indra vs Tono → Final Andi vs Tono, Juara 3 Vina vs Indra', () {
    var a = groups20o().bracket(q20o);
    expect(a.sides('PF1'), 'Andi–Gita');
    expect(a.sides('PF2'), 'Maya–Vina');
    expect(a.sides('PF3'), 'Indra–Citra');
    expect(a.sides('PF4'), 'Tono–Rudi');
    a = a.ko('PF1', 6, 3).ko('PF2', 4, 6).ko('PF3', 6, 5).ko('PF4', 6, 2);
    expect(a.sides('SF1'), 'Andi–Vina');
    expect(a.sides('SF2'), 'Indra–Tono');
    a = a.ko('SF1', 6, 4).ko('SF2', 3, 6);
    expect(a.sides('F'), 'Andi–Tono');
    expect(a.sides('J3'), 'Vina–Indra');
    a = a.ko('F', 9, 6).ko('J3', 4, 3);
    expect(a.byCode('F').winnerPairId, 'Andi');
    expect(a.isFinal(DateTime(2026, 11, 17)), isTrue);
  });

  group('label round', () {
    test('21b: R7 "Semifinal", R8 "Final"; fase grup "R3"/"Round 3"', () {
      final a = groups16E().bracket(q16E);
      expect(KnockoutBracket.roundTab(a, 3), 'R3');
      expect(KnockoutBracket.roundTitle(a, 3), 'Round 3');
      expect(KnockoutBracket.roundTab(a, 7), 'Semifinal');
      expect(KnockoutBracket.roundTitle(a, 7), 'Semifinal');
      expect(KnockoutBracket.roundTab(a, 8), 'Final');
      expect(KnockoutBracket.roundTitle(a, 8), 'Final');
      expect(KnockoutBracket.matchLabel(a.config, a.byCode('SF1')), 'SF1 · Race to 6');
      expect(KnockoutBracket.matchLabel(a.config, a.byCode('J3')), 'Juara 3 · Race to 4');
      expect(KnockoutBracket.matchLabel(a.config, a.matches.first), isNull);
    });

    test('21s 1 court: "SF1", "SF2", "Juara 3", "Final"; judul nama babak lengkap', () {
      final a = groups16E(courts: 1).bracket(q16E);
      expect([for (var r = 13; r <= 16; r++) KnockoutBracket.roundTab(a, r)], ['SF1', 'SF2', 'Juara 3', 'Final']);
      expect(
        [for (var r = 13; r <= 16; r++) KnockoutBracket.roundTitle(a, r)],
        ['Semifinal', 'Semifinal', 'Perebutan juara 3', 'Final'],
      );
    });

    test('21v 4 grup 2 court: "PF1–2", "PF3–4", judul "Perempat final"', () {
      final a = groups20o().bracket(q20o);
      expect([for (var r = 7; r <= 10; r++) KnockoutBracket.roundTab(a, r)], ['PF1–2', 'PF3–4', 'Semifinal', 'Final']);
      expect(KnockoutBracket.roundTitle(a, 7), 'Perempat final');
    });

    test('4 grup 3 court: "PF1–3", "PF4"', () {
      final a = groups20o(courts: 3).bracket(q20o);
      final first = a.matches.where((m) => m.phase is KnockoutPhase).first.roundNumber;
      expect([KnockoutBracket.roundTab(a, first), KnockoutBracket.roundTab(a, first + 1)], ['PF1–3', 'PF4']);
    });
  });

  group('AC-G6, AC-G14 status model', () {
    test('canCreateBracket hanya setelah semua match grup Selesai/WO, sebelum bagan, belum diakhiri', () {
      final full = groups16E();
      expect(full.canCreateBracket, isTrue);
      final open = full.withMatches([
        for (final (i, m) in full.matches.indexed) i == 11 ? m.copyWith(status: MatchStatus.pending, sets: []) : m,
      ]);
      expect(open.canCreateBracket, isFalse);
      final wo = full.withMatches([
        for (final (i, m) in full.matches.indexed) i == 11 ? m.asWalkover(loserPairId: m.pair1.id) : m,
      ]);
      expect(wo.canCreateBracket, isTrue);
      expect(full.bracket(q16E).canCreateBracket, isFalse);
      expect(full.finish().canCreateBracket, isFalse);
      expect(gkTournament().canCreateBracket, isFalse);
    });

    test('isFinal: fase grup lengkap tetap Sementara (20f); Final + Juara 3 terisi → Final; diakhiri → Final', () {
      final now = DateTime(2026, 11, 17);
      final full = groups16E();
      expect(full.isFinal(now), isFalse);
      final a = full.bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9);
      expect(a.isFinal(now), isFalse);
      expect(a.ko('J3', 4, 2).isFinal(now), isTrue);
      final noThird = groups16E(thirdPlace: false).bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6);
      expect(noThird.isFinal(now), isFalse);
      expect(noThird.ko('F', 7, 9).isFinal(now), isTrue);
      expect(gkTournament().finish().isFinal(now), isTrue);
    });

    test('canAddRounds false di Grup + Gugur walau semua match terisi', () {
      final done = groups16E().bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9).ko('J3', 4, 2);
      expect(done.matches.every((m) => m.status != MatchStatus.pending), isTrue);
      expect(done.canAddRounds, isFalse);
      expect(groups16E().canAddRounds, isFalse);
    });
  });
}
