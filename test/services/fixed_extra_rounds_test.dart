import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';

List<Pair> _pairs(int n) => [for (var i = 0; i < n; i++) Pair(id: 'pair$i', player1Id: 'p${i}a', player2Id: 'p${i}b')];

List<Court> _courts(int n) => [
  for (var i = 0; i < n; i++) Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: 240),
];

String _key(MatchGame m) => ([m.pair1.id, m.pair2.id]..sort()).join('|');

Map<String, int> _playedPerPair(Iterable<MatchGame> matches) {
  final count = <String, int>{};
  for (final m in matches) {
    for (final id in [m.pair1.id, m.pair2.id]) {
      count[id] = (count[id] ?? 0) + 1;
    }
  }
  return count;
}

({FixedSchedule schedule, int putaran}) _extend(int pairs, List<int> roundsLeft, {int done = 0, int first = 1}) =>
    RoundRobinGenerator.extend(
      pairs: _pairs(pairs),
      courts: _courts(roundsLeft.length),
      roundsLeft: roundsLeft,
      putaranDone: done,
      firstRound: first,
    );

void main() {
  group('Round tambahan Fixed (logic.md §12)', () {
    test('TBNE36: 8 pasangan, 2 court, sisa 30 menit (2 round) → R15–R16, tiap pasangan +1, lawan R1–R2', () {
      final rr = RoundRobinGenerator.generate(pairs: _pairs(8), courts: _courts(2));
      expect(rr.roundCount, 14);

      final extra = _extend(8, [2, 2], first: 15);
      expect(extra.putaran, 1);
      expect(extra.schedule.matches.map((m) => m.roundNumber).toSet(), {15, 16});
      expect(_playedPerPair(extra.schedule.matches).values, everyElement(1));
      expect(_playedPerPair(extra.schedule.matches), hasLength(8));
      // Mengulang round-robin dari awal: lawan dan court sama dengan R1–R2.
      final firstTwo = rr.matches.where((m) => m.roundNumber <= 2).toList();
      expect([for (final m in extra.schedule.matches) '${m.courtId} ${_key(m)}'], [
        for (final m in firstTwo) '${m.courtId} ${_key(m)}',
      ]);
      expect(extra.schedule.byePairIdByRound, isEmpty);
    });

    test('sisa 45 menit (3 round) dibulatkan ke atas: 2 putaran, R15–R18, lewat satu round', () {
      final extra = _extend(8, [3, 3], first: 15);
      expect(extra.putaran, 2);
      expect(extra.schedule.roundCount, 18);
      expect(_playedPerPair(extra.schedule.matches).values, everyElement(2));
      // Dua putaran berturut-turut tidak mengulang lawan.
      expect(extra.schedule.matches.map(_key).toSet(), hasLength(8));
    });

    test('court yang habis lebih dulu berhenti dipakai: Court 1 +1 jam, Court 2 sisa 2 round', () {
      final extra = _extend(8, [6, 2], first: 15);
      expect(extra.putaran, 2);
      final byRound = <int, List<String>>{};
      for (final m in extra.schedule.matches) {
        byRound.putIfAbsent(m.roundNumber, () => []).add(m.courtId);
      }
      expect(byRound, {
        15: ['c1', 'c2'],
        16: ['c1', 'c2'],
        17: ['c1'],
        18: ['c1'],
        19: ['c1'],
        20: ['c1'],
      });
    });

    test('lewat booking: court yang paling lama tetap dipakai', () {
      // Court 1 masih muat 1 round, Court 2 habis: satu putaran (4 match) di Court 1 saja.
      final extra = _extend(8, [1, 0], first: 15);
      expect(extra.putaran, 1);
      expect(extra.schedule.matches.map((m) => m.courtId), everyElement('c1'));
      expect(extra.schedule.roundCount, 18);
    });

    test('tidak ada court yang muat satu round → kosong', () {
      final extra = _extend(8, [0, 0], first: 15);
      expect(extra.putaran, 0);
      expect(extra.schedule.matches, isEmpty);
    });

    test('pasangan ganjil: tiap pasangan +2, satu istirahat di dua round pertama', () {
      // Frame 06a–06e: 5 pasangan, 2 court, R1–R5.
      final extra = _extend(5, [1, 1], first: 6);
      expect(extra.putaran, 1);
      final matches = extra.schedule.matches;
      expect(matches, hasLength(5));
      expect(_playedPerPair(matches).values, everyElement(2));
      expect([for (var r = 6; r <= 8; r++) matches.where((m) => m.roundNumber == r).length], [2, 2, 1]);
      expect(extra.schedule.byePairIdByRound.keys, [6, 7]);
      for (final MapEntry(key: round, value: bye) in extra.schedule.byePairIdByRound.entries) {
        expect(matches.where((m) => m.roundNumber == round).expand((m) => [m.pair1.id, m.pair2.id]), isNot(contains(bye)));
      }
    });

    for (final n in [2, 3, 4, 5, 6, 7, 8, 9, 11, 15]) {
      test('$n pasangan: putaran tambahan berturut-turut = round-robin kedua tanpa lawan ketiga kali', () {
        final cycle = n.isEven ? n - 1 : (n - 1) ~/ 2;
        final perPutaran = RoundRobinGenerator.matchesPerPutaran(n);
        // Court cukup untuk satu putaran per round-nya; round sebanyak putaran × round per putaran.
        final one = _extend(n, [1, 1, 1]);
        final rounds = one.schedule.roundCount * cycle;
        final extra = _extend(n, [rounds, rounds, rounds]);
        expect(extra.putaran, cycle);
        expect(extra.schedule.matches, hasLength(cycle * perPutaran));
        final keys = extra.schedule.matches.map(_key).toList();
        expect(keys.toSet(), hasLength(n * (n - 1) ~/ 2), reason: 'setiap lawan tepat sekali');
        expect(keys, hasLength(n * (n - 1) ~/ 2));
        expect(_playedPerPair(extra.schedule.matches).values, everyElement(n - 1));
      });
    }

    test('tidak ada pasangan yang main dua kali dalam satu round', () {
      for (final n in [5, 7, 8, 9]) {
        final extra = _extend(n, [8, 5, 3]);
        final byRound = <int, List<String>>{};
        for (final m in extra.schedule.matches) {
          byRound.putIfAbsent(m.roundNumber, () => []).addAll([m.pair1.id, m.pair2.id]);
        }
        for (final ids in byRound.values) {
          expect(ids.toSet(), hasLength(ids.length));
        }
      }
    });

    test('tambahan berikutnya melanjutkan urutan putaran', () {
      final both = _extend(7, [1], first: 1);
      final twice = RoundRobinGenerator.extend(
        pairs: _pairs(7),
        courts: _courts(1),
        roundsLeft: [both.schedule.roundCount + 1],
        putaranDone: 0,
        firstRound: 1,
      );
      expect(twice.putaran, 2);
      final second = _extend(7, [1], done: 1, first: both.schedule.roundCount + 1);
      expect(
        second.schedule.matches.map(_key),
        twice.schedule.matches.skip(both.schedule.matches.length).map(_key),
      );
    });
  });
}
