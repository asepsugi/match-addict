import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';

List<Pair> _pairs(int n) => [
      for (var i = 0; i < n; i++)
        Pair(id: 'pair$i', player1Id: 'p${i}a', player2Id: 'p${i}b'),
    ];

List<Court> _courts(int n) => [
      for (var i = 0; i < n; i++)
        Court(id: 'court$i', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: 120),
    ];

void main() {
  group('RoundRobinGenerator', () {
    test('every pair meets every other pair exactly once', () {
      final schedule = RoundRobinGenerator.generate(pairs: _pairs(4), courts: _courts(2));

      expect(schedule.matches, hasLength(6)); // C(4,2)
      final seen = schedule.matches
          .map((m) => ([m.pair1.id, m.pair2.id]..sort()).join('|'))
          .toList();
      expect(seen.toSet(), hasLength(6));
    });

    test('splits a circle round into court-sized rounds', () {
      // 6 pair → 3 pertandingan per putaran, 1 court → 1 pertandingan per round.
      final schedule = RoundRobinGenerator.generate(pairs: _pairs(6), courts: _courts(1));
      expect(schedule.matches, hasLength(15));
      expect(schedule.roundCount, 15);
      for (final m in schedule.matches) {
        expect(m.matchNumberInRound, 1);
      }
    });

    test('no pair plays twice inside one round', () {
      final schedule = RoundRobinGenerator.generate(pairs: _pairs(8), courts: _courts(3));
      final byRound = <int, List<String>>{};
      for (final m in schedule.matches) {
        byRound.putIfAbsent(m.roundNumber, () => []).addAll([m.pair1.id, m.pair2.id]);
      }
      for (final entry in byRound.entries) {
        expect(entry.value.toSet(), hasLength(entry.value.length),
            reason: 'round ${entry.key} punya pair dobel');
      }
    });

    test('marks a bye pair when the pair count is odd', () {
      final schedule = RoundRobinGenerator.generate(pairs: _pairs(5), courts: _courts(2));

      expect(schedule.matches, hasLength(10)); // C(5,2)
      expect(schedule.byePairIdByRound, isNotEmpty);

      // Pair yang bye di sebuah round memang tidak main di round itu.
      for (final entry in schedule.byePairIdByRound.entries) {
        final playing = schedule.matches
            .where((m) => m.roundNumber == entry.key)
            .expand((m) => [m.pair1.id, m.pair2.id]);
        expect(playing, isNot(contains(entry.value)));
      }
    });

    test('assigns matches to courts in order', () {
      final courts = _courts(2);
      final schedule = RoundRobinGenerator.generate(pairs: _pairs(4), courts: courts);
      for (final m in schedule.matches) {
        expect(m.courtId, courts[m.matchNumberInRound - 1].id);
      }
    });

    test('returns nothing when there are fewer than two pairs', () {
      expect(
        RoundRobinGenerator.generate(pairs: _pairs(1), courts: _courts(2)).matches,
        isEmpty,
      );
    });
  });
}
