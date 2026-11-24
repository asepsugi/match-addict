import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';
import 'package:match_addict/services/schedule/sparing_fixed_generator.dart';

import 'sparing_mixed_property.dart';

/// Batas 32 pemain (PRD 8.1, AC-B3…B5): ukuran baru yang tidak tercakup test properti 3.9.x.

List<Player> _players(int n) => [
  for (var i = 0; i < n; i++) Player(id: 'p${i.toString().padLeft(2, '0')}', name: 'P$i'),
];

List<Court> _courts(int n, [int minutes = 120]) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: minutes),
];

List<Pair> _pairs(String tag, int n) => [
  for (var i = 0; i < n; i++)
    Pair(
      id: '$tag${i.toString().padLeft(2, '0')}',
      player1Id: '${tag}a${i.toString().padLeft(2, '0')}',
      player2Id: '${tag}b${i.toString().padLeft(2, '0')}',
    ),
];

Set<String> _of(MatchGame m) => {...m.pair1.playerIds, ...m.pair2.playerIds};

/// Invariant satu round untuk 32 pemain: pemain paling banyak sekali, ukuran sesuai court yang muat, istirahat sisanya,
/// dan selisih main kumulatif ≤ 1. Dikembalikan court yang pernah dipakai.
Set<String> _checkRounds(
  int courts,
  EndlessRound Function(List<Player> ps, List<Court> cs, List<MatchGame> history, int n) make,
) {
  final ps = _players(32), cs = _courts(courts);
  final history = <MatchGame>[];
  final played = {for (final p in ps) p.id: 0};
  final used = <String>{};
  final slots = min(courts, 8) * 4;
  for (var n = 1; n <= 30; n++) {
    final made = make(ps, cs, history, n);
    final ids = [for (final m in made.matches) ..._of(m)];
    expect(ids.toSet(), hasLength(ids.length), reason: 'R$n pemain dua kali');
    expect(ids, hasLength(slots), reason: 'R$n slot');
    expect(made.resting, hasLength(32 - slots), reason: 'R$n istirahat');
    for (final id in ids) {
      played[id] = played[id]! + 1;
    }
    expect(played.values.reduce(max) - played.values.reduce(min), lessThanOrEqualTo(1), reason: '32/$courts R$n');
    used.addAll([for (final m in made.matches) m.courtId]);
    // Skor sah tetap, supaya urutan Mexicano bergerak.
    history.addAll([
      for (final m in made.matches) m.withScore([SetScore(side1: 21, side2: 10 + n % 9)]),
    ]);
  }
  return used;
}

void main() {
  for (final courts in [1, 2, 7, 8, 10]) {
    // 32/10: Court 9–10 tidak pernah dapat match; 32/8 dan 32/10 tanpa istirahat (dicek lewat 32 − slot = 0).
    final expectedCourts = {for (var i = 1; i <= min(courts, 8); i++) 'c$i'};

    test('AC-B3 Mixed 32 / $courts court × 30 round', () {
      final rng = Random(32 * 31 + courts);
      final used = _checkRounds(
        courts,
        (ps, cs, history, n) => EndlessRoundGenerator.generateRound(
          players: ps,
          courts: cs,
          history: history,
          roundNumber: n,
          seed: 20261124,
          random: rng,
        )!,
      );
      expect(used, expectedCourts);
    });

    // Invariant penuh Mexicano (urutan, susunan) ada di `mexicano_property_test.dart`; di sini ukuran 32.
    test('AC-B3 Mexicano 32 / $courts court × 30 round', () {
      final used = _checkRounds(
        courts,
        (ps, cs, history, n) => EndlessRoundGenerator.generateMexicanoRound(
          players: ps,
          courts: cs,
          history: history,
          roundNumber: n,
          seed: 20261124,
          format: const ScoreFormat(ScoringMethod.americano, 21),
        )!,
      );
      expect(used, expectedCourts);
    });
  }

  test('AC-B4 Fixed 16 pasangan: 120 match, tiap pasangan bertemu tiap lainnya sekali; 2 court → 60 round', () {
    final s = RoundRobinGenerator.generate(pairs: _pairs('f', 16), courts: _courts(2));
    expect(s.matches, hasLength(120));
    expect(s.roundCount, 60);
    final seen = <String>{};
    for (final m in s.matches) {
      final key = ([m.pair1.id, m.pair2.id]..sort()).join('|');
      expect(seen.add(key), isTrue, reason: 'duplikat $key');
    }
    expect(seen, hasLength(16 * 15 ~/ 2));
    for (var r = 1; r <= 60; r++) {
      final round = s.matches.where((m) => m.roundNumber == r).toList();
      expect(round, hasLength(2), reason: 'R$r');
      expect(
        {
          for (final m in round) ...[m.pair1.id, m.pair2.id],
        },
        hasLength(4),
        reason: 'R$r',
      );
    }
    expect(s.byePairIdByRound, isEmpty);
  });

  group('AC-B5 Sparing', () {
    ({int rounds, int matches, int activeCourts, int overMinutes}) est(int n1, int n2, int courts) =>
        SparingFixedGenerator.estimate(
          players1: n1,
          players2: n2,
          bookingMinutes: List.filled(courts, 120),
          matchDurationMinutes: 15,
        );

    test('Fixed 8 / 8 pasangan, 4 court → 16 round · lewat booking 02:00', () {
      expect(est(16, 16, 4), (rounds: 16, matches: 64, activeCourts: 4, overMinutes: 120));
      final s = SparingFixedGenerator.generate(club1: _pairs('g', 8), club2: _pairs('m', 8), courts: _courts(4));
      expect(s.matches, hasLength(64));
      expect(s.roundCount, 16);
    });

    test('Fixed 15 / 1 pasangan, 2 court → 15 match, 15 round, Court 2 kosong', () {
      expect(est(30, 2, 2), (rounds: 15, matches: 15, activeCourts: 1, overMinutes: 105));
      final s = SparingFixedGenerator.generate(club1: _pairs('g', 15), club2: _pairs('m', 1), courts: _courts(2));
      expect(s.matches, hasLength(15));
      expect(s.roundCount, 15);
      expect({for (final m in s.matches) m.courtId}, {'c1'});
    });

    // Mixed 16 / 16 dan 30 / 2: properti AC-S9 (selisih ≤ 1 per klub, bentuk round) lewat `checkSize`.
    for (final courts in [1, 2, 3, 4, 7, 10]) {
      test('Mixed sparing 16 / 16 × $courts court × 30 round', () => checkSize(16, 16, courts));
      test('Mixed sparing 30 / 2 × $courts court × 30 round', () => checkSize(30, 2, courts));
    }
  });
}
