// Cek angka frame Fixed sparing (14h, 14l, 14n, 14s, 14t, 14u) dengan generator + kalkulator.
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:sparing_proto/sparing_fixed.dart';

import 'examples_test.dart' show g, mp, courtsOf, clubScore, garuda, matcha;

List<MatchGame> scored(List<MatchGame> ms, List<(int, int)> s) => [
  for (final (i, m) in ms.indexed) m.withScore([SetScore(side1: s[i].$1, side2: s[i].$2)]),
];

void main() {
  final base = SparingFixedGenerator.generate(club1: g, club2: mp, courts: courtsOf(2)).matches;
  final all = [...garuda, ...matcha];

  test('14n round tambahan R7–R12 (satuan pertama, K = g + 0)', () {
    final ext = SparingFixedGenerator.extend(
        club1: g, club2: mp, courts: courtsOf(2), roundsLeft: [2, 2], unitsDone: 0, firstRound: 7);
    for (var r = 7; r <= 12; r++) {
      // ignore: avoid_print
      print('R$r ${ext.schedule.matches.where((m) => m.roundNumber == r).map((m) => '${m.pair1.id}-${m.pair2.id}').join(', ')}'
          ' | istirahat ${ext.schedule.restingPairIdsByRound[r]!.join(', ')}');
    }
  });

  for (final (id, fmt, s, expected) in [
    ('14s', const ScoreFormat(ScoringMethod.raceTo, 6),
        [(6, 4), (3, 6), (6, 2), (4, 6), (5, 6), (6, 3), (6, 5), (2, 6), (4, 6), (6, 4), (5, 6), (3, 6)], (5.0, 7.0, 56, 60)),
    ('14t', const ScoreFormat(ScoringMethod.raceTo, 6),
        [(6, 4), (6, 5), (3, 6), (6, 2), (5, 6), (2, 6), (6, 3), (4, 6), (6, 4), (3, 6), (6, 4), (5, 6)], (6.0, 6.0, 58, 58)),
    ('14u', const ScoreFormat(ScoringMethod.americano, 20),
        [(12, 8), (9, 11), (13, 7), (10, 10), (11, 9), (8, 12), (14, 6), (7, 13), (9, 11), (12, 8), (11, 9), (6, 14)], (6.5, 5.5, null, null)),
  ]) {
    test('$id skor klub', () {
      final ms = scored(base, s);
      final cs = clubScore(ms, fmt, {});
      // ignore: avoid_print
      print('$id: ${cs.w1}–${cs.w2}, TP ${cs.tp1}–${cs.tp2}, selisih ${cs.d1}');
      expect((cs.w1, cs.w2), (expected.$1, expected.$2));
      if (expected.$3 != null) expect((cs.tp1, cs.tp2), (expected.$3, expected.$4));
      final st = RankingCalculator.rank(players: all, matches: ms, method: RankingMethod.totalGames, format: fmt);
      final ids = {for (final p in mp) ...p.playerIds};
      final rows = standingEntries(
          standings: st.where((x) => ids.contains(x.player.id)).toList(), method: RankingMethod.totalGames, fixedPairs: mp);
      // ignore: avoid_print
      print('  Matcha TP: ${rows.map((e) => '#${e.position} ${e.label} ${e.standing.totalPoint} (${e.standing.diffLabel}) W${e.standing.wins}').join(' · ')}');
      final gids = {for (final p in g) ...p.playerIds};
      final grows = standingEntries(
          standings: st.where((x) => gids.contains(x.player.id)).toList(), method: RankingMethod.totalGames, fixedPairs: g);
      // ignore: avoid_print
      print('  Garuda TP: ${grows.map((e) => '#${e.position} ${e.label} ${e.standing.totalPoint} (${e.standing.diffLabel}) W${e.standing.wins}').join(' · ')}');
    });
  }
}
