import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/schedule/player_swap.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi/screens/sparing_mixed_fixture.dart';
import 'player_swap_fixture.dart';

/// Properti tukar pemain (logic.md §15.4 Properti): 12 round, tiap round 0–2 tukar sah acak sebelum skor diisi, kadang
/// langsung ditukar balik. Invariant §15.3 #1–#5, #7, #9 setelah tiap tukar, #6 untuk tukar balik. Selisih main
/// sengaja tidak di-assert (keputusan 50).
void main() {
  const rounds = 12;

  ActiveTournament scoreRound(ActiveTournament a) => a.copyWith(
    tournament: a.tournament.copyWith(
      matches: [
        for (final m in a.matches)
          if (m.status == MatchStatus.pending) m.withScore(const [SetScore(side1: 12, side2: 9)]) else m,
      ],
    ),
  );

  ActiveTournament nextRound(ActiveTournament a, Random rng) {
    final n = a.roundCount + 1;
    final round = a.config.isSparing
        ? EndlessRoundGenerator.generateSparingRound(
            club1: a.activePlayersByClub.$1,
            club2: a.activePlayersByClub.$2,
            courts: a.config.courts,
            history: a.matches,
            roundNumber: n,
            seed: a.drawSeed,
            latePlayerIds: a.latePlayerIds,
            random: rng,
          )!
        : EndlessRoundGenerator.generateRound(
            players: a.activePlayers,
            courts: a.config.courts,
            history: a.matches,
            roundNumber: n,
            seed: a.drawSeed,
            latePlayerIds: a.latePlayerIds,
            random: rng,
          )!;
    return a.copyWith(
      tournament: a.tournament.copyWith(matches: [...a.matches, ...round.matches]),
      resting: {...a.restingPlayerIdsByRound, n: round.resting.map((p) => p.id).toList()},
    );
  }

  /// Satu tukar sah acak dari `canSwapTeam` + `candidates`, atau null kalau round ini tidak punya.
  ({String matchId, String outId, String inId})? pick(ActiveTournament a, Random rng, DateTime now) {
    final options = <({MatchGame match, Pair team})>[
      for (final m in a.matchesOfRound(a.roundCount))
        for (final team in [m.pair1, m.pair2])
          if (PlayerSwap.canSwapTeam(a, m, team)) (match: m, team: team),
    ];
    if (options.isEmpty) return null;
    final o = options[rng.nextInt(options.length)];
    final c = PlayerSwap.candidates(a, o.match, o.team, now);
    final all = [...c.priority, ...c.later];
    expect(all, isNotEmpty);
    return (matchId: o.match.id, outId: o.team.playerIds[rng.nextInt(2)], inId: all[rng.nextInt(all.length)].id);
  }

  /// Di antara round: kadang keluarkan, kembalikan, atau tambah pemain (batas 30 aktif, sparing sisa klub ≥ 2), supaya
  /// pemain telat, P yang dikeluarkan, dan invariant #4 ikut teruji.
  ActiveTournament changeRoster(ActiveTournament a, Random rng) {
    switch (rng.nextInt(4)) {
      case 0:
        final ids = [
          for (final p in a.activePlayers)
            if (a.canWithdraw(p.id)) p.id,
        ];
        if (ids.isEmpty) return a;
        return a.copyWith(withdrawn: {...a.withdrawnPlayerIds, ids[rng.nextInt(ids.length)]});
      case 1:
        final ids = [
          for (final id in a.withdrawnPlayerIds)
            if (a.canReinstate(id)) id,
        ];
        if (ids.isEmpty || a.activePlayers.length >= TournamentConfig.maxPlayers) return a;
        return a.copyWith(withdrawn: {...a.withdrawnPlayerIds}..remove(ids[rng.nextInt(ids.length)]));
      case 2:
        if (a.activePlayers.length >= TournamentConfig.maxPlayers) return a;
        final clubs = a.config.clubs;
        final player = Player(
          id: 'new${a.config.players.length}',
          name: 'New${a.config.players.length}',
          clubId: clubs?[rng.nextInt(2)].id,
        );
        return a.copyWith(
          tournament: a.tournament.copyWith(config: a.config.copyWith(players: [...a.config.players, player])),
        );
      default:
        return a;
    }
  }

  void run(String label, ActiveTournament start, int seed) {
    test(label, () {
      final rng = Random(seed);
      var active = start;
      var swaps = 0;
      for (var r = 1; r <= rounds; r++) {
        if (r > 1) active = changeRoster(active, rng);
        active = nextRound(active, rng);
        // Jam = awal turnamen: semua court masih muat, sama dengan court yang dipakai generator di atas.
        final at = start.tournament.createdAt;
        expect(active.courtsAvailableAt(at).length, active.config.courts.length);
        ({String matchId, String outId, String inId, ActiveTournament before})? last;
        for (var k = rng.nextInt(3); k > 0; k--) {
          final back = last != null && rng.nextDouble() < 0.3;
          final move = back ? (matchId: last.matchId, outId: last.inId, inId: last.outId) : pick(active, rng, at);
          if (move == null) break;
          final next = PlayerSwap.apply(active, matchId: move.matchId, outId: move.outId, inId: move.inId);
          expect(next, isNotNull, reason: 'tukar dari canSwapTeam + candidates selalu sah');
          expectSwapInvariants(active, next!, matchId: move.matchId, outId: move.outId, inId: move.inId);
          expectSwapListMatchesCreate(next, at);
          if (back) {
            expect(TournamentCodec.encode(next), TournamentCodec.encode(last.before), reason: '#6 tukar balik identik');
            last = null;
          } else {
            last = (matchId: move.matchId, outId: move.outId, inId: move.inId, before: active);
          }
          active = next;
          swaps++;
        }
        active = scoreRound(active);
      }
      expect(swaps, greaterThan(0), reason: 'seed ini harus benar-benar menukar');
    });
  }

  ActiveTournament mixed(int players, int courts) => swapActive(
    const [],
    config: swapConfig(names: [for (var i = 0; i < players; i++) 'P${i.toString().padLeft(2, '0')}'], courts: courts),
  );

  for (final (players, courts) in [(9, 2), (10, 2), (12, 2), (14, 3), (30, 4)]) {
    for (final seed in [1, 2, 3]) {
      run('Mixed $players pemain / $courts court, seed $seed', mixed(players, courts), seed);
    }
  }

  for (final (garudaCount, seed) in [(8, 1), (8, 2), (4, 1), (4, 2)]) {
    run(
      'Sparing Garuda $garudaCount / Matcha 6, 2 court, seed $seed',
      mixedSparingEmpty(mixedSparingConfig(garudaPlayers: garudaNames.take(garudaCount).toList())),
      seed,
    );
  }
}
