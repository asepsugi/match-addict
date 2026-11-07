import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/ranking/club_score.dart';
import 'tournament_controller.dart';

/// Skor klub turnamen sparing aktif; null untuk turnamen biasa atau tanpa turnamen. Status Sementara/Final tetap
/// dari `ActiveTournament.isFinal(now)`.
final clubScoreProvider = Provider<ClubScore?>((ref) {
  final active = ref.watch(tournamentProvider);
  return active == null ? null : ClubScore.of(active);
});

/// Klasemen per klub menurut [rankingMethodProvider], nomor mulai #1 di tiap klub. Satu-satunya sumber untuk
/// Klasemen, Detail, Bagikan, caption, dan Live; kosong kalau bukan sparing.
final clubStandingEntriesProvider = Provider<List<ClubStandings>>((ref) {
  final active = ref.watch(tournamentProvider);
  if (active == null) return const [];
  return clubStandings(
    active: active,
    standings: ref.watch(standingsProvider),
    method: ref.watch(rankingMethodProvider),
  );
});

/// Klub dan nomor peringkat satu pemain di dalam klubnya (Detail: "Peringkat n · {klub}"); null kalau bukan sparing
/// atau pemain tidak ada. `position` null = belum main.
final playerClubPositionProvider = Provider.family<({Club club, int? position})?, String>((ref, playerId) {
  for (final group in ref.watch(clubStandingEntriesProvider)) {
    for (final entry in group.entries) {
      if (entry.hasPlayer(playerId)) return (club: group.club, position: entry.position);
    }
  }
  return null;
});
