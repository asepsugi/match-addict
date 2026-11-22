import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';

import 'group_knockout_fixture.dart';

/// Klasemen grup, siapa lolos, peringkat akhir Grup + Gugur (logic.md §18.6, 18.7, 18.9). Data PRD 16D–16F + frame.

/// "1 Andi 2–1 +3 67%" per baris tabel grup [g].
List<String> _table(ActiveTournament a, int g) => [
  for (final e in GroupKnockoutRanking.groupTables(a)[g].entries)
    '${e.position ?? '-'} ${e.players.first.name} ${e.standing.wins}–${e.standing.losses} '
        '${e.standing.diffLabel} ${e.standing.winPercent.round()}%',
];

/// "#1 Citra Juara" per baris peringkat akhir.
List<String> _final(ActiveTournament a) => [
  for (final e in GroupKnockoutRanking.finalEntries(a)) '#${e.position ?? '-'} ${e.players.first.name} ${e.stage}',
];

/// "A [2] [Citra, Eko, Gita] 1": grup, slot, kandidat, jumlah ketukan.
String _pick(OpenPick p) => '${GroupKnockout.letter(p.group)} ${p.slots} ${p.candidates} ${p.taps}';

/// 16D-i: seri di batas 2 vs 3.
ActiveTournament _d1() => gkTournament()
    .play('Andi', 'Citra', 6, 4)
    .play('Andi', 'Eko', 6, 3)
    .play('Andi', 'Gita', 6, 3)
    .play('Citra', 'Eko', 6, 4)
    .play('Eko', 'Gita', 6, 3)
    .play('Gita', 'Citra', 6, 4);

/// 16D-iii: seri tiga pasangan berputar.
ActiveTournament _d3() => gkTournament()
    .play('Andi', 'Citra', 6, 3)
    .play('Andi', 'Eko', 6, 3)
    .play('Andi', 'Gita', 6, 3)
    .play('Citra', 'Eko', 6, 4)
    .play('Eko', 'Gita', 6, 4)
    .play('Gita', 'Citra', 6, 4);

/// Grup B 16E (B1 Indra, B2 Maya).
ActiveTournament _groupB(ActiveTournament a) => a
    .play('Indra', 'Maya', 6, 4)
    .play('Indra', 'Kiki', 6, 2)
    .play('Indra', 'Oki', 6, 1)
    .play('Maya', 'Kiki', 6, 3)
    .play('Maya', 'Oki', 6, 2)
    .play('Kiki', 'Oki', 6, 4);

void main() {
  group('18.6 klasemen grup', () {
    test('16D-ii / 20f: A 1, 1, 2, 3 · B Indra +11, Maya +5, Kiki −5, Oki −11', () {
      final a = groups16E();
      expect(_table(a, 0), ['1 Andi 2–1 +3 67%', '1 Citra 2–1 +3 67%', '2 Eko 1–2 −2 33%', '3 Gita 1–2 −4 33%']);
      expect(_table(a, 1), ['1 Indra 3–0 +11 100%', '2 Maya 2–1 +5 67%', '3 Kiki 1–2 −5 33%', '4 Oki 0–3 −11 0%']);
      final t = GroupKnockoutRanking.groupTables(a);
      expect(t.first.method, RankingMethod.winPercent);
      expect(t.first.pairIds, ['Andi', 'Citra', 'Eko', 'Gita']);
      expect(t.first.entries.first.label, 'Andi + Budi');
    });

    test('16D-i: nomor tabel 1, 2, 2, 3 (head-to-head tidak mengubah nomor)', () {
      expect([for (final r in _table(_d1(), 0)) r.split(' ').first], ['1', '2', '2', '3']);
    });

    test('16D-iii / 20h: Citra, Eko, Gita 1–2 −3 33% → 2, 2, 2', () {
      expect(_table(_d3(), 0), ['1 Andi 3–0 +9 100%', '2 Citra 1–2 −3 33%', '2 Eko 1–2 −3 33%', '2 Gita 1–2 −3 33%']);
    });

    test('20n 4 grup (7 match): C Maya, Rudi 1, 1; D Tono belum main tanpa nomor', () {
      final a = gkTournament(groups: g16B)
          .play('Citra', 'Eko', 6, 4)
          .play('Indra', 'Kiki', 6, 2)
          .play('Rudi', 'Oki', 6, 3)
          .play('Qori', 'Vina', 4, 6)
          .play('Andi', 'Eko', 6, 1)
          .play('Gita', 'Kiki', 6, 4)
          .play('Maya', 'Oki', 6, 3);
      expect(_table(a, 2), ['1 Maya 1–0 +3 100%', '1 Rudi 1–0 +3 100%', '2 Oki 0–2 −6 0%']);
      expect(_table(a, 3).last, '- Tono 0–0 0 0%');
    });

    test('20o: A Andi 100 +7, Citra 50 0, Eko 0 −7 · B Indra, Gita, Kiki · C Maya, Rudi, Oki · D Tono, Vina, Qori', () {
      final a = groups20o();
      expect(_table(a, 0), ['1 Andi 2–0 +7 100%', '2 Citra 1–1 0 50%', '3 Eko 0–2 −7 0%']);
      expect(_table(a, 1), ['1 Indra 2–0 +7 100%', '2 Gita 1–1 −1 50%', '3 Kiki 0–2 −6 0%']);
      expect(_table(a, 2), ['1 Maya 2–0 +5 100%', '2 Rudi 1–1 +1 50%', '3 Oki 0–2 −6 0%']);
      expect(_table(a, 3), ['1 Tono 2–0 +7 100%', '2 Vina 1–1 −2 50%', '3 Qori 0–2 −5 0%']);
    });

    test('match gugur tidak masuk tabel grup', () {
      final a = groups16E().bracket(q16E).ko('SF1', 6, 4);
      expect(_table(a, 0), _table(groups16E(), 0));
    });
  });

  group('AC-G7 siapa lolos', () {
    test('16D-i: A1 Andi, A2 Citra lewat head-to-head', () {
      final plan = GroupKnockoutRanking.qualifierPlan(_groupB(_d1()));
      expect(plan.slots, [
        ['Andi', 'Citra'],
        ['Indra', 'Maya'],
      ]);
      expect(plan.picks, isEmpty);
    });

    test('16D-ii / 20f: A1 Andi (menang 6–4), A2 Citra; tanpa pilihan', () {
      final plan = GroupKnockoutRanking.qualifierPlan(groups16E());
      expect(plan.slots, q16E);
      expect(plan.picks, isEmpty);
      expect(plan.withPicks({}), q16E);
    });

    test('16D-iii / 20h–20k: OpenPick(A, [2], [Citra, Eko, Gita]); host pilih Eko → A2 Eko; tanpa pilihan → null', () {
      final plan = GroupKnockoutRanking.qualifierPlan(_groupB(_d3()));
      expect(plan.slots.first, ['Andi', null]);
      final pick = plan.picks.single;
      expect(_pick(pick), 'A [2] [Citra, Eko, Gita] 1');
      expect(plan.withPicks({}), isNull);
      expect(
        plan.withPicks({
          0: ['Andi'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Eko', 'Gita'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          1: ['Indra'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Eko'],
        }),
        [
          ['Andi', 'Eko'],
          ['Indra', 'Maya'],
        ],
      );
    });

    test('20l: T1 {Andi, Citra, Eko} h 1, 1, 1 → OpenPick(A, [1, 2], 3 kandidat), dua ketukan', () {
      final a = _groupB(
        gkTournament()
            .play('Andi', 'Gita', 6, 3)
            .play('Citra', 'Eko', 6, 4)
            .play('Andi', 'Eko', 4, 6)
            .play('Gita', 'Citra', 3, 6)
            .play('Andi', 'Citra', 6, 4)
            .play('Eko', 'Gita', 6, 3),
      );
      expect([for (final r in _table(a, 0)) r.split(' ').first], ['1', '1', '1', '2']);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      final pick = plan.picks.single;
      expect(_pick(pick), 'A [1, 2] [Andi, Citra, Eko] 2');
      expect(plan.slots.first, [null, null]);
      expect(
        plan.withPicks({
          0: ['Citra'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Citra', 'Andi'],
        })!.first,
        ['Citra', 'Andi'],
      );
    });

    test('seri dua pasangan di #1, match mereka seri (Americano 24 12–12) → satu ketukan "Pilih A1"', () {
      const am = ScoreFormat(ScoringMethod.americano, 24);
      final a = _groupB(gkTournament(format: am))
          .play('Andi', 'Citra', 12, 12)
          .play('Andi', 'Eko', 14, 10)
          .play('Andi', 'Gita', 14, 10)
          .play('Citra', 'Eko', 14, 10)
          .play('Citra', 'Gita', 14, 10)
          .play('Eko', 'Gita', 12, 12);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      final pick = plan.picks.first;
      expect(_pick(pick), 'A [1, 2] [Andi, Citra] 1');
      expect(plan.picks, hasLength(1));
      expect(
        plan.withPicks({
          0: ['Citra'],
        }),
        [
          ['Citra', 'Andi'],
          ['Indra', 'Maya'],
        ],
      );
    });

    // Americano 24, Total Point: tiga pasangan 40 poin (selisih ikut sama), Gita 24. Hanya head-to-head yang beda.
    const am = ScoreFormat(ScoringMethod.americano, 24);

    test('T1 {X, Y, Z} h 2, ½, ½ (satu seri) → A1 X, OpenPick([2], [Y, Z])', () {
      final a = _groupB(gkTournament(format: am))
          .play('Andi', 'Citra', 13, 11)
          .play('Andi', 'Eko', 13, 11)
          .play('Citra', 'Eko', 12, 12)
          .play('Andi', 'Gita', 14, 10)
          .play('Citra', 'Gita', 17, 7)
          .play('Eko', 'Gita', 17, 7);
      expect([for (final r in GroupKnockoutRanking.groupTables(a)[0].entries) r.position], [1, 1, 1, 2]);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      expect(plan.slots.first, ['Andi', null]);
      final pick = plan.picks.single;
      expect(_pick(pick), 'A [2] [Citra, Eko] 1');
    });

    test('T1 {X, Y, Z} h 2, 1, 0 → A1 X, A2 Y, tanpa pilihan', () {
      final a = _groupB(gkTournament(format: am))
          .play('Andi', 'Citra', 13, 11)
          .play('Andi', 'Eko', 13, 11)
          .play('Citra', 'Eko', 13, 11)
          .play('Andi', 'Gita', 14, 10)
          .play('Citra', 'Gita', 16, 8)
          .play('Eko', 'Gita', 18, 6);
      expect([for (final r in GroupKnockoutRanking.groupTables(a)[0].entries) r.position], [1, 1, 1, 2]);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      expect(plan.slots.first, ['Andi', 'Citra']);
      expect(plan.picks, isEmpty);
    });

    test('20o (4 grup): A1 Andi A2 Citra · B1 Indra B2 Gita · C1 Maya C2 Rudi · D1 Tono D2 Vina', () {
      final plan = GroupKnockoutRanking.qualifierPlan(groups20o());
      expect(plan.slots, q20o);
      expect(plan.picks, isEmpty);
    });

    test('dua grup perlu pilihan → dua OpenPick (20i)', () {
      final a = _d3()
          .play('Indra', 'Maya', 6, 3)
          .play('Indra', 'Kiki', 6, 3)
          .play('Indra', 'Oki', 6, 3)
          .play('Maya', 'Kiki', 6, 4)
          .play('Kiki', 'Oki', 6, 4)
          .play('Oki', 'Maya', 6, 4);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      expect([for (final p in plan.picks) '${GroupKnockout.letter(p.group)}${p.slots}'], ['A[2]', 'B[2]']);
      expect(
        plan.withPicks({
          0: ['Eko'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Eko'],
          1: ['Oki'],
        }),
        [
          ['Andi', 'Eko'],
          ['Indra', 'Oki'],
        ],
      );
    });
  });

  group('AC-G13 peringkat akhir', () {
    final sf = groups16E().bracket(q16E);

    test('16F / 22a', () {
      final a = sf.ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9).ko('J3', 4, 2);
      expect(_final(a), [
        '#1 Citra Juara',
        '#2 Andi Final',
        '#3 Maya Juara 3',
        '#4 Indra Semifinal',
        '#5 Eko Grup A · 3',
        '#5 Kiki Grup B · 3',
        '#6 Gita Grup A · 4',
        '#6 Oki Grup B · 4',
      ]);
      final first = GroupKnockoutRanking.finalEntries(a).first;
      expect((first.label, first.standing.wins, first.standing.gameDiff), ('Citra + Dewi', 2, 3));
    });

    test('22c tanpa juara 3', () {
      final a = groups16E(thirdPlace: false).bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9);
      expect(_final(a), [
        '#1 Citra Juara',
        '#2 Andi Final',
        '#3 Indra Semifinal',
        '#3 Maya Semifinal',
        '#4 Eko Grup A · 3',
        '#4 Kiki Grup B · 3',
        '#5 Gita Grup A · 4',
        '#5 Oki Grup B · 4',
      ]);
    });

    test('22f / 21t diakhiri setelah R7', () {
      final a = sf.ko('SF1', 6, 4).ko('SF2', 4, 6).finish();
      expect(_final(a), [
        '#1 Andi Final',
        '#1 Citra Final',
        '#2 Indra Semifinal',
        '#2 Maya Semifinal',
        '#3 Eko Grup A · 3',
        '#3 Kiki Grup B · 3',
        '#4 Gita Grup A · 4',
        '#4 Oki Grup B · 4',
      ]);
    });

    test('22d bagan baru dibuat', () {
      expect(_final(sf), [
        '#1 Andi Semifinal',
        '#1 Citra Semifinal',
        '#1 Indra Semifinal',
        '#1 Maya Semifinal',
        '#2 Eko Grup A · 3',
        '#2 Kiki Grup B · 3',
        '#3 Gita Grup A · 4',
        '#3 Oki Grup B · 4',
      ]);
    });

    test('22e SF1 6–4', () {
      expect(_final(sf.ko('SF1', 6, 4)), [
        '#1 Andi Final',
        '#2 Citra Semifinal',
        '#2 Indra Semifinal',
        '#3 Maya Perebutan juara 3',
        '#4 Eko Grup A · 3',
        '#4 Kiki Grup B · 3',
        '#5 Gita Grup A · 4',
        '#5 Oki Grup B · 4',
      ]);
    });

    test('22g diakhiri di R4 (20q): urut posisi grup', () {
      // 20q: R1–R3 + R4 Court 1 terisi; Grup A Citra 2–0 +5, Andi 1–1 +1, Gita 1–1 0, Eko 0–2 −6.
      final a = gkTournament()
          .play('Andi', 'Gita', 4, 6)
          .play('Indra', 'Oki', 6, 1)
          .play('Citra', 'Eko', 6, 3)
          .play('Kiki', 'Maya', 3, 6)
          .play('Andi', 'Eko', 6, 3)
          .play('Indra', 'Maya', 6, 4)
          .play('Gita', 'Citra', 4, 6)
          .finish();
      expect(_table(a, 0), ['1 Citra 2–0 +5 100%', '2 Andi 1–1 +1 50%', '3 Gita 1–1 0 50%', '4 Eko 0–2 −6 0%']);
      expect(_final(a), [
        '#1 Citra Grup A · 1',
        '#1 Indra Grup B · 1',
        '#2 Andi Grup A · 2',
        '#2 Maya Grup B · 2',
        '#3 Gita Grup A · 3',
        '#3 Kiki Grup B · 3',
        '#4 Eko Grup A · 4',
        '#4 Oki Grup B · 4',
      ]);
    });

    test('22h–22i / 21y 4 grup', () {
      final a = groups20o()
          .bracket(q20o)
          .ko('PF1', 6, 3)
          .ko('PF2', 4, 6)
          .ko('PF3', 6, 5)
          .ko('PF4', 6, 2)
          .ko('SF1', 6, 4)
          .ko('SF2', 3, 6)
          .ko('F', 9, 6)
          .ko('J3', 4, 3);
      expect(_final(a), [
        '#1 Andi Juara',
        '#2 Tono Final',
        '#3 Vina Juara 3',
        '#4 Indra Semifinal',
        '#5 Citra Perempat final',
        '#5 Gita Perempat final',
        '#5 Maya Perempat final',
        '#5 Rudi Perempat final',
        '#6 Eko Grup A · 3',
        '#6 Kiki Grup B · 3',
        '#6 Oki Grup C · 3',
        '#6 Qori Grup D · 3',
      ]);
    });

    test('16D-iii, host pilih Eko: Citra, Gita (nomor tabel 2, tidak lolos) → keduanya "Grup A · 3"', () {
      final a = _groupB(_d3()).bracket([
        ['Andi', 'Eko'],
        ['Indra', 'Maya'],
      ]);
      final rows = _final(a);
      expect(rows.where((r) => r.contains('Grup A')), ['#2 Citra Grup A · 3', '#2 Gita Grup A · 3']);
    });

    test('sebelum bagan, pasangan belum main → tanpa nomor dan tanpa babak; posisi grup 1, 1, 3', () {
      final a = gkTournament().play('Andi', 'Gita', 6, 4).play('Indra', 'Oki', 6, 4);
      final entries = GroupKnockoutRanking.finalEntries(a);
      expect(
        [for (final e in entries.take(4)) '#${e.position} ${e.players.first.name} ${e.stage}'],
        ['#1 Andi Grup A · 1', '#1 Indra Grup B · 1', '#2 Gita Grup A · 2', '#2 Oki Grup B · 2'],
      );
      expect(entries.skip(4).every((e) => e.position == null && e.stage == null), isTrue);
      // 1, 1, 2 → posisi grup 1, 1, 3 (C: Maya, Rudi seri di 20n).
      final c = gkTournament(groups: g16B).play('Rudi', 'Oki', 6, 3).play('Maya', 'Oki', 6, 3);
      expect(
        [
          for (final e in GroupKnockoutRanking.finalEntries(c))
            if (e.stage?.startsWith('Grup C') ?? false) e.stage,
        ],
        ['Grup C · 1', 'Grup C · 1', 'Grup C · 3'],
      );
    });

    test('turnamen lain: kosong', () {
      final a = gkTournament();
      final rr = ActiveTournament(
        tournament: a.tournament.copyWith(
          config: TournamentConfig(
            sport: a.config.sport,
            mode: a.config.mode,
            matchDurationMinutes: 15,
            courts: a.config.courts,
            players: a.config.players,
            fixedPairs: a.config.fixedPairs,
          ),
        ),
      );
      expect(GroupKnockoutRanking.finalEntries(rr), isEmpty);
      expect(GroupKnockoutRanking.groupTables(rr), isEmpty);
    });
  });

  group('AC-RP13 grup Americano 21 (default Point %, keputusan 123)', () {
    // Grup A: Eko Total Point 32 (51%), Andi 31 (49%), Citra 30 (57%, ada 11–0), Gita 23 (43%).
    // Total Point meloloskan Eko + Andi; Point % meloloskan Citra + Eko.
    ActiveTournament americano() => gkTournament(format: const ScoreFormat(ScoringMethod.americano, 21))
        .play('Andi', 'Citra', 11, 10)
        .play('Citra', 'Gita', 11, 0)
        .play('Citra', 'Eko', 9, 12)
        .play('Eko', 'Andi', 12, 9)
        .play('Eko', 'Gita', 8, 13)
        .play('Andi', 'Gita', 11, 10);

    test('groupTables[0].method = pointPercent; tabel urut Point %; 2 lolos = Citra, Eko', () {
      final a = americano();
      final t = GroupKnockoutRanking.groupTables(a)[0];
      expect(t.method, RankingMethod.pointPercent);
      expect(
        [
          for (final e in t.entries)
            '${e.position} ${e.players.first.name} ${e.standing.totalPoint} ${e.standing.pointPercent}%',
        ],
        ['1 Citra 30 57%', '2 Eko 32 51%', '3 Andi 31 49%', '4 Gita 23 43%'],
      );
      expect(GroupKnockoutRanking.qualifierPlan(a).slots[0], ['Citra', 'Eko']);
    });

    test('grup Race to: tetap Win % (byte-sama 3.8.1)', () {
      expect(GroupKnockoutRanking.groupTables(groups16E())[0].method, RankingMethod.winPercent);
    });
  });
}
