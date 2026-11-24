import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/group_stage.dart';

import 'group_knockout_fixture.dart';

/// Klasemen grup, siapa lolos, peringkat akhir Grup + Gugur (logic.md §18.6, 18.7, 18.9). Data PRD 16D–16F + frame.

/// "1 Andi 2–1 +3 67%" per baris tabel grup [g].
List<String> _table(ActiveTournament a, int g) => [
  for (final e in GroupKnockoutRanking.groupTables(a)[g].entries)
    '${e.position ?? '-'} ${e.players.first.name} ${e.standing.wins}–${e.standing.losses} '
        '${e.standing.diffLabel} ${e.standing.winPercent.round()}%',
];

/// "#1 Citra Juara 1" per baris peringkat akhir.
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

/// 16G: 3 grup × 4, pasangan dengan partner PRD (bukan peta fixture 16A/16B).
const _partners16G = {
  'Andi': 'Budi',
  'Citra': 'Dewi',
  'Eko': 'Fajar',
  'Gita': 'Hadi',
  'Indra': 'Joko',
  'Kiki': 'Lina',
  'Maya': 'Nanda',
  'Oki': 'Putri',
  'Qori': 'Rina',
  'Sari': 'Tono',
  'Umar': 'Vina',
  'Wawan': 'Yuni',
};

const _g16G = [
  ['Andi', 'Citra', 'Eko', 'Gita'],
  ['Indra', 'Kiki', 'Maya', 'Oki'],
  ['Qori', 'Sari', 'Umar', 'Wawan'],
];

Pair _pair16G(String n) => Pair(id: n, player1Id: n, player2Id: _partners16G[n]!);

ActiveTournament _tournament16G({ScoreFormat format = raceTo6}) {
  final pairs = [for (final g in _g16G) ...g.map(_pair16G)];
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.fixed,
    matchDurationMinutes: 15,
    courts: courtsOf(2),
    players: [
      for (final p in pairs) ...[
        Player(id: p.player1Id, name: p.player1Id),
        Player(id: p.player2Id, name: p.player2Id),
      ],
    ],
    fixedPairs: pairs,
    format: format,
    groupKnockout: const GroupKnockout(groupCount: 3, groups: _g16G, formats: formats16A, thirdPlace: true),
  );
  final matches = GroupStage.schedule(groups: [for (final g in _g16G) g.map(_pair16G).toList()], courts: config.courts);
  return ActiveTournament(
    tournament: Tournament(id: 't', createdAt: DateTime(2026, 11, 23), config: config, matches: matches),
  );
}

/// Hasil fase grup 16G (PRD 16.3); [mayaKiki] 16G-ii = 2, [qoriUmar] 16G-iii = 3.
ActiveTournament _groups16G({int mayaKiki = 1, int qoriUmar = 1, ScoreFormat format = raceTo6}) =>
    _tournament16G(format: format)
        .play('Andi', 'Citra', 6, 4)
        .play('Andi', 'Eko', 6, 2)
        .play('Andi', 'Gita', 6, 1)
        .play('Citra', 'Eko', 6, 3)
        .play('Citra', 'Gita', 6, 2)
        .play('Eko', 'Gita', 6, 4)
        .play('Indra', 'Maya', 6, 5)
        .play('Indra', 'Kiki', 6, 4)
        .play('Indra', 'Oki', 6, 3)
        .play('Maya', 'Kiki', 6, mayaKiki)
        .play('Maya', 'Oki', 6, 2)
        .play('Kiki', 'Oki', 6, 5)
        .play('Qori', 'Sari', 6, 3)
        .play('Qori', 'Umar', 6, qoriUmar)
        .play('Qori', 'Wawan', 6, 4)
        .play('Sari', 'Umar', 6, 2)
        .play('Sari', 'Wawan', 6, 3)
        .play('Umar', 'Wawan', 6, 5);

/// "Eko A 33 −1,67" per baris sheet Buat bagan; " –" = belum pasti lolos.
String _seed(SeedRow r) =>
    '${r.pairId} ${GroupKnockout.letter(r.group)} ${r.value} ${r.perMatch}${r.qualified ? '' : ' –'}';

String _seeding(Seeding s) => '${s.groupSlots} J${s.champions} WC${s.wildcards}';

PlayerStanding _standing(String id, int w, int l, int diff) => PlayerStanding(
  player: Player(id: id, name: id),
  wins: w,
  losses: l,
  gamesWon: 20 + diff,
  gamesLost: 20,
);

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

    test('AC-G13 16F / 22a label baru: Juara 1, Juara 2, Juara 3', () {
      final a = sf.ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9).ko('J3', 4, 2);
      expect(_final(a), [
        '#1 Citra Juara 1',
        '#2 Andi Juara 2',
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

    test('22c tanpa juara 3: Juara 1, Juara 2, #3 dua Semifinal', () {
      final a = groups16E(thirdPlace: false).bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9);
      expect(_final(a), [
        '#1 Citra Juara 1',
        '#2 Andi Juara 2',
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

    test('22h–22i / 21y 4 grup: Juara 1, Juara 2', () {
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
        '#1 Andi Juara 1',
        '#2 Tono Juara 2',
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

  group('21.3 metode Playoff + pembanding lintas grup', () {
    test('AC-G30 playoffMethod: Race to / Best of → Win %, Americano → Point %', () {
      TournamentConfig c(ScoreFormat f) => _tournament16G(format: f).config;
      expect(GroupKnockoutRanking.playoffMethod(c(raceTo6)), RankingMethod.winPercent);
      expect(
        GroupKnockoutRanking.playoffMethod(c(const ScoreFormat(ScoringMethod.bestOf, 3))),
        RankingMethod.winPercent,
      );
      expect(
        GroupKnockoutRanking.playoffMethod(c(const ScoreFormat(ScoringMethod.americano, 21))),
        RankingMethod.pointPercent,
      );
    });

    test('23c teks selisih per match: +11 ÷ 3, −5 ÷ 3, +6 ÷ 3, 0, −8 ÷ 3', () {
      expect(PlayoffSeeding.perMatchLabel(11, 3), '+3,67');
      expect(PlayoffSeeding.perMatchLabel(-5, 3), '−1,67');
      expect(PlayoffSeeding.perMatchLabel(6, 3), '+2,00');
      expect(PlayoffSeeding.perMatchLabel(0, 3), '0,00');
      expect(PlayoffSeeding.perMatchLabel(-8, 3), '−2,67');
      expect(PlayoffSeeding.perMatchLabel(0, 0), '0,00');
    });

    test('21.12 #8 selisih per match bilangan bulat: −5 ÷ 3 seri dengan −10 ÷ 6; nilai metode dulu', () {
      const wp = RankingMethod.winPercent;
      expect(PlayoffSeeding.comparePlayoffSeed(_standing('a', 1, 2, -5), _standing('b', 2, 4, -10), wp), 0);
      expect(PlayoffSeeding.comparePlayoffSeed(_standing('a', 1, 2, -5), _standing('b', 1, 2, -6), wp), lessThan(0));
      expect(PlayoffSeeding.comparePlayoffSeed(_standing('a', 1, 3, 9), _standing('b', 1, 2, -6), wp), greaterThan(0));
    });
  });

  group('21.4 lolos per grup, 3 grup: 3 slot', () {
    test('AC-G24 16G: A [Andi, Citra, Eko], B [Indra, Maya, Kiki], C [Qori, Sari, Umar], tanpa pilihan', () {
      final plan = GroupKnockoutRanking.qualifierPlan(_groups16G());
      expect(plan.slots, [
        ['Andi', 'Citra', 'Eko'],
        ['Indra', 'Maya', 'Kiki'],
        ['Qori', 'Sari', 'Umar'],
      ]);
      expect(plan.picks, isEmpty);
    });

    test('AC-G30 16G-pp (Point %): B [Maya, Indra, Kiki], C [Qori, Sari, Wawan]', () {
      final plan = GroupKnockoutRanking.qualifierPlan(_groups16G(), method: RankingMethod.pointPercent);
      expect(plan.slots, [
        ['Andi', 'Citra', 'Eko'],
        ['Maya', 'Indra', 'Kiki'],
        ['Qori', 'Sari', 'Wawan'],
      ]);
      final tables = GroupKnockoutRanking.groupTables(_groups16G(), method: RankingMethod.pointPercent);
      expect(tables.every((t) => t.method == RankingMethod.pointPercent), isTrue);
      expect(
        [for (final e in tables[2].entries) '${e.players.first.name} ${e.standing.pointPercent}'],
        ['Qori 69', 'Sari 58', 'Wawan 40', 'Umar 35'],
      );
    });

    // Grup A sebuah 3 grup diisi data 16D-i / 16D-iii; Grup B dan C 16G.
    ActiveTournament groupA(List<(String, String, int, int)> scores) {
      var a = _groups16G();
      for (final (x, y, sx, sy) in scores) {
        a = a.play(x, y, sx, sy);
      }
      return a;
    }

    test('16D-i sebagai Grup A 3 grup: T2 {Citra, Eko} h Citra 1 → A2 Citra, A3 Eko, tanpa pilihan', () {
      final a = groupA([
        ('Andi', 'Citra', 6, 4),
        ('Andi', 'Eko', 6, 3),
        ('Andi', 'Gita', 6, 3),
        ('Citra', 'Eko', 6, 4),
        ('Eko', 'Gita', 6, 3),
        ('Gita', 'Citra', 6, 4),
      ]);
      expect([for (final r in _table(a, 0)) r.split(' ').first], ['1', '2', '2', '3']);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      expect(plan.slots.first, ['Andi', 'Citra', 'Eko']);
      expect(plan.picks, isEmpty);
    });

    test('16D-iii sebagai Grup A 3 grup: OpenPick(A, [2, 3], 3 kandidat), dua ketukan (pola 20l)', () {
      final a = groupA([
        ('Andi', 'Citra', 6, 3),
        ('Andi', 'Eko', 6, 3),
        ('Andi', 'Gita', 6, 3),
        ('Citra', 'Eko', 6, 4),
        ('Eko', 'Gita', 6, 4),
        ('Gita', 'Citra', 6, 4),
      ]);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      expect(plan.slots.first, ['Andi', null, null]);
      expect(_pick(plan.picks.single), 'A [2, 3] [Citra, Eko, Gita] 2');
      expect(
        plan.withPicks({
          0: ['Gita'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Gita', 'Citra'],
        })!.first,
        ['Andi', 'Gita', 'Citra'],
      );
    });

    test('dua OpenPick satu grup: T1 {Andi, Citra} untuk slot 1–2, T2 {Eko, Gita} untuk slot 3', () {
      // Americano 24: Andi–Citra 12–12 dan Eko–Gita 12–12, sisanya simetris → dua tingkat, masing-masing seri.
      final a = _groups16G(format: const ScoreFormat(ScoringMethod.americano, 24))
          .play('Andi', 'Citra', 12, 12)
          .play('Eko', 'Gita', 12, 12)
          .play('Andi', 'Eko', 14, 10)
          .play('Andi', 'Gita', 14, 10)
          .play('Citra', 'Eko', 14, 10)
          .play('Citra', 'Gita', 14, 10);
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      expect(plan.slots.first, [null, null, null]);
      expect([for (final p in plan.picks) _pick(p)], ['A [1, 2] [Andi, Citra] 1', 'A [3] [Eko, Gita] 1']);
      expect(
        plan.withPicks({
          0: ['Citra'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Citra', 'Andi'],
        }),
        isNull,
      );
      expect(
        plan.withPicks({
          0: ['Citra', 'Gita'],
        })!.first,
        ['Citra', 'Andi', 'Gita'],
      );
    });

    test('2 grup tetap 2 slot (16D-ii)', () {
      expect(GroupKnockoutRanking.qualifierPlan(groups16E()).slots, q16E);
    });
  });

  group('21.5 juara, wildcard, Seeding', () {
    SeedingPlan planOf(ActiveTournament a, {RankingMethod? method}) => GroupKnockoutRanking.seedingPlan(
      a,
      GroupKnockoutRanking.qualifierPlan(a, method: method).withPicks({})!,
      method: method,
    );

    test('AC-G24 16G / 23c: J1 Andi +3,67, J2 Qori +3,33, J3 Indra +2,00; WC1 Eko, WC2 Kiki; Umar tidak lolos', () {
      final plan = planOf(_groups16G());
      expect(plan.champions.map(_seed), ['Andi A 100 +3,67', 'Qori C 100 +3,33', 'Indra B 100 +2,00']);
      expect(plan.candidates.map(_seed), ['Eko A 33 −1,67', 'Kiki B 33 −2,00', 'Umar C 33 −2,67 –']);
      expect(plan.pick, isNull);
      expect(_seeding(plan.seeding!), '[[Andi, Citra], [Indra, Maya], [Qori, Sari]] J[0, 2, 1] WC[Eko, Kiki]');
      expect(plan.withWildcardPick(['Umar']), isNull);
    });

    test('AC-G24 / AC-G30 16G-pp (Point %): J1 Andi 72, J2 Qori 69, J3 Maya 65; WC1 Eko 41, WC2 Wawan 40', () {
      final plan = planOf(_groups16G(), method: RankingMethod.pointPercent);
      expect([for (final r in plan.champions) '${r.pairId} ${r.value}'], ['Andi 72', 'Qori 69', 'Maya 65']);
      expect(plan.candidates.map(_seed), ['Eko A 41 −1,67', 'Wawan C 40 −2,00', 'Kiki B 39 −2,00 –']);
      expect(_seeding(plan.seeding!), '[[Andi, Citra], [Maya, Indra], [Qori, Sari]] J[0, 2, 1] WC[Eko, Wawan]');
    });

    test('AC-G30 tanpa parameter = Win % untuk Race to (tabel, lolos, juara, wildcard dari satu metode)', () {
      final a = _groups16G();
      expect(GroupKnockoutRanking.groupTables(a).every((t) => t.method == RankingMethod.winPercent), isTrue);
      expect(_seeding(planOf(a).seeding!), _seeding(planOf(a, method: RankingMethod.winPercent).seeding!));
    });

    test('AC-G25 16G-ii (Maya–Kiki 6–2): Eko, Kiki −1,67 seri tapi keduanya lolos → huruf grup, tanpa pilihan', () {
      final plan = planOf(_groups16G(mayaKiki: 2));
      expect(plan.candidates.map(_seed), ['Eko A 33 −1,67', 'Kiki B 33 −1,67', 'Umar C 33 −2,67 –']);
      expect(plan.pick, isNull);
      expect(plan.seeding!.wildcards, ['Eko', 'Kiki']);
      // Point % juga seri 41% (PRD 16G-ii).
      final pp = planOf(_groups16G(mayaKiki: 2), method: RankingMethod.pointPercent);
      expect([for (final r in pp.candidates.take(2)) '${r.pairId} ${r.value}'], ['Eko 41', 'Kiki 41']);
    });

    test('AC-G25 16G-iii / 23e (Qori–Umar 6–3): J2 Qori +2,67; WildcardPick(1, [Kiki, Umar]); pilih Umar', () {
      final plan = planOf(_groups16G(qoriUmar: 3));
      expect(plan.champions.map(_seed), ['Andi A 100 +3,67', 'Qori C 100 +2,67', 'Indra B 100 +2,00']);
      expect(plan.candidates.map(_seed), ['Eko A 33 −1,67', 'Kiki B 33 −2,00 –', 'Umar C 33 −2,00 –']);
      expect('${plan.pick!.need} ${plan.pick!.candidates}', '1 [Kiki, Umar]');
      expect(plan.seeding, isNull);
      expect(plan.withWildcardPick([]), isNull);
      expect(plan.withWildcardPick(['Eko']), isNull);
      expect(plan.withWildcardPick(['Kiki', 'Umar']), isNull);
      expect(
        _seeding(plan.withWildcardPick(['Umar'])!),
        '[[Andi, Citra], [Indra, Maya], [Qori, Sari]] J[0, 2, 1] WC[Eko, Umar]',
      );
    });

    test('seri tiga kandidat (33%, selisih per match sama) → WildcardPick(2, [A3, B3, C3]), terpilih urut huruf', () {
      final plan = PlayoffSeeding.plan(
        perGroup: [
          ['a1', 'a2', 'a3'],
          ['b1', 'b2', 'b3'],
          ['c1', 'c2', 'c3'],
        ],
        standings: {
          for (final g in ['a', 'b', 'c']) ...{
            '${g}1': _standing('${g}1', 3, 0, 9),
            '${g}2': _standing('${g}2', 2, 1, 3),
            '${g}3': _standing('${g}3', 1, 2, -3),
          },
        },
        method: RankingMethod.winPercent,
      );
      expect([for (final r in plan.champions) r.pairId], ['a1', 'b1', 'c1']);
      expect('${plan.pick!.need} ${plan.pick!.candidates}', '2 [a3, b3, c3]');
      expect(plan.seeding, isNull);
      expect(plan.withWildcardPick(['c3', 'a3'])!.wildcards, ['a3', 'c3']);
      expect(plan.withWildcardPick(['c3']), isNull);
    });

    test('2 dan 4 grup: tanpa juara/kandidat, Seeding langsung dari slot', () {
      for (final (a, q) in [(groups16E(), q16E), (groups20o(), q20o)]) {
        final plan = GroupKnockoutRanking.seedingPlan(a, q);
        expect([plan.champions.length, plan.candidates.length, plan.pick], [0, 0, null]);
        expect(_seeding(plan.seeding!), '$q J[] WC[]');
      }
    });
  });

  group('21.8 peringkat akhir 3 grup', () {
    test('AC-G27 16G-akhir / 23k–23l: Juara 1–3, wildcard "Perempat final", Umar "Grup C · 3", Gita "Grup A · 4"', () {
      final a = _groups16G();
      // Bagan 16G sesudah tukar dibangun tangan: `KnockoutBracket.build(Seeding)` milik GP-2.
      MatchGame ko(KnockoutRound r, int slot, int round, String x, String y, int sx, int sy) => MatchGame(
        id: 'k${r.index}$slot',
        roundNumber: round,
        matchNumberInRound: slot,
        courtId: 'c1',
        pair1: _pair16G(x),
        pair2: _pair16G(y),
        phase: KnockoutPhase(r, slot),
      ).withScore([SetScore(side1: sx, side2: sy)]);
      const qf = KnockoutRound.quarterfinal;
      final done = a.withMatches([
        ...a.matches,
        ko(qf, 1, 13, 'Andi', 'Kiki', 4, 2),
        ko(qf, 2, 13, 'Sari', 'Maya', 3, 4),
        ko(qf, 3, 14, 'Qori', 'Eko', 4, 1),
        ko(qf, 4, 14, 'Indra', 'Citra', 3, 4),
        ko(KnockoutRound.semifinal, 1, 15, 'Andi', 'Maya', 5, 3),
        ko(KnockoutRound.semifinal, 2, 15, 'Qori', 'Citra', 5, 4),
        ko(KnockoutRound.finalRound, 1, 16, 'Andi', 'Qori', 6, 4),
        ko(KnockoutRound.thirdPlace, 1, 16, 'Maya', 'Citra', 5, 2),
      ]);
      expect(_final(done), [
        '#1 Andi Juara 1',
        '#2 Qori Juara 2',
        '#3 Maya Juara 3',
        '#4 Citra Semifinal',
        '#5 Eko Perempat final',
        '#5 Indra Perempat final',
        '#5 Kiki Perempat final',
        '#5 Sari Perempat final',
        '#6 Umar Grup C · 3',
        '#7 Gita Grup A · 4',
        '#7 Oki Grup B · 4',
        '#7 Wawan Grup C · 4',
      ]);
    });
  });
}
