import '../../models/models.dart';
import 'endless_round_generator.dart';

/// Tukar pemain Mixed (PRD §15, logic.md §15). Semua fungsi total: input tidak sah → false / kosong / null, tidak
/// melempar. Tidak memanggil generator pembuat round, `Random`, atau undian: tukar hanya mengganti satu id.
abstract final class PlayerSwap {
  /// T1 + T2: [match] bisa ditukar. Syaratnya `mode == mixed`, bukan `isEndless`: Mexicano dikunci (keputusan 52) dan
  /// Fixed tidak berlaku (53). Waktu booking tidak dilihat: waktu habis tetap boleh.
  static bool isSwappable(ActiveTournament active, MatchGame match) =>
      active.config.mode == PartnerMode.mixed &&
      !active.tournament.isFinished &&
      match.roundNumber == active.roundCount &&
      match.status == MatchStatus.pending;

  /// T4: [inId] boleh masuk menggantikan pemain tim [team]: aktif, tidak main di round terakhir, dan di sparing
  /// sesama klub dengan [team] (keputusan 51).
  static bool isCandidate(ActiveTournament active, Pair team, String inId) {
    if (!active.activePlayers.any((p) => p.id == inId)) return false;
    if (_playingIn(active, active.roundCount).contains(inId)) return false;
    if (!active.config.isSparing) return true;
    final club = active.config.clubOfPair(team);
    return club != null && active.config.playerById(inId)?.clubId == club.id;
  }

  /// Ikon tim di baris match. Tidak butuh jam: [candidates] hanya membagi himpunan yang sama.
  static bool canSwapTeam(ActiveTournament active, MatchGame match, Pair team) =>
      isSwappable(active, match) &&
      (team.id == match.pair1.id || team.id == match.pair2.id) &&
      active.activePlayers.any((p) => isCandidate(active, team, p.id));

  /// Kandidat untuk sheet, dibagi dan diurut sama persis dengan daftar Istirahat Jadwal pada [now] (bukan dihitung
  /// ulang, supaya label dan urutannya tidak bisa menyimpang).
  static ({List<Player> priority, List<Player> later}) candidates(
    ActiveTournament active,
    MatchGame match,
    Pair team,
    DateTime now,
  ) {
    const none = (priority: <Player>[], later: <Player>[]);
    if (!isSwappable(active, match)) return none;
    if (!active.config.isSparing) return EndlessRoundGenerator.restingAfterLastRound(active, now);
    final club = active.config.clubOfPair(team);
    if (club == null) return none;
    for (final entry in EndlessRoundGenerator.restingByClubAfterLastRound(active, now)) {
      if (entry.club.id == club.id) return (priority: entry.priority, later: entry.later);
    }
    return none;
  }

  /// T3: [match] dengan [inId] di slot [outId]. Slot tidak diurut ulang; hanya id pasangan yang berubah dihitung
  /// ulang, supaya tukar balik menghasilkan match yang byte-sama. [outId] tidak ada di match → [match] apa adanya.
  ///
  /// Salinan di bawah wajib membawa SEMUA field [MatchGame] (`copyWith` tidak bisa dipakai: tidak mengganti pasangan).
  /// Field baru di model harus ditambahkan di sini juga.
  static MatchGame swapped(MatchGame match, {required String outId, required String inId}) {
    if (!match.pair1.contains(outId) && !match.pair2.contains(outId)) return match;
    Pair replace(Pair pair) {
      if (!pair.contains(outId)) return pair;
      final p1 = pair.player1Id == outId ? inId : pair.player1Id;
      final p2 = pair.player2Id == outId ? inId : pair.player2Id;
      return Pair(id: EndlessRoundGenerator.pairId(p1, p2), player1Id: p1, player2Id: p2);
    }

    return MatchGame(
      id: match.id,
      roundNumber: match.roundNumber,
      matchNumberInRound: match.matchNumberInRound,
      courtId: match.courtId,
      pair1: replace(match.pair1),
      pair2: replace(match.pair2),
      sets: match.sets,
      status: match.status,
      woLoserPairId: match.woLoserPairId,
      woReason: match.woReason,
    );
  }

  /// T3 + T5: turnamen setelah tukar (logic.md §15.1), atau null kalau tidak sah.
  static ActiveTournament? apply(
    ActiveTournament active, {
    required String matchId,
    required String outId,
    required String inId,
  }) {
    final match = active.matchById(matchId);
    if (match == null || outId == inId || !isSwappable(active, match)) return null;
    final team = match.pair1.contains(outId)
        ? match.pair1
        : match.pair2.contains(outId)
        ? match.pair2
        : null;
    if (team == null || !isCandidate(active, team, inId)) return null;

    final n = match.roundNumber;
    // Pemain keluar yang sudah dikeluarkan (keputusan 54) tetap dicatat di sini; daftar Istirahat menyaringnya sendiri.
    final resting = [...?active.restingPlayerIdsByRound[n]];
    final at = resting.indexOf(inId);
    if (at >= 0) {
      resting[at] = outId;
    } else {
      resting.add(outId);
    }
    return active.copyWith(
      tournament: active.tournament.copyWith(
        matches: [
          for (final m in active.matches)
            if (m.id == matchId) swapped(m, outId: outId, inId: inId) else m,
        ],
      ),
      resting: {...active.restingPlayerIdsByRound, n: resting},
    );
  }

  static Set<String> _playingIn(ActiveTournament active, int round) => {
    for (final m in active.matchesOfRound(round)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
  };
}
