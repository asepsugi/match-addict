import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_generator.dart';

List<Player> _players(int n) =>
    [for (var i = 0; i < n; i++) Player(id: 'p$i', name: 'Player $i')];

void main() {
  group('PairGenerator', () {
    test('pairs every player when count is even', () {
      final draft = PairGenerator.random(_players(8), random: Random(1));
      expect(draft.pairs, hasLength(4));
      expect(draft.unpaired, isEmpty);
      expect(draft.isComplete, isTrue);

      final assigned = draft.pairs.expand((p) => p.playerIds).toSet();
      expect(assigned, hasLength(8));
    });

    test('leaves one player unpaired when count is odd', () {
      final draft = PairGenerator.random(_players(7), random: Random(1));
      expect(draft.pairs, hasLength(3));
      expect(draft.unpaired, hasLength(1));
      expect(draft.isComplete, isFalse);
    });

    test('needs at least two pairs to be complete', () {
      final draft = PairGenerator.random(_players(2), random: Random(1));
      expect(draft.pairs, hasLength(1));
      expect(draft.isComplete, isFalse);
    });

    test('fromOrder keeps the given order', () {
      final draft = PairGenerator.fromOrder(_players(4));
      expect(draft.pairs.first.player1Id, 'p0');
      expect(draft.pairs.first.player2Id, 'p1');
      expect(draft.pairs.last.player1Id, 'p2');
      expect(draft.pairs.last.player2Id, 'p3');
    });
  });
}
