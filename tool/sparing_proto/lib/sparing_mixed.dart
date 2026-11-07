// Prototipe round Mixed sparing (PRD 13.4) di atas EndlessRoundGenerator.priorityOrder. Bukan kode produksi.
import 'dart:math';

import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

class SparingMixedRound {
  final List<MatchGame> matches;
  final List<Player> resting1, resting2;
  const SparingMixedRound(this.matches, this.resting1, this.resting2);
}

class SparingMixed {
  static int activeCourts(int courtsFit, int n1, int n2) => min(courtsFit, min(n1 ~/ 2, n2 ~/ 2));

  /// Urutan prioritas satu klub untuk round [round] dengan [slots] slot klub itu (priorityOrder biasa, hanya
  /// pemain klub itu, jadi jeda pemain telat k memakai slot & istirahat klub itu).
  static List<Player> clubOrder(
    List<Player> club,
    List<MatchGame> history,
    int round,
    int seed,
    int slots,
    Set<String> late,
  ) => EndlessRoundGenerator.priorityOrder(
    players: club,
    history: history,
    roundNumber: round,
    seed: seed,
    slots: slots,
    latePlayerIds: late,
  );

  static SparingMixedRound? generateRound({
    required List<Player> club1,
    required List<Player> club2,
    required List<Court> courts,
    required List<MatchGame> history,
    required int roundNumber,
    required int seed,
    Set<String> late = const {},
    required Random random,
  }) {
    final c = activeCourts(courts.length, club1.length, club2.length);
    if (c == 0) return null;
    final o1 = clubOrder(club1, history, roundNumber, seed, 2 * c, late);
    final o2 = clubOrder(club2, history, roundNumber, seed, 2 * c, late);
    final a1 = o1.take(2 * c).toList(), a2 = o2.take(2 * c).toList();
    final arr = bestArrangement(a1, a2, history, random);
    return SparingMixedRound(
      [
        for (final (i, (p1, p2)) in arr.indexed)
          MatchGame(
            id: 'm-r$roundNumber-${i + 1}',
            roundNumber: roundNumber,
            matchNumberInRound: i + 1,
            courtId: courts[i].id,
            pair1: p1,
            pair2: p2,
          ),
      ],
      o1.skip(2 * c).toList(),
      o2.skip(2 * c).toList(),
    );
  }

  /// Court baru di round berjalan [n] (Kelola court, PRD 13.7): 2 teratas prioritas R(n+1) yang istirahat dari
  /// tiap klub, kalau tiap klub punya ≥ 2 yang istirahat. [nextCourts] = court yang muat di R(n+1), termasuk court baru.
  static (List<Player>, List<Player>)? courtUseNow({
    required List<Player> club1,
    required List<Player> club2,
    required List<MatchGame> history,
    required int n,
    required int seed,
    required int nextCourts,
    Set<String> late = const {},
  }) {
    final playing = {
      for (final m in history.where((m) => m.roundNumber == n)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
    };
    final c = activeCourts(nextCourts, club1.length, club2.length);
    final w1 = clubOrder(club1, history, n + 1, seed, 2 * c, late).where((p) => !playing.contains(p.id)).toList();
    final w2 = clubOrder(club2, history, n + 1, seed, 2 * c, late).where((p) => !playing.contains(p.id)).toList();
    if (w1.length < 2 || w2.length < 2) return null;
    return (w1.take(2).toList(), w2.take(2).toList());
  }

  static String _key(String a, String b) => a.compareTo(b) <= 0 ? '$a+$b' : '$b+$a';

  static List<(Pair, Pair)> bestArrangement(List<Player> a1, List<Player> a2, List<MatchGame> history, Random rng) {
    final partner = <String, int>{}, opponent = <String, int>{}, matchup = <String>{};
    for (final m in history) {
      if (m.status == MatchStatus.cancelled) continue;
      for (final p in [m.pair1, m.pair2]) {
        final k = _key(p.player1Id, p.player2Id);
        partner[k] = (partner[k] ?? 0) + 1;
      }
      for (final x in m.pair1.playerIds) {
        for (final y in m.pair2.playerIds) {
          final k = _key(x, y);
          opponent[k] = (opponent[k] ?? 0) + 1;
        }
      }
      matchup.add(([_key(m.pair1.player1Id, m.pair1.player2Id), _key(m.pair2.player1Id, m.pair2.player2Id)]..sort()).join('|'));
    }
    List<(Pair, Pair)>? best;
    var bestPenalty = 1 << 30;
    for (var attempt = 0; attempt < 400; attempt++) {
      final s1 = [...a1]..shuffle(rng);
      final s2 = [...a2]..shuffle(rng);
      final cand = <(Pair, Pair)>[];
      var pen = 0;
      for (var i = 0; i < s1.length; i += 2) {
        final p1 = Pair(id: _key(s1[i].id, s1[i + 1].id), player1Id: s1[i].id, player2Id: s1[i + 1].id);
        final p2 = Pair(id: _key(s2[i].id, s2[i + 1].id), player1Id: s2[i].id, player2Id: s2[i + 1].id);
        cand.add((p1, p2));
        pen += 10 * ((partner[p1.id] ?? 0) + (partner[p2.id] ?? 0));
        for (final x in p1.playerIds) {
          for (final y in p2.playerIds) {
            pen += 3 * (opponent[_key(x, y)] ?? 0);
          }
        }
        if (matchup.contains(([p1.id, p2.id]..sort()).join('|'))) pen += 1000;
      }
      if (pen < bestPenalty) {
        best = cand;
        bestPenalty = pen;
        if (pen == 0) break;
      }
    }
    return best!;
  }
}
