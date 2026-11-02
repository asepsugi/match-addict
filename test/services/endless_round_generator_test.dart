import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

List<Player> _players(int n) =>
    [for (var i = 0; i < n; i++) Player(id: 'p$i', name: 'Player $i')];

List<Court> _courts(int n) => [
      for (var i = 0; i < n; i++)
        Court(id: 'court$i', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: 120),
    ];

/// Jalankan beberapa round berturut-turut seperti pemakaian sebenarnya.
List<MatchGame> _play(List<Player> players, List<Court> courts, int rounds) {
  final history = <MatchGame>[];
  for (var r = 1; r <= rounds; r++) {
    final round = EndlessRoundGenerator.generateRound(
      seed: 7,
      players: players,
      courts: courts,
      history: history,
      roundNumber: r,
      random: Random(r),
    );
    history.addAll(round!.matches);
  }
  return history;
}

void main() {
  group('EndlessRoundGenerator', () {
    test('fills every court and rests the rest', () {
      final players = _players(10);
      final round = EndlessRoundGenerator.generateRound(
        seed: 7,
        players: players,
        courts: _courts(2),
        history: const [],
        roundNumber: 1,
        random: Random(7),
      )!;

      expect(round.matches, hasLength(2));
      expect(round.resting, hasLength(2));

      final playing = round.matches
          .expand((m) => [...m.pair1.playerIds, ...m.pair2.playerIds])
          .toList();
      expect(playing.toSet(), hasLength(8), reason: 'tidak boleh ada pemain dobel');
      expect(playing.toSet().intersection(round.resting.map((e) => e.id).toSet()), isEmpty);
    });

    test('keeps the match-count gap at most 1 across rounds', () {
      final players = _players(10);
      final history = _play(players, _courts(2), 8);

      final counts = {for (final p in players) p.id: 0};
      for (final m in history) {
        for (final id in [...m.pair1.playerIds, ...m.pair2.playerIds]) {
          counts[id] = counts[id]! + 1;
        }
      }
      final values = counts.values.toList()..sort();
      expect(values.last - values.first, lessThanOrEqualTo(1));
    });

    test('players who rested get priority in the next round', () {
      final players = _players(10);
      final first = EndlessRoundGenerator.generateRound(
        seed: 7,
        players: players,
        courts: _courts(2),
        history: const [],
        roundNumber: 1,
        random: Random(3),
      )!;
      final second = EndlessRoundGenerator.generateRound(
        seed: 7,
        players: players,
        courts: _courts(2),
        history: first.matches,
        roundNumber: 2,
        random: Random(4),
      )!;

      final playingInSecond = second.matches
          .expand((m) => [...m.pair1.playerIds, ...m.pair2.playerIds])
          .toSet();
      for (final p in first.resting) {
        expect(playingInSecond, contains(p.id));
      }
    });

    test('avoids repeating the same partner while fresh options exist', () {
      // 8 pemain, 2 court → semua main tiap round; 3 round pertama masih punya
      // banyak kombinasi partner yang belum terpakai.
      final history = _play(_players(8), _courts(2), 3);

      final partnerKeys = <String>[];
      for (final m in history) {
        for (final pair in [m.pair1, m.pair2]) {
          partnerKeys.add(([pair.player1Id, pair.player2Id]..sort()).join('+'));
        }
      }
      expect(partnerKeys.toSet(), hasLength(partnerKeys.length));
    });

    test('returns null when there are not enough players for one match', () {
      expect(
        EndlessRoundGenerator.generateRound(
          seed: 7,
          players: _players(3),
          courts: _courts(2),
          history: const [],
          roundNumber: 1,
          random: Random(1),
        ),
        isNull,
      );
    });

    test('caps matches at the number of courts', () {
      final round = EndlessRoundGenerator.generateRound(
        seed: 7,
        players: _players(20),
        courts: _courts(3),
        history: const [],
        roundNumber: 1,
        random: Random(9),
      )!;
      expect(round.matches, hasLength(3));
      expect(round.resting, hasLength(8));
    });
  });
}
