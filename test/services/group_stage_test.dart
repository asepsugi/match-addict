import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/group_stage.dart';

/// Grup + Gugur fase grup (design/spec/logic.md §18.1–18.5). Id pasangan = nama pemain pertama; grup = PRD 16A,
/// 16B, 16C dalam urutan masuk layar Grup.

Pair _pair(String name) => Pair(id: name, player1Id: name, player2Id: '$name-2');

List<List<Pair>> _groups(List<List<String>> names) => [
  for (final g in names) [for (final n in g) _pair(n)],
];

List<Court> _courts(int n, {int hours = 2}) => [
  for (var i = 0; i < n; i++)
    Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: hours * 60),
];

const _g16A = [
  ['Andi', 'Citra', 'Eko', 'Gita'],
  ['Indra', 'Kiki', 'Maya', 'Oki'],
];

const _g16B = [
  ['Andi', 'Citra', 'Eko'],
  ['Gita', 'Indra', 'Kiki'],
  ['Maya', 'Rudi', 'Oki'],
  ['Tono', 'Qori', 'Vina'],
];

const _g16C = [
  ['Andi', 'Citra', 'Eko', 'Gita', 'Indra', 'Kiki', 'Maya', 'Oki'],
  ['Qori', 'Sari', 'Umar', 'Wawan', 'Zaki', 'Bayu', 'Dodi'],
];

/// "R1 Andi–Gita (A)" per court, urut round.
List<String> _onCourt(List<MatchGame> matches, String courtId) => [
  for (final m in matches)
    if (m.courtId == courtId) 'R${m.roundNumber} ${m.pair1.id}–${m.pair2.id} (${m.phase!.code})',
];

void main() {
  group('18.2 ukuran grup', () {
    test('sizes: grup awal mendapat sisa', () {
      expect(GroupStage.sizes(7, 2), [4, 3]);
      expect(GroupStage.sizes(11, 2), [6, 5]);
      expect(GroupStage.sizes(13, 4), [4, 3, 3, 3]);
      expect(GroupStage.sizes(15, 4), [4, 4, 4, 3]);
      expect(GroupStage.sizes(15, 2), [8, 7]);
      expect(GroupStage.sizes(12, 4), [3, 3, 3, 3]);
    });

    test('AC-G1 groupCountsFor: 10 pemain tidak ada, 22 pemain hanya 2 grup, 24 pemain 2/4', () {
      expect(GroupStage.groupCountsFor(5), isEmpty);
      expect(GroupStage.groupCountsFor(6), [2]);
      expect(GroupStage.groupCountsFor(11), [2]);
      expect(GroupStage.groupCountsFor(12), [2, 4]);
      expect(GroupStage.groupCountsFor(15), [2, 4]);
      expect(GroupStage.groupCountsFor(17 ~/ 2), [2]); // 19q: 17 pemain → 8 pasangan
    });
  });

  group('18.3 court per grup', () {
    final cases = <(String, List<int>, int, List<List<int>>, int)>[
      (
        'AC-G3 16A, 2 court',
        [4, 4],
        2,
        [
          [0],
          [1],
        ],
        6,
      ),
      (
        'AC-G3 16A, 1 court',
        [4, 4],
        1,
        [
          [0],
          [0],
        ],
        12,
      ),
      (
        'AC-G4 16B, 2 court',
        [3, 3, 3, 3],
        2,
        [
          [0],
          [1],
          [0],
          [1],
        ],
        6,
      ),
      (
        'AC-G4 16B varian 3 court, 13 pasangan',
        [4, 3, 3, 3],
        3,
        [
          [0],
          [1],
          [2],
          [1],
        ],
        6,
      ),
      (
        'AC-G5 16C, 30 pemain 4 court',
        [8, 7],
        4,
        [
          [0, 2],
          [1, 3],
        ],
        14,
      ),
      (
        'AC-G5 12 pemain, 3 court: C3 tidak dipakai',
        [3, 3],
        3,
        [
          [0],
          [1],
        ],
        3,
      ),
      (
        '16.4 30 pemain 2 grup 1 court',
        [8, 7],
        1,
        [
          [0],
          [0],
        ],
        49,
      ),
      (
        '16.4 30 pemain 4 grup 1 court',
        [4, 4, 4, 3],
        1,
        [
          [0],
          [0],
          [0],
          [0],
        ],
        21,
      ),
      (
        '16.4 14 pemain 2 court',
        [4, 3],
        2,
        [
          [0],
          [1],
        ],
        6,
      ),
    ];
    for (final (name, sizes, courts, owned, rounds) in cases) {
      test(name, () {
        expect(GroupStage.courtsOfGroups(sizes, courts), owned);
        expect(GroupStage.groupPhaseRounds(sizes, courts), rounds);
      });
    }
  });

  group('18.4 jadwal fase grup', () {
    test('AC-G3 16A R1–R6: Court 1 hanya Grup A, Court 2 hanya Grup B, tiap pasangan 3 match (20a, 20c)', () {
      final matches = GroupStage.schedule(groups: _groups(_g16A), courts: _courts(2));
      expect(_onCourt(matches, 'c1'), [
        'R1 Andi–Gita (A)',
        'R2 Citra–Eko (A)',
        'R3 Andi–Eko (A)',
        'R4 Gita–Citra (A)',
        'R5 Andi–Citra (A)',
        'R6 Eko–Gita (A)',
      ]);
      expect(_onCourt(matches, 'c2'), [
        'R1 Indra–Oki (B)',
        'R2 Kiki–Maya (B)',
        'R3 Indra–Maya (B)',
        'R4 Oki–Kiki (B)',
        'R5 Indra–Kiki (B)',
        'R6 Maya–Oki (B)',
      ]);
      for (final n in [..._g16A[0], ..._g16A[1]]) {
        expect(matches.where((m) => m.pair1.id == n || m.pair2.id == n), hasLength(3), reason: n);
      }
      expect([for (final m in matches.take(2)) (m.id, m.matchNumberInRound)], [('m-r1-1', 1), ('m-r1-2', 2)]);
    });

    test('AC-G3 16A 1 court: bergantian A, B, A, B sampai R12', () {
      final c1 = _onCourt(GroupStage.schedule(groups: _groups(_g16A), courts: _courts(1)), 'c1');
      expect(c1, hasLength(12));
      expect(c1.take(3), ['R1 Andi–Gita (A)', 'R2 Indra–Oki (B)', 'R3 Citra–Eko (A)']);
      expect(c1.last, 'R12 Maya–Oki (B)');
      for (final (i, row) in c1.indexed) {
        expect(row.endsWith(i.isEven ? '(A)' : '(B)'), isTrue, reason: row);
      }
    });

    test('AC-G4 16B: Court 1 A/C bergantian, Court 2 B/D (20m, 20o)', () {
      final matches = GroupStage.schedule(groups: _groups(_g16B), courts: _courts(2, hours: 3));
      expect(_onCourt(matches, 'c1'), [
        'R1 Citra–Eko (A)',
        'R2 Rudi–Oki (C)',
        'R3 Andi–Eko (A)',
        'R4 Maya–Oki (C)',
        'R5 Andi–Citra (A)',
        'R6 Maya–Rudi (C)',
      ]);
      expect(_onCourt(matches, 'c2'), [
        'R1 Indra–Kiki (B)',
        'R2 Qori–Vina (D)',
        'R3 Gita–Kiki (B)',
        'R4 Tono–Vina (D)',
        'R5 Gita–Indra (B)',
        'R6 Tono–Qori (D)',
      ]);
      // Sifat contoh ini (bukan invariant umum): tidak ada pasangan main di dua round beruntun.
      final roundsOf = <String, List<int>>{};
      for (final m in matches) {
        for (final p in [m.pair1.id, m.pair2.id]) {
          (roundsOf[p] ??= []).add(m.roundNumber);
        }
      }
      for (final MapEntry(:key, :value) in roundsOf.entries) {
        for (var i = 1; i < value.length; i++) {
          expect(value[i] - value[i - 1], greaterThan(1), reason: key);
        }
      }
    });

    test('AC-G4 16B varian 3 court, 13 pasangan: Court 3 kosong setelah R3', () {
      final groups = _groups([
        ['Andi', 'Citra', 'Eko', 'Gita'],
        ..._g16B.skip(1),
      ]);
      final matches = GroupStage.schedule(groups: groups, courts: _courts(3));
      expect(matches.last.roundNumber, 6);
      expect(_onCourt(matches, 'c3'), ['R1 Rudi–Oki (C)', 'R2 Maya–Oki (C)', 'R3 Maya–Rudi (C)']);
    });

    test('AC-G5 16C R1: C1 Andi–Oki, C2 Sari–Dodi, C3 Citra–Maya, C4 Umar–Bayu; R2 C4 kosong; Qori bye (20p)', () {
      final matches = GroupStage.schedule(groups: _groups(_g16C), courts: _courts(4, hours: 4));
      String row(MatchGame m) => '${m.courtId} ${m.pair1.id}–${m.pair2.id} (${m.phase!.code}) #${m.matchNumberInRound}';
      expect(
        [for (final m in matches.where((m) => m.roundNumber == 1)) row(m)],
        ['c1 Andi–Oki (A) #1', 'c2 Sari–Dodi (B) #2', 'c3 Citra–Maya (A) #3', 'c4 Umar–Bayu (B) #4'],
      );
      expect([for (final m in matches.where((m) => m.roundNumber == 2)) m.courtId], ['c1', 'c2', 'c3']);
      expect(matches.where((m) => m.roundNumber <= 2 && (m.pair1.id == 'Qori' || m.pair2.id == 'Qori')), isEmpty);
      expect(matches.last.roundNumber, 14);
    });

    test('16.4 30 pemain 2 grup 1 court: B habis R42, A R43–R49', () {
      final matches = GroupStage.schedule(groups: _groups(_g16C), courts: _courts(1));
      expect(matches.lastWhere((m) => m.phase == const GroupPhase(1)).roundNumber, 42);
      expect([for (final m in matches.where((m) => m.roundNumber >= 43)) m.phase!.code], List.filled(7, 'A'));
      expect(matches.last.roundNumber, 49);
    });
  });

  group('18.5 estimasi Konfigurasi', () {
    // (nama, pemain, grup, court, jam booking, durasi, juara 3, rounds, matches, over)
    final cases = <(String, int, int, int, int, int, bool, int, int, int)>[
      ('19b 16A, 2 court 2 jam, 15 mnt', 16, 2, 2, 2, 15, true, 8, 16, 0),
      ('19g 16A tanpa juara 3', 16, 2, 2, 2, 15, false, 8, 15, 0),
      ('19k 16A 1 court', 16, 2, 1, 2, 15, true, 16, 16, 120),
      ('19g 16A 1 court tanpa juara 3', 16, 2, 1, 2, 15, false, 15, 15, 105),
      ('AC-G4 19i 16B 24 pemain 4 grup 2 court 3 jam 20 mnt', 24, 4, 2, 3, 20, true, 10, 20, 20),
      ('AC-G4 16B varian 26 pemain 4 grup 3 court', 26, 4, 3, 3, 20, true, 10, 23, 20),
      ('AC-G5 16C 30 pemain 2 grup 4 court 4 jam', 30, 2, 4, 4, 15, true, 16, 53, 0),
      ('AC-G5 12 pemain 2 grup 3 court 2 jam', 12, 2, 3, 2, 15, true, 5, 10, 0),
      ('16.4 30 pemain 2 grup 1 court', 30, 2, 1, 2, 15, true, 53, 53, 45 * 15),
      ('16.4 30 pemain 4 grup 1 court', 30, 4, 1, 2, 15, true, 29, 29, 21 * 15),
    ];
    for (final (name, players, groups, courts, hours, duration, third, rounds, matches, over) in cases) {
      test(name, () {
        final e = GroupStage.estimate(
          players: players,
          groups: groups,
          bookingMinutes: List.filled(courts, hours * 60),
          matchDurationMinutes: duration,
          thirdPlace: third,
        );
        expect((e.rounds, e.matches, e.overMinutes), (rounds, matches, over));
      });
    }

    test('19q: P = ⌊pemain ÷ 2⌋ (17 pemain = 8 pasangan); grup tidak ditawarkan → 0', () {
      ({int rounds, int matches, int overMinutes}) est(int players, int groups) => GroupStage.estimate(
        players: players,
        groups: groups,
        bookingMinutes: const [120, 120],
        matchDurationMinutes: 15,
        thirdPlace: true,
      );
      expect(est(17, 2), est(16, 2));
      expect(est(22, 4), (rounds: 0, matches: 0, overMinutes: 0));
      expect(est(10, 2), (rounds: 0, matches: 0, overMinutes: 0));
    });

    test('booking terpendek yang menentukan lewat booking', () {
      final e = GroupStage.estimate(
        players: 16,
        groups: 2,
        bookingMinutes: const [120, 90],
        matchDurationMinutes: 15,
        thirdPlace: true,
      );
      expect(e.overMinutes, 2 * 15);
    });
  });

  group('18.1 model', () {
    final sf1 = MatchGame(
      id: 'm-r7-1',
      roundNumber: 7,
      matchNumberInRound: 1,
      courtId: 'c1',
      pair1: _pair('Andi'),
      pair2: _pair('Indra'),
      phase: const KnockoutPhase(KnockoutRound.semifinal, 1),
    );

    test('jebakan #1: withScore/asWalkover/copyWith mempertahankan phase', () {
      const phase = KnockoutPhase(KnockoutRound.semifinal, 1);
      expect(sf1.withScore(const [SetScore(side1: 6, side2: 4)]).phase, phase);
      expect(sf1.asWalkover(loserPairId: 'Indra').phase, phase);
      expect(sf1.copyWith(status: MatchStatus.cancelled).phase, phase);
    });

    final gk = GroupKnockout(
      groupCount: 2,
      groups: [
        ['Andi', 'Citra', 'Eko', 'Gita'],
        ['Indra', 'Kiki', 'Maya', 'Oki'],
      ],
      formats: const {
        KnockoutRound.semifinal: ScoreFormat(ScoringMethod.raceTo, 6),
        KnockoutRound.thirdPlace: ScoreFormat(ScoringMethod.raceTo, 4),
        KnockoutRound.finalRound: ScoreFormat(ScoringMethod.raceTo, 9),
      },
    );
    final config = TournamentConfig(
      sport: SportType.padel,
      mode: PartnerMode.fixed,
      matchDurationMinutes: 15,
      courts: _courts(2),
      players: const [],
      groupKnockout: gk,
    );

    test('jebakan #1: config.copyWith(players: …) tetap Grup + Gugur', () {
      final copy = config.copyWith(
        players: const [Player(id: 'x', name: 'X')],
        courts: _courts(1),
      );
      expect(copy.isGroupKnockout, isTrue);
      expect(identical(copy.groupKnockout, gk), isTrue);
      expect(
        const TournamentConfig(
          sport: SportType.padel,
          mode: PartnerMode.fixed,
          matchDurationMinutes: 15,
          courts: [],
          players: [],
        ).isGroupKnockout,
        isFalse,
      );
    });

    test('formatFor: gugur → format babak, grup/lainnya → config.format', () {
      expect(config.formatFor(sf1), const ScoreFormat(ScoringMethod.raceTo, 6));
      final fin = MatchGame(
        id: 'f',
        roundNumber: 8,
        matchNumberInRound: 1,
        courtId: 'c1',
        pair1: Pair.tbd,
        pair2: Pair.tbd,
        phase: const KnockoutPhase(KnockoutRound.finalRound, 1),
      );
      expect(config.formatFor(fin).label, 'Race to 9');
      final grp = GroupStage.schedule(groups: _groups(_g16A), courts: _courts(2)).first;
      expect(config.formatFor(grp), config.format);
    });

    test('GroupKnockout helper: letter, groupOfPair, rounds', () {
      expect([for (var g = 0; g < 4; g++) GroupKnockout.letter(g)], ['A', 'B', 'C', 'D']);
      expect(gk.groupOfPair('Kiki'), 1);
      expect(gk.groupOfPair('Zaki'), isNull);
      expect(gk.rounds, [KnockoutRound.semifinal, KnockoutRound.thirdPlace, KnockoutRound.finalRound]);
      const four = GroupKnockout(groupCount: 4, formats: {}, thirdPlace: false);
      expect(four.rounds, [KnockoutRound.quarterfinal, KnockoutRound.semifinal, KnockoutRound.finalRound]);
    });

    test('KnockoutRound label, shortLabel, codePrefix; MatchPhase code dan ==', () {
      expect(
        [for (final r in KnockoutRound.values) r.label],
        ['Perempat final', 'Semifinal', 'Perebutan juara 3', 'Final'],
      );
      expect(KnockoutRound.thirdPlace.shortLabel, 'Juara 3');
      expect(KnockoutRound.finalRound.shortLabel, 'Final');
      expect([for (final r in KnockoutRound.values) r.codePrefix], ['PF', 'SF', null, null]);
      expect(
        [
          const GroupPhase(3).code,
          const KnockoutPhase(KnockoutRound.quarterfinal, 1).code,
          const KnockoutPhase(KnockoutRound.semifinal, 2).code,
          const KnockoutPhase(KnockoutRound.finalRound, 1).code,
          const KnockoutPhase(KnockoutRound.thirdPlace, 1).code,
        ],
        ['D', 'PF1', 'SF2', 'F', 'J3'],
      );
      // ignore: prefer_const_constructors — sengaja instance berbeda untuk menguji kesamaan nilai.
      expect(KnockoutPhase(KnockoutRound.semifinal, 1), const KnockoutPhase(KnockoutRound.semifinal, 1));
      expect(const GroupPhase(0) == const GroupPhase(1), isFalse);
    });

    test('Pair.tbd, hasBracket, isGroupKnockoutLocked, StandingEntry.stage default null', () {
      expect(Pair.tbd.isTbd, isTrue);
      expect(_pair('Andi').isTbd, isFalse);
      final group = GroupStage.schedule(groups: _groups(_g16A), courts: _courts(2));
      Tournament t(List<MatchGame> m) => Tournament(id: 't', createdAt: DateTime(2026), config: config, matches: m);
      final before = ActiveTournament(tournament: t(group));
      expect(before.hasBracket, isFalse);
      expect(before.isGroupKnockoutLocked(group.first), isFalse);
      final after = ActiveTournament(tournament: t([...group, sf1]));
      expect(after.hasBracket, isTrue);
      expect(after.isGroupKnockoutLocked(group.first), isTrue);
      expect(after.isGroupKnockoutLocked(sf1), isFalse);
      expect(
        const StandingEntry(
          players: [],
          standing: PlayerStanding(
            player: Player(id: 'x', name: 'X'),
          ),
          position: 1,
        ).stage,
        isNull,
      );
    });
  });
}
