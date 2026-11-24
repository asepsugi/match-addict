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

/// 16G (PRD §16, logic.md §21.6): 3 grup × 4, QF Race to 4, SF Race to 5, Juara 3 Race to 5, Final Race to 6.
const g16G = [
  ['Andi', 'Citra', 'Eko', 'Gita'],
  ['Indra', 'Kiki', 'Maya', 'Oki'],
  ['Qori', 'Sari', 'Umar', 'Wawan'],
];

const formats16G = {
  KnockoutRound.quarterfinal: ScoreFormat(ScoringMethod.raceTo, 4),
  KnockoutRound.semifinal: ScoreFormat(ScoringMethod.raceTo, 5),
  KnockoutRound.thirdPlace: ScoreFormat(ScoringMethod.raceTo, 5),
  KnockoutRound.finalRound: ScoreFormat(ScoringMethod.raceTo, 6),
};

ActiveTournament t16G({int courts = 2}) => gkTournament(groups: g16G, courts: courts, formats: formats16G);

/// AC-G24 16G (Win %): J1 Andi (A), J2 Qori (C), J3 Indra (B); WC1 Eko (A3), WC2 Kiki (B3).
const seeding16G = Seeding(
  groupSlots: [
    ['Andi', 'Citra'],
    ['Indra', 'Maya'],
    ['Qori', 'Sari'],
  ],
  champions: [0, 2, 1],
  wildcards: ['Eko', 'Kiki'],
);

Seeding _seeding({List<List<String>>? slots, required List<String> wc}) =>
    Seeding(groupSlots: slots ?? seeding16G.groupSlots, champions: seeding16G.champions, wildcards: wc);

/// "Andi–Kiki" per QF dari fungsi topologi.
List<String> _qf(Seeding s) => [for (final (a, b) in KnockoutBracket.threeGroupQuarterfinals(s, g16G)!) '$a–$b'];

extension on ActiveTournament {
  /// Buat bagan dari [seeding]: match baru + config (wildcards) dalam satu langkah, seperti controller.
  ActiveTournament seeded(Seeding seeding) {
    final built = KnockoutBracket.build(this, seeding);
    return ActiveTournament(
      tournament: tournament.copyWith(config: built.config, matches: [...this.matches, ...built.matches]),
    );
  }
}

/// "R13 QF1 C1 J1 vs WC1" per slot pratinjau.
List<String> _preview(ActiveTournament a) => [
  for (final s in KnockoutBracket.preview(a))
    'R${s.round} ${KnockoutBracket.code(s.phase)} C${s.court + 1} '
        '${KnockoutBracket.sourceLabel(s.side1)} vs ${KnockoutBracket.sourceLabel(s.side2)}',
];

/// Warna alur sisi atas dan bawah match ber-kode simpanan [code].
List<int?> _flow(ActiveTournament a, String code) {
  final phase = KnockoutBracket.phases(
    groupCount: a.config.groupKnockout!.groupCount,
    thirdPlace: true,
  ).firstWhere((p) => p.code == code);
  return [KnockoutBracket.flowIndex(a, phase, 1), KnockoutBracket.flowIndex(a, phase, 2)];
}

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
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 1), 4), 'Pemenang QF1 vs Pemenang QF2');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 2), 4), 'Pemenang QF3 vs Pemenang QF4');
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

    test('code (UI, kode simpanan tetap PF): SF1, QF4, Juara 3, Final', () {
      expect(
        [for (final p in KnockoutBracket.phases(groupCount: 4, thirdPlace: true)) KnockoutBracket.code(p)],
        ['QF1', 'QF2', 'QF3', 'QF4', 'SF1', 'SF2', 'Juara 3', 'Final'],
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
      expect(KnockoutBracket.seedCode(built, 'Andi'), 'A1');
      expect(KnockoutBracket.seedCode(built, 'Maya'), 'B2');
      expect(KnockoutBracket.seedCode(built, 'Citra'), 'A2');
      expect(KnockoutBracket.seedLabel(built, 'Citra'), 'A2');
      expect(KnockoutBracket.seedCode(built, 'Eko'), isNull);
      expect(KnockoutBracket.seedCode(built, ''), isNull);
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
    test('21b: R7 "SF" (tabLabel, keputusan 152), R8 "Final"; fase grup "R3"/"Round 3"', () {
      final a = groups16E().bracket(q16E);
      expect(KnockoutBracket.roundTab(a, 3), 'R3');
      expect(KnockoutBracket.roundTitle(a, 3), 'Round 3');
      expect(KnockoutBracket.roundTab(a, 7), 'SF');
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

    test('21v 4 grup 2 court: "QF1–2", "QF3–4", "SF", judul "Perempat final"', () {
      final a = groups20o().bracket(q20o);
      expect([for (var r = 7; r <= 10; r++) KnockoutBracket.roundTab(a, r)], ['QF1–2', 'QF3–4', 'SF', 'Final']);
      expect(KnockoutBracket.roundTitle(a, 7), 'Perempat final');
    });

    test('4 grup 3 court: "QF1–3", "QF4"', () {
      final a = groups20o(courts: 3).bracket(q20o);
      final first = a.matches.where((m) => m.phase is KnockoutPhase).first.roundNumber;
      expect([KnockoutBracket.roundTab(a, first), KnockoutBracket.roundTab(a, first + 1)], ['QF1–3', 'QF4']);
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

  group('AC-G24 3 grup (G15, logic.md §21.6)', () {
    test('phases 3 grup: QF1–QF4, SF1, SF2, Juara 3, Final; kode simpanan tetap PF', () {
      final phases = KnockoutBracket.phases(groupCount: 3, thirdPlace: true);
      expect(
        [for (final p in phases) KnockoutBracket.code(p)],
        ['QF1', 'QF2', 'QF3', 'QF4', 'SF1', 'SF2', 'Juara 3', 'Final'],
      );
      expect([for (final p in phases) p.code], ['PF1', 'PF2', 'PF3', 'PF4', 'SF1', 'SF2', 'J3', 'F']);
    });

    test('23t sumber sebelum Buat bagan: QF1 J1–WC1, QF2 #2 grup J2–#2 grup J3, QF3 J2–WC2, QF4 J3–#2 grup J1', () {
      expect(
        [for (var s = 1; s <= 4; s++) _sourcesOf(KnockoutPhase(KnockoutRound.quarterfinal, s), 3)],
        ['J1 vs WC1', '#2 grup J2 vs #2 grup J3', 'J2 vs WC2', 'J3 vs #2 grup J1'],
      );
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 1), 3), 'Pemenang QF1 vs Pemenang QF2');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.semifinal, 2), 3), 'Pemenang QF3 vs Pemenang QF4');
      expect(_sourcesOf(const KnockoutPhase(KnockoutRound.thirdPlace, 1), 3), 'Kalah SF1 vs Kalah SF2');
    });

    test('AC-G24 16G: WC1 Eko segrup J1 → tukar; QF1 Andi–Kiki, QF2 Sari–Maya, QF3 Qori–Eko, QF4 Indra–Citra', () {
      expect(_qf(seeding16G), ['Andi–Kiki', 'Sari–Maya', 'Qori–Eko', 'Indra–Citra']);
    });

    test('AC-G25 16G-iii pilih Umar: QF1 Andi–Umar (WC2 · C3), QF3 Qori–Eko (tukar)', () {
      expect(_qf(_seeding(wc: ['Eko', 'Umar'])), ['Andi–Umar', 'Sari–Maya', 'Qori–Eko', 'Indra–Citra']);
    });

    test('AC-G30 16G-pp: QF1 Andi–Wawan, QF2 Sari–Indra, QF3 Qori–Eko, QF4 Maya–Citra', () {
      final pp = _seeding(
        slots: [
          ['Andi', 'Citra'],
          ['Maya', 'Indra'],
          ['Qori', 'Sari'],
        ],
        wc: ['Eko', 'Wawan'],
      );
      expect(_qf(pp), ['Andi–Wawan', 'Sari–Indra', 'Qori–Eko', 'Maya–Citra']);
    });

    test('G15 tukar hanya kalau WC1 segrup J1 atau WC2 segrup J2', () {
      // WC1 Umar (C) bukan grup J1 (A), WC2 Kiki (B) bukan grup J2 (C) → tanpa tukar.
      expect(_qf(_seeding(wc: ['Umar', 'Kiki'])), ['Andi–Umar', 'Sari–Maya', 'Qori–Kiki', 'Indra–Citra']);
      // WC2 Umar segrup J2 Qori → tukar.
      expect(_qf(_seeding(wc: ['Kiki', 'Umar'])), ['Andi–Umar', 'Sari–Maya', 'Qori–Kiki', 'Indra–Citra']);
    });

    test('W2 seeding tidak sah → null (total, dipakai validator GR19)', () {
      Seeding bad({List<List<String>>? slots, List<int>? champions, List<String>? wc}) => Seeding(
        groupSlots: slots ?? seeding16G.groupSlots,
        champions: champions ?? seeding16G.champions,
        wildcards: wc ?? seeding16G.wildcards,
      );
      const q = KnockoutBracket.threeGroupQuarterfinals;
      final rest = seeding16G.groupSlots.skip(1);
      expect(q(bad(champions: [0, 1]), g16G), isNull);
      expect(q(bad(champions: [0, 0, 1]), g16G), isNull);
      expect(q(bad(champions: [0, 1, 3]), g16G), isNull);
      expect(q(bad(wc: ['Eko']), g16G), isNull);
      expect(q(bad(wc: ['Eko', 'Gita']), g16G), isNull, reason: 'dua WC segrup');
      expect(q(bad(wc: ['Eko', 'Zaki']), g16G), isNull, reason: 'WC tanpa grup');
      expect(q(bad(wc: ['Citra', 'Kiki']), g16G), isNull, reason: 'WC sudah slot 2');
      expect(q(bad(slots: seeding16G.groupSlots.sublist(0, 2)), g16G), isNull);
      expect(
        q(
          bad(
            slots: [
              ['Andi'],
              ...rest,
            ],
          ),
          g16G,
        ),
        isNull,
      );
      expect(
        q(
          bad(
            slots: [
              ['Andi', 'Andi'],
              ...rest,
            ],
          ),
          g16G,
        ),
        isNull,
      );
      expect(
        q(
          bad(
            slots: [
              ['Andi', 'Kiki'],
              ...rest,
            ],
          ),
          g16G,
        ),
        isNull,
        reason: 'slot bukan anggota grupnya',
      );
      expect(q(seeding16G, g16G.sublist(0, 2)), isNull);
    });

    test(
      'AC-G24 16G build 2 court: R13 QF1+QF2, R14 QF3+QF4, R15 SF, R16 Final C1 + Juara 3 C2; wildcards ditulis',
      () {
        final base = t16G();
        final built = KnockoutBracket.build(base, seeding16G);
        expect(
          [for (final m in built.matches) '${m.id} ${m.courtId} ${m.phase!.code}'],
          [
            'm-r13-1 c1 PF1',
            'm-r13-2 c2 PF2',
            'm-r14-1 c1 PF3',
            'm-r14-2 c2 PF4',
            'm-r15-1 c1 SF1',
            'm-r15-2 c2 SF2',
            'm-r16-1 c1 F',
            'm-r16-2 c2 J3',
          ],
        );
        // Urutan WC1, WC2 dari Seeding, bukan urutan sisi sesudah tukar (21.12 #4).
        final gk = built.config.groupKnockout!;
        expect(gk.wildcards, ['Eko', 'Kiki']);
        expect(gk.formats, base.config.groupKnockout!.formats);
        expect(gk.groups, g16G);
        expect(gk.thirdPlace, isTrue);
        expect(built.config.format, base.config.format);
        final a = base.seeded(seeding16G);
        expect(a.sides('PF1'), 'Andi–Kiki');
        expect(a.sides('PF2'), 'Sari–Maya');
        expect(a.sides('PF3'), 'Qori–Eko');
        expect(a.sides('PF4'), 'Indra–Citra');
        expect(a.sides('SF1'), '?–?');
        expect(a.sides('F'), '?–?');
        expect(KnockoutBracket.isResolved(a.config, a.matches), isTrue);
      },
    );

    test('16G varian 3 court: R7 QF1–QF3, R8 QF4, R9 SF, R10 Final + Juara 3; tab "QF1–3", "QF4"', () {
      final a = t16G(courts: 3).seeded(seeding16G);
      expect(
        [
          for (final m in a.matches)
            if (m.phase is KnockoutPhase) 'R${m.roundNumber} ${m.phase!.code} ${m.courtId}',
        ],
        ['R7 PF1 c1', 'R7 PF2 c2', 'R7 PF3 c3', 'R8 PF4 c1', 'R9 SF1 c1', 'R9 SF2 c2', 'R10 F c1', 'R10 J3 c2'],
      );
      expect([for (var r = 7; r <= 10; r++) KnockoutBracket.roundTab(a, r)], ['QF1–3', 'QF4', 'SF', 'Final']);
    });

    test('QF semua di satu round (4 court) → tab "QF"', () {
      final a = t16G(courts: 4).seeded(seeding16G);
      final first = a.matches.where((m) => m.phase is KnockoutPhase).first.roundNumber;
      expect(KnockoutBracket.roundTab(a, first), 'QF');
    });

    test('2/4 grup: build tidak mengganti config (identical, startIfNeeded); Seeding salah bentuk ditolak', () {
      final base = groups16E();
      final built = KnockoutBracket.build(base, const Seeding(groupSlots: q16E));
      expect(identical(built.config, base.config), isTrue);
      expect(
        () => KnockoutBracket.build(base, const Seeding(groupSlots: q16E, wildcards: ['Eko', 'Kiki'])),
        throwsArgumentError,
      );
      expect(() => KnockoutBracket.build(t16G(), const Seeding(groupSlots: q16E)), throwsArgumentError);
      expect(() => KnockoutBracket.build(t16G(), _seeding(wc: ['Eko', 'Gita'])), throwsArgumentError);
    });

    test('23h seedCode/seedLabel: A1, C2, WC1/WC2 dari wildcards (bukan sisi sesudah tukar); tidak lolos null', () {
      final a = t16G().seeded(seeding16G);
      expect(
        {
          for (final id in ['Andi', 'Citra', 'Maya', 'Indra', 'Qori', 'Sari', 'Eko', 'Kiki'])
            id: KnockoutBracket.seedCode(a, id),
        },
        {
          'Andi': 'A1',
          'Citra': 'A2',
          'Maya': 'B2',
          'Indra': 'B1',
          'Qori': 'C1',
          'Sari': 'C2',
          'Eko': 'WC1',
          'Kiki': 'WC2',
        },
      );
      expect(KnockoutBracket.seedLabel(a, 'Kiki'), 'WC2 · B3');
      expect(KnockoutBracket.seedLabel(a, 'Eko'), 'WC1 · A3');
      expect(KnockoutBracket.seedLabel(a, 'Sari'), 'C2');
      expect(KnockoutBracket.seedCode(a, 'Umar'), isNull);
      expect(KnockoutBracket.seedLabel(a, 'Gita'), isNull);
      expect(KnockoutBracket.seedCode(t16G(), 'Andi'), isNull, reason: 'sebelum bagan');
      final iii = t16G().seeded(_seeding(wc: ['Eko', 'Umar']));
      expect(KnockoutBracket.seedLabel(iii, 'Umar'), 'WC2 · C3');
      expect(KnockoutBracket.seedCode(iii, 'Kiki'), isNull);
    });

    test('16G-akhir (23w): QF → SF1 Andi–Maya, SF2 Qori–Citra → Final Andi–Qori 6–4, Juara 3 Maya–Citra 5–2', () {
      var a = t16G().seeded(seeding16G);
      a = a.ko('PF1', 4, 2).ko('PF2', 3, 4).ko('PF3', 4, 1).ko('PF4', 3, 4);
      expect(a.sides('SF1'), 'Andi–Maya');
      expect(a.sides('SF2'), 'Qori–Citra');
      a = a.ko('SF1', 5, 3).ko('SF2', 5, 4);
      expect(a.sides('F'), 'Andi–Qori');
      expect(a.sides('J3'), 'Maya–Citra');
      a = a.ko('F', 6, 4).ko('J3', 5, 2);
      expect(a.byCode('F').winnerPairId, 'Andi');
      expect(a.byCode('J3').winnerPairId, 'Maya');
      expect(KnockoutBracket.progress(a), (done: 8, total: 8));
      expect(KnockoutBracket.firstOpenColumn(a), KnockoutRound.finalRound, reason: 'semua terisi → babak terakhir');
      // Final: atas dari QF1 (Andi), bawah dari QF3 (Qori); Juara 3 abu.
      expect(_flow(a, 'F'), [0, 2]);
      expect(_flow(a, 'J3'), [null, null]);
    });

    test('23v SF berjalan: tab QF1–2/QF3–4/SF/Final, progress 5/8, geser awal Semifinal, warna alur', () {
      final a = t16G()
          .seeded(seeding16G)
          .ko('PF1', 4, 2)
          .ko('PF2', 3, 4)
          .ko('PF3', 4, 1)
          .ko('PF4', 3, 4)
          .ko('SF1', 5, 3);
      expect([for (var r = 13; r <= 16; r++) KnockoutBracket.roundTab(a, r)], ['QF1–2', 'QF3–4', 'SF', 'Final']);
      expect(KnockoutBracket.roundTitle(a, 13), 'Perempat final');
      expect(KnockoutBracket.matchLabel(a.config, a.byCode('PF1')), 'QF1 · Race to 4');
      expect(KnockoutBracket.progress(a), (done: 5, total: 8));
      expect(KnockoutBracket.firstOpenColumn(a), KnockoutRound.semifinal);
      expect(_flow(a, 'PF1'), [0, 0]);
      expect(_flow(a, 'PF4'), [3, 3]);
      expect(_flow(a, 'SF1'), [0, 1]);
      expect(_flow(a, 'SF2'), [2, 3]);
      expect(_flow(a, 'F'), [0, null], reason: 'Andi menang SF1 (asal QF1); SF2 belum');
      expect(_flow(a, 'J3'), [null, null]);
    });

    test('23t 3 grup sebelum Buat bagan: pratinjau R13–R16 kode slot, progress 0/8, geser awal QF', () {
      final a = t16G();
      expect(_preview(a), [
        'R13 QF1 C1 J1 vs WC1',
        'R13 QF2 C2 #2 grup J2 vs #2 grup J3',
        'R14 QF3 C1 J2 vs WC2',
        'R14 QF4 C2 J3 vs #2 grup J1',
        'R15 SF1 C1 Pemenang QF1 vs Pemenang QF2',
        'R15 SF2 C2 Pemenang QF3 vs Pemenang QF4',
        'R16 Final C1 Pemenang SF1 vs Pemenang SF2',
        'R16 Juara 3 C2 Kalah SF1 vs Kalah SF2',
      ]);
      expect(a.matches.where((m) => m.phase is KnockoutPhase), isEmpty, reason: 'pratinjau bukan match (21.12 #9)');
      expect(KnockoutBracket.progress(a), (done: 0, total: 8));
      expect(KnockoutBracket.firstOpenColumn(a), KnockoutRound.quarterfinal);
      expect(_flow(a, 'SF1'), [0, 1]);
      expect(_flow(a, 'F'), [null, null], reason: 'sumber lanjutan tanpa pemenang = abu');
    });
  });

  group('23s 2 grup: pratinjau, progress, alur', () {
    test('23s sebelum Buat bagan: SF1 A1–B2 R7 C1, SF2 B1–A2 R7 C2, Final/Juara 3 R8; progress 0/4; alur', () {
      final a = gkTournament();
      expect(_preview(a), [
        'R7 SF1 C1 A1 vs B2',
        'R7 SF2 C2 B1 vs A2',
        'R8 Final C1 Pemenang SF1 vs Pemenang SF2',
        'R8 Juara 3 C2 Kalah SF1 vs Kalah SF2',
      ]);
      expect(KnockoutBracket.progress(a), (done: 0, total: 4));
      expect(KnockoutBracket.firstOpenColumn(a), KnockoutRound.semifinal);
      // Final "Pemenang SF1"/"Pemenang SF2" sudah berwarna (sumbernya babak pertama); Juara 3 abu.
      expect(_flow(a, 'SF1'), [0, 0]);
      expect(_flow(a, 'SF2'), [1, 1]);
      expect(_flow(a, 'F'), [0, 1]);
      expect(_flow(a, 'J3'), [null, null]);
    });

    test('juara 3 mati sebelum bagan: pratinjau tanpa Juara 3, progress 0/3', () {
      final a = gkTournament(thirdPlace: false);
      expect(_preview(a), ['R7 SF1 C1 A1 vs B2', 'R7 SF2 C2 B1 vs A2', 'R8 Final C1 Pemenang SF1 vs Pemenang SF2']);
      expect(KnockoutBracket.progress(a), (done: 0, total: 3));
    });

    test('sesudah bagan: pratinjau tetap; progress dari match gugur; Final terisi, Juara 3 belum → Juara 3', () {
      final a = groups16E().bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9);
      expect(_preview(a), [
        'R7 SF1 C1 A1 vs B2',
        'R7 SF2 C2 B1 vs A2',
        'R8 Final C1 Pemenang SF1 vs Pemenang SF2',
        'R8 Juara 3 C2 Kalah SF1 vs Kalah SF2',
      ]);
      expect(KnockoutBracket.progress(a), (done: 3, total: 4));
      expect(KnockoutBracket.firstOpenColumn(a), KnockoutRound.thirdPlace);
      expect(_flow(a, 'F'), [0, 1]);
    });
  });
}
