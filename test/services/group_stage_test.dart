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

/// 16G (PRD §16, 3.10.0): 24 pemain, 3 grup × 4; id = nama pemain pertama.
const _g16G = [
  ['Andi', 'Citra', 'Eko', 'Gita'],
  ['Indra', 'Kiki', 'Maya', 'Oki'],
  ['Qori', 'Sari', 'Umar', 'Wawan'],
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

    test('21.2 sizes 3 grup: 13 → [5, 4, 4], 14 → [5, 5, 4], 16 → [6, 5, 5]; 16/4 → [4, 4, 4, 4]; 9/2 → [5, 4]', () {
      expect(GroupStage.sizes(13, 3), [5, 4, 4]);
      expect(GroupStage.sizes(14, 3), [5, 5, 4]);
      expect(GroupStage.sizes(16, 3), [6, 5, 5]);
      expect(GroupStage.sizes(16, 4), [4, 4, 4, 4]);
      expect(GroupStage.sizes(9, 2), [5, 4]);
    });

    // Menggantikan AC-G1 3.8.x (min 3 pasangan per grup, 2/4 grup): min 4 per grup (AC-G29: diganti, bukan dilonggarkan).
    test('AC-G21 groupCountsFor: 14 pemain tidak ada, 16–22 [2], 24–30 [2, 3], 32 [2, 3, 4]', () {
      List<int> forPlayers(int players) => GroupStage.groupCountsFor(players ~/ 2);
      expect(forPlayers(14), isEmpty);
      expect(GroupStage.groupCountsFor(0), isEmpty);
      for (final n in [16, 17, 18, 20, 22, 23]) {
        expect(forPlayers(n), [2], reason: '$n pemain');
      }
      for (final n in [24, 25, 26, 28, 30, 31]) {
        expect(forPlayers(n), [2, 3], reason: '$n pemain');
      }
      expect(forPlayers(32), [2, 3, 4]);
      expect(GroupStage.groupCountsFor(17), isEmpty, reason: 'P > 16 tidak mungkin');
    });

    test('AC-G21 19c unavailableReason: 3 grup "Mulai 24 pemain", 4 grup "Tepat 32 pemain", yang tersedia null', () {
      expect(GroupStage.unavailableReason(3, 11), 'Mulai 24 pemain');
      expect(GroupStage.unavailableReason(4, 15), 'Tepat 32 pemain');
      expect(GroupStage.unavailableReason(4, 12), 'Tepat 32 pemain');
      expect(GroupStage.unavailableReason(2, 8), isNull);
      expect(GroupStage.unavailableReason(3, 12), isNull);
      expect(GroupStage.unavailableReason(3, 16), isNull);
      expect(GroupStage.unavailableReason(4, 16), isNull);
    });

    test('AC-G21 GP9 19d fallbackGroupCount: 3 grup 24 → 20 = 2; 4 grup 32 → 30 = 3, → 22 = 2; < 16 pemain null', () {
      expect(GroupStage.fallbackGroupCount(20 ~/ 2, 3), 2);
      expect(GroupStage.fallbackGroupCount(30 ~/ 2, 4), 3);
      expect(GroupStage.fallbackGroupCount(22 ~/ 2, 4), 2);
      expect(GroupStage.fallbackGroupCount(14 ~/ 2, 2), isNull);
      expect(GroupStage.fallbackGroupCount(32 ~/ 2, 4), 4);
      expect(GroupStage.fallbackGroupCount(26 ~/ 2, 2), 2);
    });

    test('21.9 decodableGroupCounts: 6–11 [2], 12–16 [2, 3, 4], di luar itu [] (W4: P = 17 ditolak)', () {
      for (var p = 0; p < 6; p++) {
        expect(GroupStage.decodableGroupCounts(p), isEmpty, reason: 'P $p');
      }
      for (var p = 6; p <= 11; p++) {
        expect(GroupStage.decodableGroupCounts(p), [2], reason: 'P $p');
      }
      for (var p = 12; p <= 16; p++) {
        expect(GroupStage.decodableGroupCounts(p), [2, 3, 4], reason: 'P $p');
      }
      expect(GroupStage.decodableGroupCounts(17), isEmpty);
      // Superset groupCountsFor: semua yang bisa dibuat app baru juga terbaca.
      for (var p = 0; p <= 17; p++) {
        expect(GroupStage.decodableGroupCounts(p), containsAll(GroupStage.groupCountsFor(p)), reason: 'P $p');
      }
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

    test('AC-G23 16G 2 court: Court 1 A di R ganjil, C di R genap R1–R12; Court 2 hanya B R1–R6 (20p, 23b)', () {
      final matches = GroupStage.schedule(groups: _groups(_g16G), courts: _courts(2, hours: 3));
      expect(
        [for (final m in matches.where((m) => m.courtId == 'c1')) '${m.roundNumber}${m.phase!.code}'],
        [for (var r = 1; r <= 12; r++) '$r${r.isOdd ? 'A' : 'C'}'],
      );
      final court2 = matches.where((m) => m.courtId == 'c2');
      expect([for (final m in court2) m.roundNumber], [1, 2, 3, 4, 5, 6]);
      expect(court2.every((m) => m.phase == const GroupPhase(1)), isTrue);
      final r12 = matches.where((m) => m.roundNumber == 12).single;
      expect('${r12.pair1.id}–${r12.pair2.id}', 'Umar–Wawan');
      expect(matches.last.roundNumber, 12);
    });

    test('AC-G23 16G varian 3 court: A C1, B C2, C C3, R1–R6', () {
      final matches = GroupStage.schedule(groups: _groups(_g16G), courts: _courts(3, hours: 3));
      for (final (g, court) in [(0, 'c1'), (1, 'c2'), (2, 'c3')]) {
        expect(matches.where((m) => m.phase == GroupPhase(g)).every((m) => m.courtId == court), isTrue);
      }
      expect(matches.last.roundNumber, 6);
    });

    // PRD 16.4 "B dan C habis di R30": bergantian A, B, C (GU4) → B match ke-10 di R29, C di R30; A lanjut R31–R35.
    test('16.4 32 pemain 3 grup 1 court [6, 5, 5]: B dan C habis R29/R30, A R31–R35, fase grup 35 round', () {
      final groups = [
        for (final (g, n) in GroupStage.sizes(16, 3).indexed) [for (var i = 0; i < n; i++) '${'ABC'[g]}$i'],
      ];
      final matches = GroupStage.schedule(groups: _groups(groups), courts: _courts(1));
      expect(matches.lastWhere((m) => m.phase == const GroupPhase(1)).roundNumber, 29);
      expect(matches.lastWhere((m) => m.phase == const GroupPhase(2)).roundNumber, 30);
      expect([for (final m in matches.where((m) => m.roundNumber >= 31)) m.phase!.code], List.filled(5, 'A'));
      expect(matches.last.roundNumber, 35);
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
      ('AC-G5 16C 30 pemain 2 grup 4 court 4 jam', 30, 2, 4, 4, 15, true, 16, 53, 0),
      ('16.4 30 pemain 2 grup 1 court', 30, 2, 1, 2, 15, true, 53, 53, 45 * 15),
      // 3.10.0 (logic.md §21.2): 3 grup + Perempat final; 4 grup hanya 32 pemain. Kasus 3.8.x 4 grup × 3 pasangan
      // (24/26/30 pemain) dan 12 pemain 2 grup tidak ditawarkan lagi (AC-G21), diganti baris tabel 21.2.
      ('AC-G23 19i 16G 24 pemain 3 grup 2 court 3 jam', 24, 3, 2, 3, 15, true, 16, 26, 60),
      ('AC-G23 16G varian 3 court', 24, 3, 3, 3, 15, true, 10, 26, 0),
      ('AC-G21a 23a 32 pemain 4 grup 2 court 3 jam', 32, 4, 2, 3, 15, true, 16, 32, 60),
      ('AC-G21a 32 pemain 4 grup 1 court', 32, 4, 1, 3, 15, true, 32, 32, 20 * 15),
      ('AC-G21a 32 pemain 4 grup 4 court', 32, 4, 4, 3, 15, true, 9, 32, 0),
      ('16.4 32 pemain 3 grup 1 court [6, 5, 5]', 32, 3, 1, 3, 15, true, 43, 43, 31 * 15),
      ('AC-G21a 32 pemain 2 grup 1 court [8, 8]', 32, 2, 1, 3, 15, true, 60, 60, 48 * 15),
      ('16.4 30 pemain 3 grup 1 court [5, 5, 5]', 30, 3, 1, 3, 15, true, 38, 38, 26 * 15),
      ('16G 3 grup tanpa juara 3, 2 court', 24, 3, 2, 3, 15, false, 16, 25, 60),
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
      expect(est(24, 4), (rounds: 0, matches: 0, overMinutes: 0), reason: '4 grup hanya 32 pemain (AC-G21)');
      expect(est(22, 3), (rounds: 0, matches: 0, overMinutes: 0));
      expect(est(14, 2), (rounds: 0, matches: 0, overMinutes: 0));
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
      thirdPlace: true,
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
      const three = GroupKnockout(groupCount: 3, formats: {}, thirdPlace: true);
      expect(three.rounds, [
        KnockoutRound.quarterfinal,
        KnockoutRound.semifinal,
        KnockoutRound.thirdPlace,
        KnockoutRound.finalRound,
      ]);
      expect(three.wildcards, isEmpty);
    });

    test('jebakan 21.12 #1: GroupKnockout.copyWith membawa wildcards, formats, thirdPlace, groups', () {
      final three = GroupKnockout(
        groupCount: 3,
        groups: const [
          ['Andi', 'Citra', 'Eko', 'Gita'],
          ['Indra', 'Kiki', 'Maya', 'Oki'],
          ['Qori', 'Sari', 'Umar', 'Wawan'],
        ],
        formats: {...gk.formats, KnockoutRound.quarterfinal: const ScoreFormat(ScoringMethod.raceTo, 4)},
        thirdPlace: false,
      ).copyWith(wildcards: const ['Eko', 'Kiki']);
      expect(three.wildcards, ['Eko', 'Kiki']);
      final formatChanged = three.copyWith(formats: gk.formats);
      expect(formatChanged.wildcards, ['Eko', 'Kiki']);
      expect(formatChanged.thirdPlace, isFalse);
      expect(formatChanged.groupCount, 3);
      final thirdOn = three.copyWith(thirdPlace: true);
      expect(thirdOn.wildcards, ['Eko', 'Kiki']);
      expect(thirdOn.formats, three.formats);
      expect(thirdOn.groups, three.groups);
      expect(three.copyWith(groups: three.groups).wildcards, ['Eko', 'Kiki']);
      expect(three.copyWith(wildcards: const []).wildcards, isEmpty);
    });

    test('21.1 Seeding: 2/4 grup tanpa juara/wildcard; 3 grup membawa J1–J3 dan WC1, WC2', () {
      const two = Seeding(
        groupSlots: [
          ['Andi', 'Eko'],
          ['Indra', 'Kiki'],
        ],
      );
      expect(two.champions, isEmpty);
      expect(two.wildcards, isEmpty);
      const three = Seeding(
        groupSlots: [
          ['Andi', 'Citra'],
          ['Indra', 'Maya'],
          ['Qori', 'Sari'],
        ],
        champions: [0, 2, 1],
        wildcards: ['Eko', 'Kiki'],
      );
      expect(three.champions, [0, 2, 1]);
      expect(three.wildcards, ['Eko', 'Kiki']);
      expect(three.groupSlots[2], ['Qori', 'Sari']);
    });

    test('GroupKnockout.copyWith(groups: …) mempertahankan thirdPlace false dan formats', () {
      final off = gk.copyWith(thirdPlace: false);
      final regrouped = off.copyWith(
        groups: const [
          ['Andi', 'Eko', 'Citra', 'Gita'],
          ['Indra', 'Kiki', 'Maya', 'Oki'],
        ],
      );
      expect(regrouped.thirdPlace, isFalse);
      expect(regrouped.formats, gk.formats);
      expect(regrouped.groupCount, 2);
      expect(regrouped.groups.first, ['Andi', 'Eko', 'Citra', 'Gita']);
    });

    test('21.1 KnockoutRound label, shortLabel, codePrefix UI "QF" vs kode simpanan "PF", tabLabel; MatchPhase ==', () {
      expect(
        [for (final r in KnockoutRound.values) r.label],
        ['Perempat final', 'Semifinal', 'Perebutan juara 3', 'Final'],
      );
      expect(KnockoutRound.thirdPlace.shortLabel, 'Juara 3');
      expect(KnockoutRound.finalRound.shortLabel, 'Final');
      expect([for (final r in KnockoutRound.values) r.codePrefix], ['QF', 'SF', null, null]);
      expect([for (final r in KnockoutRound.values) r.tabLabel], ['QF', 'SF', 'Juara 3', 'Final']);
      expect(
        [
          const GroupPhase(3).code,
          const KnockoutPhase(KnockoutRound.quarterfinal, 1).code,
          const KnockoutPhase(KnockoutRound.semifinal, 2).code,
          const KnockoutPhase(KnockoutRound.finalRound, 1).code,
          const KnockoutPhase(KnockoutRound.thirdPlace, 1).code,
        ],
        ['D', 'PF1', 'SF2', 'F', 'J3'],
        reason: 'kode simpanan tetap "PF" (keputusan 152, §21.9)',
      );
      expect(
        [for (var s = 1; s <= 4; s++) KnockoutPhase(KnockoutRound.quarterfinal, s).code],
        ['PF1', 'PF2', 'PF3', 'PF4'],
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
