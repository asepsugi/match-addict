import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/scoring/score_entry.dart';

/// Invariant generator Mexicano (logic.md §14.3, AC-M8) dan ukuran (AC-M9). Suite biasa: tiap ukuran 30 round, satu
/// seed, skor Americano 21 acak berseed yang sah + ±10% WO. Oracle urutan dihitung ulang dari
/// `RankingCalculator.compare` + undian, bukan memanggil `mexicanoOrder`.

const _fmt = ScoreFormat(ScoringMethod.americano, 21);

List<Player> _players(int n) => [
  for (var i = 0; i < n; i++) Player(id: 'p${i.toString().padLeft(2, '0')}', name: 'P$i'),
];

List<Court> _courts(int n) => [
  for (var i = 0; i < n; i++)
    Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: 720),
];

Set<String> _of(MatchGame m) => {...m.pair1.playerIds, ...m.pair2.playerIds};

int _partner(List<MatchGame> history, String a, String b) => history
    .where((m) => m.status != MatchStatus.cancelled)
    .where((m) => [m.pair1, m.pair2].any((p) => p.contains(a) && p.contains(b)))
    .length;

/// Skor akhir sah acak untuk satu match, atau WO (±10%).
MatchGame _play(MatchGame m, Random rng) {
  if (rng.nextInt(10) == 0) {
    return m.asWalkover(loserPairId: rng.nextBool() ? m.pair1.id : m.pair2.id, reason: WoReason.absent);
  }
  final winner = _fmt.minWinningScore + rng.nextInt(_fmt.target - _fmt.minWinningScore + 1);
  final loser = rng.nextInt(min(_fmt.target - winner, winner - 1) + 1);
  final (a, b) = rng.nextBool() ? (winner, loser) : (loser, winner);
  expect(ScoreRules.judge(_fmt, a, b), isA<ScoreWin>());
  return m.withScore([SetScore(side1: a, side2: b)]);
}

/// Menjalankan [rounds] round untuk [players]/[courts], memanggil [check] sebelum skor tiap round diisi.
void _run(
  int players,
  int courts,
  int rounds, {
  int seed = 20261111,
  void Function(int round, List<MatchGame> before, EndlessRound made)? check,
}) {
  final ps = _players(players), cs = _courts(courts);
  final history = <MatchGame>[];
  final rng = Random(seed ^ players * 31 ^ courts);
  for (var n = 1; n <= rounds; n++) {
    final before = [...history];
    EndlessRound make() => EndlessRoundGenerator.generateMexicanoRound(
      players: ps,
      courts: cs,
      history: before,
      roundNumber: n,
      seed: seed,
      format: _fmt,
    )!;
    final made = make();
    // 5. Pasti: input sama → round sama persis.
    final again = make();
    expect(
      [for (final m in again.matches) '${m.courtId} ${m.pair1.id} ${m.pair2.id}'],
      [for (final m in made.matches) '${m.courtId} ${m.pair1.id} ${m.pair2.id}'],
    );
    check?.call(n, before, made);
    history.addAll([for (final m in made.matches) _play(m, rng)]);
  }
}

void main() {
  group('AC-M8 invariant 30 round', () {
    for (final (players, courts) in [(4, 1), (5, 1), (7, 2), (8, 2), (9, 2), (10, 2), (12, 3), (16, 4), (30, 10)]) {
      test('AC-M8 $players pemain / $courts court', () {
        final ps = _players(players), cs = _courts(courts);
        final played = {for (final p in ps) p.id: 0};
        _run(
          players,
          courts,
          30,
          check: (n, before, made) {
            final slots = EndlessRoundGenerator.slotsFor(players: players, courts: courts);
            expect(made.matches.length * 4, slots);

            // 2. Tiap pemain paling banyak sekali per round; tiap match 4 pemain berbeda.
            final ids = [for (final m in made.matches) ..._of(m)];
            for (final m in made.matches) {
              expect(_of(m), hasLength(4));
            }
            expect(ids.toSet(), hasLength(ids.length));
            expect({...ids, ...made.resting.map((p) => p.id)}, {for (final p in ps) p.id});

            // 1. Selisih main ≤ 1 setelah round ini.
            for (final id in ids) {
              played[id] = played[id]! + 1;
            }
            expect(played.values.reduce(max) - played.values.reduce(min), lessThanOrEqualTo(1), reason: 'R$n');

            // 3. Kelompok court ke-i = posisi 4i..4i+3 urutan Mexicano yang main; court ke-i = court muat ke-i.
            final draw = EndlessRoundGenerator.lockedDraw(ps.map((p) => p.id), seed: 20261111, roundNumber: n);
            final standing = {
              for (final s in RankingCalculator.rank(
                players: ps,
                matches: before,
                method: RankingMethod.totalGames,
                format: _fmt,
              ))
                s.player.id: s,
            };
            final oracle = ids.toList()
              ..sort((a, b) {
                final byRank = RankingCalculator.compare(standing[a]!, standing[b]!, RankingMethod.totalGames);
                if (byRank != 0) return byRank;
                final byDraw = draw[a]!.compareTo(draw[b]!);
                return byDraw != 0 ? byDraw : a.compareTo(b);
              });
            for (final (i, m) in made.matches.indexed) {
              expect(m.courtId, cs[i].id);
              final p = oracle.sublist(4 * i, 4 * i + 4);
              expect(_of(m), p.toSet(), reason: 'R$n court ${i + 1}');

              // 4. Susunan = beban terkecil A/B/C, seri → yang lebih dulu; sisi atas berisi posisi 1.
              final options = [(0, 2, 1, 3), (0, 3, 1, 2), (0, 1, 2, 3)];
              final loads = [
                for (final (a, b, c, d) in options) _partner(before, p[a], p[b]) + _partner(before, p[c], p[d]),
              ];
              final pick = options[loads.indexOf(loads.reduce(min))];
              expect(
                [m.pair1.player1Id, m.pair1.player2Id, m.pair2.player1Id, m.pair2.player2Id],
                [p[pick.$1], p[pick.$2], p[pick.$3], p[pick.$4]],
                reason: 'R$n court ${i + 1} beban $loads',
              );
            }
          },
        );
      });
    }
  });

  group('AC-M9 ukuran', () {
    test('AC-M9 4/1 tanpa istirahat', () {
      _run(4, 1, 6, check: (n, before, made) => expect(made.resting, isEmpty));
    });

    test('AC-M9 5/1 satu istirahat per round, setelah R5 semua 4 match', () {
      final played = <String, int>{};
      _run(
        5,
        1,
        5,
        check: (n, before, made) {
          expect(made.resting, hasLength(1));
          for (final id in _of(made.matches.single)) {
            played[id] = (played[id] ?? 0) + 1;
          }
        },
      );
      expect(played.values.toSet(), {4});
      expect(played, hasLength(5));
    });

    test('AC-M9 7/2 hanya Court 1, 3 istirahat', () {
      _run(
        7,
        2,
        6,
        check: (n, before, made) {
          expect([for (final m in made.matches) m.courtId], ['c1']);
          expect(made.resting, hasLength(3));
        },
      );
    });

    test('AC-M9 30/10 Court 1–7 dipakai, Court 8–10 kosong, 2 istirahat', () {
      _run(
        30,
        10,
        4,
        check: (n, before, made) {
          expect([for (final m in made.matches) m.courtId], [for (var i = 1; i <= 7; i++) 'c$i']);
          expect(made.resting, hasLength(2));
        },
      );
    });
  });
}
